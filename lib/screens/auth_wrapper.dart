import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../demo/demo_data.dart';
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
  bool _demoBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    // If auth stream doesn't emit within 5 seconds, fall through to SignInScreen
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
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
    // Demo mode: bypass authentication entirely
    if (isDemoMode) {
      _timeoutTimer?.cancel();
      return Stack(
        children: [
          const HomeScreen(),
          if (!_demoBannerDismissed)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Demo Mode \u2014 Not connected to real devices',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _demoBannerDismissed = true),
                        child: Icon(Icons.close, size: 16, color: Colors.amber.shade800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

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
