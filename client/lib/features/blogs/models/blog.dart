class Blog {
  final String id;
  final String doctorId;
  final String doctorName;
  final String? doctorAvatarUrl;
  final String title;
  final String content;
  final String? thumbnailUrl;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;

  Blog({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    this.doctorAvatarUrl,
    required this.title,
    required this.content,
    this.thumbnailUrl,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayDoctorName {
    if (doctorName.toLowerCase().startsWith('dr.') ||
        doctorName.toLowerCase().startsWith('dr ')) {
      return doctorName;
    }
    return 'Dr. $doctorName';
  }

  factory Blog.fromJson(Map<String, dynamic> json) {
    return Blog(
      id: json['id'],
      doctorId: json['doctor_id'],
      doctorName: json['doctor_name'] ?? 'Unknown Doctor',
      doctorAvatarUrl: json['doctor_avatar_url'],
      title: json['title'] ?? 'No Title',
      content: json['content'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      category: json['category'] ?? 'General',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'thumbnail_url': thumbnailUrl,
      'category': category,
    };
  }
}
