import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart' show supabaseReady;
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
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    // If the auth stream doesn't emit within 3 seconds, fall through to
    // sign-in so the reviewer (or user) never sees a blank screen.
    _fallbackTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If Supabase didn't initialize, go straight to sign-in so the user
    // never sees a blank screen. Sign-in will show a connection error when
    // they attempt to log in.
    if (!supabaseReady) {
      return const SignInScreen();
    }

    // Quick check: if we already have a valid session, skip the stream wait
    final currentSession = Supabase.instance.client.auth.currentSession;
    if (currentSession != null) {
      return const HomeScreen();
    }

    // If the stream timed out, go straight to sign-in
    if (_timedOut) {
      return const SignInScreen();
    }

    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Stream hasn't emitted yet — show branded loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        // Handle stream errors gracefully
        if (snapshot.hasError) {
          return const SignInScreen();
        }

        final hasSession = snapshot.hasData && snapshot.data!.session != null;
        if (hasSession) {
          return const HomeScreen();
        }

        return const SignInScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: context.hBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/hbot_logo.png',
                width: 80,
                height: 80,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: HBotColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.home_rounded, color: Colors.white, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(HBotColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
