import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../shared/widgets/theme_toggle_button.dart';
import '../core/globals.dart';
import '../core/undo_manager.dart';
import 'admin_dio_client.dart';
import 'admin_login_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  // Data Storage
  List<dynamic> _allPatients = [];
  List<dynamic> _allDoctors = [];
  List<dynamic> _allSpecialties = [];

  // Local Filtering State
  List<dynamic> _filteredDoctors = [];
  String? _selectedSpecialtyId;

  bool _loading = true;
  final _divisionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        AdminDioClient.instance.get('/patients/'),
        AdminDioClient.instance.get('/doctors/'),
        AdminDioClient.instance.get('/specialties/'),
      ]);

      setState(() {
        _allPatients = _extractResults(results[0].data);
        _allDoctors = _extractResults(results[1].data);
        _allSpecialties = _extractResults(results[2].data);
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Failed to load data: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      setState(() => _loading = false);
    }
  }

  List<dynamic> _extractResults(dynamic data) {
    if (data is Map && data.containsKey('results')) {
      return data['results'] as List;
    }
    return data as List;
  }

  void _applyFilters() {
    setState(() {
      final approved = _allDoctors.where((d) => d['verification_status'] == 'approved').toList();
      if (_selectedSpecialtyId == null) {
        _filteredDoctors = approved;
      } else {
        final specialty = _allSpecialties.cast<Map<String, dynamic>?>().firstWhere(
          (s) => s?['id'] == _selectedSpecialtyId,
          orElse: () => null,
        );

        if (specialty == null) {
          _filteredDoctors = approved;
          return;
        }

        final specName = specialty['name'];
        _filteredDoctors = approved.where((d) {
          final List specs = d['specialties'] ?? [];
          return specs.contains(specName);
        }).toList();
      }
    });
  }

  List<dynamic> get _pendingRequests =>
      _allDoctors.where((d) => d['verification_status'] == 'pending').toList();

  Future<void> _approveDoctor(String id) async {
    final originalDoctors = List.from(_allDoctors);
    setState(() {
      final index = _allDoctors.indexWhere((d) => d['id'] == id);
      if (index != -1) {
        _allDoctors[index]['verification_status'] = 'approved';
        _applyFilters();
      }
    });

    try {
      await AdminDioClient.instance.post('/doctors/$id/approve/');
    } catch (e) {
      setState(() {
        _allDoctors = originalDoctors;
        _applyFilters();
      });
      rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _rejectDoctor(String id, String reason) async {
    final originalDoctors = List.from(_allDoctors);
    setState(() {
      _allDoctors.removeWhere((d) => d['id'] == id);
      _applyFilters();
    });

    try {
      await AdminDioClient.instance.post('/doctors/$id/reject/', data: {'reason': reason});
    } catch (e) {
      setState(() {
        _allDoctors = originalDoctors;
        _applyFilters();
      });
    }
  }

  Future<void> _showRejectDialog(String id) async {
    String reason = "";
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject Doctor Request"),
        content: TextField(
          decoration: const InputDecoration(hintText: "Reason for rejection"),
          onChanged: (val) => reason = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(context);
              _rejectDoctor(id, reason);
            },
            child: Text("Reject", style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(String title) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text("Are you sure you want to delete $title?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete", style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _removeUser(String id, {required bool isDoctor}) async {
    final title = isDoctor ? "this doctor" : "this patient";
    if (!await _confirmDelete(title)) return;

    final originalPatients = List.from(_allPatients);
    final originalDoctors = List.from(_allDoctors);

    setState(() {
      if (isDoctor) {
        _allDoctors.removeWhere((doc) => doc['id'] == id);
      } else {
        _allPatients.removeWhere((p) => p['id'] == id);
      }
      _applyFilters();
    });

    final result = await UndoManager.showUndoSnackBar(
      message: "${isDoctor ? 'Doctor' : 'Patient'} removed",
      onUndo: () {
        setState(() {
          _allPatients = originalPatients;
          _allDoctors = originalDoctors;
          _applyFilters();
        });
      },
    );

    if (!result.wasUndone) {
      try {
        await AdminDioClient.instance.delete('/users/$id/');
      } catch (e) {
        setState(() {
          _allPatients = originalPatients;
          _allDoctors = originalDoctors;
          _applyFilters();
        });
        rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Future<void> _addSpecialty(String name) async {
    final newSpec = {'id': 'temp-${DateTime.now().millisecondsSinceEpoch}', 'name': name};
    final original = List.from(_allSpecialties);

    setState(() {
      _allSpecialties.add(newSpec);
      _divisionController.clear();
    });

    try {
      final response = await AdminDioClient.instance.post('/specialties/', data: {'name': name});
      setState(() {
        final idx = _allSpecialties.indexWhere((s) => s['id'] == newSpec['id']);
        if (idx != -1) _allSpecialties[idx] = response.data;
      });
    } catch (e) {
      setState(() => _allSpecialties = original);
      rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _deleteSpecialty(String id, String name) async {
    if (!await _confirmDelete("the division '$name'")) return;
    final original = List.from(_allSpecialties);

    setState(() => _allSpecialties.removeWhere((s) => s['id'] == id));

    final result = await UndoManager.showUndoSnackBar(
      message: "Division '$name' removed",
      onUndo: () {
        setState(() => _allSpecialties = original);
      },
    );

    if (!result.wasUndone) {
      try {
        await AdminDioClient.instance.delete('/specialties/$id/');
      } catch (e) {
        setState(() => _allSpecialties = original);
        rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _showDoctorDetails(Map<String, dynamic> doc) {
    final colorScheme = Theme.of(context).colorScheme;
    final specs = (doc['specialties'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Doctor Details'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: (doc['avatar_url'] != null && doc['avatar_url'].toString().isNotEmpty)
                        ? NetworkImage(doc['avatar_url'])
                        : null,
                    child: (doc['avatar_url'] == null || doc['avatar_url'].toString().isEmpty)
                        ? Icon(Icons.person, size: 50, color: colorScheme.primary)
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                _buildDetailRow('Full Name', doc['full_name']),
                _buildDetailRow('Specialties', specs.join(', ')),
                _buildDetailRow('License Number', doc['license_number']),
                _buildDetailRow('Experience', '${doc['years_experience']} years'),
                _buildDetailRow('Consultation Fee', 'Rs. ${doc['consultation_fee']}'),
                _buildDetailRow('Rating', '${doc['average_rating']} (${doc['total_reviews']} reviews)'),
                _buildDetailRow('Status', doc['verification_status']?.toString().toUpperCase()),
                _buildDetailRow('Joined', doc['created_at'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(doc['created_at'].toString())) : 'Unknown'),
                const SizedBox(height: 16),
                const Text('Bio', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(doc['bio'] ?? 'No bio provided', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          if (doc['verification_status'] == 'pending') ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showRejectDialog(doc['id']);
              },
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _approveDoctor(doc['id']);
              },
              child: const Text('Approve'),
            ),
          ],
        ],
      ),
    );
  }

  void _showPatientDetails(Map<String, dynamic> p) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Patient Details'),
        content: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: (p['avatar_url'] != null && p['avatar_url'].toString().isNotEmpty)
                      ? NetworkImage(p['avatar_url'])
                      : null,
                  child: (p['avatar_url'] == null || p['avatar_url'].toString().isEmpty)
                      ? Icon(Icons.person, size: 50, color: colorScheme.primary)
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Full Name', p['full_name']),
              _buildDetailRow('Phone', p['phone']),
              _buildDetailRow('Gender', p['gender']),
              _buildDetailRow('Date of Birth', p['date_of_birth']),
              _buildDetailRow('Joined', p['created_at'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(p['created_at'])) : 'Unknown'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value ?? 'N/A')),
        ],
      ),
    );
  }

  void _logout() {
    AdminDioClient.setToken(null);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Verification Requests'),
        Expanded(
          child: _pendingRequests.isEmpty
              ? Center(
                  child: Text('Currently no pending requests', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16)),
                )
              : ListView.builder(
                  itemCount: _pendingRequests.length,
                  itemBuilder: (context, i) {
                    final doc = _pendingRequests[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        onTap: () => _showDoctorDetails(doc),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        title: Text(doc['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('License: ${doc['license_number']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => _approveDoctor(doc['id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.withValues(alpha: 0.1),
                                foregroundColor: Colors.green,
                                elevation: 0,
                              ),
                              child: const Text('Approve'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _showRejectDialog(doc['id']),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Decline'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDoctorsTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Doctor Directory'),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: SizedBox(
            width: 300,
            child: DropdownButtonFormField<String>(
              value: _selectedSpecialtyId,
              decoration: const InputDecoration(
                labelText: 'Filter by Specialty',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Specialties')),
                ..._allSpecialties.map((s) => DropdownMenuItem(value: s['id'], child: Text(s['name']))),
              ],
              onChanged: (val) {
                _selectedSpecialtyId = val;
                _applyFilters();
              },
            ),
          ),
        ),
        Expanded(
          child: _filteredDoctors.isEmpty
              ? Center(child: Text('No doctors found', style: TextStyle(color: colorScheme.onSurfaceVariant)))
              : ListView.builder(
                  itemCount: _filteredDoctors.length,
                  itemBuilder: (context, i) {
                    final doc = _filteredDoctors[i];
                    final specs = (doc['specialties'] as List?) ?? [];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        onTap: () => _showDoctorDetails(doc),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        title: Text(doc['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${specs.join(", ")} · ${doc['license_number']}'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: colorScheme.error),
                          onPressed: () => _removeUser(doc['id'], isDoctor: true),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPatientsTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Registered Patients'),
        Expanded(
          child: _allPatients.isEmpty
              ? Center(child: Text('No patients registered yet', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16)))
              : ListView.builder(
                  itemCount: _allPatients.length,
                  itemBuilder: (context, i) {
                    final p = _allPatients[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        onTap: () => _showPatientDetails(p),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        title: Text(p['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(p['phone'] ?? 'No phone'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: colorScheme.error),
                          onPressed: () => _removeUser(p['id'], isDoctor: false),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDivisionsTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Specialty Divisions'),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _divisionController,
                  decoration: const InputDecoration(
                    hintText: 'Enter new division name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) _addSpecialty(val.trim());
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  if (_divisionController.text.trim().isNotEmpty) _addSpecialty(_divisionController.text.trim());
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Division'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _allSpecialties.isEmpty
              ? Center(child: Text('No divisions added yet', style: TextStyle(color: colorScheme.onSurfaceVariant)))
              : ListView.builder(
                  itemCount: _allSpecialties.length,
                  itemBuilder: (context, i) {
                    final s = _allSpecialties[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: colorScheme.error),
                          onPressed: () => _deleteSpecialty(s['id'], s['name'] ?? ''),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _tabController.index = index;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(32),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: () {
            switch (_selectedIndex) {
              case 0: return _buildRequestsTab();
              case 1: return _buildDoctorsTab();
              case 2: return _buildPatientsTab();
              case 3: return _buildDivisionsTab();
              default: return const SizedBox();
            }
          }(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 900;
    final colorScheme = Theme.of(context).colorScheme;

    if (isWideScreen) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Row(
          children: [
            // Sidebar
            Container(
              width: 280,
              color: colorScheme.surface,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Icon(Icons.health_and_safety, color: colorScheme.primary, size: 32),
                        const SizedBox(width: 12),
                        const Text('CallAppoint', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildSidebarItem(0, Icons.pending_actions, 'Requests'),
                  _buildSidebarItem(1, Icons.person, 'Doctors'),
                  _buildSidebarItem(2, Icons.people, 'Patients'),
                  _buildSidebarItem(3, Icons.category, 'Divisions'),
                  const Spacer(),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primary,
                            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                          ),
                          title: const Text('Admin User', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('System Manager', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Log Out'),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.error,
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Top Bar
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    color: colorScheme.surface,
                    child: Row(
                      children: [
                        const Text('Dashboard Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        const ThemeToggleButton(),
                        IconButton(
                          onPressed: _loadAll,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh Data',
                        ),
                        const SizedBox(width: 8),
                        const Badge(
                          label: Text('3'),
                          child: Icon(Icons.notifications_outlined),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: _buildContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(controller: _tabController, isScrollable: true, tabs: const [
          Tab(text: 'Requests'),
          Tab(text: 'Doctors'),
          Tab(text: 'Patients'),
          Tab(text: 'Divisions'),
        ]),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsTab(),
                _buildDoctorsTab(),
                _buildPatientsTab(),
                _buildDivisionsTab(),
              ],
            ),
    );
  }
}
