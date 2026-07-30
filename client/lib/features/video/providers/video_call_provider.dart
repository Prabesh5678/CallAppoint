import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../../../core/supabase_client.dart';
import '../../../core/dio_client.dart';
import '../../../core/config.dart';
import '../../../core/globals.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../auth/providers/auth_provider.dart';

class VideoCallState {
  final String? appointmentId;
  final String? callAttemptId;
  final bool isConnecting;
  final bool isConnected;
  final bool remoteJoined;
  final bool micEnabled;
  final bool camEnabled;
  final bool remoteMicEnabled;
  final bool remoteCamEnabled;
  final double bitrateMbps;
  final double latencyMs;
  final String connectionMethod;
  final bool showStatsOverlay;

  VideoCallState({
    this.appointmentId,
    this.callAttemptId,
    this.isConnecting = false,
    this.isConnected = false,
    this.remoteJoined = false,
    this.micEnabled = true,
    this.camEnabled = true,
    this.remoteMicEnabled = true,
    this.remoteCamEnabled = true,
    this.bitrateMbps = 0,
    this.latencyMs = 0,
    this.connectionMethod = "Checking...",
    this.showStatsOverlay = false,
  });

  VideoCallState copyWith({
    String? appointmentId,
    String? callAttemptId,
    bool? isConnecting,
    bool? isConnected,
    bool? remoteJoined,
    bool? micEnabled,
    bool? camEnabled,
    bool? remoteMicEnabled,
    bool? remoteCamEnabled,
    double? bitrateMbps,
    double? latencyMs,
    String? connectionMethod,
    bool? showStatsOverlay,
  }) {
    return VideoCallState(
      appointmentId: appointmentId ?? this.appointmentId,
      callAttemptId: callAttemptId ?? this.callAttemptId,
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      remoteJoined: remoteJoined ?? this.remoteJoined,
      micEnabled: micEnabled ?? this.micEnabled,
      camEnabled: camEnabled ?? this.camEnabled,
      remoteMicEnabled: remoteMicEnabled ?? this.remoteMicEnabled,
      remoteCamEnabled: remoteCamEnabled ?? this.remoteCamEnabled,
      bitrateMbps: bitrateMbps ?? this.bitrateMbps,
      latencyMs: latencyMs ?? this.latencyMs,
      connectionMethod: connectionMethod ?? this.connectionMethod,
      showStatsOverlay: showStatsOverlay ?? this.showStatsOverlay,
    );
  }
}

class VideoCallNotifier extends StateNotifier<VideoCallState> {
  final Ref ref;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  WebSocketChannel? _channel;
  StreamSubscription? _signalingSubscription;
  Timer? _statsPollTimer;
  int _lastBytesReceived = 0;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _offerInitiated = false;
  bool _peerReadyReceived = false;
  bool _isInitializingPC = false;
  bool _remoteDescriptionSet = false;
  final List<Map<String, dynamic>> _pendingCandidates = [];

  VideoCallNotifier(this.ref) : super(VideoCallState()) {
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> startCall(String appointmentId, {String? callAttemptId}) async {
    // Prevent re-entry if already active for the SAME appointment
    if (state.appointmentId == appointmentId) {
      debugPrint('VideoCallNotifier: Already active for $appointmentId, resuming view.');
      ref.read(activeCallIdProvider.notifier).state = appointmentId;
      return;
    }

    // Clean up any existing call first
    await hangUp(internal: true);

    debugPrint('VideoCallNotifier: Starting call for $appointmentId');
    state = state.copyWith(
      appointmentId: appointmentId,
      callAttemptId: callAttemptId,
      isConnecting: true,
    );
    ref.read(activeCallIdProvider.notifier).state = appointmentId;

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      localRenderer.srcObject = _localStream;

      _connectSignaling(appointmentId);

      if (callAttemptId != null || state.callAttemptId != null) {
        _initializePeerConnection();
      }
    } catch (e) {
      debugPrint('VideoCallNotifier: Start call error: $e');
      state = state.copyWith(isConnecting: false);
    }
  }

