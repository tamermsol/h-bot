import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/smart_input_field.dart';
import '../theme/app_theme.dart';
import '../models/profile.dart';
import 'home_screen.dart';
import 'otp_verification_screen.dart';

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
      backgroundColor: HBotColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: HBotSpacing.space5),

                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: HBotSpacing.space2),

                Text(
                  'Join the smart home revolution',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: HBotSpacing.space7),

                // Full Name
                SmartInputField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  hint: 'Your full name',
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your full name';
                    if (value.trim().length < 2) return 'Name must be at least 2 characters';
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space4),

                // Email
                SmartInputField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'user@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space4),

                // Phone
                SmartInputField(
                  controller: _phoneController,
                  label: 'Phone (Optional)',
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
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter a password';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space4),

                // Confirm Password
                SmartInputField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: '••••••••',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  enabled: !_isLoading,
                  onEditingComplete: _signUpWithEmail,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please confirm your password';
                    if (value != _passwordController.text) return 'Passwords do not match';
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
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: HBotSpacing.space5),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider(color: HBotColors.borderLight)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space4),
                      child: Text('or', style: Theme.of(context).textTheme.bodySmall),
                    ),
                    const Expanded(child: Divider(color: HBotColors.borderLight)),
                  ],
                ),

                const SizedBox(height: HBotSpacing.space5),

                // Google Sign Up
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signUpWithGoogle,
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      height: 20,
                      width: 20,
                      errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 20),
                    ),
                    label: const Text('Continue with Google'),
                  ),
                ),

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
                    Text('Already have an account? ', style: Theme.of(context).textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontFamily: 'Inter',
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
    );
  }
}
