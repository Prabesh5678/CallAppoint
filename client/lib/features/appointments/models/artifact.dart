class Artifact {
  final String id;
  final String appointmentId;
  final String doctorId;
  final String doctorName;
  final String patientId;
  final String patientName;
  final String reportType;
  final String title;
  final String? content;
  final String? fileUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Artifact({
    required this.id,
    required this.appointmentId,
    required this.doctorId,
    required this.doctorName,
    required this.patientId,
    required this.patientName,
    required this.reportType,
    required this.title,
    this.content,
    this.fileUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json['id'],
      appointmentId: json['appointment'],
      doctorId: json['doctor'] ?? '',
      doctorName: json['doctor_name'] ?? '',
      patientId: json['patient'] ?? '',
      patientName: json['patient_name'] ?? '',
      reportType: json['report_type'] ?? '',
      title: json['title'] ?? '',
      content: json['content'],
      fileUrl: json['file_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
