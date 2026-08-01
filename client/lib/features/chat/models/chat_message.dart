enum ChatMessageType { text, image, pdf }

class ChatMessage {
  final String id;
  final String senderId;
  final String message;
  final String? fileUrl;
  final String? fileName;
  final ChatMessageType type;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.message,
    this.fileUrl,
    this.fileName,
    this.type = ChatMessageType.text,
    required this.sentAt,
  });

  factory ChatMessage.fromRest(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      senderId: json['sender'],
      message: json['message'] ?? '',
      fileUrl: json['file_url'],
      fileName: json['file_name'],
      type: _parseType(json['message_type']),
      sentAt: DateTime.parse(json['sent_at']).toLocal(),
    );
  }

  factory ChatMessage.fromSocket(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      senderId: json['sender_id'],
      message: json['message'] ?? '',
      fileUrl: json['file_url'],
      fileName: json['file_name'],
      type: _parseType(json['message_type']),
      sentAt: DateTime.parse(json['sent_at']).toLocal(),
    );
  }

  static ChatMessageType _parseType(String? type) {
    switch (type) {
      case 'image':
        return ChatMessageType.image;
      case 'pdf':
        return ChatMessageType.pdf;
      default:
        return ChatMessageType.text;
    }
  }
}
