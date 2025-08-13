import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(),
);

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  Future<String> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw Exception('Invalid login or password');
      }
      final lower = email.toLowerCase();
      final role = lower.endsWith('@admin.com')
          ? 'admin'
          : lower.endsWith('@manager.com')
          ? 'manager'
          : 'employee';
      state = const AsyncValue.data(null);
      return role;
    } on FirebaseAuthException catch (e, st) {
      state = AsyncValue.error(e.message ?? 'Authentication error', st);
      rethrow;
    } catch (e, st) {
      state = AsyncValue.error('Login failed', st);
      throw Exception('Login failed');
    }
  }
}
