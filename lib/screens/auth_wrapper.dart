import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'sign_in_screen.dart';
import 'home_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _timedOut = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    // Safety timeout: if auth stream doesn't emit within 5 seconds,
    // fall through to sign-in screen (prevents blank page on iPad/device)
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // If stream has error, go to sign-in
        if (snapshot.hasError) {
          return const SignInScreen();
        }

        // Show loading indicator while checking auth state,
        // but only until timeout to prevent permanent blank screen
        if (snapshot.connectionState == ConnectionState.waiting && !_timedOut) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8F9FB),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0883FD)),
              ),
            ),
          );
        }

        // Cancel timeout timer once we have data
        _timeoutTimer?.cancel();

        // Check if we have valid auth data and session
        final hasSession = snapshot.hasData && snapshot.data!.session != null;

        // If user is signed in with valid session, show home screen
        if (hasSession) {
          return const HomeScreen();
        }

        // If user is not signed in or session is invalid, show sign in screen
        return const SignInScreen();
      },
    );
  }
}
