import 'package:flutter/material.dart';
import 'admin_dio_client.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data Storage (The "Source of Truth")
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
    _loadAll();
  }

  /// Fetches all data once and stores it locally for instant filtering
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      // Fetch everything in parallel
      final results = await Future.wait([
        AdminDioClient.instance.get('/patients/'),
        AdminDioClient.instance.get('/doctors/'), // Fetch ALL doctors at once
        AdminDioClient.instance.get('/specialties/'),
      ]);

      setState(() {
        _allPatients = results[0].data;
        _allDoctors = results[1].data;
        _allSpecialties = results[2].data;
        _applyFilters(); // Apply initial filter logic
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _loading = false);
    }
  }

  /// Instant Local Filtering Logic
  void _applyFilters() {
    setState(() {
      // 1. Get only approved doctors for the "Doctors" tab
      final approved = _allDoctors.where((d) => d['verification_status'] == 'approved').toList();

      // 2. Apply Specialty Filter locally
      if (_selectedSpecialtyId == null) {
        _filteredDoctors = approved;
      } else {
        // Find the specialty name to match against the doctor's specialty list
        final specName = _allSpecialties.firstWhere((s) => s['id'] == _selectedSpecialtyId)['name'];
        _filteredDoctors = approved.where((d) {
          final List specs = d['specialties'] ?? [];
          return specs.contains(specName);
        }).toList();
      }
    });
  }

  /// Helper to get pending requests from local data
  List<dynamic> get _pendingRequests =>
      _allDoctors.where((d) => d['verification_status'] == 'pending').toList();

  Future<void> _approveDoctor(String id) async {
    // Optimistic Update: Move from pending to approved locally
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
      // Revert if server fails
      setState(() {
        _allDoctors = originalDoctors;
        _applyFilters();
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _rejectDoctor(id, reason);
            },
            child: const Text("Reject", style: TextStyle(color: Colors.white)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _removeUser(String id, {required bool isDoctor}) async {
    if (!await _confirmDelete(isDoctor ? "this doctor" : "this patient")) return;

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

    try {
      await AdminDioClient.instance.delete('/users/$id/');
    } catch (e) {
      setState(() {
        _allPatients = originalPatients;
        _allDoctors = originalDoctors;
        _applyFilters();
      });
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
      // Replace temp with real ID from server
      setState(() {
        final idx = _allSpecialties.indexWhere((s) => s['id'] == newSpec['id']);
        if (idx != -1) _allSpecialties[idx] = response.data;
      });
    } catch (e) {
      setState(() => _allSpecialties = original);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _deleteSpecialty(String id, String name) async {
    if (!await _confirmDelete("the division '$name'")) return;
    final original = List.from(_allSpecialties);
    setState(() => _allSpecialties.removeWhere((s) => s['id'] == id));
    try {
      await AdminDioClient.instance.delete('/specialties/$id/');
    } catch (e) {
      setState(() => _allSpecialties = original);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(controller: _tabController, isScrollable: true, tabs: const [
          Tab(text: 'Requests'),
          Tab(text: 'Doctors'),
          Tab(text: 'Patients'),
          Tab(text: 'Divisions'),
        ]),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. Requests Tab (Local filtering)
                _pendingRequests.isEmpty
                    ? const Center(
                        child: Text(
                          'Currently no pending requests',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _pendingRequests.length,
                        itemBuilder: (context, i) {
                          final doc = _pendingRequests[i];
                          return ListTile(
                            title: Text(doc['full_name'] ?? ''),
                            subtitle: Text('License: ${doc['license_number']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(onPressed: () => _approveDoctor(doc['id']), child: const Text('Approve', style: TextStyle(color: Colors.green))),
                                TextButton(onPressed: () => _showRejectDialog(doc['id']), child: const Text('Decline', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                        },
                      ),

                // 2. Doctors Tab (INSTANT local filtering)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: DropdownButtonFormField<String>(
                        value: _selectedSpecialtyId,
                        decoration: const InputDecoration(labelText: 'Filter by Specialty', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Specialties')),
                          ..._allSpecialties.map((s) => DropdownMenuItem(value: s['id'], child: Text(s['name']))),
                        ],
                        onChanged: (val) {
                          _selectedSpecialtyId = val;
                          _applyFilters(); // Instant!
                        },
                      ),
                    ),
                    Expanded(
                      child: _filteredDoctors.isEmpty
                          ? const Center(
                              child: Text(
                                'No doctors found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredDoctors.length,
                              itemBuilder: (context, i) {
                                final doc = _filteredDoctors[i];
                                final specs = (doc['specialties'] as List?) ?? [];
                                return ListTile(
                                  title: Text(doc['full_name'] ?? ''),
                                  subtitle: Text('${specs.join(", ")} · ${doc['license_number']}'),
                                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeUser(doc['id'], isDoctor: true)),
                                );
                              },
                            ),
                    ),
                  ],
                ),

                // 3. Patients Tab
                _allPatients.isEmpty
                    ? const Center(
                        child: Text(
                          'No patients registered yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _allPatients.length,
                        itemBuilder: (context, i) {
                          final p = _allPatients[i];
                          return ListTile(
                            title: Text(p['full_name'] ?? ''),
                            subtitle: Text(p['phone'] ?? 'No phone'),
                            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeUser(p['id'], isDoctor: false)),
                          );
                        },
                      ),

                // 4. Divisions Tab
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(child: TextField(
                          controller: _divisionController,
                          decoration: InputDecoration(
                            hintText: 'New division name',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: () {
                                if (_divisionController.text.trim().isNotEmpty) _addSpecialty(_divisionController.text.trim());
                              },
                            ),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) _addSpecialty(val.trim());
                          },
                        )),
                      ]),
                    ),
                    Expanded(
                      child: _allSpecialties.isEmpty
                          ? const Center(
                              child: Text(
                                'No divisions added yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _allSpecialties.length,
                              itemBuilder: (context, i) {
                                final s = _allSpecialties[i];
                                return ListTile(
                                  title: Text(s['name']),
                                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteSpecialty(s['id'], s['name'])),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
