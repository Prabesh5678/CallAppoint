import 'package:flutter/material.dart';
import '../../shared/widgets/theme_toggle_button.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Doctor'),
        actions: const [ThemeToggleButton()],
      ),
      body: const Center(child: Text('Doctor list goes here')),
    );
  }
}
