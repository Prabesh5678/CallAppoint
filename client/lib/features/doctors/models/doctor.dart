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

class Doctor {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final double consultationFee;
  final int yearsExperience;
  final double averageRating;
  final int totalReviews;
  final List<Specialty> specialties;

  Doctor({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.consultationFee,
    required this.yearsExperience,
    required this.averageRating,
    required this.totalReviews,
    required this.specialties,
  });

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
      specialties: (json['specialties'] as List? ?? [])
          .map((s) => Specialty.fromJson(s))
          .toList(),
    );
  }
}
