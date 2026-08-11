import 'package:flutter/material.dart';
import '../../shared/widgets/anatomy_viewer.dart';

class AnatomyTestScreen extends StatefulWidget {
  const AnatomyTestScreen({super.key});

  @override
  State<AnatomyTestScreen> createState() => _AnatomyTestScreenState();
}

class _AnatomyTestScreenState extends State<AnatomyTestScreen> {
  final List<String> _organs = ['heart', 'brain', 'skeleton', 'lungs'];
  String _selectedOrgan = 'heart';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anatomy 3D Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.view_in_ar, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Select an organ to visualize',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedOrgan,
              items: _organs.map((organ) {
                return DropdownMenuItem(
                  value: organ,
                  child: Text(organ.toUpperCase()),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedOrgan = val);
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AnatomyViewer(organ: _selectedOrgan),
                  ),
                );
              },
              child: const Text('Open 3D Viewer'),
            ),
          ],
        ),
      ),
    );
  }
}
