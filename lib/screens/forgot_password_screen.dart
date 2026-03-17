import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/smart_input_field.dart';
import '../theme/app_theme.dart';
import 'reset_password_screen.dart';
import '../widgets/responsive_shell.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _authService.resetPassword(_emailController.text.trim());
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(email: _emailController.text.trim()),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset code: ${e.toString()}'),
            backgroundColor: HBotColors.error,
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.hTextPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ResponsiveShell(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: HBotSpacing.space7),

                  // Icon
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: HBotColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_reset_rounded, size: 32, color: HBotColors.primary),
                    ),
                  ),

                  const SizedBox(height: HBotSpacing.space5),

                  Text(
                    'Reset password',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: context.hTextPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: HBotSpacing.space2),

                  SizedBox(
                    width: 280,
                    child: Text(
                      "Enter your email and we'll send you a verification code to reset your password",
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: context.hTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: HBotSpacing.space7),

                  SmartInputField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'user@example.com',
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your email';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: HBotSpacing.space6),

                  SizedBox(
                    height: 52,
                    child: Container(
                      decoration: hbotPrimaryButtonDecoration(disabled: _isLoading),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendResetCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: HBotRadius.mediumRadius),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                              )
                            : const Text('Send Reset Code', style: TextStyle(fontFamily: 'DM Sans', fontSize: 16, fontWeight: FontWeight.w500)),
                      ),
                    ),
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
