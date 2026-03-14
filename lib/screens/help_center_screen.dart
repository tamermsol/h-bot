import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/phosphor_icons.dart';

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
        backgroundColor: HBotColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? HBotColors.backgroundLight
          : HBotColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Help Center'),
        backgroundColor: isDark
            ? HBotColors.backgroundLight
            : HBotColors.backgroundLight,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'We\'re here to help',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: HBotColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: HBotSpacing.space2),
            Text(
              'Get in touch with us through any of the following channels',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HBotColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: HBotSpacing.space6),

            // Contact Information Section
            _buildSectionHeader(context, 'Contact Information'),
            const SizedBox(height: HBotSpacing.space4),
            Container(
              decoration: BoxDecoration(
                color: HBotColors.cardLight,
                borderRadius: BorderRadius.circular(HBotRadius.medium),
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
                    icon: HBotIcons.email,
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
                    icon: HBotIcons.phone,
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
            const SizedBox(height: HBotSpacing.space6),

            // Additional Info
            Container(
              padding: const EdgeInsets.all(HBotSpacing.space4),
              decoration: BoxDecoration(
                color: HBotColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(HBotRadius.medium),
                border: Border.all(
                  color: HBotColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    HBotIcons.info,
                    color: HBotColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: HBotSpacing.space4),
                  Expanded(
                    child: Text(
                      'We typically respond within 24 hours during business days.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HBotColors.textPrimaryLight,
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
        color: HBotColors.textPrimaryLight,
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
        padding: const EdgeInsets.all(HBotSpacing.space2),
        decoration: BoxDecoration(
          color: HBotColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(HBotRadius.small),
        ),
        child: Icon(icon, color: HBotColors.primary, size: 24),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: HBotColors.textPrimaryLight,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: HBotColors.textSecondaryLight,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: HBotColors.textSecondaryLight,
      ),
      onTap: onTap,
    );
  }
}
