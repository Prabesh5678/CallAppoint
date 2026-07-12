import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/availability_provider.dart';

const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class AvailabilityScreenBody extends ConsumerStatefulWidget {
  const AvailabilityScreenBody({super.key});

  @override
  ConsumerState<AvailabilityScreenBody> createState() =>
      _AvailabilityScreenBodyState();
}


class _AvailabilityScreenBodyState
    extends ConsumerState<AvailabilityScreenBody> {
  int _selectedDay = 1; // default Monday
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  int _slotDuration = 30;

  String _fmtTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _addSlot() async {
    try {
      await ref
          .read(availabilityControllerProvider)
          .add(
            dayOfWeek: _selectedDay,
            startTime: _fmtTimeOfDay(_startTime),
            endTime: _fmtTimeOfDay(_endTime),
            slotDurationMinutes: _slotDuration,
          );
      ref.invalidate(myAvailabilityProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Availability added')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availabilityAsync = ref.watch(myAvailabilityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Schedule')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Weekly Availability',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      children: List.generate(7, (i) {
                        return ChoiceChip(
                          label: Text(_dayNames[i]),
                          selected: _selectedDay == i,
                          onSelected: (_) => setState(() => _selectedDay = i),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (picked != null)
                                setState(() => _startTime = picked);
                            },
                            child: Text('Start: ${_startTime.format(context)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _endTime,
                              );
                              if (picked != null)
                                setState(() => _endTime = picked);
                            },
                            child: Text('End: ${_endTime.format(context)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Slot length: '),
                        DropdownButton<int>(
                          value: _slotDuration,
                          items: [15, 30, 45, 60]
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('$m min'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _slotDuration = v ?? 30),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addSlot,
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: availabilityAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (slots) {
                if (slots.isEmpty) {
                  return const Center(child: Text('No availability set yet'));
                }
                return ListView.builder(
                  itemCount: slots.length,
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(_dayNames[slot.dayOfWeek]),
                      ),
                      title: Text(
                        '${slot.startTime.substring(0, 5)} - ${slot.endTime.substring(0, 5)}',
                      ),
                      subtitle: Text('${slot.slotDurationMinutes} min slots'),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          await ref
                              .read(availabilityControllerProvider)
                              .delete(slot.id);
                          ref.invalidate(myAvailabilityProvider);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
