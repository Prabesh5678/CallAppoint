class Appointment {
  final String id;
  final String patientId;
  final String doctorId;
  final String? doctorName;
  final String? patientName;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String status;
  final String? reasonForVisit;
  final String? videoRoomId;

  Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    this.doctorName,
    this.patientName,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.status,
    this.reasonForVisit,
    this.videoRoomId,
  });

  String get displayDoctorName {
    final name = doctorName ?? 'Unknown Doctor';
    if (name.toLowerCase().startsWith('dr.') ||
        name.toLowerCase().startsWith('dr ')) {
      return name;
    }
    return 'Dr. $name';
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      patientId: json['patient'],
      doctorId: json['doctor'],
      doctorName: json['doctor_name'],
      patientName: json['patient_name'],
      scheduledStart: DateTime.parse(json['scheduled_start']),
      scheduledEnd: DateTime.parse(json['scheduled_end']),
      status: json['status'],
      reasonForVisit: json['reason_for_visit'],
      videoRoomId: json['video_room_id'],
    );
  }
}
