import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/phosphor_icons.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _sendEmailFeedback() async {
    final feedback = _feedbackController.text.trim();

    if (feedback.isEmpty) {
      _showErrorSnackBar('Please enter your feedback before sending');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // URL encode the feedback text
      final encodedFeedback = Uri.encodeComponent(feedback);
      final url =
          'mailto:support@h-bot.tech?subject=HBOT%20App%20Feedback&body=$encodedFeedback';
      final uri = Uri.parse(url);

      debugPrint('Attempting to launch email with URL: $url');

      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched && mounted) {
          _showSuccessSnackBar('Opening email app...');
          // Clear the text field after successful launch
          _feedbackController.clear();
        } else if (mounted) {
          _showErrorSnackBar('Could not open email app');
        }
      } else {
        if (mounted) {
          _showErrorSnackBar('No email app found on your device');
        }
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
      if (mounted) {
        _showErrorSnackBar('Error opening email: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendWhatsAppFeedback() async {
    final feedback = _feedbackController.text.trim();

    if (feedback.isEmpty) {
      _showErrorSnackBar('Please enter your feedback before sending');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // URL encode the feedback text
      final encodedFeedback = Uri.encodeComponent(
        'Hello, I have feedback about the HBOT app:\n\n$feedback',
      );
      final url = 'https://wa.me/201281167100?text=$encodedFeedback';
      final uri = Uri.parse(url);

      debugPrint('Attempting to launch WhatsApp with URL: $url');

      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched && mounted) {
          _showSuccessSnackBar('Opening WhatsApp...');
          // Clear the text field after successful launch
          _feedbackController.clear();
        } else if (mounted) {
          _showErrorSnackBar('Could not open WhatsApp');
        }
      } else {
        if (mounted) {
          _showErrorSnackBar('WhatsApp is not installed on your device');
        }
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      if (mounted) {
        _showErrorSnackBar('Error opening WhatsApp: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HBotColors.primaryLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
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
        title: const Text('Send Feedback'),
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
              'We value your feedback',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: HBotColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: HBotSpacing.space2),
            Text(
              'Help us improve HBOT by sharing your thoughts, suggestions, or reporting issues',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HBotColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: HBotSpacing.space6),

            // Feedback Input
            Text(
              'Your Feedback',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: HBotColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),
            Container(
              decoration: BoxDecoration(
                color: HBotColors.cardLight,
                borderRadius: BorderRadius.circular(HBotRadius.medium),
                border: Border.all(
                  color: HBotColors.textSecondaryLight.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _feedbackController,
                maxLines: 8,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: HBotColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Tell us what you think...\n\nYou can share:\n• Feature suggestions\n• Bug reports\n• General feedback\n• Questions or concerns',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HBotColors.textSecondaryLight,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(HBotSpacing.space4),
                ),
              ),
            ),
            const SizedBox(height: HBotSpacing.space6),

            // Send Options
            Text(
              'Send via',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: HBotColors.textPrimaryLight,
              ),
            ),
            SizedBox(height: HBotSpacing.space4),

            // Email Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendEmailFeedback,
                icon: Icon(HBotIcons.email),
                label: const Text('Send via Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HBotColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: HBotSpacing.space4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HBotRadius.medium),
                  ),
                ),
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),

            // WhatsApp Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSending ? null : _sendWhatsAppFeedback,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Send via WhatsApp'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HBotColors.primary,
                  side: const BorderSide(color: HBotColors.primary),
                  padding: const EdgeInsets.symmetric(
                    vertical: HBotSpacing.space4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HBotRadius.medium),
                  ),
                ),
              ),
            ),
            const SizedBox(height: HBotSpacing.space6),

            // Info Box
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    HBotIcons.info,
                    color: HBotColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: HBotSpacing.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your feedback matters',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: HBotColors.textPrimaryLight,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'We read every message and use your feedback to improve HBOT. We typically respond within 24 hours during business days.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: HBotColors.textPrimaryLight,
                              ),
                        ),
                      ],
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
}
