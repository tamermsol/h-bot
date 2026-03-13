import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _authService = AuthService();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
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

  String _getOtpCode() {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _verifyOtp() async {
    final otp = _getOtpCode();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit code'),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await _authService.verifyOtp(widget.email, otp);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: HBotColors.success,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.toString()}'),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);

    try {
      await _authService.resendOtp(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent! Please check your email.'),
            backgroundColor: HBotColors.success,
          ),
        );
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend OTP: ${e.toString()}'),
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
      backgroundColor: HBotColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: HBotColors.textPrimaryLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: HBotSpacing.tabletMaxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: HBotSpacing.screenPadding,
                vertical: HBotSpacing.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: HBotSpacing.space5),

                  // Icon
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: HBotColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_outlined,
                        size: 40,
                        color: HBotColors.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: HBotSpacing.space7),

                  // Card
                  Container(
                    padding: const EdgeInsets.all(HBotSpacing.space6),
                    decoration: BoxDecoration(
                      color: HBotColors.cardLight,
                      borderRadius: HBotRadius.xlRadius,
                      boxShadow: HBotShadows.small,
                      border: Border.all(color: HBotColors.borderLight, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Verify Your Email',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: HBotColors.textPrimaryLight,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: HBotSpacing.space3),

                        const Text(
                          'We sent a 6-digit code to:',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: HBotColors.textSecondaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: HBotSpacing.space1),

                        Text(
                          widget.email,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: HBotColors.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: HBotSpacing.space7),

                        // OTP Input Fields
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 48,
                              height: 56,
                              child: TextField(
                                controller: _otpControllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: HBotColors.textPrimaryLight,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: HBotColors.neutral50,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: HBotRadius.smallRadius,
                                    borderSide: const BorderSide(
                                      color: HBotColors.borderLight,
                                      width: 1.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: HBotRadius.smallRadius,
                                    borderSide: const BorderSide(
                                      color: HBotColors.borderLight,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: HBotRadius.smallRadius,
                                    borderSide: const BorderSide(
                                      color: HBotColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty && index < 5) {
                                    _focusNodes[index + 1].requestFocus();
                                  } else if (value.isEmpty && index > 0) {
                                    _focusNodes[index - 1].requestFocus();
                                  }

                                  if (index == 5 && value.isNotEmpty) {
                                    _verifyOtp();
                                  }
                                },
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: HBotSpacing.space7),

                        // Verify Button
                        Container(
                          height: 48,
                          decoration: hbotPrimaryButtonDecoration(enabled: !_isVerifying),
                          child: ElevatedButton(
                            onPressed: _isVerifying ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: HBotRadius.mediumRadius,
                              ),
                            ),
                            child: _isVerifying
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Verify Email',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: HBotSpacing.space5),

                        // Resend OTP
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Didn't receive the code? ",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: HBotColors.textSecondaryLight,
                                fontSize: 14,
                              ),
                            ),
                            if (_resendCountdown > 0)
                              Text(
                                'Resend in ${_resendCountdown}s',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: HBotColors.textTertiaryLight,
                                  fontSize: 14,
                                ),
                              )
                            else
                              TextButton(
                                onPressed: _isResending ? null : _resendOtp,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: _isResending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            HBotColors.primary,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'Resend',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          color: HBotColors.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: HBotSpacing.space6),

                  // Skip for now
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                          (route) => false,
                        );
                      },
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: HBotColors.textTertiaryLight,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
