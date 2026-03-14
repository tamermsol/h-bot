import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class EmailConfirmationScreen extends StatefulWidget {
  final String email;

  const EmailConfirmationScreen({super.key, required this.email});

  @override
  State<EmailConfirmationScreen> createState() =>
      _EmailConfirmationScreenState();
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
          const SnackBar(
            content: Text('Confirmation email sent! Please check your inbox.'),
            backgroundColor: HBotColors.success,
          ),
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
      backgroundColor: HBotTheme.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: HBotTheme.textPrimary(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: HBotSpacing.tabletMaxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.screenPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Envelope icon in success-colored circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: HBotTheme.surfacePrimarySubtle(context),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.email_outlined,
                      size: 40,
                      color: HBotColors.primary,
                    ),
                  ),

                  const SizedBox(height: HBotSpacing.space7),

                  // Card
                  Container(
                    padding: const EdgeInsets.all(HBotSpacing.space6),
                    decoration: BoxDecoration(
                      color: HBotTheme.card(context),
                      borderRadius: HBotRadius.xlRadius,
                      boxShadow: HBotShadows.small,
                      border: Border.all(color: HBotTheme.border(context), width: 1),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Check Your Email',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: HBotTheme.textPrimary(context),
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: HBotSpacing.space3),

                        Text(
                          'We sent a confirmation link to:',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: HBotTheme.textSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: HBotSpacing.space2),

                        Text(
                          widget.email,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: HBotColors.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: HBotSpacing.space6),

                        // Info card
                        Container(
                          padding: const EdgeInsets.all(HBotSpacing.space4),
                          decoration: BoxDecoration(
                            color: HBotTheme.surfacePrimarySubtle(context),
                            borderRadius: HBotRadius.mediumRadius,
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Mobile App Note',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: HBotTheme.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: HBotSpacing.space2),
                              Text(
                                'If the email link doesn\'t work, you can still use the app! Email confirmation is optional for testing.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: HBotTheme.textSecondary(context),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: HBotSpacing.space6),

                        // Resend Button (gradient)
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: hbotPrimaryButtonDecoration(enabled: !_isResending),
                          child: ElevatedButton(
                            onPressed: _isResending ? null : _resendConfirmation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: HBotRadius.mediumRadius,
                              ),
                            ),
                            child: _isResending
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Resend Email',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: HBotSpacing.space3),

                        // Continue without confirmation
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HBotColors.primary,
                              side: const BorderSide(color: HBotColors.primary, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: HBotRadius.mediumRadius,
                              ),
                            ),
                            child: const Text(
                              'Continue Without Confirmation',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: HBotSpacing.space5),

                  Text(
                    'You can always confirm your email later in settings.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: HBotTheme.textTertiary(context),
                    ),
                    textAlign: TextAlign.center,
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
