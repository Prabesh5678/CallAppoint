class Blog {
  final String id;
  final String doctorId;
  final String doctorName;
  final String? doctorAvatarUrl;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Blog({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    this.doctorAvatarUrl,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Blog.fromJson(Map<String, dynamic> json) {
    return Blog(
      id: json['id'],
      doctorId: json['doctor_id'],
      doctorName: json['doctor_name'] ?? 'Unknown Doctor',
      doctorAvatarUrl: json['doctor_avatar_url'],
      title: json['title'] ?? 'No Title',
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
    };
  }
}
