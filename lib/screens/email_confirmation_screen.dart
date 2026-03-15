import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_shell.dart';

class EmailConfirmationScreen extends StatefulWidget {
  final String email;
  const EmailConfirmationScreen({super.key, required this.email});

  @override
  State<EmailConfirmationScreen> createState() => _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> {
  final _authService = AuthService();
  bool _isResending = false;

  Future<void> _resendConfirmation() async {
    setState(() => _isResending = true);
    try {
      await _authService.resendEmailConfirmation(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Confirmation email sent!'), backgroundColor: HBotColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: HBotColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HBotColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: HBotColors.textPrimaryLight, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Email Confirmation', style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600, color: HBotColors.textPrimaryLight)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(color: HBotColors.primarySurface, shape: BoxShape.circle),
                child: const Center(child: Text('✉️', style: TextStyle(fontSize: 32))),
              ),

              const SizedBox(height: HBotSpacing.space5),

              const Text('Check Your Email',
                style: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w700, color: HBotColors.textPrimaryLight),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: HBotSpacing.space3),

              Text("We've sent a confirmation email to",
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: HBotColors.textSecondaryLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(widget.email,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: HBotColors.primary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: HBotSpacing.space3),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: HBotSpacing.space4),
                child: Text(
                  'Please check your inbox and click the confirmation link to activate your account.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: HBotColors.textSecondaryLight),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: HBotSpacing.space7),

              // Resend button — gradient
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
                  decoration: hbotPrimaryButtonDecoration(disabled: _isResending),
                  child: ElevatedButton(
                    onPressed: _isResending ? null : _resendConfirmation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: HBotRadius.mediumRadius),
                    ),
                    child: _isResending
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('Resend Email', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),

              const SizedBox(height: HBotSpacing.space3),

              // Continue without — outlined
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HBotColors.textPrimaryLight,
                    side: const BorderSide(color: HBotColors.borderLight, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: HBotRadius.mediumRadius),
                  ),
                  child: const Text('Continue Without Confirmation', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
