import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'sign_in_screen.dart';
import 'home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: HBotColors.backgroundLight,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF9500)),
              ),
            ),
          );
        }

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
