import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  Future<void> _launchUrl(
    BuildContext context,
    String url,
    String errorMessage,
  ) async {
    try {
      debugPrint('Attempting to launch URL: $url');
      final uri = Uri.parse(url);

      final canLaunch = await canLaunchUrl(uri);
      debugPrint('Can launch URL: $canLaunch');

      if (canLaunch) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        debugPrint('Launch result: $launched');

        if (!launched && context.mounted) {
          _showErrorSnackBar(context, 'Could not open $errorMessage');
        }
      } else {
        debugPrint('Cannot launch URL: $url');
        if (context.mounted) {
          _showErrorSnackBar(context, 'Could not open $errorMessage');
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Error: $errorMessage - $e');
      }
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundColor
          : AppTheme.lightBackgroundColor,
      appBar: AppBar(
        title: const Text('Help Center'),
        backgroundColor: isDark
            ? AppTheme.backgroundColor
            : AppTheme.lightBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'We\'re here to help',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: AppTheme.paddingSmall),
            Text(
              'Get in touch with us through any of the following channels',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: AppTheme.paddingLarge),

            // Contact Information Section
            _buildSectionHeader(context, 'Contact Information'),
            const SizedBox(height: AppTheme.paddingMedium),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Column(
                children: [
                  _buildContactTile(
                    context,
                    icon: Icons.language,
                    title: 'Website',
                    subtitle: 'https://h-bot.tech/',
                    onTap: () =>
                        _launchUrl(context, 'https://h-bot.tech/', 'website'),
                  ),
                  const Divider(height: 1, indent: 72),
                  _buildContactTile(
                    context,
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: 'support@h-bot.tech',
                    onTap: () => _launchUrl(
                      context,
                      'mailto:support@h-bot.tech',
                      'email',
                    ),
                  ),
                  const Divider(height: 1, indent: 72),
                  _buildContactTile(
                    context,
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    subtitle: '+20 12 81167100',
                    onTap: () =>
                        _launchUrl(context, 'tel:+201281167100', 'phone'),
                  ),
                  const Divider(height: 1, indent: 72),
                  _buildContactTile(
                    context,
                    icon: Icons.chat_outlined,
                    title: 'WhatsApp',
                    subtitle: '+20 12 81167100',
                    onTap: () => _launchUrl(
                      context,
                      'https://wa.me/201281167100',
                      'WhatsApp',
                    ),
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.paddingLarge),

            // Additional Info
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: AppTheme.paddingMedium),
                  Expanded(
                    child: Text(
                      'We typically respond within 24 hours during business days.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppTheme.getTextPrimary(context),
      ),
    );
  }

  Widget _buildContactTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.paddingSmall),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 24),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: AppTheme.getTextPrimary(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.getTextSecondary(context),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppTheme.getTextSecondary(context),
      ),
      onTap: onTap,
    );
  }
}
