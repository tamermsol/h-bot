import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'sign_in_screen.dart';
import 'home_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _timedOut = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    // If auth stream doesn't emit within 5 seconds, fall through to SignInScreen
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _timedOut = true;
        });
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
    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // If timed out and still waiting, fall through to sign in
        if (_timedOut && snapshot.connectionState == ConnectionState.waiting) {
          return const SignInScreen();
        }

        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: context.hBackground,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF9500)),
              ),
            ),
          );
        }

        // Cancel timeout timer once we get data
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
