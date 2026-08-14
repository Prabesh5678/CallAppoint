class PatientMedicalProfile {
  final String id;
  final String fullName;
  final String? bloodGroup;
  final String smokingStatus;
  final String alcoholConsumption;
  final String? exerciseFrequency;
  final String? allergies;
  final String? chronicConditions;
  final bool familyCancerHistory;
  final String? familyHistoryDetails;
  final DateTime updatedAt;

  PatientMedicalProfile({
    required this.id,
    required this.fullName,
    this.bloodGroup,
    required this.smokingStatus,
    required this.alcoholConsumption,
    this.exerciseFrequency,
    this.allergies,
    this.chronicConditions,
    required this.familyCancerHistory,
    this.familyHistoryDetails,
    required this.updatedAt,
  });

  factory PatientMedicalProfile.fromJson(Map<String, dynamic> json) {
    return PatientMedicalProfile(
      id: json['id'],
      fullName: json['full_name'],
      bloodGroup: json['blood_group'],
      smokingStatus: json['smoking_status'],
      alcoholConsumption: json['alcohol_consumption'],
      exerciseFrequency: json['exercise_frequency'],
      allergies: json['allergies'],
      chronicConditions: json['chronic_conditions'],
      familyCancerHistory: json['family_cancer_history'] ?? false,
      familyHistoryDetails: json['family_history_details'],
      updatedAt: DateTime.parse(json['updated_at']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blood_group': bloodGroup,
      'smoking_status': smokingStatus,
      'alcohol_consumption': alcoholConsumption,
      'exercise_frequency': exerciseFrequency,
      'allergies': allergies,
      'chronic_conditions': chronicConditions,
      'family_cancer_history': familyCancerHistory,
      'family_history_details': familyHistoryDetails,
    };
  }
}
