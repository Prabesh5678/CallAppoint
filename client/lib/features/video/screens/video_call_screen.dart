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
  static const Map<String, dynamic> _iceServersConfig = {
    'iceServers': [
      {
        'urls': ['stun:stun.l.google.com:19302'],
      },
      // Free TURN server for TESTING ONLY (openrelay.metered.ca) — this is
      // rate-limited and not meant for production traffic, but it's enough
      // to confirm whether missing TURN is why connections are flaky for
      // you. Swap for your own coturn deployment or a paid provider
      // (Twilio, Metered, Xirsys) before shipping.
      {
        'urls': [
          'turn:openrelay.metered.ca:80',
          'turn:openrelay.metered.ca:443',
          'turn:openrelay.metered.ca:443?transport=tcp',
        ],
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
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

  Future<void> _hangUp() async {
    await _localStream?.dispose();
    await _pc?.close();
    _channel?.sink.close();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
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
                Positioned.fill(
                  child: _remoteJoined
                      ? RTCVideoView(
                          _remoteRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
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
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      backgroundColor: Colors.red,
                      onPressed: _hangUp,
                      child: const Icon(Icons.call_end),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
