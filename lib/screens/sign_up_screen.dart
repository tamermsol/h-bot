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
        if (response.user != null && response.user!.emailConfirmedAt == null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  OtpVerificationScreen(email: _emailController.text.trim()),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String userMessage =
            'Sign-up failed. Please check your information and try again.';

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
          SnackBar(
            content: Text(userMessage),
            backgroundColor: HBotColors.error,
          ),
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
        const Duration(seconds: 45),
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
          SnackBar(
            content: const Text(
              'Google sign-up was cancelled or failed. Please try again.',
            ),
            backgroundColor: HBotColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String userMessage = 'Google sign-up failed. Please try again.';

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
            backgroundColor: HBotColors.error,
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
      body: Column(
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A1628),
                  Color(0xFF0668CA),
                  Color(0xFF0883FD),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 28),
                child: Column(
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/branding/hbot_app_icon.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.smart_toy, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Create account',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Join H-Bot today',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Form section
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: HBotSpacing.tabletMaxWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HBotSpacing.screenPadding,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),

                    // Full Name Field
                    SmartInputField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      keyboardType: TextInputType.name,
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (value.trim().length < 2) {
                          return 'Full name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: HBotSpacing.space4),

                    // Email Field
                    SmartInputField(
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: HBotSpacing.space4),

                    // Phone Number Field (Optional)
                    SmartInputField(
                      controller: _phoneController,
                      label: 'Phone Number (Optional)',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
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

                    // Password Field
                    SmartInputField(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: _obscurePassword,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: HBotTheme.iconDefault(context),
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: HBotSpacing.space4),

                    // Confirm Password Field
                    SmartInputField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      obscureText: _obscureConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: HBotTheme.iconDefault(context),
                          size: 24,
                        ),
                        onPressed: () {
                          setState(
                            () => _obscureConfirmPassword = !_obscureConfirmPassword,
                          );
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: HBotSpacing.space6),

                    // "Create Account" gradient button (52px)
                    Container(
                      height: 52,
                      decoration: hbotPrimaryButtonDecoration(enabled: !_isLoading),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: HBotSpacing.space6),

                    // OR Divider
                    Row(
                      children: [
                        Expanded(
                          child: Container(height: 1, color: HBotTheme.divider(context)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space4),
                          child: Text(
                            'or continue with',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: HBotTheme.textTertiary(context),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(height: 1, color: HBotTheme.divider(context)),
                        ),
                      ],
                    ),

                    const SizedBox(height: HBotSpacing.space4),

                    // Google Sign Up Button (52px)
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signUpWithGoogle,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HBotTheme.textPrimary(context),
                          backgroundColor: HBotTheme.surface(context),
                          side: BorderSide(
                            color: HBotTheme.border(context),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: HBotRadius.mediumRadius,
                          ),
                        ),
                        icon: Image.asset(
                          'assets/images/google_logo.png',
                          height: 20,
                          width: 20,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.login,
                              color: HBotTheme.iconDefault(context),
                              size: 20,
                            );
                          },
                        ),
                        label: const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: HBotSpacing.space7),

                    // "Already have an account? Sign In" centered
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: HBotTheme.textSecondary(context),
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: HBotColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
