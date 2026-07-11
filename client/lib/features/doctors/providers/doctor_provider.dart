import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dio_client.dart';
import '../models/doctor.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedSpecialtyProvider = StateProvider<String?>((ref) => null);

final specialtiesProvider = FutureProvider.autoDispose<List<Specialty>>((
  ref,
) async {
  final response = await DioClient.instance.get('/doctors/specialties/');
  return (response.data as List).map((s) => Specialty.fromJson(s)).toList();
});

final doctorsProvider = FutureProvider.autoDispose<List<Doctor>>((ref) async {
  final search = ref.watch(searchQueryProvider);
  final specialtyId = ref.watch(selectedSpecialtyProvider);

  final queryParams = <String, dynamic>{};
  if (search.isNotEmpty) queryParams['search'] = search;
  if (specialtyId != null) queryParams['specialty'] = specialtyId;

  final response = await DioClient.instance.get(
    '/doctors/',
    queryParameters: queryParams,
  );
  return (response.data as List).map((d) => Doctor.fromJson(d)).toList();
});
