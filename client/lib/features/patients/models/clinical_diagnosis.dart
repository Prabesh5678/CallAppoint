class ClinicalDiagnosis {
  final String id;
  final String patient;
  final String patientName;
  final String? doctor;
  final String? doctorName;
  final String icdCode;
  final String conditionName;
  final DateTime dateOfDiagnosis;
  final String? tumorStage;
  final String? nodesStage;
  final String? metastasisStage;
  final String? overallStage;
  final String? histology;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;

  ClinicalDiagnosis({
    required this.id,
    required this.patient,
    required this.patientName,
    this.doctor,
    this.doctorName,
    required this.icdCode,
    required this.conditionName,
    required this.dateOfDiagnosis,
    this.tumorStage,
    this.nodesStage,
    this.metastasisStage,
    this.overallStage,
    this.histology,
    required this.isActive,
    this.notes,
    required this.createdAt,
  });

  factory ClinicalDiagnosis.fromJson(Map<String, dynamic> json) {
    return ClinicalDiagnosis(
      id: json['id'],
      patient: json['patient'],
      patientName: json['patient_name'],
      doctor: json['doctor'],
      doctorName: json['doctor_name'],
      icdCode: json['icd_code'],
      conditionName: json['condition_name'],
      dateOfDiagnosis: DateTime.parse(json['date_of_diagnosis']),
      tumorStage: json['tumor_stage'],
      nodesStage: json['nodes_stage'],
      metastasisStage: json['metastasis_stage'],
      overallStage: json['overall_stage'],
      histology: json['histology'],
      isActive: json['is_active'] ?? true,
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}
