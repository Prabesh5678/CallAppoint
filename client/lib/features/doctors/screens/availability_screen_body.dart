import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/availability_provider.dart';
import '../../appointments/providers/appointment_provider.dart';
import '../../appointments/models/appointment.dart';

const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class AvailabilityScreenBody extends ConsumerStatefulWidget {
  const AvailabilityScreenBody({super.key});

  @override
  ConsumerState<AvailabilityScreenBody> createState() =>
      _AvailabilityScreenBodyState();
}


class _AvailabilityScreenBodyState
    extends ConsumerState<AvailabilityScreenBody> {
  String _fmtTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Schedule'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Current Routine', icon: Icon(Icons.calendar_view_week)),
              Tab(text: 'Manage Schedule', icon: Icon(Icons.edit_calendar)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RoutineView(),
            _ManageView(
              onAdd: (day, start, end, duration) async {
                try {
                  await ref.read(availabilityControllerProvider).add(
                        dayOfWeek: day,
                        startTime: _fmtTimeOfDay(start),
                        endTime: _fmtTimeOfDay(end),
                        slotDurationMinutes: duration,
                      );
                  ref.invalidate(myAvailabilityProvider);
                } catch (e) {
                  // Error handling already in provider/controller or shown via snackbar
                  rethrow;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availabilityAsync = ref.watch(myAvailabilityProvider);

    return availabilityAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (slots) {
        if (slots.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No schedule set yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                Text('Go to "Manage" to add your availability.'),
              ],
            ),
          );
        }

        // Group slots by day
        final grouped = <int, List<WeeklySlot>>{};
        for (var s in slots) {
          grouped.putIfAbsent(s.dayOfWeek, () => []).add(s);
        }

        final days = grouped.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            final daySlots = grouped[day]!..sort((a, b) => a.startTime.compareTo(b.startTime));

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Text(
                      _dayNames[day],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  ...daySlots.map((s) => ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text(
                      '${s.startTime.substring(0, 5)} - ${s.endTime.substring(0, 5)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text('Slot duration: ${s.slotDurationMinutes} mins'),
                  )),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FollowupWarning extends StatelessWidget {
  final int selectedDay;
  final List<Appointment> appointments;

  const _FollowupWarning({required this.selectedDay, required this.appointments});

  @override
  Widget build(BuildContext context) {
    // dayOfWeek is 0=Sun .. 6=Sat in our model
    // DateTime.weekday is 1=Mon .. 7=Sun
    // Convert DateTime.weekday to our model format: (weekday % 7)
    final relevantAppts = appointments.where((a) {
      if (a.status != 'confirmed') return false;
      final apptDay = a.scheduledStart.toLocal().weekday % 7;
      return apptDay == selectedDay && a.scheduledStart.isAfter(DateTime.now());
    }).toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

    if (relevantAppts.isEmpty) return const SizedBox.shrink();

    // Just show the next few
    final displayAppts = relevantAppts.take(2).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Appointments on ${_dayNames[selectedDay]}s',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...displayAppts.map((a) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '• ${DateFormat('MMM d, h:mm a').format(a.scheduledStart.toLocal())} (${a.patientName})',
              style: const TextStyle(fontSize: 13),
            ),
          )),
          if (relevantAppts.length > 2)
            const Text('• ... and more', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ManageView extends ConsumerWidget {
  final Future<void> Function(int day, TimeOfDay start, TimeOfDay end, int duration) onAdd;

  const _ManageView({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availabilityAsync = ref.watch(myAvailabilityProvider);
    final appointmentsAsync = ref.watch(myAppointmentsProvider);

    return availabilityAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (slots) {
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: 7,
          itemBuilder: (context, dayIndex) {
            final daySlots = slots.where((s) => s.dayOfWeek == dayIndex).toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));

            return _DayManagementCard(
              dayIndex: dayIndex,
              slots: daySlots,
              appointments: appointmentsAsync.valueOrNull ?? [],
              onAdd: onAdd,
            );
          },
        );
      },
    );
  }
}

class _DayManagementCard extends ConsumerStatefulWidget {
  final int dayIndex;
  final List<WeeklySlot> slots;
  final List<Appointment> appointments;
  final Future<void> Function(int day, TimeOfDay start, TimeOfDay end, int duration) onAdd;

  const _DayManagementCard({
    required this.dayIndex,
    required this.slots,
    required this.appointments,
    required this.onAdd,
  });

  @override
  ConsumerState<_DayManagementCard> createState() => _DayManagementCardState();
}

class _DayManagementCardState extends ConsumerState<_DayManagementCard> {
  bool _isAdding = false;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  int _duration = 30;

  @override
  Widget build(BuildContext context) {
    final hasAppts = widget.appointments.any((a) =>
        a.status == 'confirmed' &&
        (a.scheduledStart.toLocal().weekday % 7) == widget.dayIndex &&
        a.scheduledStart.isAfter(DateTime.now()));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: [
          ListTile(
            title: Text(
              _dayNames[widget.dayIndex],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            trailing: _isAdding
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _isAdding = false),
                  )
                : TextButton.icon(
                    onPressed: () => setState(() => _isAdding = true),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Time'),
                  ),
          ),
          if (hasAppts)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _FollowupWarning(
                selectedDay: widget.dayIndex,
                appointments: widget.appointments,
              ),
            ),
          if (_isAdding)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final p = await showTimePicker(context: context, initialTime: _start);
                            if (p != null) setState(() => _start = p);
                          },
                          child: Text('Start: ${_start.format(context)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final p = await showTimePicker(context: context, initialTime: _end);
                            if (p != null) setState(() => _end = p);
                          },
                          child: Text('End: ${_end.format(context)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Slot length: '),
                      DropdownButton<int>(
                        value: _duration,
                        items: [15, 30, 45, 60]
                            .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                            .toList(),
                        onChanged: (v) => setState(() => _duration = v ?? 30),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () async {
                          final startMinutes = _start.hour * 60 + _start.minute;
                          final endMinutes = _end.hour * 60 + _end.minute;

                          if (endMinutes <= startMinutes) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('End time must be after start time')),
                            );
                            return;
                          }

                          // Client-side overlap check
                          final newStart = '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}:00';
                          final newEnd = '${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}:00';

                          final isOverlapping = widget.slots.any((s) {
                            return s.startTime.compareTo(newEnd) < 0 && s.endTime.compareTo(newStart) > 0;
                          });

                          if (isOverlapping) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('This time overlaps with an existing slot'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          try {
                            await widget.onAdd(widget.dayIndex, _start, _end, _duration);
                            setState(() => _isAdding = false);
                          } catch (e) {
                            // Error shown by parent via Dio interceptor or snackbar
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (widget.slots.isEmpty && !_isAdding)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Not available', style: TextStyle(color: Colors.grey)),
            ),
          ...widget.slots.map((slot) => ListTile(
                dense: true,
                leading: const Icon(Icons.access_time, size: 20),
                title: Text('${slot.startTime.substring(0, 5)} - ${slot.endTime.substring(0, 5)}'),
                subtitle: Text('${slot.slotDurationMinutes} min slots'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => ref.read(availabilityControllerProvider).deleteWithUndo(slot.id),
                ),
              )),
        ],
      ),
    );
  }
}
