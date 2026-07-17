import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dio_client.dart';
import '../models/appointment.dart';

final myAppointmentsProvider = FutureProvider.autoDispose<List<Appointment>>((
  ref,
) async {
  final response = await DioClient.instance.get('/appointments/mine/');
  final list = response.data as List;
  return list.map((json) => Appointment.fromJson(json)).toList();
});

final peerPresenceProvider = StreamProvider.family.autoDispose<bool, String>((ref, appointmentId) async* {
  // Poll the backend every 2 seconds for faster updates
  while (true) {
    try {
      final response = await DioClient.instance.get('/chat/$appointmentId/video-presence/');
      yield response.data['is_present'] as bool;
    } catch (e) {
      yield false;
    }
    await Future.delayed(const Duration(seconds: 2));
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
