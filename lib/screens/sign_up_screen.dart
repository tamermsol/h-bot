import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/smart_input_field.dart';
import '../theme/app_theme.dart';
import '../models/profile.dart';
import '../l10n/app_strings.dart';
import 'home_screen.dart';
import 'otp_verification_screen.dart';
import '../widgets/responsive_shell.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await _authService
          .registerWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
            fullName: _fullNameController.text.trim(),
            phoneNumber: _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception(
                'Sign-up timed out. This may be due to email server delays. Please try again.',
              );
            },
          );

      if (mounted) {
        // Check if user needs email confirmation
        if (response.user != null && response.user!.emailConfirmedAt == null) {
          // Show OTP verification screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  OtpVerificationScreen(email: _emailController.text.trim()),
            ),
          );
        } else {
          // User is confirmed, go to home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String userMessage =
            'Sign-up failed. Please check your information and try again.';

        // Handle specific error cases with user-friendly messages
        if (e.toString().contains('timeout') ||
            e.toString().contains('timed out')) {
          userMessage =
              'Connection timeout. Please check your internet connection and try again.';
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          userMessage = 'Network error. Please check your internet connection.';
        } else if (e.toString().contains('already registered') ||
            e.toString().contains('already exists')) {
          userMessage =
              'An account with this email already exists. Please sign in instead.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final response = await _authService.signInWithApple();
      if (response.user != null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        if (!msg.contains('canceled')) {
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

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithGoogle().timeout(
        const Duration(seconds: 45), // Longer timeout for OAuth flow
        onTimeout: () {
          throw Exception('Google sign-up timed out. Please try again.');
        },
      );

      if (result && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Google sign-up was cancelled or failed. Please try again.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String userMessage = 'Google sign-up failed. Please try again.';

        // Handle specific error cases
        if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          userMessage =
              'Network error. Please check your internet connection and try again.';
        } else if (e.toString().contains('cancelled') ||
            e.toString().contains('canceled')) {
          userMessage = 'Sign-up was cancelled.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ResponsiveShell(child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: HBotSpacing.space5),

                // Logo
                Center(
                  child: ClipRRect(
                    borderRadius: HBotRadius.mediumRadius,
                    child: Image.asset(
                      'assets/images/hbot_logo.png',
                      width: 64,
                      height: 64,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(gradient: HBotColors.primaryGradient, borderRadius: HBotRadius.mediumRadius),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: HBotSpacing.space4),

                Text(
                  AppStrings.get('sign_up'),
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: HBotSpacing.space2),

                Text(
                  AppStrings.get('sign_up_subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: HBotSpacing.space7),

                // Full Name
                SmartInputField(
                  controller: _fullNameController,
                  label: AppStrings.get('full_name'),
                  hint: AppStrings.get('full_name_hint'),
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) return AppStrings.get('name_required');
                    if (value.trim().length < 2) return AppStrings.get('name_required');
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space4),

                // Email
                SmartInputField(
                  controller: _emailController,
                  label: AppStrings.get('email'),
                  hint: AppStrings.get('email_hint'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) return AppStrings.get('email_required');
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return AppStrings.get('email_invalid');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space4),

                // Phone
                SmartInputField(
                  controller: _phoneController,
                  label: AppStrings.get('sign_up_phone_optional'),
                  hint: '+1234567890',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (!Profile.isValidPhoneNumber(value)) {
                        return 'Use E.164 format (e.g., +1234567890)';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space4),

                // Password
                SmartInputField(
                  controller: _passwordController,
                  label: AppStrings.get('password'),
                  hint: '••••••••',
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) return AppStrings.get('password_required');
                    if (value.length < 6) return AppStrings.get('password_short');
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space4),

                // Confirm Password
                SmartInputField(
                  controller: _confirmPasswordController,
                  label: AppStrings.get('confirm_password'),
                  hint: '••••••••',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  enabled: !_isLoading,
                  onEditingComplete: _signUpWithEmail,
                  validator: (value) {
                    if (value == null || value.isEmpty) return AppStrings.get('password_required');
                    if (value != _passwordController.text) return AppStrings.get('passwords_no_match');
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space6),

                // Create Account button
                SizedBox(
                  height: 52,
                  child: Container(
                    decoration: hbotPrimaryButtonDecoration(disabled: _isLoading),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUpWithEmail,
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              AppStrings.get('sign_up'),
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ),

                // Sign in with Apple (iOS only)
                if (Platform.isIOS) ...[
                  const SizedBox(height: HBotSpacing.space4),

                  Row(
                    children: [
                      Expanded(child: Divider(color: context.hBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          AppStrings.get('or'),
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 14,
                            color: context.hTextSecondary,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: context.hBorder)),
                    ],
                  ),

                  const SizedBox(height: HBotSpacing.space4),

                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithApple,
                      icon: const Icon(Icons.apple, size: 24),
                      label: Text(
                        AppStrings.get('sign_in_with_apple'),
                        style: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.hTextPrimary,
                        side: BorderSide(color: context.hBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: HBotRadius.mediumRadius,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: HBotSpacing.space6),

                // Terms
                Text(
                  'By creating an account, you agree to our Terms of Service and Privacy Policy',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: HBotSpacing.space4),

                // Sign In link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${AppStrings.get('already_have_account')} ', style: Theme.of(context).textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        AppStrings.get('sign_in'),
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

                const SizedBox(height: HBotSpacing.space5),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
