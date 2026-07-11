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
