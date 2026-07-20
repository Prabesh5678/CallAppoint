import 'dart:async';
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

class MyAvailabilityNotifier extends AutoDisposeAsyncNotifier<List<WeeklySlot>> {
  @override
  FutureOr<List<WeeklySlot>> build() async {
    final response = await DioClient.instance.get('/doctors/me/availability/');
    return (response.data as List).map((s) => WeeklySlot.fromJson(s)).toList();
  }

  void setSlots(List<WeeklySlot> slots) {
    state = AsyncData(slots);
  }
}

final myAvailabilityProvider = AsyncNotifierProvider.autoDispose<MyAvailabilityNotifier, List<WeeklySlot>>(
  () => MyAvailabilityNotifier(),
);

class AvailabilityController {
  final Ref ref;
  AvailabilityController(this.ref);

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
    ref.invalidate(myAvailabilityProvider);
  }

  Future<void> deleteWithUndo({
    required String id,
    required void Function(Future<void> Function() onUndo, void Function() dismiss) showUndoSnackBar,
  }) async {
    final previousState = ref.read(myAvailabilityProvider).valueOrNull;
    if (previousState == null) return;

    // Optimistic remove
    final updatedList = previousState.where((s) => s.id != id).toList();
    ref.read(myAvailabilityProvider.notifier).setSlots(updatedList);

    bool wasUndone = false;
    final userActionCompleter = Completer<void>();

    showUndoSnackBar(
      () async {
        if (userActionCompleter.isCompleted) return;
        wasUndone = true;
        ref.read(myAvailabilityProvider.notifier).setSlots(previousState);
        userActionCompleter.complete();
      },
      () {
        if (!userActionCompleter.isCompleted) userActionCompleter.complete();
      },
    );

    // Independent fallback timer
    final timer = Timer(const Duration(milliseconds: 4500), () {
      if (!userActionCompleter.isCompleted) {
        userActionCompleter.complete();
      }
    });

    await userActionCompleter.future;
    timer.cancel();

    if (!wasUndone) {
      try {
        await DioClient.instance.delete('/doctors/me/availability/$id/');
      } catch (e) {
        ref.read(myAvailabilityProvider.notifier).setSlots(previousState);
        rethrow;
      }
    }
  }
}

final availabilityControllerProvider = Provider(
  (ref) => AvailabilityController(ref),
);
