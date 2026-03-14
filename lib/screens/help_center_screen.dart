import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                HBotIcons.back,
                size: 16,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Help Center',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
            color: Color(0xFF1F2937),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'We\'re here to help',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Get in touch with us through any of the following channels',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 24),

            // Contact Information Section
            _buildSectionHeader(context, 'Contact Information'),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildContactTile(
                    context,
                    icon: HBotIcons.network,
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
                    icon: HBotIcons.feedback,
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
            const SizedBox(height: 24),

            // Additional Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0883FD).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF0883FD).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    HBotIcons.info,
                    color: const Color(0xFF0883FD),
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'We typically respond within 24 hours during business days.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1F2937),
                        fontFamily: 'Inter',
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
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
        fontFamily: 'Inter',
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0883FD).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF0883FD), size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: Color(0xFF1F2937),
          fontFamily: 'Inter',
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF6B7280),
          fontFamily: 'Inter',
        ),
      ),
      trailing: Icon(
        HBotIcons.chevronRight,
        size: 16,
        color: Color(0xFF6B7280),
      ),
      onTap: onTap,
    );
  }
}
