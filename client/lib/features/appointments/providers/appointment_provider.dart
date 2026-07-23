import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dio_client.dart';
import '../../../core/undo_manager.dart';
import '../models/appointment.dart';
import '../../notifications/providers/notification_provider.dart';

class MyAppointmentsNotifier extends AutoDisposeAsyncNotifier<List<Appointment>> {
  @override
  FutureOr<List<Appointment>> build() async {
    final response = await DioClient.instance.get('/appointments/mine/');
    final data = response.data;
    if (data is Map && data.containsKey('results')) {
      final list = data['results'] as List;
      return list.map((json) => Appointment.fromJson(json)).toList();
    }
    final list = data as List;
    return list.map((json) => Appointment.fromJson(json)).toList();
  }

  void setAppointments(List<Appointment> list) {
    state = AsyncData(list);
  }
}

final myAppointmentsProvider = AsyncNotifierProvider.autoDispose<MyAppointmentsNotifier, List<Appointment>>(
  () => MyAppointmentsNotifier(),
);

final peerPresenceProvider = StreamProvider.family.autoDispose<bool, String>((ref, appointmentId) async* {
  final socketStatus = ref.watch(notificationManagerProvider.select((map) => map[appointmentId]));

  if (socketStatus != null) {
    yield socketStatus;
    return;
  }

  try {
    final response = await DioClient.instance.get('/chat/$appointmentId/video-presence/');
    final isPresent = response.data['is_present'] as bool;
    ref.read(notificationManagerProvider.notifier).setPresence(appointmentId, isPresent);
    yield isPresent;
  } catch (_) {
    yield false;
  }
});

class AppointmentActions {
  final Ref ref;
  AppointmentActions(this.ref);

  Future<void> respond(String appointmentId, String action) async {
    await DioClient.instance.post(
      '/appointments/$appointmentId/respond/',
      data: {'action': action},
    );
    ref.invalidate(myAppointmentsProvider);
  }

  Future<void> cancelWithUndo({required String appointmentId, String? reason}) async {
    final previousState = ref.read(myAppointmentsProvider).valueOrNull;
    if (previousState == null) return;

    final updatedList = previousState.where((a) => a.id != appointmentId).toList();
    ref.read(myAppointmentsProvider.notifier).setAppointments(updatedList);

    final result = await UndoManager.showUndoSnackBar(
      message: 'Appointment cancelled',
      onUndo: () => ref.read(myAppointmentsProvider.notifier).setAppointments(previousState),
    );

    if (!result.wasUndone) {
      try {
        await DioClient.instance.post(
          '/appointments/$appointmentId/cancel/',
          data: {'reason': reason ?? ''},
        );
      } catch (e) {
        ref.read(myAppointmentsProvider.notifier).setAppointments(previousState);
        rethrow;
      }
    }
  }
}

final appointmentActionsProvider = Provider((ref) => AppointmentActions(ref));
