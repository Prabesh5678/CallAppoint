import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/dio_client.dart';
import '../../../core/supabase_client.dart';
import '../models/chat_message.dart';

String get _wsHost {
  if (kIsWeb) return 'localhost';
  if (Platform.isAndroid) return '10.0.2.2';
  return 'localhost';
}

final String wsBaseUrl =
    'ws://$_wsHost:8000'; // Android emulator; swap for LAN IP on a physical device

final chatHistoryProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, appointmentId) async {
      final response = await DioClient.instance.get(
        '/chat/$appointmentId/history/',
      );
      return (response.data as List)
          .map((m) => ChatMessage.fromRest(m))
          .toList();
    });

class ChatSocket {
  WebSocketChannel? _channel;
  final _messagesController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get messages => _messagesController.stream;

  void connect(String appointmentId) {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) return;
    _channel = WebSocketChannel.connect(
      Uri.parse('$wsBaseUrl/ws/chat/$appointmentId/?token=$token'),
    );
    _channel!.stream.listen(
      (event) {
        final data = jsonDecode(event);
        _messagesController.add(ChatMessage.fromSocket(data));
      },
      onError: (e) => print('WebSocket error: $e'),
      onDone: () => print('WebSocket closed'),
    );
  }

  void send(String message) {
    _channel?.sink.add(jsonEncode({'message': message}));
  }

  void dispose() {
    _channel?.sink.close();
    _messagesController.close();
  }
}

final chatSocketProvider = Provider.autoDispose.family<ChatSocket, String>((
  ref,
  appointmentId,
) {
  final socket = ChatSocket();
  socket.connect(appointmentId);
  ref.onDispose(() => socket.dispose());
  return socket;
});
