import 'package:flutter/material.dart';
import 'admin_dio_client.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _patients = [];
  List<dynamic> _doctors = [];
  List<dynamic> _specialties = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final p = await AdminDioClient.instance.get('/patients/');
      final d = await AdminDioClient.instance.get('/doctors/');
      final s = await AdminDioClient.instance.get('/specialties/');
      setState(() {
        _patients = p.data;
        _doctors = d.data;
        _specialties = s.data;
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

  Future<void> _approveDoctor(String id) async {
    try {
      await AdminDioClient.instance.post('/doctors/$id/approve/');
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve doctor: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeUser(String id) async {
    try {
      await AdminDioClient.instance.delete('/users/$id/');
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove user: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addSpecialty(String name) async {
    try {
      await AdminDioClient.instance.post('/specialties/', data: {'name': name});
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add division: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteSpecialty(String id) async {
    try {
      await AdminDioClient.instance.delete('/specialties/$id/');
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete division: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(controller: _tabController, tabs: const [
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
                ListView.builder(
                  itemCount: _doctors.length,
                  itemBuilder: (context, i) {
                    final doc = _doctors[i];
                    return ListTile(
                      title: Text(doc['full_name'] ?? ''),
                      subtitle: Text('${doc['verification_status']} · ${doc['license_number']}'),
                      trailing: Wrap(spacing: 8, children: [
                        if (doc['verification_status'] != 'approved')
                          TextButton(onPressed: () => _approveDoctor(doc['id']), child: const Text('Approve')),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeUser(doc['id'])),
                      ]),
                    );
                  },
                ),
                ListView.builder(
                  itemCount: _patients.length,
                  itemBuilder: (context, i) {
                    final p = _patients[i];
                    return ListTile(
                      title: Text(p['full_name'] ?? ''),
                      subtitle: Text(p['email'] ?? ''),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeUser(p['id'])),
                    );
                  },
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(child: TextField(
                          decoration: const InputDecoration(hintText: 'New division name'),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _addSpecialty(val.trim());
                            }
                          },
                        )),
                      ]),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _specialties.length,
                        itemBuilder: (context, i) {
                          final s = _specialties[i];
                          return ListTile(
                            title: Text(s['name']),
                            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteSpecialty(s['id'])),
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
