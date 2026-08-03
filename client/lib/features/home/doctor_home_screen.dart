import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/appointment_card.dart';
import '../../shared/widgets/pulse_indicator.dart';
import '../../shared/widgets/responsive_scaffold.dart';
import '../appointments/providers/appointment_provider.dart';
import '../appointments/models/appointment.dart';
import '../doctors/screens/availability_screen_body.dart';
import '../notifications/providers/notification_provider.dart';
import '../blogs/screens/blog_list_screen.dart';

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

    final hasAnyPresence = appointmentsAsync.maybeWhen(
      data: (list) => list.any((a) => presenceMap[a.id] == true),
      orElse: () => false,
    );

    final destinations = [
      NavigationDestinationItem(
        icon: Stack(
          children: [
            const Icon(Icons.calendar_today_outlined),
            if (hasAnyPresence)
              const Positioned(
                right: 0,
                top: 0,
                child: PulseIndicator(size: 6),
              ),
          ],
        ),
        selectedIcon: Stack(
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
      const NavigationDestinationItem(
        icon: Icon(Icons.article_outlined),
        selectedIcon: Icon(Icons.article),
        label: 'Blogs',
      ),
      const NavigationDestinationItem(
        icon: Icon(Icons.schedule_outlined),
        selectedIcon: Icon(Icons.schedule),
        label: 'Schedule',
      ),
    ];

    return ResponsiveScaffold(
      selectedIndex: _tabIndex,
      onDestinationSelected: (index) {
        setState(() => _tabIndex = index);
        if (index == 0) {
          ref.invalidate(myAppointmentsProvider);
        }
      },
      destinations: destinations,
      title: Text(_tabIndex == 0
          ? 'Doctor Appointments'
          : _tabIndex == 1
              ? 'Health Blogs'
              : 'Manage Schedule'),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _DoctorAppointmentsView(),
          BlogListScreen(),
          _ScheduleTab(),
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
      length: 4,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.label,
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
                  (a) => a.status == 'confirmed' && a.parentAppointmentId == null,
                ),
                _buildPresenceTab(
                  'Follow-ups',
                  appointmentsAsync,
                  presenceMap,
                  (a) => a.status == 'confirmed' && a.parentAppointmentId != null,
                ),
                _buildPresenceTab(
                  'History',
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
          Expanded(
            child: appointmentsAsync.when(
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
                final upcomingRegular =
                    appointments.where((a) => a.status == 'confirmed' && a.parentAppointmentId == null).toList();
                final upcomingFollowup =
                    appointments.where((a) => a.status == 'confirmed' && a.parentAppointmentId != null).toList();
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('Nothing here yet', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(myAppointmentsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final appt = list[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppointmentCard(
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
                              await actions.cancelWithUndo(appointmentId: appt.id);
                            },
                          ),
                        );
                      },
                    ),
                  );
                }

                return TabBarView(
                  children: [
                    buildList(pending, isPending: true),
                    buildList(upcomingRegular),
                    buildList(upcomingFollowup),
                    buildList(past),
                  ],
                );
              },
            ),
          ),
        ],
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
