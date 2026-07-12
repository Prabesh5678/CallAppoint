import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/dio_client.dart';
import '../models/doctor.dart';

final doctorDetailProvider = FutureProvider.autoDispose.family<Doctor, String>((
  ref,
  doctorId,
) async {
  final response = await DioClient.instance.get('/doctors/$doctorId/');
  return Doctor.fromJson(response.data);
});

class Slot {
  final DateTime start;
  final DateTime end;
  final bool isAvailable;
  Slot({required this.start, required this.end, required this.isAvailable});

  factory Slot.fromJson(Map<String, dynamic> json) {
    return Slot(
      start: DateTime.parse(json['start']),
      end: DateTime.parse(json['end']),
      isAvailable: json['is_available'] ?? true,
    );
  }
}

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final availableSlotsProvider = FutureProvider.autoDispose
    .family<List<Slot>, String>((ref, doctorId) async {
      final date = ref.watch(selectedDateProvider);
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await DioClient.instance.get(
        '/appointments/doctor/$doctorId/slots/',
        queryParameters: {'date': dateStr},
      );
      return (response.data as List).map((s) => Slot.fromJson(s)).toList();
    });
