import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
        content: Text(message, style: const TextStyle(fontFamily: 'Inter')),
        backgroundColor: const Color(0xFF8CD1FB),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Inter')),
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
          onTap: () => Navigator.of(context).pop(),
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
                color: Color(0xFF1F2937),
                size: 18,
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Send Feedback',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.bold,
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
              'We value your feedback',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Help us improve HBOT by sharing your thoughts, suggestions, or reporting issues',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),

            // Feedback Input
            const Text(
              'Your Feedback',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _feedbackController,
                maxLines: 8,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: Color(0xFF1F2937),
                ),
                decoration: const InputDecoration(
                  hintText:
                      'Tell us what you think...\n\nYou can share:\n\u2022 Feature suggestions\n\u2022 Bug reports\n\u2022 General feedback\n\u2022 Questions or concerns',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Send Options
            const Text(
              'Send via',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),

            // Email Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x590883FD),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendEmailFeedback,
                  icon: Icon(HBotIcons.email),
                  label: const Text(
                    'Send via Email',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // WhatsApp Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isSending ? null : _sendWhatsAppFeedback,
                icon: Icon(HBotIcons.feedback),
                label: const Text(
                  'Send via WhatsApp',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0883FD),
                  side: const BorderSide(color: Color(0xFF0883FD)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Info Box
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    HBotIcons.info,
                    color: const Color(0xFF0883FD),
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your feedback matters',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'We read every message and use your feedback to improve HBOT. We typically respond within 24 hours during business days.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF1F2937),
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
