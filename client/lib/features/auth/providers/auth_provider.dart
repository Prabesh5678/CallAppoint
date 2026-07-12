import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';
import '../../../core/dio_client.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return supabase.auth.currentUser;
});

final currentUserProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) throw Exception('No active session');
      final response = await DioClient.instance.get('/accounts/me/');
      return response.data as Map<String, dynamic>;
    });

class AuthController {
  Future<void> signUp(String email, String password, String fullName) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
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
