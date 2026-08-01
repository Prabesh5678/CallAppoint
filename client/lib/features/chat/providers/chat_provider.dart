import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/dio_client.dart';
import '../../../core/supabase_client.dart';
import '../../../core/config.dart';
import '../models/chat_message.dart';


final chatHistoryProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, appointmentId) async {
      final response = await DioClient.instance.get(
        '/chat/$appointmentId/history/',
      );
      final data = response.data;
      final List list = (data is Map && data.containsKey('results')) ? data['results'] : data;
      return list.map((m) => ChatMessage.fromRest(m)).toList();
    });

class ChatSocket {
  WebSocketChannel? _channel;
  final _messagesController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get messages => _messagesController.stream;

  void connect(String appointmentId) {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) return;
    _channel = WebSocketChannel.connect(
      Uri.parse('${Config.wsBaseUrl}/ws/chat/$appointmentId/?token=$token'),
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

  void send(String message, {String? fileUrl, String? fileName, String type = 'text'}) {
    _channel?.sink.add(jsonEncode({
      'message': message,
      'file_url': fileUrl,
      'file_name': fileName,
      'message_type': type,
    }));
  }

  Future<String?> uploadFile(String appointmentId, List<int> bytes, String fileName, {required String doctorId, required String patientId}) async {
    try {
      // Ensure Supabase knows who has access to this appointment's reports
      await supabase.from('appointment_access').upsert({
        'appointment_id': appointmentId,
        'doctor_id': doctorId,
        'patient_id': patientId,
      });

      final ext = fileName.split('.').last.toLowerCase();
      // Using a structure that matches the RLS policy: chat/appointment_id/filename
      final path = 'chat/$appointmentId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from('reports').uploadBinary(
        path,
        Uint8List.fromList(bytes),
      );

      return path; // Return the path, not the public URL
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  Future<String> getSecureUrl(String path) async {
    try {
      final response = await supabase.storage.from('reports').createSignedUrl(path, 3600);
      return response;
    } catch (e) {
      print('Error getting signed URL: $e');
      return '';
    }
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
