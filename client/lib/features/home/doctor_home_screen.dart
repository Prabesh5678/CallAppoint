import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/theme_toggle_button.dart';
import '../../shared/widgets/appointment_card.dart';
import '../appointments/providers/appointment_provider.dart';
import '../../shared/widgets/logout_button.dart';

class DoctorHomeScreen extends ConsumerWidget {
  const DoctorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(myAppointmentsProvider);
    final actions = ref.read(appointmentActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        actions: const [ThemeToggleButton(), LogoutButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myAppointmentsProvider),
        child: appointmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (appointments) {
            if (appointments.isEmpty) {
              return const Center(child: Text('No appointments yet'));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                final appt = appointments[index];
                return AppointmentCard(
                  appointment: appt,
                  isDoctorView: true,
                  onConfirm: () async {
                    await actions.respond(appt.id, 'confirm');
                    ref.invalidate(myAppointmentsProvider);
                  },
                  onReject: () async {
                    await actions.respond(appt.id, 'reject');
                    ref.invalidate(myAppointmentsProvider);
                  },
                  onCancel: () async {
                    await actions.cancel(appt.id);
                    ref.invalidate(myAppointmentsProvider);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
