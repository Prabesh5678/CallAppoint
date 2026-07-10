import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ?? supabase.auth.currentUser;
});

class AuthController {
  Future<void> signUp(String email, String password, String fullName) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName}, // read by the handle_new_auth_user trigger
    );
  }

  Future<void> signIn(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}

final authControllerProvider = Provider((ref) => AuthController());
