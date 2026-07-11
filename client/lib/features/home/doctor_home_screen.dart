import 'package:flutter/material.dart';
import '../../shared/widgets/theme_toggle_button.dart';

class DoctorHomeScreen extends StatelessWidget {
  const DoctorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        actions: const [ThemeToggleButton()],
      ),
      body: const Center(child: Text('Appointment list goes here')),
    );
  }
}
