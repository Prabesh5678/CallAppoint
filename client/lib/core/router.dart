import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/home/patient_home_screen.dart';
import '../features/home/doctor_home_screen.dart';
import '../features/doctors/screens/doctor_detail_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/video/screens/video_call_screen.dart';
import '../features/doctors/screens/apply_doctor_screen.dart';
import 'supabase_client.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authStateProvider.stream),
    ),
    redirect: (context, state) {
      final loggedIn = supabase.auth.currentSession != null;
      final loggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeRouter()),
      GoRoute(
        path: '/doctor/:id',
        builder: (context, state) =>
            DoctorDetailScreen(doctorId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:appointmentId',
        builder: (context, state) => ChatScreen(appointmentId: state.pathParameters['appointmentId']!),
      ),
      GoRoute(
        path: '/video/:appointmentId',
        builder: (context, state) => VideoCallScreen(appointmentId: state.pathParameters['appointmentId']!),
      ),
      GoRoute(
        path: '/apply-doctor',
        builder: (context, state) => const ApplyDoctorScreen(),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    stream.listen((_) => notifyListeners());
  }
}

class HomeRouter extends ConsumerStatefulWidget {
  const HomeRouter({super.key});

  @override
  ConsumerState<HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends ConsumerState<HomeRouter> {
  @override
  void initState() {
    super.initState();
    // force a fresh /me/ fetch every time this screen is entered,
    // rather than relying on Riverpod's equality check on the auth stream
    Future.microtask(() => ref.invalidate(currentUserProfileProvider));
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(currentUserProfileProvider);
    return meAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await supabase.auth.signOut();
                  if (context.mounted) context.go('/login');
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
      data: (profile) {
        if (profile['role'] == 'doctor') return const DoctorHomeScreen();
        return const PatientHomeScreen();
      },
    );
  }
}
