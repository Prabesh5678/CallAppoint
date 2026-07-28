import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/appointment_provider.dart';

class ScheduleFollowupDialog extends ConsumerStatefulWidget {
  final String parentAppointmentId;
  final String doctorId;

  const ScheduleFollowupDialog({
    super.key,
    required this.parentAppointmentId,
    required this.doctorId,
  });

  @override
  ConsumerState<ScheduleFollowupDialog> createState() => _ScheduleFollowupDialogState();
}

class _ScheduleFollowupDialogState extends ConsumerState<ScheduleFollowupDialog> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _reasonController = TextEditingController(text: 'Follow-up appointment');
  bool _isLoading = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    final start = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    if (start.isBefore(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot schedule an appointment in the past')),
        );
      }
      return;
    }

    // Default duration 30 mins
    final end = start.add(const Duration(minutes: 30));

    setState(() => _isLoading = true);
    try {
      await ref.read(appointmentActionsProvider).scheduleFollowup(
            parentAppointmentId: widget.parentAppointmentId,
            doctorId: widget.doctorId,
            start: start,
            end: end,
            reason: _reasonController.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Schedule Follow-up'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(_selectedDate == null
              ? 'Select Date'
              : DateFormat.yMMMd().format(_selectedDate!)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _selectDate,
          ),
          ListTile(
            title: Text(_selectedTime == null
              ? 'Select Time'
              : _selectedTime!.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: _selectTime,
          ),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: 'Reason/Notes'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const CircularProgressIndicator() : const Text('Schedule'),
        ),
      ],
    );
  }
}
