import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:go_router/go_router.dart';
import '../../features/video/providers/video_call_provider.dart';
import '../../core/globals.dart';
import '../../core/router.dart';

class GlobalCallWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const GlobalCallWrapper({super.key, required this.child});

  @override
  ConsumerState<GlobalCallWrapper> createState() => _GlobalCallWrapperState();
}

class _GlobalCallWrapperState extends ConsumerState<GlobalCallWrapper> with WidgetsBindingObserver {
  bool _pipSupported = false;
  Offset _floatingOffset = const Offset(20, 100);
  bool _isInPipMode = false;
  final GlobalKey _childKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPipSupport();
    // Listen to router changes to hide/show PiP instantly
    ref.read(routerProvider).routerDelegate.addListener(_handleRouterChange);
  }

  void _handleRouterChange() {
    if (mounted) setState(() {});
  }

  Future<void> _checkPipSupport() async {
    try {
      final supported = await SimplePip.isPipAvailable;
      if (mounted) setState(() => _pipSupported = supported);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // We check both the notifier state and our internal flag
    final callState = ref.read(videoCallNotifierProvider);

    // Only trigger system PiP when app is fully hidden (paused)
    // Use a slightly more lenient check for appointmentId
    if (callState.appointmentId != null &&
        state == AppLifecycleState.paused &&
        !_isInPipMode) {
      debugPrint('GlobalCallWrapper: App paused, entering PiP for ${callState.appointmentId}');
      _enterPipMode();
    }
  }

  void _enterPipMode() async {
    if (_pipSupported) {
      try {
        // Ensure we are not already in PiP before calling enter
        final isAlreadyInPip = await SimplePip.isPipActivated;
        if (!isAlreadyInPip) {
          SimplePip().enterPipMode(aspectRatio: (9, 16));
        }
      } catch (e) {
        debugPrint('GlobalCallWrapper: Error entering PiP mode: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(routerProvider).routerDelegate.removeListener(_handleRouterChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Check if we are physically on the video screen
    // We check both the provider and the router state for maximum reliability during transitions
    final router = ref.watch(routerProvider);
    final configuration = router.routerDelegate.currentConfiguration;
    String location = '';

    // Safely extract location across different GoRouter versions
    try {
      if (configuration is RouteMatchList) {
        location = configuration.uri.path;
      } else if (configuration is Iterable && configuration.isNotEmpty) {
        location = (configuration.last as RouteMatch).matchedLocation;
      } else {
        final matches = (configuration as dynamic).matches;
        if (matches is List && matches.isNotEmpty) {
          location = matches.last.matchedLocation;
        }
      }
    } catch (_) {}

    final isOnVideoScreen = location.startsWith('/video/');
    final isInVideoScreen = isOnVideoScreen;

    // 2. Select other fields needed for rebuilding
    final appointmentId = ref.watch(videoCallNotifierProvider.select((s) => s.appointmentId));
    final remoteJoined = ref.watch(videoCallNotifierProvider.select((s) => s.remoteJoined));
    final remoteCamEnabled = ref.watch(videoCallNotifierProvider.select((s) => s.remoteCamEnabled));

    final notifier = ref.read(videoCallNotifierProvider.notifier);

    // Stabilize the child with a GlobalKey
    final Widget stableChild = KeyedSubtree(
      key: _childKey,
      child: widget.child,
    );

    if (appointmentId == null) {
      return stableChild;
    }

    return Stack(
      children: [
        _pipSupported
            ? PipWidget(
                onPipEntered: () => setState(() => _isInPipMode = true),
                onPipExited: () => setState(() => _isInPipMode = false),
                pipChild: Scaffold(
                  backgroundColor: Colors.black,
                  body: RTCVideoView(
                    notifier.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
                child: stableChild,
              )
            : stableChild,

        // In-App Floating Video (In-app PiP)
        // ONLY show if NOT on the video screen and NOT in system PiP
        if (!isInVideoScreen && !_isInPipMode && remoteJoined)
          Positioned(
            left: _floatingOffset.dx,
            top: _floatingOffset.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _floatingOffset += details.delta;
                  final size = MediaQuery.of(context).size;
                  _floatingOffset = Offset(
                    _floatingOffset.dx.clamp(0.0, size.width - 100),
                    _floatingOffset.dy.clamp(0.0, size.height - 150),
                  );
                });
              },
              onTap: () => ref.read(routerProvider).push('/video/$appointmentId'),
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
                  ],
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    children: [
                      RTCVideoView(
                        notifier.remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                      if (!remoteCamEnabled)
                        const Center(child: Icon(Icons.videocam_off, color: Colors.white54, size: 30)),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.call, color: Colors.white, size: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else if (!isInVideoScreen && !_isInPipMode)
          // Show connecting bar if remote hasn't joined yet and we are away from screen
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: _InAppCallBar(
              appointmentId: appointmentId,
              remoteJoined: remoteJoined,
            ),
          ),
      ],
    );
  }
}

class _InAppCallBar extends ConsumerWidget {
  final String appointmentId;
  final bool remoteJoined;

  const _InAppCallBar({required this.appointmentId, required this.remoteJoined});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(routerProvider).push('/video/$appointmentId'),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.call, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  remoteJoined ? 'Active Call - Tap to return' : 'Connecting...',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
