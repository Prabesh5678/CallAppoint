import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/appointments/models/appointment.dart';
import '../../features/appointments/providers/appointment_provider.dart';
import '../../core/globals.dart';
import 'package:go_router/go_router.dart';
import 'pulse_indicator.dart';
import 'glowing_effect.dart';

class AppointmentCard extends ConsumerWidget {
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
    final colorScheme = Theme.of(context).colorScheme;
    switch (appointment.status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
        return colorScheme.error;
      case 'completed':
        return colorScheme.primary;
      default:
        return colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('MMM d, y • h:mm a');
    final otherPartyName = isDoctorView
        ? (appointment.patientName ?? 'Unknown Patient')
        : appointment.displayDoctorName;

    final isOtherWaiting = ref.watch(peerPresenceProvider(appointment.id)).maybeWhen(
      data: (isPresent) => isPresent,
      orElse: () => false,
    );

    final isActiveCall = ref.watch(activeCallIdProvider) == appointment.id;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      isDoctorView ? Icons.person : Icons.medical_services,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          otherPartyName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Theme.of(context).hintColor),
                            const SizedBox(width: 4),
                            Text(
                              dateFmt.format(appointment.scheduledStart),
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(context),
                ],
              ),

              if (isOtherWaiting && appointment.status == 'confirmed' && !isActiveCall) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const PulseIndicator(size: 8),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${isDoctorView ? "Patient" : "Doctor"} is waiting for you',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (appointment.reasonForVisit != null &&
                  appointment.reasonForVisit!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    appointment.reasonForVisit!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              if (appointment.status == 'confirmed') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 20),
                        label: const Text('Message'),
                        onPressed: () =>
                            context.push('/chat/${appointment.id}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlowingEffect(
                        isGlowing: isActiveCall || isOtherWaiting,
                        color: Colors.green,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActiveCall ? Colors.green : null,
                            foregroundColor: isActiveCall ? Colors.white : null,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(
                            isActiveCall ? Icons.call_received : Icons.videocam,
                            size: 20,
                          ),
                          label: Text(isActiveCall ? 'Return' : 'Join Call'),
                          onPressed: () =>
                              context.push('/video/${appointment.id}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (isDoctorView && appointment.status == 'pending') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          side: BorderSide(color: Theme.of(context).colorScheme.error.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: onReject,
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      child: const Text('Cancel Appointment'),
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

  Widget _buildStatusBadge(BuildContext context) {
    final color = _statusColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        appointment.status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
