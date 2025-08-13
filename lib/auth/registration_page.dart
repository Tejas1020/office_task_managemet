import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:office_task_managemet/utils/colors.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _displayNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final displayName = _displayNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    try {
      // 1️⃣ Create Auth user
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      final user = cred.user;
      if (user == null) throw Exception('Auth created no user!');

      // 2️⃣ Update displayName
      await user.updateDisplayName(displayName);

      // 3️⃣ Write to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': displayName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Confirm write success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User saved to Database ✅')),
      );

      // 4️⃣ Send email verification
      await user.sendEmailVerification();

      // 5️⃣ Go back to login
      context.go('/login');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
      debugPrint('Auth error: ${e.code} – ${e.message}');
    } on FirebaseException catch (e) {
      setState(() => _error = 'Firestore error: ${e.message}');
      debugPrint('Firestore write failed: ${e.code} – ${e.message}');
    } catch (e, st) {
      setState(() => _error = e.toString());
      debugPrint('Unknown error: $e\n$st');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.gray900,
      title: const Center(child: Text('Register')),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/login'),
      ),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _displayNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _register,
                    child: const Text('Sign Up'),
                  ),
          ],
        ),
      ),
    ),
  );
}
