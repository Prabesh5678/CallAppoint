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
  // 1. Watch ONLY the status for this specific appointment to avoid unnecessary rebuilds
  final socketStatus = ref.watch(notificationManagerProvider.select((map) => map[appointmentId]));

  if (socketStatus != null) {
    yield socketStatus;
    return; // Trust the socket/manager state if it exists
  }

  // 2. Fallback to initial fetch if socket hasn't received an event yet
  try {
    final response = await DioClient.instance.get('/chat/$appointmentId/video-presence/');
    final isPresent = response.data['is_present'] as bool;

    // Sync the global manager so tabs/other UI can see this state
    // We use ref.read to avoid creating a circular dependency
    ref.read(notificationManagerProvider.notifier).setPresence(appointmentId, isPresent);

    yield isPresent;
  } catch (_) {
    yield false;
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
