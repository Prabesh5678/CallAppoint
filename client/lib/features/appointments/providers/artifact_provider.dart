import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dio_client.dart';
import '../models/artifact.dart';

class ArtifactsNotifier extends AutoDisposeAsyncNotifier<List<Artifact>> {
  @override
  FutureOr<List<Artifact>> build() async {
    final response = await DioClient.instance.get('/artifacts/');
    final data = response.data;
    if (data is Map && data.containsKey('results')) {
      final list = data['results'] as List;
      return list.map((json) => Artifact.fromJson(json)).toList();
    }
    final list = data as List;
    return list.map((json) => Artifact.fromJson(json)).toList();
  }
}

final artifactsProvider = AsyncNotifierProvider.autoDispose<ArtifactsNotifier, List<Artifact>>(
  () => ArtifactsNotifier(),
);

final artifactFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

final filteredArtifactsProvider = Provider.autoDispose<AsyncValue<List<Artifact>>>((ref) {
  final artifactsAsync = ref.watch(artifactsProvider);
  final filter = ref.watch(artifactFilterProvider);

  return artifactsAsync.whenData((artifacts) {
    if (filter == null || filter == 'All') return artifacts;
    return artifacts.where((a) => a.reportType == filter).toList();
  });
});

final appointmentArtifactsProvider = FutureProvider.family.autoDispose<List<Artifact>, String>((ref, appointmentId) async {
  final response = await DioClient.instance.get('/artifacts/', queryParameters: {'appointment': appointmentId});
  final data = response.data;
  List list;
  if (data is Map && data.containsKey('results')) {
    list = data['results'] as List;
  } else {
    list = data as List;
  }
  return list.map((json) => Artifact.fromJson(json)).toList();
});

final patientDoctorArtifactsProvider = FutureProvider.family.autoDispose<List<Artifact>, ({String patientId, String doctorId})>((ref, arg) async {
  final response = await DioClient.instance.get('/artifacts/', queryParameters: {
    'patient': arg.patientId,
    'doctor': arg.doctorId,
  });
  final data = response.data;
  List list;
  if (data is Map && data.containsKey('results')) {
    list = data['results'] as List;
  } else {
    list = data as List;
  }
  return list.map((json) => Artifact.fromJson(json)).toList();
});
