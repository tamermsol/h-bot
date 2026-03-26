import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/smart_input_field.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';
import 'sign_up_screen.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import '../widgets/responsive_shell.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService
          .signInWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Sign-in timed out. Please check your connection and try again.',
              );
            },
          );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Sign-in failed. Please check your credentials.';
        if (e.toString().contains('timeout')) {
          msg = AppStrings.get('connection_timeout');
        } else if (e.toString().contains('network')) {
          msg = AppStrings.get('network_error');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithApple();
      if (result && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        if (!msg.contains('canceled') && !msg.contains('cancelled')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppStrings.get("error_apple_sign_in")}: ${e.toString()}'),
              backgroundColor: HBotColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithGoogle().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw Exception('Google sign-in timed out. Please try again.');
        },
      );

      if (result && mounted) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.get('sign_in_google_signin_was_cancelled'))),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('sign_in_google_sign_in_was_cancelled'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.get("error_google_sign_in")}: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hBackground,
      body: ResponsiveShell(child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: HBotSpacing.space9),

                // Logo — H-Bot brand mark from h-bot.tech
                Center(
                  child: ClipRRect(
                    borderRadius: HBotRadius.mediumRadius,
                    child: Image.asset(
                      'assets/images/hbot_logo.png',
                      width: 64,
                      height: 64,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: HBotColors.primaryGradient,
                          borderRadius: HBotRadius.mediumRadius,
                        ),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: HBotSpacing.space4),

                // Welcome text
                Text(
                  AppStrings.get('welcome_back'),
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: HBotSpacing.space2),

                Text(
                  AppStrings.get('sign_in_subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: HBotSpacing.space7),

                // Email field
                SmartInputField(
                  controller: _emailController,
                  label: AppStrings.get('email'),
                  hint: AppStrings.get('email_hint'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppStrings.get('email_required');
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return AppStrings.get('email_invalid');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space4),

                // Password field
                SmartInputField(
                  controller: _passwordController,
                  label: AppStrings.get('password'),
                  hint: '••••••••',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  enabled: !_isLoading,
                  onEditingComplete: _signInWithEmail,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppStrings.get('password_required');
                    }
                    if (value.length < 6) {
                      return AppStrings.get('password_short');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space2),

                // Forgot password — right-aligned
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: Text(
                      AppStrings.get('forgot_password'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: HBotColors.primary,
                          ),
                    ),
                  ),
                ),

                const SizedBox(height: HBotSpacing.space6),

                // Sign In button — primary gradient
                SizedBox(
                  height: 52,
                  child: Container(
                    decoration: hbotPrimaryButtonDecoration(disabled: _isLoading),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: HBotRadius.mediumRadius,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              AppStrings.get('sign_in'),
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ),

                

                if (Platform.isIOS) ...[
                  const SizedBox(height: HBotSpacing.space4),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithApple,
                      icon: const Icon(Icons.apple, size: 24),
                      label: Text(
                        AppStrings.get('sign_in_with_apple'),
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: HBotRadius.mediumRadius,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: HBotSpacing.space6),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.get('dont_have_account'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ),
                        );
                      },
                      child: Text(
                        AppStrings.get('sign_up'),
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HBotColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
