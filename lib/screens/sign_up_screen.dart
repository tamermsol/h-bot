import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _fullName {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (last.isEmpty) return first;
    return '$first $last';
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await _authService
          .registerWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
            fullName: _fullName,
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
          SnackBar(content: Text(userMessage), backgroundColor: HBotColors.error),
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

  // ignore: unused_element
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
      backgroundColor: HBotColors.darkBgTop,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HBotColors.darkBgTop, HBotColors.darkBgBottom],
          ),
        ),
        child: ResponsiveShell(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: HBotSpacing.space4),

                    // Logo — 80x80 rounded
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: HBotColors.primary.withOpacity(0.25),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/hbot_logo.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment(-0.5, -0.5),
                                  end: Alignment(0.5, 0.5),
                                  colors: [Color(0xFF0883FD), Color(0xFF3BC4FF)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.home_rounded, color: Colors.white, size: 40),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: HBotSpacing.space5),

                    // Glass card
                    ClipRRect(
                      borderRadius: HBotRadius.xlRadius,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: HBotColors.glassBlur,
                          sigmaY: HBotColors.glassBlur,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 32,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: HBotColors.glassBackground,
                            borderRadius: HBotRadius.xlRadius,
                            border: Border.all(
                              color: HBotColors.glassBorder,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Title
                              const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontFamily: 'Readex Pro',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: HBotSpacing.space2),

                              const Text(
                                'Start controlling your home with H-Bot',
                                style: TextStyle(
                                  fontFamily: 'Readex Pro',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: HBotColors.textMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: HBotSpacing.space6),

                              // First Name + Last Name side by side
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildGlassField(
                                      controller: _firstNameController,
                                      label: 'FIRST NAME',
                                      hint: 'John',
                                      keyboardType: TextInputType.name,
                                      textInputAction: TextInputAction.next,
                                      enabled: !_isLoading,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return AppStrings.get('name_required');
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: HBotSpacing.space3),
                                  Expanded(
                                    child: _buildGlassField(
                                      controller: _lastNameController,
                                      label: 'LAST NAME',
                                      hint: 'Doe',
                                      keyboardType: TextInputType.name,
                                      textInputAction: TextInputAction.next,
                                      enabled: !_isLoading,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: HBotSpacing.space4),

                              // Email
                              _buildGlassField(
                                controller: _emailController,
                                label: 'EMAIL',
                                hint: 'you@example.com',
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                enabled: !_isLoading,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return AppStrings.get('email_required');
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return AppStrings.get('email_invalid');
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: HBotSpacing.space4),

                              // Password
                              _buildGlassField(
                                controller: _passwordController,
                                label: 'PASSWORD',
                                hint: 'Min 8 characters',
                                obscureText: true,
                                obscured: _obscurePassword,
                                onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                                textInputAction: TextInputAction.next,
                                enabled: !_isLoading,
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

                              const SizedBox(height: HBotSpacing.space4),

                              // Confirm Password
                              _buildGlassField(
                                controller: _confirmPasswordController,
                                label: 'CONFIRM PASSWORD',
                                hint: 'Re-enter password',
                                obscureText: true,
                                obscured: _obscureConfirmPassword,
                                onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                textInputAction: TextInputAction.done,
                                enabled: !_isLoading,
                                onEditingComplete: _signUpWithEmail,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return AppStrings.get('password_required');
                                  }
                                  if (value != _passwordController.text) {
                                    return AppStrings.get('passwords_no_match');
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: HBotSpacing.space4),

                              // Terms text — 11px muted, line-height 1.6
                              const Text(
                                'By creating an account you agree to Terms of Service and Privacy Policy',
                                style: TextStyle(
                                  fontFamily: 'Readex Pro',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: HBotColors.textMuted,
                                  height: 1.6,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: HBotSpacing.space5),

                              // Create Account button — gradient, radius 16
                              _buildGradientButton(
                                label: 'Create Account',
                                onPressed: _signUpWithEmail,
                                isLoading: _isLoading,
                              ),

                              if (Platform.isIOS) ...[
                                const SizedBox(height: HBotSpacing.space4),
                                _buildOutlineButton(
                                  icon: Icons.apple,
                                  label: AppStrings.get('sign_in_with_apple'),
                                  onPressed: _signInWithApple,
                                  isLoading: _isLoading,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: HBotSpacing.space5),

                    // Sign In link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${AppStrings.get('already_have_account')} ',
                          style: const TextStyle(
                            fontFamily: 'Readex Pro',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: HBotColors.textMuted,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            AppStrings.get('sign_in'),
                            style: const TextStyle(
                              fontFamily: 'Readex Pro',
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
      ),
    );
  }

  /// Gradient button with loading state
  Widget _buildGradientButton({
    required String label,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return SizedBox(
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          gradient: isLoading
              ? null
              : const LinearGradient(
                  begin: Alignment(-0.5, -0.5),
                  end: Alignment(0.5, 0.5),
                  colors: [Color(0xFF0883FD), Color(0xFF3BC4FF)],
                ),
          color: isLoading ? HBotColors.neutral700 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: HBotColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Readex Pro',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  /// Outline button for SSO / Apple
  Widget _buildOutlineButton({
    IconData? icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isLoading,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: HBotColors.glassBorder, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 24),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Glass-styled input field — rgba(255,255,255,0.03) bg, radius 14, uppercase 12px label
  Widget _buildGlassField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    bool? obscured,
    VoidCallback? onToggleObscure,
    bool enabled = true,
    VoidCallback? onEditingComplete,
    FormFieldValidator<String>? validator,
  }) {
    final isObscured = obscured ?? obscureText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Uppercase 12px muted label — w600, letter-spacing 0.5, 6px bottom margin
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Readex Pro',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: HBotColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: isObscured,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onEditingComplete: onEditingComplete,
          validator: validator,
          enabled: enabled,
          style: const TextStyle(
            fontFamily: 'Readex Pro',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
          cursorColor: HBotColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Readex Pro',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: HBotColors.textMuted.withOpacity(0.5),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.03),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: HBotSpacing.space4,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: HBotColors.glassBorder, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: HBotColors.glassBorder, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: HBotColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: HBotColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: HBotColors.error, width: 1.5),
            ),
            errorStyle: const TextStyle(
              fontFamily: 'Readex Pro',
              fontSize: 12,
              color: HBotColors.error,
            ),
            suffixIcon: obscureText
                ? IconButton(
                    icon: Icon(
                      isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: HBotColors.textMuted,
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
