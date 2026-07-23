import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/supabase_client.dart';
import '../../../core/dio_client.dart';
import '../../../core/config.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  const VideoCallScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final String callAttemptId = const Uuid().v4();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  WebSocketChannel? _channel;

  bool _connecting = true;
  bool _remoteJoined = false;

  // Controls & Remote state
  bool _micEnabled = true;
  bool _camEnabled = true;
  bool _remoteMicEnabled = true;
  bool _remoteCamEnabled = true;

  // Diagnostic Stats
  Timer? _statsPollTimer;
  double _bitrateMbps = 0;
  int _lastBytesReceived = 0;
  double _latencyMs = 0;
  String _connectionMethod = "Checking...";
  bool _showStatsOverlay = false;

  // --- FIX: ICE candidate race-condition guard ---
  // Candidates can arrive over the signaling WebSocket BEFORE
  // setRemoteDescription() has finished (it's async, and the WS
  // 'ice' messages can be delivered concurrently). Calling
  // addCandidate() before the remote description is set can
  // silently fail, dropping that candidate — which was causing
  // otherwise-viable direct (srflx) candidates to be lost, forcing
  // an unnecessary fallback to TURN relay. We buffer any candidates
  // that arrive too early and flush them right after
  // setRemoteDescription completes.
  bool _remoteDescriptionSet = false;
  final List<Map<String, dynamic>> _pendingCandidates = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      // 1. Fetch secure ICE servers from backend
      final response = await DioClient.instance.get(
        '/appointments/ice-servers/',
        queryParameters: {'call_attempt_id': callAttemptId},
      );
      final iceConfig = Map<String, dynamic>.from(response.data);

      // 2. Get User Media
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      _localRenderer.srcObject = _localStream;

      // 3. Create Peer Connection with dynamic config
      _pc = await createPeerConnection(iceConfig);

      for (var track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }

      _pc!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            _remoteJoined = true;
          });
          _startStatsPolling(); // Start diagnostic loop immediately
        }
      };

      _pc!.onIceCandidate = (candidate) {
        _send({'type': 'ice', 'candidate': candidate.toMap()});
      };

      _pc!.onConnectionState = (state) {
        debugPrint('PeerConnection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _startStatsPolling();
        }
      };

      _connectSignaling();
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize call: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startStatsPolling() {
    _statsPollTimer?.cancel();
    _statsPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_pc == null || !mounted) return;

      final stats = await _pc!.getStats();
      for (var report in stats) {
        // 1. More robust detection of Method & Latency
        if (report.type == 'candidate-pair' &&
            (report.values['nominated'] == true ||
                report.values['state'] == 'succeeded')) {
          final localId = report.values['localCandidateId'];
          final remoteId = report.values['remoteCandidateId'];

          String method = "Checking...";
          try {
            final localReport = stats.firstWhere((r) => r.id == localId);
            final remoteReport = stats.firstWhere((r) => r.id == remoteId);

            final lType = localReport.values['candidateType']
                .toString()
                .toLowerCase();
            final rType = remoteReport.values['candidateType']
                .toString()
                .toLowerCase();

            if (lType == 'relay' || rType == 'relay') {
              method = "TURN (Relay)";
            } else if (lType == 'srflx' || rType == 'srflx') {
              method = "STUN (Direct)";
            } else {
              method = "HOST (Local)";
            }
          } catch (_) {}

          if (mounted) {
            setState(() {
              _connectionMethod = method;
              // Extract Latency: some devices use currentRoundTripTime or roundTripTime
              final rtt =
                  report.values['currentRoundTripTime'] ??
                  report.values['roundTripTime'] ??
                  0;
              _latencyMs = rtt * 1000;
            });
          }
        }

        // 2. Bandwidth (Incoming Bitrate)
        if (report.type == 'inbound-rtp' && report.values['kind'] == 'video') {
          int currentBytes = report.values['bytesReceived'] ?? 0;
          if (_lastBytesReceived > 0 && mounted) {
            setState(() {
              _bitrateMbps =
                  ((currentBytes - _lastBytesReceived) * 8) / (2 * 1000000);
            });
          }
          _lastBytesReceived = currentBytes;
        }
      }
    });
  }

  // --- FIX: queue-or-apply helper ---
  Future<void> _handleIncomingCandidate(Map<String, dynamic> c) async {
    if (!_remoteDescriptionSet) {
      _pendingCandidates.add(c);
      debugPrint(
        'Queued ICE candidate (remote description not set yet). '
        'Queue size: ${_pendingCandidates.length}',
      );
      return;
    }
    await _addCandidateFromMap(c);
  }

  Future<void> _addCandidateFromMap(Map<String, dynamic> c) async {
    if (_pc == null) return;
    try {
      await _pc!.addCandidate(
        RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
      );
    } catch (e) {
      debugPrint('Failed to add ICE candidate: $e');
    }
  }

  // --- FIX: call immediately after every setRemoteDescription ---
  Future<void> _flushPendingCandidates() async {
    _remoteDescriptionSet = true;
    if (_pendingCandidates.isEmpty) return;
    debugPrint('Flushing ${_pendingCandidates.length} queued ICE candidates');
    for (final c in _pendingCandidates) {
      await _addCandidateFromMap(c);
    }
    _pendingCandidates.clear();
  }

  void _connectSignaling() {
    final token = supabase.auth.currentSession?.accessToken;
    _channel = WebSocketChannel.connect(
      Uri.parse(
        '${Config.wsBaseUrl}/ws/video/${widget.appointmentId}/?token=$token',
      ),
    );

    _channel!.stream.listen((event) async {
      final data = jsonDecode(event);
      switch (data['type']) {
        case 'ready':
          // FIX: Glare handling with "Polite/Impolite" peer logic.
          // Patient = Impolite (always initiates offer when ready).
          // Doctor = Polite (waits for offer, but sends ready back if they were already there).
          final userProfile = ref.read(currentUserProfileProvider).valueOrNull;
          final isPatient = userProfile?['role'] == 'patient';

          if (isPatient) {
            debugPrint('Signaling: Received ready, I am patient (Impolite), initiating offer.');
            await _createOffer();
          } else {
            debugPrint('Signaling: Received ready, I am doctor (Polite), acknowledging presence.');
            // Only send ready back if we are NOT the one who just joined
            // (The server doesn't echo our own ready back to us, so this is safe).
            _send({'type': 'ready'});
          }
          break;
        case 'offer':
          await _pc!.setRemoteDescription(
            RTCSessionDescription(data['sdp'], data['sdpType']),
          );
          await _flushPendingCandidates(); // FIX: flush right after remote desc is set
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          _send({'type': 'answer', 'sdp': answer.sdp, 'sdpType': answer.type});
          break;
        case 'answer':
          await _pc!.setRemoteDescription(
            RTCSessionDescription(data['sdp'], data['sdpType']),
          );
          await _flushPendingCandidates(); // FIX: flush right after remote desc is set
          break;
        case 'ice':
          final c = data['candidate'];
          await _handleIncomingCandidate(
            c,
          ); // FIX: queue-or-apply instead of direct add
          break;
        case 'toggle-audio':
          setState(() => _remoteMicEnabled = data['enabled']);
          break;
        case 'toggle-video':
          setState(() => _remoteCamEnabled = data['enabled']);
          break;
        case 'bye':
          _hangUp();
          break;
      }
    }, onError: (e) => debugPrint('Signaling error: $e'));

    _send({'type': 'ready'});
    setState(() => _connecting = false);
  }

  Future<void> _createOffer() async {
    if (_pc == null) return;
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _send({'type': 'offer', 'sdp': offer.sdp, 'sdpType': offer.type});
  }

  void _send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  void _toggleMic() {
    if (_localStream == null) return;
    setState(() => _micEnabled = !_micEnabled);
    for (var track in _localStream!.getAudioTracks()) {
      track.enabled = _micEnabled;
    }
    _send({'type': 'toggle-audio', 'enabled': _micEnabled});
  }

  void _toggleCam() {
    if (_localStream == null) return;
    setState(() => _camEnabled = !_camEnabled);
    for (var track in _localStream!.getVideoTracks()) {
      track.enabled = _camEnabled;
    }
    _send({'type': 'toggle-video', 'enabled': _camEnabled});
  }

  Future<void> _hangUp() async {
    _statsPollTimer?.cancel();
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }
    await _pc?.close();
    _pc = null;
    _channel?.sink.close();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _statsPollTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _pc?.close();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _connecting
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                // Remote Video
                Positioned.fill(
                  child: !_remoteJoined
                      ? const Center(
                          child: Text(
                            'Waiting for the other person...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : Stack(
                          children: [
                            RTCVideoView(
                              _remoteRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                            if (!_remoteCamEnabled)
                              Container(
                                color: Colors.black87,
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.videocam_off,
                                        color: Colors.white54,
                                        size: 80,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Remote camera is off',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (!_remoteMicEnabled)
                              Positioned(
                                top: 40,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.mic_off,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Remote muted',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),

                // Local Video Preview
                if (_camEnabled)
                  Positioned(
                    top: 40,
                    right: 16,
                    width: 110,
                    height: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RTCVideoView(_localRenderer, mirror: true),
                    ),
                  ),

                // Control Buttons & Diagnostic Overlay
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showStatsOverlay)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Method: $_connectionMethod',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Latency: ${_latencyMs.toStringAsFixed(0)} ms',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Bandwidth: ${_bitrateMbps.toStringAsFixed(2)} Mbps',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Diagnostic Button
                          MouseRegion(
                            onEnter: (_) =>
                                setState(() => _showStatsOverlay = true),
                            onExit: (_) =>
                                setState(() => _showStatsOverlay = false),
                            child: GestureDetector(
                              onTap: () => setState(
                                () => _showStatsOverlay = !_showStatsOverlay,
                              ),
                              onLongPressStart: (_) =>
                                  setState(() => _showStatsOverlay = true),
                              onLongPressEnd: (_) =>
                                  setState(() => _showStatsOverlay = false),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: _showStatsOverlay
                                    ? Colors.blueAccent
                                    : Colors.white12,
                                child: const Icon(
                                  Icons.analytics_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          _ControlButton(
                            icon: _micEnabled ? Icons.mic : Icons.mic_off,
                            color: _micEnabled ? Colors.white24 : Colors.red,
                            onPressed: _toggleMic,
                          ),
                          const SizedBox(width: 16),
                          FloatingActionButton(
                            heroTag: 'hangup',
                            backgroundColor: Colors.red,
                            onPressed: _hangUp,
                            child: const Icon(Icons.call_end),
                          ),
                          const SizedBox(width: 16),
                          _ControlButton(
                            icon: _camEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                            color: _camEnabled ? Colors.white24 : Colors.red,
                            onPressed: _toggleCam,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: color,
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
