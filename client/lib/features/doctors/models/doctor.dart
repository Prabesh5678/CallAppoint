class Specialty {
  final String id;
  final String name;
  final String? iconUrl;

  Specialty({required this.id, required this.name, this.iconUrl});

  factory Specialty.fromJson(Map<String, dynamic> json) {
    return Specialty(
      id: json['id'],
      name: json['name'],
      iconUrl: json['icon_url'],
    );
  }
}

class WeeklyAvailability {
  final String id;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final int slotDurationMinutes;

  WeeklyAvailability({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.slotDurationMinutes,
  });

  factory WeeklyAvailability.fromJson(Map<String, dynamic> json) {
    return WeeklyAvailability(
      id: json['id'],
      dayOfWeek: json['day_of_week'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      slotDurationMinutes: json['slot_duration_minutes'],
    );
  }
}

class Doctor {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final double consultationFee;
  final int yearsExperience;
  final double averageRating;
  final int totalReviews;
  final double totalWeeklyHours;
  final int requiredWeeklyHours;
  final List<Specialty> specialties;
  final List<WeeklyAvailability> availability;

  Doctor({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.consultationFee,
    required this.yearsExperience,
    required this.averageRating,
    required this.totalReviews,
    required this.totalWeeklyHours,
    required this.requiredWeeklyHours,
    required this.specialties,
    required this.availability,
  });

  String get displayName {
    if (fullName.toLowerCase().startsWith('dr.') ||
        fullName.toLowerCase().startsWith('dr ')) {
      return fullName;
    }
    return 'Dr. $fullName';
  }

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'],
      fullName: json['full_name'] ?? 'Unknown',
      avatarUrl: json['avatar_url'],
      consultationFee:
          double.tryParse(json['consultation_fee'].toString()) ?? 0,
      yearsExperience: json['years_experience'] ?? 0,
      averageRating: double.tryParse(json['average_rating'].toString()) ?? 0,
      totalReviews: json['total_reviews'] ?? 0,
      totalWeeklyHours: double.tryParse(json['total_weekly_hours'].toString()) ?? 0,
      requiredWeeklyHours: json['required_weekly_hours'] ?? 20,
      specialties: (json['specialties'] as List? ?? [])
          .map((s) => Specialty.fromJson(s))
          .toList(),
      availability: (json['availability'] as List? ?? [])
          .map((a) => WeeklyAvailability.fromJson(a))
          .toList(),
    );
  }
}
