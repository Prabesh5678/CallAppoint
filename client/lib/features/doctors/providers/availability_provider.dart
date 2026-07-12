import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dio_client.dart';

class WeeklySlot {
  final String id;
  final int dayOfWeek; // 0=Sun .. 6=Sat, matching backend
  final String startTime; // "HH:MM:SS"
  final String endTime;
  final int slotDurationMinutes;

  WeeklySlot({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.slotDurationMinutes,
  });

  factory WeeklySlot.fromJson(Map<String, dynamic> json) => WeeklySlot(
    id: json['id'],
    dayOfWeek: json['day_of_week'],
    startTime: json['start_time'],
    endTime: json['end_time'],
    slotDurationMinutes: json['slot_duration_minutes'],
  );
}

final myAvailabilityProvider = FutureProvider.autoDispose<List<WeeklySlot>>((
  ref,
) async {
  final response = await DioClient.instance.get('/doctors/me/availability/');
  return (response.data as List).map((s) => WeeklySlot.fromJson(s)).toList();
});

class AvailabilityController {
  Future<void> add({
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    int slotDurationMinutes = 30,
  }) async {
    await DioClient.instance.post(
      '/doctors/me/availability/',
      data: {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'slot_duration_minutes': slotDurationMinutes,
        'is_active': true,
      },
    );
  }

  Future<void> delete(String id) async {
    await DioClient.instance.delete('/doctors/me/availability/$id/');
  }
}

final availabilityControllerProvider = Provider(
  (ref) => AvailabilityController(),
);
