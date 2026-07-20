import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';
import '../../../core/config.dart';
import '../../../core/globals.dart';

// Stream of auth state changes to make notifications reactive to login/logout
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

final notificationSocketProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  // Watch auth state - provider will restart when user logs in/out
  final authState = ref.watch(authStateProvider).value;
  final session = authState?.session ?? supabase.auth.currentSession;

  if (session == null) {
    debugPrint('NotificationSocket: No active session, socket standby.');
    return const Stream.empty();
  }

  final token = session.accessToken;
  final wsUrl = '${Config.wsBaseUrl}/ws/notifications/?token=$token';
  debugPrint('NotificationSocket: Connecting to $wsUrl');

  final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

  // Handle potential connection errors
  final streamController = StreamController<Map<String, dynamic>>();

  final subscription = channel.stream.listen(
    (event) {
      debugPrint('NotificationSocket: Raw data: $event');
      try {
        final decoded = jsonDecode(event) as Map<String, dynamic>;
        streamController.add(decoded);
      } catch (e) {
        debugPrint('NotificationSocket: Decode error: $e');
      }
    },
    onError: (error) {
      debugPrint('NotificationSocket: Connection error: $error');
      streamController.addError(error);
    },
    onDone: () {
      debugPrint('NotificationSocket: Connection closed by server');
      streamController.close();
    },
  );

  ref.onDispose(() {
    debugPrint('NotificationSocket: Disposing provider, closing channel');
    subscription.cancel();
    channel.sink.close();
    streamController.close();
  });

  return streamController.stream;
});

// A notifier to keep track of real-time peer presence events and handle in-app toasts
class NotificationManager extends StateNotifier<Map<String, bool>> {
  final Ref ref;
  NotificationManager(this.ref) : super({});

  void handleEvent(Map<String, dynamic> data, BuildContext? context) {
    debugPrint('NotificationManager: Event processing started: $data');
    final String type = data['type'] ?? '';

    final messenger = rootScaffoldMessengerKey.currentState;

    if (type == 'video_presence') {
      final String? apptId = data['appointment_id']?.toString();
      final bool isPresent = data['is_present'] == true;
      final String role = data['role'] ?? 'someone';

      if (apptId == null) return;

      // PREVENT SPAM: Only act if the presence actually changed
      final bool wasPresent = state[apptId] ?? false;
      if (wasPresent == isPresent) return;

      setPresence(apptId, isPresent);

      if (messenger == null) return;

      if (isPresent) {
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
            duration: const Duration(seconds: 10), // Longer duration for call alerts
            action: SnackBarAction(
              label: 'Join',
              textColor: Colors.white,
              onPressed: () {
                messenger.hideCurrentSnackBar();
                if (context != null) {
                  context.push('/video/$apptId');
                }
              },
            ),
          ),
        );
      } else {
        // If presence lost, hide relevant notifications
        messenger.hideCurrentSnackBar();
      }
    }

    else if (type == 'new_chat_message') {
      final String senderName = data['sender_name'] ?? 'Someone';
      final String message = data['message'] ?? '';
      final String? apptId = data['appointment_id']?.toString();

      if (messenger == null) return;

      messenger.clearSnackBars();
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
              if (apptId != null && context != null) {
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
    if (state[appointmentId] == isPresent) return;
    final newState = Map<String, bool>.from(state);
    newState[appointmentId] = isPresent;
    state = newState;
  }
}

final notificationManagerProvider = StateNotifierProvider<NotificationManager, Map<String, bool>>((ref) {
  return NotificationManager(ref);
});
