import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/appointments/models/appointment.dart';
import '../../features/appointments/providers/appointment_provider.dart';
import 'package:go_router/go_router.dart';

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
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('MMM d, y • h:mm a');
    final otherPartyName = isDoctorView
        ? appointment.patientName
        : appointment.doctorName;

    final isOtherWaiting = ref.watch(peerPresenceProvider(appointment.id)).maybeWhen(
      data: (isPresent) => isPresent,
      orElse: () => false,
    );

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

              if (isOtherWaiting && appointment.status == 'confirmed') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const _PulseIndicator(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${isDoctorView ? "Patient" : "Doctor"} has joined and is waiting for you',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (appointment.reasonForVisit != null &&
                  appointment.reasonForVisit!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  appointment.reasonForVisit!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (appointment.status == 'confirmed') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Chat'),
                        onPressed: () =>
                            context.push('/chat/${appointment.id}'),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.videocam, size: 18),
                            label: const Text('Join Call'),
                            onPressed: () =>
                                context.push('/video/${appointment.id}'),
                          ),
                          if (isOtherWaiting)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: const _PulseIndicator(),
                            ),
                        ],
                      ),
                    ),
                  ],
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

class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator();

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
