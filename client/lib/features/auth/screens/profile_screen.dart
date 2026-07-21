import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../../shared/widgets/logout_button.dart';
import '../../../core/dio_client.dart';
import '../../doctors/providers/doctor_provider.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _avatarUrlController;
  late TextEditingController _licenseController;
  late TextEditingController _bioController;
  late TextEditingController _experienceController;
  late TextEditingController _feeController;

  String? _gender;
  DateTime? _dob;
  List<String> _selectedSpecialtyIds = [];
  String? _verificationStatus;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _avatarUrlController = TextEditingController();
    _licenseController = TextEditingController();
    _bioController = TextEditingController();
    _experienceController = TextEditingController();
    _feeController = TextEditingController();

    // Initialize with current profile data
    Future.microtask(() async {
      final profile = await ref.read(currentUserProfileProvider.future);
      setState(() {
        _nameController.text = profile['full_name'] ?? '';
        _phoneController.text = profile['phone'] ?? '';
        _avatarUrlController.text = profile['avatar_url'] ?? '';
        _gender = profile['gender'];
        if (profile['date_of_birth'] != null) {
          _dob = DateTime.parse(profile['date_of_birth']);
        }

        if (profile['role'] == 'doctor') {
          _loadDoctorData();
        }
      });
    });
  }

  Future<void> _loadDoctorData() async {
    try {
      final response = await DioClient.instance.get('/doctors/me/');
      final data = response.data;
      setState(() {
        _verificationStatus = data['verification_status'];
        _licenseController.text = data['license_number'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _experienceController.text = data['years_experience']?.toString() ?? '0';
        _feeController.text = data['consultation_fee']?.toString() ?? '0';
        _selectedSpecialtyIds = (data['current_specialty_ids'] as List)
            .map((id) => id.toString())
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading doctor data: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarUrlController.dispose();
    _licenseController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final profile = ref.read(currentUserProfileProvider).value;
      if (profile == null) return;

      // Update common fields
      await DioClient.instance.patch('/accounts/me/', data: {
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'avatar_url': _avatarUrlController.text.trim().isEmpty ? null : _avatarUrlController.text.trim(),
        'gender': _gender,
        'date_of_birth': _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : null,
      });

      // Update doctor specific fields
      if (profile['role'] == 'doctor') {
        await DioClient.instance.patch('/doctors/me/', data: {
          'license_number': _licenseController.text,
          'bio': _bioController.text,
          'years_experience': int.tryParse(_experienceController.text) ?? 0,
          'consultation_fee': double.tryParse(_feeController.text) ?? 0,
          'specialty_ids': _selectedSpecialtyIds,
        });
      }

      ref.invalidate(currentUserProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final specialtiesAsync = ref.watch(specialtiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          const ThemeToggleButton(),
          const LogoutButton(),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          final isDoctor = profile['role'] == 'doctor';

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _avatarUrlController.text.isNotEmpty
                            ? NetworkImage(_avatarUrlController.text)
                            : null,
                        child: _avatarUrlController.text.isEmpty
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                            onPressed: () {
                              _showAvatarUrlDialog();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) return null; // Optional
                    final trimmed = value.trim();
                    if (trimmed.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
                      return 'Must be exactly 10 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Male', 'Female', 'Other']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (val) => setState(() => _gender = val),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dob ?? DateTime(1990),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _dob = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Birth Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_dob == null
                              ? 'Select'
                              : DateFormat('yyyy-MM-dd').format(_dob!)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isDoctor) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(),
                  ),
                  Text('Professional Details',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (_verificationStatus != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _verificationStatus == 'approved' ? Colors.green : (_verificationStatus == 'rejected' ? Colors.red : Colors.orange),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(_verificationStatus!.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(
                      labelText: 'License Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _experienceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Experience (Years)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            final n = int.tryParse(value);
                            if (n == null) return 'Invalid number';
                            if (n < 0) return 'Cannot be negative';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _feeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Consultation Fee',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            final n = double.tryParse(value);
                            if (n == null) return 'Invalid number';
                            if (n < 0) return 'Cannot be negative';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Specialties',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  specialtiesAsync.when(
                    data: (specialties) => Wrap(
                      spacing: 8,
                      children: specialties.map((s) {
                        final isSelected = _selectedSpecialtyIds.contains(s.id);
                        return FilterChip(
                          label: Text(s.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSpecialtyIds.add(s.id);
                              } else {
                                _selectedSpecialtyIds.remove(s.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Save Changes'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAvatarUrlDialog() {
    final controller = TextEditingController(text: _avatarUrlController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avatar URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter image URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _avatarUrlController.text = controller.text);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
