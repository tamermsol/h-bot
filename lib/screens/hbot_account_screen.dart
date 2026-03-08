import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_tile.dart';
import '../services/auth_service.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundColor
          : AppTheme.lightBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'HBOT Account',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark
            ? AppTheme.backgroundColor
            : AppTheme.lightBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Email Address Section
            Container(
              color: AppTheme.getCardColor(context),
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

            // Delete Account Section
            Container(
              color: AppTheme.getCardColor(context),
              child: SettingsTile(
                icon: Icons.person_remove_outlined,
                title: 'Delete Account',
                subtitle: '',
                titleColor: AppTheme.errorColor,
                onTap: () {
                  _showDeleteAccountDialog();
                },
                showDivider: false,
              ),
            ),
          ],
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

  void _showEmailDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.getCardColor(context),
          title: Text(
            'Email Address',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userEmail ?? 'No email',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.getTextPrimary(context),
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
          backgroundColor: AppTheme.getCardColor(context),
          title: Row(
            children: [
              Icon(Icons.warning, color: AppTheme.errorColor),
              const SizedBox(width: 8),
              Text(
                'Delete Account',
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
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
                    color: AppTheme.getTextPrimary(context),
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
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action is permanent and cannot be reversed',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.errorColor,
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
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
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
          Icon(Icons.close, color: AppTheme.errorColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextPrimary(context),
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
          backgroundColor: AppTheme.getCardColor(context),
          title: Text(
            'Final Confirmation',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To confirm deletion, please type:',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.backgroundColor
                      : AppTheme.lightSurfaceColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DELETE MY ACCOUNT',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmationController,
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
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
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
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
            backgroundColor: AppTheme.errorColor,
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
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
