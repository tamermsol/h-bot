import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'sign_in_screen.dart';
import '../widgets/smart_input_field.dart';
import '../widgets/responsive_shell.dart';
import '../l10n/app_strings.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _authService = AuthService();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isResetting = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  void _handleOtpPaste(String value, int startIndex) {
    // Extract only digits
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    for (int i = 0; i < digits.length && (startIndex + i) < 6; i++) {
      _otpControllers[startIndex + i].text = digits[i];
    }
    // Focus the next empty field or the last one
    final nextEmpty = _otpControllers.indexWhere((c) => c.text.isEmpty);
    if (nextEmpty >= 0 && nextEmpty < 6) {
      _focusNodes[nextEmpty].requestFocus();
    } else {
      _focusNodes[5].requestFocus();
    }
    setState(() {});
  }

  String _getOtpCode() {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _resetPassword() async {
    final otp = _getOtpCode();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('reset_password_please_enter_the_complete_6digit_code')),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('reset_password_please_enter_a_new_password')),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('reset_password_password_must_be_at_least_6_characters')),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('reset_password_passwords_do_not_match')),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    setState(() => _isResetting = true);

    try {
      await _authService.verifyPasswordResetOtp(
        widget.email,
        otp,
        _newPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('reset_password_password_reset_successfully')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignInScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("error_reset_password")}: ${e.toString()}'),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);

    try {
      await _authService.resetPassword(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('reset_password_reset_code_sent_please_check_your_email')),
            backgroundColor: Colors.green,
          ),
        );
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("error_resend_code")}: ${e.toString()}'),
            backgroundColor: HBotColors.error,
          ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: HBotSpacing.space4),

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
                  AppStrings.get('reset_password_title'),
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: context.hTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: HBotSpacing.space2),

                Text(
                  AppStrings.get('reset_enter_code'),
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 14,
                    color: context.hTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 4),

                Text(
                  widget.email,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HBotColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: HBotSpacing.space6),

                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 48,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 6, // Allow paste of full OTP
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: context.hTextPrimary,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: context.hCard,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.hBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.hBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HBotColors.primary, width: 2),
                          ),
                        ),
                        onChanged: (value) {
                          // Handle paste — if user pastes a full OTP code
                          if (value.length > 1) {
                            _handleOtpPaste(value, index);
                            return;
                          }
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                        },
                      ),
                    );
                  }),
                ),

                const SizedBox(height: HBotSpacing.space6),

                // New Password
                SmartInputField(
                  controller: _newPasswordController,
                  label: AppStrings.get('reset_password_new_password'),
                  hint: AppStrings.get('reset_at_least_6'),
                  obscureText: true,
                  enabled: !_isResetting,
                  validator: (value) {
                    if (value == null || value.isEmpty) return AppStrings.get('reset_enter_new_password');
                    if (value.length < 6) return AppStrings.get('reset_password_min_error');
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space3),

                // Confirm Password
                SmartInputField(
                  controller: _confirmPasswordController,
                  label: AppStrings.get('reset_password_confirm_password'),
                  hint: AppStrings.get('reset_reenter_password'),
                  obscureText: true,
                  enabled: !_isResetting,
                  validator: (value) {
                    if (value != _newPasswordController.text) return AppStrings.get('reset_passwords_no_match');
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space2),

                Text(
                  AppStrings.get('reset_password_min_error'),
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 12,
                    color: context.hTextTertiary,
                  ),
                ),

                const SizedBox(height: HBotSpacing.space6),

                // Reset Button
                SizedBox(
                  height: 52,
                  child: Container(
                    decoration: hbotPrimaryButtonDecoration(disabled: _isResetting),
                    child: ElevatedButton(
                      onPressed: _isResetting ? null : _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: HBotRadius.mediumRadius),
                      ),
                      child: _isResetting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                            )
                          : Text(AppStrings.get('reset_password_reset_password'), style: TextStyle(fontFamily: 'DM Sans', fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),

                const SizedBox(height: HBotSpacing.space5),

                // Resend Code
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${AppStrings.get('reset_didnt_receive')} ",
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: context.hTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (_resendCountdown > 0)
                      Text(
                        '${AppStrings.get('reset_resend_in')} ${_resendCountdown}s',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          color: context.hTextTertiary,
                          fontSize: 14,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _isResending ? null : _resendOtp,
                        child: _isResending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(HBotColors.primary)),
                              )
                            : Text(
                                AppStrings.get('reset_resend'),
                                style: TextStyle(
                                  fontFamily: 'DM Sans',
                                  color: HBotColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                  ],
                ),

                const SizedBox(height: HBotSpacing.space7),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
