class ChatMessage {
  final String id;
  final String senderId;
  final String message;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.message,
    required this.sentAt,
  });

  factory ChatMessage.fromRest(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      senderId: json['sender'],
      message: json['message'] ?? '',
      sentAt: DateTime.parse(json['sent_at']),
    );
  }

  factory ChatMessage.fromSocket(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      senderId: json['sender_id'],
      message: json['message'] ?? '',
      sentAt: DateTime.parse(json['sent_at']),
    );
  }
}
