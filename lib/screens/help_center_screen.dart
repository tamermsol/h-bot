import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_shell.dart';
import '../l10n/app_strings.dart';

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

    return Scaffold(
      backgroundColor: context.hBackground,
      appBar: AppBar(
        title: Text(AppStrings.get('help_center_help_center')),
        backgroundColor: context.hBackground,
        elevation: 0,
      ),
      body: ResponsiveShell(child: SingleChildScrollView(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              AppStrings.get('help_were_here_to_help'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.hTextPrimary,
              ),
            ),
            const SizedBox(height: HBotSpacing.space2),
            Text(
              AppStrings.get('help_get_in_touch'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.hTextSecondary,
              ),
            ),
            const SizedBox(height: HBotSpacing.space6),

            // Contact Information Section
            _buildSectionHeader(context, AppStrings.get('help_contact_information')),
            const SizedBox(height: HBotSpacing.space4),
            Container(
              decoration: BoxDecoration(
                color: context.hCard,
                borderRadius: HBotRadius.mediumRadius,
              ),
              child: Column(
                children: [
                  _buildContactTile(
                    context,
                    icon: Icons.language,
                    title: AppStrings.get('help_website'),
                    subtitle: 'https://h-bot.tech/',
                    onTap: () =>
                        _launchUrl(context, 'https://h-bot.tech/', 'website'),
                  ),
                  const Divider(height: 1, indent: 72),
                  _buildContactTile(
                    context,
                    icon: Icons.email_outlined,
                    title: AppStrings.get('help_email'),
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
                    title: AppStrings.get('help_phone'),
                    subtitle: '+20 12 81167100',
                    onTap: () =>
                        _launchUrl(context, 'tel:+201281167100', 'phone'),
                  ),
                  const Divider(height: 1, indent: 72),
                  _buildContactTile(
                    context,
                    icon: Icons.chat_outlined,
                    title: AppStrings.get('help_whatsapp'),
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
                borderRadius: HBotRadius.mediumRadius,
                border: Border.all(
                  color: HBotColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: HBotColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: HBotSpacing.space4),
                  Expanded(
                    child: Text(
                      AppStrings.get('help_response_time'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.hTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: context.hTextPrimary,
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
          borderRadius: HBotRadius.smallRadius,
        ),
        child: Icon(icon, color: HBotColors.primary, size: 24),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: context.hTextPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.hTextSecondary,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: context.hTextSecondary,
      ),
      onTap: onTap,
    );
  }
}
