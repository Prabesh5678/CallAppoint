import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/theme_toggle_button.dart';
import '../../shared/widgets/logout_button.dart';
import '../../shared/widgets/doctor_card.dart';
import '../../shared/widgets/appointment_card.dart';
import '../doctors/providers/doctor_provider.dart';
import '../appointments/providers/appointment_provider.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: const [_FindDoctorsTab(), _MyAppointmentsTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Find Doctors',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today),
            label: 'Appointments',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Doctor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.medical_services_outlined),
            tooltip: 'Become a Doctor',
            onPressed: () => context.push('/apply-doctor'),
          ),
          const ThemeToggleButton(),
          const LogoutButton(),
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
              padding: const EdgeInsets.all(16),
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
                  isDoctorView: false,
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
