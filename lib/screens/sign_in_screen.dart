import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
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

  // ─── Auth Logic (preserved) ──────────────────────────────────

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

  // ignore: unused_element
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

  // ─── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HBotColors.darkBgTop,
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
                    const SizedBox(height: HBotSpacing.space9),

                    // Logo — 80x80 rounded with glow
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

                    const SizedBox(height: HBotSpacing.space7),

                    // Glass card — padding 32px vertical, 24px horizontal, radius 24
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
                              Text(
                                AppStrings.get('welcome_back'),
                                style: const TextStyle(
                                  fontFamily: 'Readex Pro',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: HBotSpacing.space2),

                              // Subtitle
                              Text(
                                AppStrings.get('sign_in_subtitle'),
                                style: const TextStyle(
                                  fontFamily: 'Readex Pro',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: HBotColors.textMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: HBotSpacing.space6),

                              // Email field
                              _buildGlassInputField(
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
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return AppStrings.get('email_invalid');
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 18),

                              // Password field
                              _buildGlassInputField(
                                controller: _passwordController,
                                label: 'PASSWORD',
                                hint: 'Enter password',
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

                              // Forgot password — right aligned, 12px, primary
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
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 36),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    AppStrings.get('forgot_password'),
                                    style: const TextStyle(
                                      fontFamily: 'Readex Pro',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: HBotColors.primary,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: HBotSpacing.space5),

                              // Sign In — gradient button, full width, padding 16, radius 16
                              _buildGradientButton(
                                label: AppStrings.get('sign_in'),
                                onPressed: _signInWithEmail,
                                isLoading: _isLoading,
                              ),

                              const SizedBox(height: HBotSpacing.space5),

                              // "or" divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: HBotColors.glassBorder,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'or',
                                      style: TextStyle(
                                        fontFamily: 'Readex Pro',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: HBotColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: HBotColors.glassBorder,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: HBotSpacing.space5),

                              // SSO / Apple sign in
                              if (Platform.isIOS)
                                _buildOutlineButton(
                                  icon: Icons.apple,
                                  label: AppStrings.get('sign_in_with_apple'),
                                  onPressed: _signInWithApple,
                                  isLoading: _isLoading,
                                )
                              else
                                _buildOutlineButton(
                                  label: 'Continue with SSO',
                                  onPressed: null,
                                  isLoading: _isLoading,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: HBotSpacing.space6),

                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.get('dont_have_account'),
                          style: const TextStyle(
                            fontFamily: 'Readex Pro',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: HBotColors.textMuted,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontFamily: 'Readex Pro',
                              fontSize: 13,
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

  // ─── Shared Widget Builders ──────────────────────────────────

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
            padding: const EdgeInsets.symmetric(vertical: 16),
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

  /// Glass-styled input field
  Widget _buildGlassInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    bool enabled = true,
    VoidCallback? onEditingComplete,
    FormFieldValidator<String>? validator,
  }) {
    return _GlassInputField(
      controller: controller,
      label: label,
      hint: hint,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: enabled,
      onEditingComplete: onEditingComplete,
      validator: validator,
    );
  }
}

/// Stateful glass input field with toggle for password visibility
class _GlassInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final VoidCallback? onEditingComplete;
  final FormFieldValidator<String>? validator;

  const _GlassInputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.onEditingComplete,
    this.validator,
  });

  @override
  State<_GlassInputField> createState() => _GlassInputFieldState();
}

class _GlassInputFieldState extends State<_GlassInputField> {
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label — 12px, muted, uppercase, weight 600, letter-spacing 0.5, 6px bottom margin
        Text(
          widget.label.toUpperCase(),
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
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onEditingComplete: widget.onEditingComplete,
          validator: widget.validator,
          enabled: widget.enabled,
          style: const TextStyle(
            fontFamily: 'Readex Pro',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
          cursorColor: HBotColors.primary,
          decoration: InputDecoration(
            hintText: widget.hint,
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
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: HBotColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