  void _connectSignaling(String appointmentId) {
    _signalingSubscription?.cancel();

    final token = supabase.auth.currentSession?.accessToken;
    final wsUrl = '${Config.wsBaseUrl}/ws/video/$appointmentId/?token=$token';
    debugPrint('VideoCallNotifier: Connecting to $wsUrl');

    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _signalingSubscription = _channel!.stream.listen((event) async {
      final data = jsonDecode(event);
      switch (data['type']) {
        case 'connection_info':
          if (state.callAttemptId == null) {
            final newId = (data['callAttemptId'] ?? data['call_attempt_id'])?.toString();
            state = state.copyWith(callAttemptId: newId);
            await _initializePeerConnection();
          }
          break;
        case 'ready':
          _peerReadyReceived = true;
          final userProfile = ref.read(currentUserProfileProvider).valueOrNull;
          if (userProfile?['role'] == 'patient') {
            if (!_offerInitiated && _pc != null) {
              _offerInitiated = true;
              await _createOffer();
            }
          } else {
            _send({'type': 'ready'});
          }
          break;
        case 'offer':
          if (_pc == null) return;
          await _pc!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdpType']));
          await _flushPendingCandidates();
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          _send({'type': 'answer', 'sdp': answer.sdp, 'sdpType': answer.type});
          break;
        case 'answer':
          if (_pc == null) return;
          await _pc!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdpType']));
          await _flushPendingCandidates();
          break;
        case 'ice':
          await _handleIncomingCandidate(data['candidate']);
          break;
        case 'toggle-audio':
          state = state.copyWith(remoteMicEnabled: data['enabled']);
          break;
        case 'toggle-video':
          state = state.copyWith(remoteCamEnabled: data['enabled']);
          break;
        case 'peer_disconnected':
          debugPrint('VideoCallNotifier: Peer disconnected, updating state.');
          state = state.copyWith(remoteJoined: false);
          // Don't hang up here! The peer might just be backgrounding or switching networks.
          // They will reconnect automatically via signaling if they return.
          break;
        case 'bye':
          debugPrint('VideoCallNotifier: Received bye, hanging up.');
          await hangUp(internal: true);
          break;
      }
    }, onError: (e) {
      debugPrint('VideoCallNotifier: Signaling error: $e');
    }, onDone: () {
      debugPrint('VideoCallNotifier: Signaling closed');
    });
  }

  Future<void> _initializePeerConnection() async {
    if (state.callAttemptId == null || _pc != null || _isInitializingPC) return;
    _isInitializingPC = true;

    try {
      final response = await DioClient.instance.get(
        '/appointments/ice-servers/',
        queryParameters: {
          'appointment_id': state.appointmentId,
          'call_attempt_id': state.callAttemptId,
        },
      );
      final iceConfig = Map<String, dynamic>.from(response.data);

      _pc = await createPeerConnection(iceConfig, {
        'mandatory': {},
        'optional': [{'DtlsSrtpKeyAgreement': true}],
      });

      if (_localStream != null) {
        for (var track in _localStream!.getTracks()) {
          await _pc!.addTrack(track, _localStream!);
        }
      }

      _pc!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          state = state.copyWith(remoteJoined: true);
          remoteRenderer.srcObject = event.streams[0];
          _startStatsPolling();
        }
      };

      _pc!.onIceCandidate = (candidate) {
        _send({'type': 'ice', 'candidate': candidate.toMap()});
      };

      _pc!.onConnectionState = (pcState) {
        debugPrint('VideoCallNotifier: Connection state changed to: $pcState');
        if (pcState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          state = state.copyWith(isConnected: true, isConnecting: false);
          _startStatsPolling();
        } else if (pcState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
                   pcState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                   pcState == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          state = state.copyWith(isConnected: false, isConnecting: false);
        }
      };

      _send({'type': 'ready'});

