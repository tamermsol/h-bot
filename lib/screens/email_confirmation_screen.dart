import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_shell.dart';
import '../l10n/app_strings.dart';

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
          SnackBar(content: Text(AppStrings.get('email_resent')), backgroundColor: HBotColors.success),
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
      backgroundColor: context.hBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.hTextPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(AppStrings.get('email_confirmation_title'), style: TextStyle(fontFamily: 'DM Sans', fontSize: 17, fontWeight: FontWeight.w600, color: context.hTextPrimary)),
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

              Text(AppStrings.get('check_your_email'),
                style: TextStyle(fontFamily: 'DM Sans', fontSize: 24, fontWeight: FontWeight.w700, color: context.hTextPrimary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: HBotSpacing.space3),

              Text(AppStrings.get('email_sent_to'),
                style: TextStyle(fontFamily: 'DM Sans', fontSize: 14, color: context.hTextSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(widget.email,
                style: const TextStyle(fontFamily: 'DM Sans', fontSize: 14, fontWeight: FontWeight.w600, color: HBotColors.primary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: HBotSpacing.space3),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: HBotSpacing.space4),
                child: Text(
                  AppStrings.get('email_confirmation_body'),
                  style: TextStyle(fontFamily: 'DM Sans', fontSize: 14, color: context.hTextSecondary),
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
                        : Text(AppStrings.get('resend_email'), style: const TextStyle(fontFamily: 'DM Sans', fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),


            ],
          ),
        ),
      ),
    );
  }
}
