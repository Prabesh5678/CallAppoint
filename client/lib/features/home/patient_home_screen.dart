import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/theme_toggle_button.dart';
import '../../shared/widgets/doctor_card.dart';
import '../../shared/widgets/appointment_card.dart';
import '../../shared/widgets/pulse_indicator.dart';
import '../doctors/providers/doctor_provider.dart';
import '../appointments/providers/appointment_provider.dart';
import '../appointments/models/appointment.dart';
import '../notifications/providers/notification_provider.dart';
import '../blogs/screens/blog_list_screen.dart';
import '../auth/screens/profile_screen.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final presenceMap = ref.watch(notificationManagerProvider);
    final appointmentsAsync = ref.watch(myAppointmentsProvider);

    final hasAnyPresence = appointmentsAsync.maybeWhen(
      data: (list) => list.any((a) => presenceMap[a.id] == true),
      orElse: () => false,
    );

    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _FindDoctorsTab(),
          _MyAppointmentsTab(),
          BlogListScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() => _tabIndex = index);
          if (index == 1) {
            ref.invalidate(myAppointmentsProvider);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Find',
          ),
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
            icon: Icon(Icons.article),
            label: 'Blogs',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _FindDoctorsTab extends ConsumerStatefulWidget {
  const _FindDoctorsTab();

  @override
  ConsumerState<_FindDoctorsTab> createState() => _FindDoctorsTabState();
}

class _FindDoctorsTabState extends ConsumerState<_FindDoctorsTab> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final specialtiesAsync = ref.watch(specialtiesProvider);
    final doctorsAsync = ref.watch(doctorsProvider);
    final selectedSpecialty = ref.watch(selectedSpecialtyProvider);
    final filterDate = ref.watch(filterDateProvider);
    final filterTime = ref.watch(filterTimeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Doctor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'My Reports',
            onPressed: () => context.push('/artifacts'),
          ),
          IconButton(
            icon: const Icon(Icons.medical_services_outlined),
            tooltip: 'Become a Doctor',
            onPressed: () => context.push('/apply-doctor'),
          ),
          const ThemeToggleButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(doctorsProvider);
          ref.invalidate(specialtiesProvider);
        },
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search doctors by name',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (value) =>
                    ref.read(searchQueryProvider.notifier).state = value,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: filterDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        ref.read(filterDateProvider.notifier).state = picked;
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(filterDate == null
                          ? 'Select Date'
                          : DateFormat('MMM d').format(filterDate)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: filterDate != null ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: filterTime != null
                              ? TimeOfDay.fromDateTime(filterTime)
                              : const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (picked != null) {
                          final now = DateTime.now();
                          ref.read(filterTimeProvider.notifier).state = DateTime(
                            now.year, now.month, now.day, picked.hour, picked.minute);
                        }
                      },
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text(filterTime == null
                          ? 'Select Time'
                          : DateFormat('h:mm a').format(filterTime)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: filterTime != null ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : null,
                      ),
                    ),
                  ),
                  if (filterDate != null || filterTime != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        ref.read(filterDateProvider.notifier).state = null;
                        ref.read(filterTimeProvider.notifier).state = null;
                      },
                      tooltip: 'Clear filters',
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: specialtiesAsync.when(
                loading: () => const SizedBox(),
                error: (e, _) => const SizedBox(),
                data: (specialties) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _SpecialtyChip(
                      label: 'All',
                      selected: selectedSpecialty == null,
                      onTap: () =>
                          ref.read(selectedSpecialtyProvider.notifier).state =
                              null,
                    ),
                    ...specialties.map(
                      (s) => _SpecialtyChip(
                        label: s.name,
                        selected: selectedSpecialty == s.id,
                        onTap: () =>
                            ref.read(selectedSpecialtyProvider.notifier).state =
                                s.id,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            doctorsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('Error: $e')),
              ),
              data: (doctors) {
                if (doctors.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No doctors found')),
                  );
                }
                return Column(
                  children: doctors
                      .map(
                        (doctor) => DoctorCard(
                          doctor: doctor,
                          onTap: () => context.push('/doctor/${doctor.id}'),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _MyAppointmentsTab extends ConsumerWidget {
  const _MyAppointmentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(myAppointmentsProvider);
    final actions = ref.read(appointmentActionsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Appointments'),
          actions: [
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'My Reports',
              onPressed: () => context.push('/artifacts'),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh list',
              onPressed: () => ref.invalidate(myAppointmentsProvider),
            ),
            const ThemeToggleButton(),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Regular'),
              Tab(text: 'Follow-up'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'patient_appointments_refresh_fab',
          onPressed: () => ref.invalidate(myAppointmentsProvider),
          tooltip: 'Refresh Appointments',
          child: const Icon(Icons.refresh),
        ),
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(myAppointmentsProvider),
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
              final regular = appointments
                  .where((a) => a.status == 'confirmed' && a.parentAppointmentId == null)
                  .toList();
              final followups = appointments
                  .where((a) => a.status == 'confirmed' && a.parentAppointmentId != null)
                  .toList();
              final past = appointments
                  .where((a) => ['completed', 'cancelled', 'rejected', 'no_show'].contains(a.status))
                  .toList();

              Widget buildList(List<Appointment> list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No appointments found'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final appt = list[index];
                    return AppointmentCard(
                      appointment: appt,
                      isDoctorView: false,
                      onCancel: () async {
                        await actions.cancelWithUndo(appointmentId: appt.id);
                      },
                    );
                  },
                );
              }

              return TabBarView(
                children: [
                  buildList(regular),
                  buildList(followups),
                  buildList(past),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpecialtyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
