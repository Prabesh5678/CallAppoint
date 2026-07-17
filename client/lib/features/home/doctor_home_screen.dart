import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/theme_toggle_button.dart';
import '../../shared/widgets/logout_button.dart';
import '../../shared/widgets/appointment_card.dart';
import '../../shared/widgets/pulse_indicator.dart';
import '../appointments/providers/appointment_provider.dart';
import '../appointments/models/appointment.dart';
import '../doctors/screens/availability_screen_body.dart';
import '../notifications/providers/notification_provider.dart';

class DoctorHomeScreen extends ConsumerStatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  ConsumerState<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends ConsumerState<DoctorHomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final presenceMap = ref.watch(notificationManagerProvider);
    final appointmentsAsync = ref.watch(myAppointmentsProvider);

    // Check if any appointment has active presence for the bottom nav dot
    final hasAnyPresence = appointmentsAsync.maybeWhen(
      data: (list) => list.any((a) => presenceMap[a.id] == true),
      orElse: () => false,
    );

    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: const [_DoctorAppointmentsView(), _ScheduleTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() => _tabIndex = index);
          if (index == 0) {
            ref.invalidate(myAppointmentsProvider);
          }
        },
        destinations: [
          NavigationDestination(
            icon: Stack(
              children: [
                const Icon(Icons.calendar_today),
                if (hasAnyPresence)
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: PulseIndicator(size: 6),
                  ),
              ],
            ),
            label: 'Appointments',
          ),
          const NavigationDestination(
            icon: Icon(Icons.schedule),
            label: 'My Schedule',
          ),
        ],
      ),
    );
  }
}

class _DoctorAppointmentsView extends ConsumerWidget {
  const _DoctorAppointmentsView();

  Widget _buildPresenceTab(
    String label,
    AsyncValue<List<Appointment>> appointmentsAsync,
    Map<String, bool> presenceMap,
    bool Function(Appointment) filter,
  ) {
    final hasPresence = appointmentsAsync.maybeWhen(
      data: (list) => list.where(filter).any((a) => presenceMap[a.id] == true),
      orElse: () => false,
    );

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (hasPresence) ...[
            const SizedBox(width: 8),
            const PulseIndicator(size: 6),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(myAppointmentsProvider);
    final presenceMap = ref.watch(notificationManagerProvider);
    final actions = ref.read(appointmentActionsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appointments'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh list',
              onPressed: () => ref.invalidate(myAppointmentsProvider),
            ),
            const ThemeToggleButton(),
            const LogoutButton(),
          ],
          bottom: TabBar(
            tabs: [
              _buildPresenceTab(
                'Requests',
                appointmentsAsync,
                presenceMap,
                (a) => a.status == 'pending',
              ),
              _buildPresenceTab(
                'Upcoming',
                appointmentsAsync,
                presenceMap,
                (a) => a.status == 'confirmed',
              ),
              _buildPresenceTab(
                'Past',
                appointmentsAsync,
                presenceMap,
                (a) => [
                  'completed',
                  'cancelled',
                  'rejected',
                  'no_show',
                ].contains(a.status),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => ref.invalidate(myAppointmentsProvider),
          tooltip: 'Refresh Appointments',
          child: const Icon(Icons.refresh),
        ),
        body: appointmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $e'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(myAppointmentsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (appointments) {
            final pending =
                appointments.where((a) => a.status == 'pending').toList();
            final upcoming =
                appointments.where((a) => a.status == 'confirmed').toList();
            final past = appointments
                .where(
                  (a) => [
                    'completed',
                    'cancelled',
                    'rejected',
                    'no_show',
                  ].contains(a.status),
                )
                .toList();

            Widget buildList(
              List<Appointment> list, {
              bool isPending = false,
            }) {
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
