import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dio_client.dart';
import '../models/doctor.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedSpecialtyProvider = StateProvider<String?>((ref) => null);
final filterDateProvider = StateProvider<DateTime?>((ref) => null);
final filterTimeProvider = StateProvider<DateTime?>((ref) => null);

final specialtiesProvider = FutureProvider.autoDispose<List<Specialty>>((
  ref,
) async {
  final response = await DioClient.instance.get('/doctors/specialties/');
  final data = response.data;
  final List list = (data is Map && data.containsKey('results')) ? data['results'] : data;
  return list.map((s) => Specialty.fromJson(s)).toList();
});

final doctorsProvider = FutureProvider.autoDispose<List<Doctor>>((ref) async {
  final search = ref.watch(searchQueryProvider);
  final specialtyId = ref.watch(selectedSpecialtyProvider);
  final filterDate = ref.watch(filterDateProvider);
  final filterTime = ref.watch(filterTimeProvider);

  final queryParams = <String, dynamic>{};
  if (search.isNotEmpty) queryParams['search'] = search;
  if (specialtyId != null) queryParams['specialty'] = specialtyId;

  if (filterDate != null) {
    queryParams['date'] = '${filterDate.year}-${filterDate.month.toString().padLeft(2, '0')}-${filterDate.day.toString().padLeft(2, '0')}';
  }
  if (filterTime != null) {
    queryParams['time'] = '${filterTime.hour.toString().padLeft(2, '0')}:${filterTime.minute.toString().padLeft(2, '0')}';
  }

  final response = await DioClient.instance.get(
    '/doctors/',
    queryParameters: queryParams,
  );
  final data = response.data;
  final List list = (data is Map && data.containsKey('results')) ? data['results'] : data;
  return list.map((d) => Doctor.fromJson(d)).toList();
});

final myDoctorProfileProvider = FutureProvider.autoDispose<Doctor>((ref) async {
  final response = await DioClient.instance.get('/doctors/me/');
  return Doctor.fromJson(response.data);
});
