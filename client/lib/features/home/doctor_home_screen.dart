import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/theme_toggle_button.dart';
import '../../shared/widgets/logout_button.dart';
import '../../shared/widgets/appointment_card.dart';
import '../appointments/providers/appointment_provider.dart';
import '../appointments/models/appointment.dart';
import '../doctors/screens/availability_screen_body.dart';

class DoctorHomeScreen extends ConsumerStatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  ConsumerState<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends ConsumerState<DoctorHomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _DoctorAppointmentsView(),
          _ScheduleTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today), label: 'Appointments'),
          NavigationDestination(icon: Icon(Icons.schedule), label: 'My Schedule'),
        ],
      ),
    );
  }
}

class _DoctorAppointmentsView extends ConsumerWidget {
  const _DoctorAppointmentsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appointments'),
          actions: const [ThemeToggleButton(), LogoutButton()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Requests'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: Consumer(
          builder: (context, ref, _) {
            final appointmentsAsync = ref.watch(myAppointmentsProvider);
            final actions = ref.read(appointmentActionsProvider);

            return appointmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (appointments) {
                final pending = appointments.where((a) => a.status == 'pending').toList();
                final upcoming = appointments.where((a) => a.status == 'confirmed').toList();
                final past = appointments
                    .where((a) => ['completed', 'cancelled', 'rejected', 'no_show'].contains(a.status))
                    .toList();

                Widget buildList(List<Appointment> list, {bool isPending = false}) {
                  if (list.isEmpty) {
                    return const Center(child: Text('Nothing here yet'));
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(myAppointmentsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final appt = list[index];
                        return AppointmentCard(
                          appointment: appt,
                          isDoctorView: true,
                          onConfirm: isPending
                              ? () async {
                                  await actions.respond(appt.id, 'confirm');
                                  ref.invalidate(myAppointmentsProvider);
                                }
                              : null,
                          onReject: isPending
                              ? () async {
                                  await actions.respond(appt.id, 'reject');
                                  ref.invalidate(myAppointmentsProvider);
                                }
                              : null,
                          onCancel: () async {
                            await actions.cancel(appt.id);
                            ref.invalidate(myAppointmentsProvider);
                          },
                        );
                      },
                    ),
                  );
                }

                return TabBarView(
                  children: [
                    buildList(pending, isPending: true),
                    buildList(upcoming),
                    buildList(past),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context) {
    return const AvailabilityScreenBody();
  }
}