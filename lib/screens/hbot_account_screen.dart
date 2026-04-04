import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system.dart';
import '../widgets/settings_tile.dart';
import '../services/auth_service.dart';
import '../widgets/responsive_shell.dart';
import '../l10n/app_strings.dart';

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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          AppStrings.get('hbot_account_title'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Readex Pro',
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: HBotIconButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HBotColors.darkBgTop, HBotColors.darkBgBottom],
          ),
        ),
        child: ResponsiveShell(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + HBotSpacing.space4),

                // Profile card at top — centered avatar, name, email
                _buildProfileCard(),

                // Account info group
                SettingsGroup(
                  label: AppStrings.get('profile_account'),
                  children: [
                    SettingsTile(
                      icon: Icons.email_outlined,
                      title: AppStrings.get('email_address'),
                      subtitle: _maskEmail(widget.userEmail ?? ''),
                      iconColor: HBotColors.primary,
                      onTap: () {
                        _showEmailDialog();
                      },
                    ),
                    SettingsTile(
                      icon: Icons.lock_outline,
                      title: AppStrings.get('change_password'),
                      subtitle: 'Update your password',
                      iconColor: HBotColors.primary,
                      onTap: () {
                        _showChangePasswordSheet();
                      },
                    ),
                    SettingsTile(
                      icon: Icons.download_outlined,
                      title: 'Data Export',
                      subtitle: 'Download your data',
                      iconColor: const Color(0xFFF59E0B),
                      showDivider: false,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Data export coming soon'), backgroundColor: HBotColors.primary),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: HBotSpacing.space6),

                // Danger zone — red-tinted glass card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
                  padding: const EdgeInsets.all(HBotSpacing.space5),
                  decoration: BoxDecoration(
                    color: const Color(0x0FEF4444), // rgba(239,68,68,0.06)
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x26EF4444), width: 1), // rgba(239,68,68,0.15)
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showDeleteAccountDialog(),
                          icon: const Icon(Icons.person_remove_outlined, size: 18),
                          label: Text(
                            AppStrings.get('delete_account'),
                            style: const TextStyle(fontFamily: 'Readex Pro', fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: HBotColors.error,
                            side: const BorderSide(color: HBotColors.error, width: 1),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: HBotSpacing.space7),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: HBotSpacing.space5,
        vertical: HBotSpacing.space3,
      ),
      child: HBotCard(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Center(
          child: Column(
            children: [
              // Avatar — 72x72 circle with gradient
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1070AD), Color(0xFF2FB8EC)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0883FD).withOpacity(0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(child: Icon(Icons.person, size: 40, color: Colors.white)),
              ),
              const SizedBox(height: HBotSpacing.space3),
              Text(
                widget.userName ?? 'User',
                style: const TextStyle(
                  fontFamily: 'Readex Pro',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: HBotSpacing.space1),
              Text(
                widget.userEmail ?? '',
                style: const TextStyle(
                  fontFamily: 'Readex Pro',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: HBotColors.textMuted,
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
            // helpers
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
                for (final c in otpControllers) { c.dispose(); }
                for (final n in focusNodes) { n.dispose(); }
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                if (mounted) {
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.get('password_updated')),
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

            // OTP box builder
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
                  style: const TextStyle(
                    fontFamily: 'Readex Pro',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: HBotColors.glassBackground,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: HBotRadius.smallRadius,
                      borderSide: BorderSide(color: HBotColors.glassBorder, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: HBotRadius.smallRadius,
                      borderSide: BorderSide(color: HBotColors.glassBorder, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: HBotRadius.smallRadius,
                      borderSide: const BorderSide(color: HBotColors.primary, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.length > 1) {
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

            // gradient button
            Widget buildGradientButton({required String label, required VoidCallback? onPressed}) {
              return HBotGradientButton(
                enabled: !isLoading && onPressed != null,
                onTap: isLoading ? null : onPressed,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(label),
              );
            }

            // sheet body per step
            Widget buildStepContent() {
              if (step == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: HBotColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline, size: 28, color: HBotColors.primary),
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    Text(
                      AppStrings.get('change_password'),
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: HBotSpacing.space3),
                    Text(
                      AppStrings.get('enter_otp'),
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 14,
                        color: HBotColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.userEmail ?? '',
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
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
                          fontFamily: 'Readex Pro',
                          fontSize: 13,
                          color: HBotColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: HBotSpacing.space5),
                    buildGradientButton(label: AppStrings.get('send_code'), onPressed: sendCode),
                  ],
                );
              } else if (step == 1) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: HBotColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_outlined, size: 28, color: HBotColors.primary),
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    const Text(
                      'Enter Verification Code',
                      style: TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: HBotSpacing.space3),
                    const Text(
                      'We sent a 6-digit code to',
                      style: TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 14,
                        color: HBotColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.userEmail ?? '',
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
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
                          fontFamily: 'Readex Pro',
                          fontSize: 13,
                          color: HBotColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: HBotSpacing.space5),
                    buildGradientButton(label: AppStrings.get('verify'), onPressed: verifyOtp),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: HBotColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_reset_outlined, size: 28, color: HBotColors.primary),
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    Text(
                      AppStrings.get('new_password'),
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        labelText: AppStrings.get('new_password'),
                        labelStyle: const TextStyle(
                          fontFamily: 'Readex Pro',
                          color: HBotColors.textMuted,
                        ),
                        filled: true,
                        fillColor: HBotColors.glassBackground,
                        border: OutlineInputBorder(
                          borderRadius: HBotRadius.mediumRadius,
                          borderSide: BorderSide(color: HBotColors.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: HBotRadius.mediumRadius,
                          borderSide: BorderSide(color: HBotColors.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: HBotRadius.mediumRadius,
                          borderSide: const BorderSide(color: HBotColors.primary, width: 2),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: HBotColors.textMuted,
                          ),
                          onPressed: () => setState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space3),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        labelText: AppStrings.get('confirm_password'),
                        labelStyle: const TextStyle(
                          fontFamily: 'Readex Pro',
                          color: HBotColors.textMuted,
                        ),
                        filled: true,
                        fillColor: HBotColors.glassBackground,
                        border: OutlineInputBorder(
                          borderRadius: HBotRadius.mediumRadius,
                          borderSide: BorderSide(color: HBotColors.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: HBotRadius.mediumRadius,
                          borderSide: BorderSide(color: HBotColors.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: HBotRadius.mediumRadius,
                          borderSide: const BorderSide(color: HBotColors.primary, width: 2),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: HBotColors.textMuted,
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
                          fontFamily: 'Readex Pro',
                          fontSize: 13,
                          color: HBotColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: HBotSpacing.space5),
                    buildGradientButton(label: AppStrings.get('change_password'), onPressed: submitNewPassword),
                  ],
                );
              }
            }

            // sheet container
            return Container(
              decoration: const BoxDecoration(
                color: HBotColors.sheetBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                        color: HBotColors.textMuted.withOpacity(0.3),
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
          backgroundColor: HBotColors.sheetBackground,
          title: Text(
            AppStrings.get('email_address'),
            style: const TextStyle(color: Colors.white, fontFamily: 'Readex Pro', fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userEmail ?? 'No email',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppStrings.get('close')),
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
          backgroundColor: HBotColors.sheetBackground,
          title: Row(
            children: [
              Icon(Icons.warning, color: HBotColors.error),
              const SizedBox(width: 8),
              Text(
                AppStrings.get('delete_account'),
                style: const TextStyle(color: Colors.white, fontFamily: 'Readex Pro', fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action cannot be undone. Deleting your account will:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
              child: Text(AppStrings.get('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showDeleteAccountConfirmation();
              },
              style: TextButton.styleFrom(foregroundColor: HBotColors.error),
              child: Text(AppStrings.get('confirm')),
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
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
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
          backgroundColor: HBotColors.sheetBackground,
          title: const Text(
            'Final Confirmation',
            style: TextStyle(color: Colors.white, fontFamily: 'Readex Pro', fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To confirm deletion, please type:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HBotColors.glassBackground,
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: AppStrings.get('hbot_account_type_here'),
                  hintStyle: const TextStyle(color: HBotColors.textMuted),
                  filled: true,
                  fillColor: HBotColors.glassBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: HBotColors.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: HBotColors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: HBotColors.error),
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
              child: Text(AppStrings.get('cancel')),
            ),
            TextButton(
              onPressed: () async {
                if (confirmationController.text == 'DELETE MY ACCOUNT') {
                  Navigator.of(dialogContext).pop();
                  await _handleDeleteAccount();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.get('fill_all_fields')),
                      backgroundColor: HBotColors.error,
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: HBotColors.error),
              child: Text(AppStrings.get('delete_account')),
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
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(AppStrings.get('loading')),
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
          SnackBar(
            content: Text(AppStrings.get('account_deleted')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Handle deletion error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get('account_delete_failed')}: $e'),
            backgroundColor: HBotColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
