import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import '../../../core/dio_client.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  const VideoCallScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  final _jitsiMeet = JitsiMeet();
  bool _joining = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    try {
      final response = await DioClient.instance.get(
        '/appointments/${widget.appointmentId}/video-room/',
      );
      final roomName = response.data['room_name'];
      final displayName = response.data['display_name'];

      final options = JitsiMeetConferenceOptions(
        serverURL: 'https://meet.jit.si',
        room: roomName,
        userInfo: JitsiMeetUserInfo(displayName: displayName),
        configOverrides: {
          'startWithLobbyDisabled': true,
          'prejoinConfig.enabled': false,
          'requireDisplayName': false,
        },
        featureFlags: {
          'welcomepage.enabled': false,
          'invite.enabled': false,
          'lobby-mode.enabled': false,
        },
      );

      await _jitsiMeet.join(options);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _joining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Video Call')),
        body: Center(child: Text('Error: $_error')),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
