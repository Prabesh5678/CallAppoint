import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/supabase_client.dart';
import '../../../core/dio_client.dart';
import '../../../core/config.dart';
import '../../../core/globals.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../appointments/widgets/create_artifact_dialog.dart';
import '../../appointments/widgets/artifact_list_overlay.dart';
import '../../appointments/providers/artifact_provider.dart';
import '../widgets/call_controls.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  const VideoCallScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> with WidgetsBindingObserver {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final String callAttemptId = const Uuid().v4();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  WebSocketChannel? _channel;

  bool _connecting = true;
  bool _remoteJoined = false;
  bool _offerInitiated = false;

  bool _micEnabled = true;
  bool _camEnabled = true;
  bool _remoteMicEnabled = true;
  bool _remoteCamEnabled = true;

  bool _showArtifacts = false;
  bool _isInPipMode = false;
  bool _pipSupported = false;

  Timer? _statsPollTimer;
  double _bitrateMbps = 0;
  int _lastBytesReceived = 0;
  double _latencyMs = 0;
  String _connectionMethod = "Checking...";
  bool _showStatsOverlay = false;

  bool _remoteDescriptionSet = false;
  final List<Map<String, dynamic>> _pendingCandidates = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Try to enter PiP when app is inactive or paused
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.inactive) && !_isInPipMode) {
      _enterPipMode();
    }
  }

  Future<void> _init() async {
    try {
      // Delay provider update to avoid modifying state during widget building
      Future.microtask(() {
        if (mounted) {
          ref.read(activeCallIdProvider.notifier).state = widget.appointmentId;
        }
      });

      try {
        final supported = await SimplePip.isPipAvailable;
        if (mounted) {
          setState(() => _pipSupported = supported);
        }
      } catch (e) {
        debugPrint('PiP not supported on this platform: $e');
      }

      final statuses = await [Permission.camera, Permission.microphone].request();
      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera and Microphone permissions are required.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      final response = await DioClient.instance.get(
        '/appointments/ice-servers/',
        queryParameters: {'call_attempt_id': callAttemptId},
      );
      final iceConfig = Map<String, dynamic>.from(response.data);

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      _localRenderer.srcObject = _localStream;

      _pc = await createPeerConnection(iceConfig, {
        'mandatory': {},
        'optional': [{'DtlsSrtpKeyAgreement': true}],
      });

      for (var track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }

      _pc!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            _remoteJoined = true;
          });
          _startStatsPolling();
        }
      };

      _pc!.onIceCandidate = (candidate) {
        if (candidate == null) return;
        _send({'type': 'ice', 'candidate': candidate.toMap()});
      };

      _pc!.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _startStatsPolling();
        }
        // Don't automatically hang up on disconnect to allow reconnection
      };

      _connectSignaling();
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  void _connectSignaling() {
    final token = supabase.auth.currentSession?.accessToken;
    _channel = WebSocketChannel.connect(
      Uri.parse('${Config.wsBaseUrl}/ws/video/${widget.appointmentId}/?token=$token'),
    );

    _channel!.stream.listen((event) async {
      final data = jsonDecode(event);
      switch (data['type']) {
        case 'ready':
          final userProfile = ref.read(currentUserProfileProvider).valueOrNull;
          if (userProfile?['role'] == 'patient') {
            if (!_offerInitiated) {
              _offerInitiated = true;
              await _createOffer();
            }
          } else {
            _send({'type': 'ready'});
          }
          break;
        case 'offer':
          await _pc!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdpType']));
          await _flushPendingCandidates();
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          _send({'type': 'answer', 'sdp': answer.sdp, 'sdpType': answer.type});
          break;
        case 'answer':
          await _pc!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdpType']));
          await _flushPendingCandidates();
          break;
        case 'ice':
          await _handleIncomingCandidate(data['candidate']);
          break;
        case 'toggle-audio':
          setState(() => _remoteMicEnabled = data['enabled']);
          break;
        case 'toggle-video':
          setState(() => _remoteCamEnabled = data['enabled']);
          break;
        case 'peer_disconnected':
          // Just update UI, don't exit
          setState(() {
            _remoteJoined = false;
            _remoteRenderer.srcObject = null;
          });
          break;
        case 'bye':
          _cleanupAndExit();
          break;
      }
    }, onError: (e) {
      debugPrint('Signaling error: $e');
      if (!_connecting) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!_connecting && mounted) _connectSignaling();
        });
      }
    }, onDone: () {
      debugPrint('Signaling closed');
      if (!_connecting) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!_connecting && mounted) _connectSignaling();
        });
      }
    });

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

  void _switchCamera() {
    if (_localStream != null && _camEnabled) {
      Helper.switchCamera(_localStream!.getVideoTracks()[0]);
    }
  }

  void _enterPipMode() async {
    try {
      if (_pipSupported) {
        // Use record (9, 16) as it was originally
        SimplePip().enterPipMode(aspectRatio: (9, 16));
      }
    } catch (e) {
      debugPrint('Error entering PiP mode: $e');
    }
  }

  void _toggleMic() {
    if (_localStream == null) return;
    setState(() => _micEnabled = !_micEnabled);
    for (var track in _localStream!.getAudioTracks()) {
      track.enabled = _micEnabled;
    }
    _send({'type': 'toggle-audio', 'enabled': _micEnabled});
  }

  void _toggleCam() async {
    if (_localStream == null || _pc == null) return;

    if (_camEnabled) {
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = false;
        track.stop();
      }
      setState(() => _camEnabled = false);
      _send({'type': 'toggle-video', 'enabled': false});
    } else {
      try {
        final newStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {'facingMode': 'user'},
        });
        final newTrack = newStream.getVideoTracks().first;
        final senders = await _pc!.getSenders();
        final videoSender = senders.firstWhere((s) => s.track?.kind == 'video');
        await videoSender.replaceTrack(newTrack);

        _localStream!.addTrack(newTrack);
        _localRenderer.srcObject = _localStream;
        setState(() => _camEnabled = true);
        _send({'type': 'toggle-video', 'enabled': true});
      } catch (e) {
        debugPrint('Error re-enabling camera: $e');
      }
    }
  }

  void _hangUp() {
    _send({'type': 'hangup'});
    _cleanupAndExit();
  }

  void _cleanupAndExit() {
    _connecting = true; // prevent reconnection
    ref.read(activeCallIdProvider.notifier).state = null;
    ref.read(notificationManagerProvider.notifier).clearPresence(widget.appointmentId);
    rootScaffoldMessengerKey.currentState?.clearSnackBars();
    _statsPollTimer?.cancel();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _pc?.close();
    _channel?.sink.close();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleIncomingCandidate(Map<String, dynamic> c) async {
    if (!_remoteDescriptionSet) {
      _pendingCandidates.add(c);
      return;
    }
    await _addCandidateFromMap(c);
  }

  Future<void> _addCandidateFromMap(Map<String, dynamic>? c) async {
    if (_pc == null || c == null) return;
    try {
      await _pc!.addCandidate(RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
    } catch (e) {
      debugPrint('Failed to add ICE candidate: $e');
    }
  }

  Future<void> _flushPendingCandidates() async {
    _remoteDescriptionSet = true;
    for (final c in _pendingCandidates) {
      await _addCandidateFromMap(c);
    }
    _pendingCandidates.clear();
  }

  void _startStatsPolling() {
    _statsPollTimer?.cancel();
    _statsPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_pc == null || !mounted) return;
      final stats = await _pc!.getStats();
      for (var report in stats) {
        if (report.type == 'candidate-pair' && (report.values['nominated'] == true || report.values['state'] == 'succeeded')) {
          String connectionType = "Checking...";
          final localCandidateId = report.values['localCandidateId'];

          if (localCandidateId != null) {
            for (var r in stats) {
              if (r.id == localCandidateId) {
                final cType = r.values['candidateType'];
                if (cType == 'relay') {
                  connectionType = "Relay (TURN)";
                } else if (cType == 'host' || cType == 'srflx') {
                  connectionType = "P2P (${cType.toUpperCase()})";
                } else {
                  connectionType = cType?.toString().toUpperCase() ?? "P2P";
                }
                break;
              }
            }
          }

          if (mounted) {
            setState(() {
              final rtt = report.values['currentRoundTripTime'] ?? report.values['roundTripTime'] ?? 0;
              _latencyMs = rtt * 1000;
              _connectionMethod = connectionType;
            });
          }
        }
        if (report.type == 'inbound-rtp' && report.values['kind'] == 'video') {
          int currentBytes = report.values['bytesReceived'] ?? 0;
          if (_lastBytesReceived > 0 && mounted) {
            setState(() => _bitrateMbps = ((currentBytes - _lastBytesReceived) * 8) / (2 * 1000000));
          }
          _lastBytesReceived = currentBytes;
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainContent = Scaffold(
      backgroundColor: Colors.black,
      body: _connecting
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                Positioned.fill(
                  child: !_remoteJoined
                      ? Center(
                          child: Text(
                            _channel == null ? 'Connecting...' : 'Waiting for the other person...',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        )
                      : Stack(
                          children: [
                            RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                            if (!_remoteCamEnabled)
                              Container(color: Colors.black87, child: const Center(child: Icon(Icons.videocam_off, color: Colors.white54, size: 80))),
                          ],
                        ),
                ),
                if (_camEnabled && !_isInPipMode)
                  Positioned(
                    top: 50, right: 20, width: 120, height: 180,
                    child: Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24, width: 2)),
                      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: RTCVideoView(_localRenderer, mirror: true)),
                    ),
                  ),
                if (_showArtifacts && !_isInPipMode)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ArtifactListOverlay(
                      appointmentId: widget.appointmentId,
                      onClose: () => setState(() => _showArtifacts = false),
                    ),
                  ),
                if (!_isInPipMode)
                  Positioned(
                    bottom: 30, left: 0, right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showStatsOverlay)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(color: Colors.black54, border: Border.all(color: Colors.white10)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Method: $_connectionMethod', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text('Latency: ${_latencyMs.toStringAsFixed(0)} ms', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text('Bandwidth: ${_bitrateMbps.toStringAsFixed(2)} Mbps', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        CallControls(
                          appointmentId: widget.appointmentId,
                          micEnabled: _micEnabled,
                          camEnabled: _camEnabled,
                          onSwitchCamera: _switchCamera,
                          showStatsOverlay: _showStatsOverlay,
                          showArtifacts: _showArtifacts,
                          onToggleMic: _toggleMic,
                          onToggleCam: _toggleCam,
                          onToggleStats: () => setState(() => _showStatsOverlay = !_showStatsOverlay),
                          onToggleArtifacts: () => setState(() => _showArtifacts = !_showArtifacts),
                          onHangUp: _hangUp,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_pipSupported) {
          _enterPipMode();
        } else {
          _hangUp(); // Fallback: just exit if PiP isn't supported
        }
      },
      child: _pipSupported
          ? PipWidget(
              onPipEntered: () => setState(() => _isInPipMode = true),
              onPipExited: () => setState(() => _isInPipMode = false),
              pipChild: Scaffold(
                backgroundColor: Colors.black,
                body: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
              child: mainContent,
            )
          : mainContent,
    );
  }
}
