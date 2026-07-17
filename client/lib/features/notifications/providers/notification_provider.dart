import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase_client.dart';
import '../../../core/config.dart';

final notificationSocketProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final session = supabase.auth.currentSession;
  if (session == null) return const Stream.empty();

  final token = session.accessToken;
  final channel = WebSocketChannel.connect(
    Uri.parse('${Config.wsBaseUrl}/ws/notifications/?token=$token'),
  );

  ref.onDispose(() {
    channel.sink.close();
  });

  return channel.stream.map((event) => jsonDecode(event) as Map<String, dynamic>);
});

// A notifier to keep track of real-time peer presence events and handle in-app toasts
class NotificationManager extends StateNotifier<Map<String, bool>> {
  final Ref ref;
  NotificationManager(this.ref) : super({});

  void handleEvent(Map<String, dynamic> data, BuildContext? context) {
    if (context == null) return;

    final String type = data['type'] ?? '';

    if (type == 'video_presence') {
      final apptId = data['appointment_id'];
      final isPresent = data['is_present'] as bool;
      final role = data['role'] ?? 'someone';
      state = {...state, apptId: isPresent};

      final messenger = ScaffoldMessenger.of(context);

      if (isPresent) {
        // Show temporary In-App Toast for Call Join
        final roleTitle = role[0].toUpperCase() + role.substring(1);

        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.videocam, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('$roleTitle is ready for the call!')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
            closeIconColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Join',
              textColor: Colors.white,
              onPressed: () {
                messenger.hideCurrentSnackBar();
                context.push('/video/$apptId');
              },
            ),
          ),
        );
      } else {
        // If they left, hide any active "ready for call" snackbars immediately
        messenger.clearSnackBars();
      }
    }

    else if (type == 'new_chat_message') {
      final String senderName = data['sender_name'] ?? 'Someone';
      final String message = data['message'] ?? '';
      final apptId = data['appointment_id'];
      final messenger = ScaffoldMessenger.of(context);

      messenger.clearSnackBars();

      // Show In-App Toast
      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(senderName, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          closeIconColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              if (apptId != null) {
                messenger.hideCurrentSnackBar();
                context.push('/chat/$apptId');
              }
            },
          ),
        ),
      );
    }
  }

  void setPresence(String appointmentId, bool isPresent) {
    state = {...state, appointmentId: isPresent};
  }
}

final notificationManagerProvider = StateNotifierProvider<NotificationManager, Map<String, bool>>((ref) {
  return NotificationManager(ref);
});
