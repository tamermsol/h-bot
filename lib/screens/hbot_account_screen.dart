import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_tile.dart';
import '../services/auth_service.dart';
import '../widgets/responsive_shell.dart';

class HBOTAccountScreen extends StatefulWidget {
  final String? userEmail;
  final String? userName;
  final String? userPhone;
  final VoidCallback onAccountDeleted;

  const HBOTAccountScreen({
    super.key,
    this.userEmail,
    this.userName,
    this.userPhone,
    required this.onAccountDeleted,
  });

  @override
  State<HBOTAccountScreen> createState() => _HBOTAccountScreenState();
}

class _HBOTAccountScreenState extends State<HBOTAccountScreen> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: context.hBackground,
      appBar: AppBar(
        title: const Text(
          'HBOT Account',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: context.hBackground,
        elevation: 0,
      ),
      body: ResponsiveShell(child: SingleChildScrollView(
        child: Column(
          children: [
            // Email Address Section
            Container(
              color: context.hCard,
              child: SettingsTile(
                icon: Icons.email_outlined,
                title: 'Email address',
                subtitle: _maskEmail(widget.userEmail ?? ''),
                onTap: () {
                  // Show full email in a dialog
                  _showEmailDialog();
                },
                showDivider: false,
              ),
            ),
            const SizedBox(height: 1),

            // Change Password Section
            Container(
              color: context.hCard,
              child: SettingsTile(
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: '',
                onTap: () {
                  _showChangePasswordSheet();
                },
                showDivider: false,
              ),
            ),
            const SizedBox(height: 1),

            // Delete Account Section
            Container(
              color: context.hCard,
              child: SettingsTile(
                icon: Icons.person_remove_outlined,
                title: 'Delete Account',
                subtitle: '',
                titleColor: HBotColors.error,
                onTap: () {
                  _showDeleteAccountDialog();
                },
                showDivider: false,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _maskEmail(String email) {
    if (email.isEmpty) return '';

    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 4) {
      return '${username[0]}***@$domain';
    }

    final visibleStart = username.substring(0, 4);
    final visibleEnd = username.substring(username.length - 4);
    return '$visibleStart****$visibleEnd@$domain';
  }

  void _showChangePasswordSheet() {
    // Step: 0 = intro, 1 = OTP, 2 = new password
    int step = 0;
    bool isLoading = false;
    String? errorMessage;

    // OTP controllers & focus nodes
    final otpControllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());

    // Password controllers
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setState) {
            // ── helpers ──────────────────────────────────────────────
            String getOtp() => otpControllers.map((c) => c.text).join();

            Future<void> sendCode() async {
              setState(() {
                isLoading = true;
                errorMessage = null;
              });
              try {
                await _authService.resetPassword(widget.userEmail ?? '');
                setState(() {
                  step = 1;
                  isLoading = false;
                });
              } catch (e) {
                setState(() {
                  errorMessage = e.toString();
                  isLoading = false;
                });
              }
            }

            Future<void> verifyOtp() async {
              final otp = getOtp();
              if (otp.length != 6) {
                setState(() => errorMessage = 'Please enter the complete 6-digit code');
                return;
              }
              setState(() {
                isLoading = true;
                errorMessage = null;
              });
              // move to password step (OTP verified client-side on submit)
              setState(() {
                step = 2;
                isLoading = false;
              });
            }

            Future<void> submitNewPassword() async {
              final newPassword = newPasswordController.text;
              final confirm = confirmPasswordController.text;
              if (newPassword.isEmpty || confirm.isEmpty) {
                setState(() => errorMessage = 'Please fill in all fields');
                return;
              }
              if (newPassword != confirm) {
                setState(() => errorMessage = 'Passwords do not match');
                return;
              }
              if (newPassword.length < 8) {
                setState(() => errorMessage = 'Password must be at least 8 characters');
                return;
              }
              setState(() {
                isLoading = true;
                errorMessage = null;
              });
              try {
                await _authService.verifyPasswordResetOtp(
                  widget.userEmail ?? '',
                  getOtp(),
                  newPassword,
                );
                // Dispose resources
                for (final c in otpControllers) { c.dispose(); }
                for (final n in focusNodes) { n.dispose(); }
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                if (mounted) {
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully!'),
                      backgroundColor: HBotColors.success,
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  errorMessage = e.toString();
                  isLoading = false;
                });
              }
            }

            // ── OTP box builder ──────────────────────────────────────
            Widget buildOtpBox(int index) {
              return SizedBox(
                width: 46,
                height: 54,
                child: TextField(
                  controller: otpControllers[index],
                  focusNode: focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ctx.hTextPrimary,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: ctx.hBackground,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: HBotRadius.smallRadius,
                      borderSide: BorderSide(color: ctx.hBorder, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: HBotRadius.smallRadius,
                      borderSide: BorderSide(color: ctx.hBorder, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: HBotRadius.smallRadius,
                      borderSide: const BorderSide(color: HBotColors.primary, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.length > 1) {
                      // Paste detected — distribute digits
                      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                      for (int i = 0; i < 6; i++) {
                        otpControllers[i].text = i < digits.length ? digits[i] : '';
                      }
                      if (digits.length >= 6) {
                        focusNodes[5].requestFocus();
                        verifyOtp();
                      } else if (digits.isNotEmpty) {
                        focusNodes[digits.length.clamp(0, 5)].requestFocus();
                      }
                      return;
                    }
                    if (value.isNotEmpty && index < 5) {
                      focusNodes[index + 1].requestFocus();
                    } else if (value.isEmpty && index > 0) {
                      focusNodes[index - 1].requestFocus();
                    }
                    if (index == 5 && value.isNotEmpty) verifyOtp();
                  },
                ),
              );
            }

            // ── gradient button ──────────────────────────────────────
            Widget buildGradientButton({required String label, required VoidCallback? onPressed}) {
              return SizedBox(
                height: 52,
                child: Container(
                  decoration: hbotPrimaryButtonDecoration(disabled: isLoading || onPressed == null),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: HBotRadius.mediumRadius),
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
                              fontFamily: 'DM Sans',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              );
            }

            // ── sheet body per step ───────────────────────────────────
            Widget buildStepContent() {
              if (step == 0) {
                // Step 0: Intro — send code
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: HBotColors.primarySurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline, size: 28, color: HBotColors.primary),
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    Text(
                      'Change Password',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: ctx.hTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: HBotSpacing.space3),
                    Text(
                      "We'll send a verification code to your email",
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 14,
                        color: ctx.hTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.userEmail ?? '',
                      style: const TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: HBotColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: HBotSpacing.space3),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 13,
                          color: HBotColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: HBotSpacing.space5),
                    buildGradientButton(label: 'Send Code', onPressed: sendCode),
                  ],
                );
              } else if (step == 1) {
                // Step 1: OTP entry
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: HBotColors.primarySurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_outlined, size: 28, color: HBotColors.primary),
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    Text(
                      'Enter Verification Code',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: ctx.hTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: HBotSpacing.space3),
                    Text(
                      'We sent a 6-digit code to',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 14,
                        color: ctx.hTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.userEmail ?? '',
                      style: const TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: HBotColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: HBotSpacing.space5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (i) => buildOtpBox(i)),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: HBotSpacing.space3),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 13,
                          color: HBotColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: HBotSpacing.space5),
                    buildGradientButton(label: 'Verify Code', onPressed: verifyOtp),
                  ],
                );
              } else {
                // Step 2: New password entry
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: HBotColors.primarySurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_reset_outlined, size: 28, color: HBotColors.primary),
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    Text(
                      'Set New Password',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: ctx.hTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    // New password field
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 15,
                        color: ctx.hTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: TextStyle(
                          fontFamily: 'DM Sans',
                          color: ctx.hTextSecondary,
                        ),
                        filled: true,
                        fillColor: ctx.hBackground,
                        border: OutlineInputBorder(
                          borderRadius: HBotRadius.mediumRadius,
                          borderSide: BorderSide(color: ctx.hBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: HBotRadius.mediumRadius,
                          borderSide: BorderSide(color: ctx.hBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: HBotRadius.mediumRadius,
                          borderSide: const BorderSide(color: HBotColors.primary, width: 2),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: ctx.hTextSecondary,
                          ),
                          onPressed: () => setState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space3),
                    // Confirm password field
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 15,
                        color: ctx.hTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        labelStyle: TextStyle(
                          fontFamily: 'DM Sans',
                          color: ctx.hTextSecondary,
                        ),
                        filled: true,
                        fillColor: ctx.hBackground,
                        border: OutlineInputBorder(
                          borderRadius: HBotRadius.mediumRadius,
                          borderSide: BorderSide(color: ctx.hBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: HBotRadius.mediumRadius,
                          borderSide: BorderSide(color: ctx.hBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: HBotRadius.mediumRadius,
                          borderSide: const BorderSide(color: HBotColors.primary, width: 2),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: ctx.hTextSecondary,
                          ),
                          onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: HBotSpacing.space3),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 13,
                          color: HBotColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: HBotSpacing.space5),
                    buildGradientButton(label: 'Change Password', onPressed: submitNewPassword),
                  ],
                );
              }
            }

            // ── sheet container ───────────────────────────────────────
            return Container(
              decoration: BoxDecoration(
                color: ctx.hCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.fromLTRB(
                HBotSpacing.space5,
                HBotSpacing.space4,
                HBotSpacing.space5,
                HBotSpacing.space5 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: HBotSpacing.space4),
                      decoration: BoxDecoration(
                        color: ctx.hBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    buildStepContent(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEmailDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: context.hCard,
          title: Text(
            'Email Address',
            style: TextStyle(color: context.hTextPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userEmail ?? 'No email',
                style: TextStyle(
                  fontSize: 16,
                  color: context.hTextPrimary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: context.hCard,
          title: Row(
            children: [
              Icon(Icons.warning, color: HBotColors.error),
              const SizedBox(width: 8),
              Text(
                'Delete Account',
                style: TextStyle(color: context.hTextPrimary),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This action cannot be undone. Deleting your account will:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.hTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDeleteWarningItem('Delete all your homes and rooms'),
                _buildDeleteWarningItem('Remove all your devices'),
                _buildDeleteWarningItem(
                  'Delete all your scenes and automations',
                ),
                _buildDeleteWarningItem('Erase all your personal data'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HBotColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: HBotColors.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: HBotColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action is permanent and cannot be reversed',
                          style: TextStyle(
                            fontSize: 12,
                            color: HBotColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showDeleteAccountConfirmation();
              },
              style: TextButton.styleFrom(foregroundColor: HBotColors.error),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeleteWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.close, color: HBotColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: context.hTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation() {
    final confirmationController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: context.hCard,
          title: Text(
            'Final Confirmation',
            style: TextStyle(color: context.hTextPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To confirm deletion, please type:',
                style: TextStyle(
                  fontSize: 14,
                  color: context.hTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? context.hBackground
                      : context.hSurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DELETE MY ACCOUNT',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: HBotColors.error,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmationController,
                style: TextStyle(color: context.hTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Type here',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (confirmationController.text == 'DELETE MY ACCOUNT') {
                  Navigator.of(dialogContext).pop();
                  await _handleDeleteAccount();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please type the exact confirmation text'),
                      backgroundColor: HBotColors.error,
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: HBotColors.error),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDeleteAccount() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Deleting account...'),
              ],
            ),
            backgroundColor: HBotColors.error,
            duration: const Duration(seconds: 30),
          ),
        );
      }

      // Delete the user account
      await _authService.deleteAccount();

      // Call the callback to navigate to sign-in screen
      widget.onAccountDeleted();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Handle deletion error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: HBotColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
