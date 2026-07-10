import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/supabase_client.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const ProviderScope(child: CallAppointApp()));
}

class CallAppointApp extends StatelessWidget {
  const CallAppointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CallAppoint',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        // '/home' comes next once we build role-based routing
      },
    );
  }
}
