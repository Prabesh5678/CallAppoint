import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/globals.dart';
import '../providers/video_call_provider.dart';
import '../../appointments/widgets/artifact_list_overlay.dart';
import '../widgets/call_controls.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  final String? callAttemptId;
  const VideoCallScreen({super.key, required this.appointmentId, this.callAttemptId});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  bool _showArtifacts = false;

  @override
  void initState() {
    super.initState();
    // Set active call ID and screen status in microtask to avoid "modify provider while building" error
    Future.microtask(() {
      if (mounted) {
        ref.read(activeCallIdProvider.notifier).state = widget.appointmentId;
        ref.read(isInVideoCallScreenProvider.notifier).state = true;
      }
    });
    _initCall();
  }

  void _initCall() async {
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

    ref.read(videoCallNotifierProvider.notifier).startCall(
      widget.appointmentId,
      callAttemptId: widget.callAttemptId
    );
  }

  @override
  void dispose() {
    // Track that we left the video screen
    Future.microtask(() {
      ref.read(isInVideoCallScreenProvider.notifier).state = false;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(videoCallNotifierProvider);
    final notifier = ref.read(videoCallNotifierProvider.notifier);

    // If call ended externally (e.g. peer hung up), pop screen if we are still on it
    ref.listen(videoCallNotifierProvider, (previous, next) {
      if (previous?.appointmentId != null && next.appointmentId == null) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    });

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          debugPrint('VideoCallScreen: Returning to app navigation.');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
          body: (callState.isConnecting && !callState.remoteJoined)
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text('Waiting for other party to join...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: !callState.remoteJoined
                        ? Center(
                            child: Text(
                              'Waiting for the other person...',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          )
                        : Stack(
                            children: [
                              RTCVideoView(notifier.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                              if (!callState.remoteCamEnabled)
                                Container(color: Colors.black87, child: const Center(child: Icon(Icons.videocam_off, color: Colors.white54, size: 80))),
                            ],
                          ),
                  ),
                  if (callState.camEnabled)
                    Positioned(
                      top: 50, right: 20, width: 120, height: 180,
                      child: Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24, width: 2)),
                        child: ClipRRect(borderRadius: BorderRadius.circular(14), child: RTCVideoView(notifier.localRenderer, mirror: true)),
                      ),
                    ),
                  if (_showArtifacts)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ArtifactListOverlay(
                        appointmentId: widget.appointmentId,
                        onClose: () => setState(() => _showArtifacts = false),
                      ),
                    ),
                  Positioned(
                    bottom: 30, left: 0, right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (callState.showStatsOverlay)
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
                                    Text('Method: ${callState.connectionMethod}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text('Latency: ${callState.latencyMs.toStringAsFixed(0)} ms', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text('Bandwidth: ${callState.bitrateMbps.toStringAsFixed(2)} Mbps', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        CallControls(
                          appointmentId: widget.appointmentId,
                          micEnabled: callState.micEnabled,
                          camEnabled: callState.camEnabled,
                          onSwitchCamera: notifier.switchCamera,
                          showStatsOverlay: callState.showStatsOverlay,
                          showArtifacts: _showArtifacts,
                          onToggleMic: notifier.toggleMic,
                          onToggleCam: notifier.toggleCam,
                          onToggleStats: notifier.toggleStats,
                          onToggleArtifacts: () => setState(() => _showArtifacts = !_showArtifacts),
                          onHangUp: () => notifier.hangUp(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
