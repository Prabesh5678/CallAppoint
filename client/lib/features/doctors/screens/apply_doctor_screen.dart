import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/doctor_provider.dart';
import '../providers/doctor_application_provider.dart';

class ApplyDoctorScreen extends ConsumerStatefulWidget {
  const ApplyDoctorScreen({super.key});

  @override
  ConsumerState<ApplyDoctorScreen> createState() => _ApplyDoctorScreenState();
}

class _ApplyDoctorScreenState extends ConsumerState<ApplyDoctorScreen> {
  final _licenseController = TextEditingController();
  final _bioController = TextEditingController();
  final _yearsController = TextEditingController();
  final _feeController = TextEditingController();
  final Set<String> _selectedSpecialties = {};
  bool _loading = false;

  Future<void> _submit() async {
    if (_licenseController.text.trim().isEmpty ||
        _feeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('License number and fee are required')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(doctorApplicationControllerProvider)
          .apply(
            licenseNumber: _licenseController.text.trim(),
            bio: _bioController.text.trim(),
            yearsExperience: int.tryParse(_yearsController.text.trim()) ?? 0,
            consultationFee: double.tryParse(_feeController.text.trim()) ?? 0,
            specialtyIds: _selectedSpecialties.toList(),
          );
      if (mounted) {
        ref.invalidate(applicationStatusProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted! Awaiting admin review.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
Widget build(BuildContext context) {
  final specialtiesAsync = ref.watch(specialtiesProvider);
  final statusAsync = ref.watch(applicationStatusProvider);

  return Scaffold(
    appBar: AppBar(title: const Text('Become a Doctor')),
    body: statusAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (status) {
        if (status != null && status['verification_status'] == 'pending') {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Your application is under review. You\'ll be notified once an admin makes a decision.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final wasRejected = status != null && status['verification_status'] == 'rejected';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wasRejected) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your previous application was rejected',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 6),
                      Text(
                        (status['rejection_reason'] as String?)?.isNotEmpty == true
                            ? status['rejection_reason']
                            : 'No reason was provided.',
                      ),
                      const SizedBox(height: 6),
                      const Text('You can review the details below and reapply.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const Text(
                  'Submit your professional details for admin review. You\'ll be notified once approved.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 20),
              ],
              TextField(controller: _licenseController, decoration: const InputDecoration(labelText: 'License Number *')),
              const SizedBox(height: 16),
              TextField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _yearsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Years of Experience'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _feeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Consultation Fee (Rs.) *'),
              ),
              const SizedBox(height: 20),
              const Text('Specialties', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              specialtiesAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (specialties) => Wrap(
                  spacing: 8,
                  children: specialties.map((s) {
                    final selected = _selectedSpecialties.contains(s.id);
                    return FilterChip(
                      label: Text(s.name),
                      selected: selected,
                      onSelected: (val) => setState(() {
                        if (val) {
                          _selectedSpecialties.add(s.id);
                        } else {
                          _selectedSpecialties.remove(s.id);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(wasRejected ? 'Reapply' : 'Submit Application'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
}