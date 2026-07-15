import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/supabase_client.dart';

const wsBaseUrl = 'wss://call-appoint.azurewebsites.net';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  const VideoCallScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  // Metered.ca TURN/STUN servers (from your Metered dashboard credentials).
  static const Map<String, dynamic> _iceServersConfig = {
    'iceServers': [
      {
        'urls': ['stun:stun.relay.metered.ca:80'],
      },
      {
        'urls': ['turn:global.relay.metered.ca:80'],
        'username': '175aa236231a8375c1a75c2f',
        'credential': 'yNC4rOKivp5wSX9M',
      },
      {
        'urls': ['turn:global.relay.metered.ca:80?transport=tcp'],
        'username': '175aa236231a8375c1a75c2f',
        'credential': 'yNC4rOKivp5wSX9M',
      },
      {
        'urls': ['turn:global.relay.metered.ca:443'],
        'username': '175aa236231a8375c1a75c2f',
        'credential': 'yNC4rOKivp5wSX9M',
      },
      {
        'urls': ['turns:global.relay.metered.ca:443?transport=tcp'],
        'username': '175aa236231a8375c1a75c2f',
        'credential': 'yNC4rOKivp5wSX9M',
      },
    ],
  };

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  WebSocketChannel? _channel;
  bool _connecting = true;
  bool _remoteJoined = false;

  // Local media toggle states
  bool _micMuted = false;
  bool _cameraOff = false;

  // Remote states (persistent indicators)
  bool _remoteCameraOff = false;
  bool _remoteMicMuted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    _localRenderer.srcObject = _localStream;

    _pc = await createPeerConnection(_iceServersConfig);
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
          await _pc!.setRemoteDescription(
            RTCSessionDescription(data['sdp'], data['sdpType']),
          );
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          _send({'type': 'answer', 'sdp': answer.sdp, 'sdpType': answer.type});
          break;
        case 'answer':
          await _pc!.setRemoteDescription(
            RTCSessionDescription(data['sdp'], data['sdpType']),
          );
          break;
        case 'ice':
          final c = data['candidate'];
          await _pc!.addCandidate(
            RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
          );
          break;
        case 'media-toggle':
          // Persist remote camera/mic state instead of a toast
          setState(() {
            if (data['cameraOff'] != null) {
              _remoteCameraOff = data['cameraOff'];
            }
            if (data['micMuted'] != null) {
              _remoteMicMuted = data['micMuted'];
            }
          });
          break;
        case 'call-end':
          _hangUp(notifyRemote: false); // Remote already dropped, just clean up
          break;
      }
    }, onError: (e) => debugPrint('Signaling error: $e'));

    _send({'type': 'ready'});

    setState(() => _connecting = false);
  }

  Future<void> _createOffer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _send({'type': 'offer', 'sdp': offer.sdp, 'sdpType': offer.type});
  }

  void _send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  void _toggleMic() {
    final audioTracks = _localStream?.getAudioTracks();
    if (audioTracks != null && audioTracks.isNotEmpty) {
      final audioTrack = audioTracks.first;
      audioTrack.enabled = !audioTrack.enabled;
      setState(() => _micMuted = !audioTrack.enabled);
      _send({'type': 'media-toggle', 'micMuted': _micMuted});
    }
  }

  void _toggleCamera() {
    final videoTracks = _localStream?.getVideoTracks();
    if (videoTracks != null && videoTracks.isNotEmpty) {
      final videoTrack = videoTracks.first;
      videoTrack.enabled = !videoTrack.enabled;
      setState(() => _cameraOff = !videoTrack.enabled);
      _send({'type': 'media-toggle', 'cameraOff': _cameraOff});
    }
  }

  Future<void> _hangUp({bool notifyRemote = true}) async {
    if (notifyRemote) {
      _send({'type': 'call-end'});
    }
    _stopLocalStream();
    await _pc?.close();
    _channel?.sink.close();
    if (mounted) Navigator.pop(context);
  }

  void _stopLocalStream() {
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        track.stop();
      }
      _localStream!.dispose();
      _localStream = null;
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _stopLocalStream();
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
                // 1. Fullscreen remote feed or placeholder
                Positioned.fill(
                  child: _remoteJoined
                      ? (_remoteCameraOff
                            // Show camera-off icon persistently when remote camera is off
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.videocam_off,
                                      color: Colors.white70,
                                      size: 48,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Camera is off",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              )
                            : RTCVideoView(
                                _remoteRenderer,
                                objectFit: RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitCover,
                              ))
                      : const Center(
                          child: Text(
                            'Waiting for the other person to join...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),

                // 2. Remote mic muted indicator (persistent, overlaid on remote feed)
                if (_remoteJoined && _remoteMicMuted)
                  Positioned(
                    top: 40,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.mic_off, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text("Muted", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),

                // 3. Picture-in-Picture self view
                Positioned(
                  top: 40,
                  right: 16,
                  width: 110,
                  height: 150,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _cameraOff
                        ? const Center(
                            child: Icon(
                              Icons.videocam_off,
                              color: Colors.white,
                              size: 28,
                            ),
                          )
                        : RTCVideoView(_localRenderer, mirror: true),
                  ),
                ),

                // 4. Control dock
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton(
                        heroTag: 'mic',
                        backgroundColor: _micMuted
                            ? Colors.grey
                            : Colors.white24,
                        onPressed: _toggleMic,
                        child: Icon(
                          _micMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      FloatingActionButton(
                        heroTag: 'end',
                        backgroundColor: Colors.red,
                        onPressed: () => _hangUp(),
                        child: const Icon(Icons.call_end, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      FloatingActionButton(
                        heroTag: 'cam',
                        backgroundColor: _cameraOff
                            ? Colors.grey
                            : Colors.white24,
                        onPressed: _toggleCamera,
                        child: Icon(
                          _cameraOff ? Icons.videocam_off : Icons.videocam,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