      // Fallback: If connection takes too long, stop the connecting state so UI isn't stuck
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted && state.isConnecting) {
          debugPrint('VideoCallNotifier: Connection timeout fallback triggered');
          state = state.copyWith(isConnecting: false);
        }
      });

      final userProfile = ref.read(currentUserProfileProvider).valueOrNull;
      if (userProfile?['role'] == 'patient' && _peerReadyReceived && !_offerInitiated) {
        _offerInitiated = true;
        await _createOffer();
      }
    } catch (e) {
      debugPrint('VideoCallNotifier: PC Init error: $e');
    } finally {
      _isInitializingPC = false;
    }
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

  void toggleMic() {
    if (_localStream == null) return;
    final newEnabled = !state.micEnabled;
    for (var track in _localStream!.getAudioTracks()) {
      track.enabled = newEnabled;
    }
    _send({'type': 'toggle-audio', 'enabled': newEnabled});
    state = state.copyWith(micEnabled: newEnabled);
  }

  void toggleCam() async {
    if (_localStream == null || _pc == null) return;

    if (state.camEnabled) {
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = false;
        track.stop();
      }
      _send({'type': 'toggle-video', 'enabled': false});
      state = state.copyWith(camEnabled: false);
    } else {
      try {
        final newStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {'facingMode': 'user'},
        });
        final videoTracks = newStream.getVideoTracks();
        if (videoTracks.isEmpty) return;

        final newTrack = videoTracks.first;
        final senders = await _pc!.getSenders();
        final videoSender = senders.where((s) => s.track?.kind == 'video').firstOrNull;
        if (videoSender != null) {
          await videoSender.replaceTrack(newTrack);
        }

        _localStream!.addTrack(newTrack);
        localRenderer.srcObject = _localStream;
        _send({'type': 'toggle-video', 'enabled': true});
        state = state.copyWith(camEnabled: true);
      } catch (e) {
        debugPrint('VideoCallNotifier: Error re-enabling camera: $e');
      }
    }
  }

  void switchCamera() {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isNotEmpty && state.camEnabled) {
      Helper.switchCamera(tracks[0]);
    }
  }

  void toggleStats() {
    state = state.copyWith(showStatsOverlay: !state.showStatsOverlay);
  }

  Future<void> hangUp({bool internal = false}) async {
    debugPrint('VideoCallNotifier: Hanging up call (internal: $internal)');

    if (!internal && _channel != null) {
      try {
        _send({'type': 'hangup'});
      } catch (e) {
        debugPrint('VideoCallNotifier: Error sending hangup signal: $e');
      }
    }

    _statsPollTimer?.cancel();
    _signalingSubscription?.cancel();

    _localStream?.getTracks().forEach((t) {
      t.enabled = false;
      t.stop();
    });

    await _localStream?.dispose();
    await _pc?.close();
    await _channel?.sink.close();

    _localStream = null;
    _pc = null;
    _channel = null;
    _signalingSubscription = null;
    _offerInitiated = false;
    _peerReadyReceived = false;
    _remoteDescriptionSet = false;
    _isInitializingPC = false;
    _pendingCandidates.clear();

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    final apptId = state.appointmentId;
    state = VideoCallState(); // This will trigger listeners to pop screens

    ref.read(activeCallIdProvider.notifier).state = null;

    if (apptId != null) {
      ref.read(notificationManagerProvider.notifier).clearPresence(apptId);
    }
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
      debugPrint('VideoCallNotifier: Failed to add ICE candidate: $e');
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
      if (_pc == null) return;
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

          final rtt = report.values['currentRoundTripTime'] ?? report.values['roundTripTime'] ?? 0;
          state = state.copyWith(
            latencyMs: rtt * 1000,
            connectionMethod: connectionType,
          );
        }
        if (report.type == 'inbound-rtp' && report.values['kind'] == 'video') {
          int currentBytes = report.values['bytesReceived'] ?? 0;
          if (_lastBytesReceived > 0) {
            state = state.copyWith(bitrateMbps: ((currentBytes - _lastBytesReceived) * 8) / (2 * 1000000));
          }
          _lastBytesReceived = currentBytes;
        }
      }
    });
  }

  @override
  void dispose() {
    _statsPollTimer?.cancel();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}

final videoCallNotifierProvider = StateNotifierProvider<VideoCallNotifier, VideoCallState>((ref) {
  return VideoCallNotifier(ref);
});
