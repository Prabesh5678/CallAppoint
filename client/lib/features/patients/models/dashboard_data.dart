import 'medical_profile.dart';
import 'clinical_diagnosis.dart';

class PatientDashboardData {
  final PatientMedicalProfile? medicalProfile;
  final ClinicalDiagnosis? latestDiagnosis;
  final Map<String, List<Map<String, dynamic>>> biomarkerSummaries;
  final bool isLive;

  PatientDashboardData({
    this.medicalProfile,
    this.latestDiagnosis,
    required this.biomarkerSummaries,
    this.isLive = false,
  });

  factory PatientDashboardData.fromJson(Map<String, dynamic> json) {
    return PatientDashboardData(
      medicalProfile: json['medical_profile'] != null
          ? PatientMedicalProfile.fromJson(json['medical_profile'])
          : null,
      latestDiagnosis: json['latest_diagnosis'] != null
          ? ClinicalDiagnosis.fromJson(json['latest_diagnosis'])
          : (json['latest_diagnosis'] is Map && json['latest_diagnosis'].containsKey('condition')
              ? null // Handle the precomputed string version if needed, or just let it be null
              : null),
      biomarkerSummaries: Map<String, List<Map<String, dynamic>>>.from(
        (json['biomarker_summaries'] ?? {}).map(
          (key, value) => MapEntry(key, List<Map<String, dynamic>>.from(value)),
        ),
      ),
      isLive: json['is_live'] ?? false,
    );
  }
}
