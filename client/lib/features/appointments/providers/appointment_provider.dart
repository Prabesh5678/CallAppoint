import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dio_client.dart';
import '../models/appointment.dart';
import '../../notifications/providers/notification_provider.dart';

final myAppointmentsProvider = FutureProvider.autoDispose<List<Appointment>>((
  ref,
) async {
  final response = await DioClient.instance.get('/appointments/mine/');
  final list = response.data as List;
  return list.map((json) => Appointment.fromJson(json)).toList();
});

final peerPresenceProvider = StreamProvider.family.autoDispose<bool, String>((ref, appointmentId) async* {
  // 1. Initial fetch from API
  bool currentStatus = false;
  try {
    final response = await DioClient.instance.get('/chat/$appointmentId/video-presence/');
    currentStatus = response.data['is_present'] as bool;
    yield currentStatus;
  } catch (_) {
    yield false;
  }

  // 2. Listen to real-time events from notification socket
  final presenceMap = ref.watch(notificationManagerProvider);
  if (presenceMap.containsKey(appointmentId)) {
    yield presenceMap[appointmentId]!;
  } else {
    // If no new event has arrived, keep yielding the last known status
    yield currentStatus;
  }
});

class AppointmentActions {
  Future<void> respond(String appointmentId, String action) async {
    await DioClient.instance.post(
      '/appointments/$appointmentId/respond/',
      data: {'action': action},
    );
  }

  Future<void> cancel(String appointmentId, {String? reason}) async {
    await DioClient.instance.post(
      '/appointments/$appointmentId/cancel/',
      data: {'reason': reason ?? ''},
    );
  }
}

final appointmentActionsProvider = Provider((ref) => AppointmentActions());
