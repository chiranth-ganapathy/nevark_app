import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import '../home/home_screen.dart';
import '../../core/theme/app_theme.dart';

class AuthService extends StatelessWidget {
  const AuthService({super.key});

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<String?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final name = displayName?.trim();
      if (name != null && name.isNotEmpty) {
        await cred.user?.updateDisplayName(name);
        await cred.user?.reload();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('member_since_ms', DateTime.now().millisecondsSinceEpoch);
      if (name != null && name.isNotEmpty) {
        await prefs.setString('display_name', name);
      }
      await prefs.setString('user_email', email.trim());

      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyAuthError(e);
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email.trim());
      final user = _auth.currentUser;
      if (user?.displayName != null && user!.displayName!.isNotEmpty) {
        await prefs.setString('display_name', user.displayName!);
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyAuthError(e);
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> forgotPassword({required String email}) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return 'Enter your email address';
    }
    try {
      await _auth.sendPasswordResetEmail(email: trimmed);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyAuthError(e);
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static User? getCurrentUser() => _auth.currentUser;

  static String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found for this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak (min 6 characters)';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'network-request-failed':
        return 'Network error. Check your internet connection';
      default:
        return e.message ?? 'Authentication failed (${e.code})';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.cyan.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.trending_up_rounded,
                      color: AppColors.cyan,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'NEVARK',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.cyan,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          return const HomeShell();
        }

        return const LoginScreen();
      },
    );
  }
}
