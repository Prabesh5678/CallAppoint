import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../features/appointments/models/appointment.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool isDoctorView;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final VoidCallback? onTap;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.isDoctorView,
    this.onConfirm,
    this.onReject,
    this.onCancel,
    this.onTap,
  });

  Color _statusColor(BuildContext context) {
    switch (appointment.status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, y • h:mm a');
    final otherPartyName = isDoctorView
        ? appointment.patientName
        : appointment.doctorName;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      otherPartyName ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(context).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      appointment.status.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dateFmt.format(appointment.scheduledStart),
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
              if (appointment.reasonForVisit != null &&
                  appointment.reasonForVisit!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  appointment.reasonForVisit!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (isDoctorView && appointment.status == 'pending') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onConfirm,
                        child: const Text('Confirm'),
                      ),
                    ),
                  ],
                ),
              ],
              if (appointment.status == 'pending' ||
                  appointment.status == 'confirmed') ...[
                if (!isDoctorView || appointment.status == 'confirmed') ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onCancel,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
