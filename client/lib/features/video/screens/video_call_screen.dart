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
  // NOTE: these credentials are visible to anyone who decompiles the app —
  // fine for testing, but for production fetch them at runtime from your
  // own backend (Metered's REST API issues short-lived credentials) instead
  // of hardcoding them here.
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
