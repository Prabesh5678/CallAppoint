import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/supabase_client.dart';
import '../../../core/dio_client.dart';

const wsBaseUrl = 'wss://call-appoint.azurewebsites.net';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  const VideoCallScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
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

  Timer? _statsPollTimer;

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
      final response = await DioClient.instance.get('/appointments/ice-servers/');
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
        }
      };

      _pc!.onIceCandidate = (candidate) {
        _send({'type': 'ice', 'candidate': candidate.toMap()});
      };

      _connectSignaling();
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize call: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
    }
  }

  void _connectSignaling() {
    final token = supabase.auth.currentSession?.accessToken;
    _channel = WebSocketChannel.connect(
      Uri.parse('$wsBaseUrl/ws/video/${widget.appointmentId}/?token=$token'),
    );

    _channel!.stream.listen((event) async {
      final data = jsonDecode(event);
      switch (data['type']) {
        case 'ready':
          await _createOffer();
          break;
        case 'offer':
          await _pc!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdpType']));
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          _send({'type': 'answer', 'sdp': answer.sdp, 'sdpType': answer.type});
          break;
        case 'answer':
          await _pc!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdpType']));
          break;
        case 'ice':
          final c = data['candidate'];
          await _pc!.addCandidate(RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
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
                      ? const Center(child: Text('Waiting for the other person...', style: TextStyle(color: Colors.white70)))
                      : Stack(
                          children: [
                            RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                            if (!_remoteCamEnabled)
                              Container(
                                color: Colors.black87,
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.videocam_off, color: Colors.white54, size: 80),
                                      SizedBox(height: 16),
                                      Text('Remote camera is off', style: TextStyle(color: Colors.white54, fontSize: 18)),
                                    ],
                                  ),
                                ),
                              ),
                            if (!_remoteMicEnabled)
                              Positioned(
                                top: 40,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.mic_off, color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text('Remote muted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

                // Control Buttons
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ControlButton(
                        icon: _micEnabled ? Icons.mic : Icons.mic_off,
                        color: _micEnabled ? Colors.white24 : Colors.red,
                        onPressed: _toggleMic,
                      ),
                      const SizedBox(width: 20),
                      FloatingActionButton(
                        heroTag: 'hangup',
                        backgroundColor: Colors.red,
                        onPressed: _hangUp,
                        child: const Icon(Icons.call_end),
                      ),
                      const SizedBox(width: 20),
                      _ControlButton(
                        icon: _camEnabled ? Icons.videocam : Icons.videocam_off,
                        color: _camEnabled ? Colors.white24 : Colors.red,
                        onPressed: _toggleCam,
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
  const _ControlButton({required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: color,
      child: IconButton(icon: Icon(icon, color: Colors.white), onPressed: onPressed),
    );
  }
}
