import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dio_client.dart';
import '../models/medical_profile.dart';
import '../models/clinical_diagnosis.dart';
import '../models/biomarker.dart';
import '../models/dashboard_data.dart';

// Dashboard Provider
final patientDashboardProvider = FutureProvider.autoDispose<PatientDashboardData>((ref) async {
  final response = await DioClient.instance.get('/patients/dashboard/');
  return PatientDashboardData.fromJson(response.data);
});

// Medical Profile Provider
class MedicalProfileNotifier extends AutoDisposeAsyncNotifier<PatientMedicalProfile?> {
  @override
  FutureOr<PatientMedicalProfile?> build() async {
    try {
      final response = await DioClient.instance.get('/patients/me/');
      return PatientMedicalProfile.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateProfile(PatientMedicalProfile profile) async {
    state = const AsyncLoading();
    try {
      final response = await DioClient.instance.put(
        '/patients/me/',
        data: profile.toJson(),
      );
      state = AsyncData(PatientMedicalProfile.fromJson(response.data));
      ref.invalidate(patientDashboardProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final medicalProfileProvider = AsyncNotifierProvider.autoDispose<MedicalProfileNotifier, PatientMedicalProfile?>(
  () => MedicalProfileNotifier(),
);

// Diagnoses Provider
final patientDiagnosesProvider = FutureProvider.autoDispose<List<ClinicalDiagnosis>>((ref) async {
  final response = await DioClient.instance.get('/patients/diagnoses/');
  final data = response.data;
  if (data is Map && data.containsKey('results')) {
    final list = data['results'] as List;
    return list.map((json) => ClinicalDiagnosis.fromJson(json)).toList();
  }
  final list = data as List;
  return list.map((json) => ClinicalDiagnosis.fromJson(json)).toList();
});

// Biomarkers Provider
final patientBiomarkersProvider = FutureProvider.family.autoDispose<List<Biomarker>, String?>((ref, name) async {
  String url = '/patients/biomarkers/';
  if (name != null) {
    url += '?name=$name';
  }
  final response = await DioClient.instance.get(url);
  final data = response.data;
  if (data is Map && data.containsKey('results')) {
    final list = data['results'] as List;
    return list.map((json) => Biomarker.fromJson(json)).toList();
  }
  final list = data as List;
  return list.map((json) => Biomarker.fromJson(json)).toList();
});

// Biomarker Trends Provider
final biomarkerTrendProvider = FutureProvider.family.autoDispose<BiomarkerTrend, String>((ref, patientId) async {
  final name = ref.watch(selectedBiomarkerNameProvider);
  final response = await DioClient.instance.get('/patients/trends/$patientId/?name=$name');
  return BiomarkerTrend.fromJson(response.data);
});

final selectedBiomarkerNameProvider = StateProvider<String>((ref) => 'Glucose');

// Biomarker Actions
class BiomarkerActions {
  final Ref ref;
  BiomarkerActions(this.ref);

  Future<void> addBiomarker({
    required String name,
    required double value,
    required String unit,
    String? referenceRange,
    required DateTime recordedAt,
    String? notes,
  }) async {
    await DioClient.instance.post(
      '/patients/biomarkers/',
      data: {
        'name': name,
        'value': value,
        'unit': unit,
        'reference_range': referenceRange,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'notes': notes,
      },
    );
    ref.invalidate(patientBiomarkersProvider(null));
    ref.invalidate(patientDashboardProvider);
  }

  Future<void> deleteBiomarker(String id) async {
    await DioClient.instance.delete('/patients/biomarkers/$id/');
    ref.invalidate(patientBiomarkersProvider(null));
    ref.invalidate(patientDashboardProvider);
  }
}

final biomarkerActionsProvider = Provider((ref) => BiomarkerActions(ref));
