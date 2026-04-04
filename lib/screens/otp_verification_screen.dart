import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import '../l10n/app_strings.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _authService = AuthService();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
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
    for (var c in _otpControllers) { c.dispose(); }
    for (var n in _focusNodes) { n.dispose(); }
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) { _resendCountdown--; } else { timer.cancel(); }
        });
      }
    });
  }

  String _getOtpCode() => _otpControllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final otp = _getOtpCode();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('otp_incomplete')), backgroundColor: HBotColors.error),
      );
      return;
    }
    setState(() => _isVerifying = true);
    try {
      await _authService.verifyOtp(widget.email, otp);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('otp_verified')), backgroundColor: HBotColors.success),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.get('otp_failed')}${e.toString()}'), backgroundColor: HBotColors.error),
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
          SnackBar(content: Text(AppStrings.get('otp_resent')), backgroundColor: HBotColors.success),
        );
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.get('otp_resend_failed')}${e.toString()}'), backgroundColor: HBotColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.hTextPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(AppStrings.get('otp_title'), style: TextStyle(fontFamily: 'DM Sans', fontSize: 17, fontWeight: FontWeight.w600, color: context.hTextPrimary)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: HBotSpacing.space7),

              // Icon
              Center(
                child: Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(color: HBotColors.primarySurface, shape: BoxShape.circle),
                  child: const Icon(Icons.verified_outlined, size: 32, color: HBotColors.primary),
                ),
              ),

              const SizedBox(height: HBotSpacing.space5),

              Text(AppStrings.get('verify_your_email'),
                style: TextStyle(fontFamily: 'DM Sans', fontSize: 24, fontWeight: FontWeight.w700, color: context.hTextPrimary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: HBotSpacing.space3),

              Text(AppStrings.get('otp_sent_to'), style: TextStyle(fontFamily: 'DM Sans', fontSize: 14, color: context.hTextSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(widget.email, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 14, fontWeight: FontWeight.w600, color: HBotColors.primary), textAlign: TextAlign.center),

              const SizedBox(height: HBotSpacing.space7),

              // OTP boxes — 48×56px each per spec
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) => SizedBox(
                  width: 48, height: 56,
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: TextStyle(fontFamily: 'DM Sans', fontSize: 24, fontWeight: FontWeight.w700, color: context.hTextPrimary),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: context.hCard,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(borderRadius: HBotRadius.smallRadius, borderSide: BorderSide(color: context.hBorder, width: 1)),
                      enabledBorder: OutlineInputBorder(borderRadius: HBotRadius.smallRadius, borderSide: BorderSide(color: context.hBorder, width: 1)),
                      focusedBorder: OutlineInputBorder(borderRadius: HBotRadius.smallRadius, borderSide: const BorderSide(color: HBotColors.primary, width: 2)),
                    ),
                    onChanged: (value) {
                      if (value.length > 1) {
                        // Paste detected — distribute digits across all fields
                        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                        for (int i = 0; i < 6; i++) {
                          _otpControllers[i].text = i < digits.length ? digits[i] : '';
                        }
                        if (digits.length >= 6) {
                          _focusNodes[5].requestFocus();
                          _verifyOtp();
                        } else if (digits.isNotEmpty) {
                          _focusNodes[digits.length.clamp(0, 5)].requestFocus();
                        }
                        return;
                      }
                      if (value.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
                      else if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
                      if (index == 5 && value.isNotEmpty) _verifyOtp();
                    },
                  ),
                )),
              ),

              const SizedBox(height: HBotSpacing.space7),

              // Verify button — gradient
              SizedBox(
                height: 52,
                child: Container(
                  decoration: hbotPrimaryButtonDecoration(disabled: _isVerifying),
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: HBotRadius.mediumRadius),
                    ),
                    child: _isVerifying
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : Text(AppStrings.get('verify'), style: const TextStyle(fontFamily: 'DM Sans', fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),

              const SizedBox(height: HBotSpacing.space5),

              // Resend countdown
              Center(
                child: _resendCountdown > 0
                    ? Text('${AppStrings.get('resend_in')}0:${_resendCountdown.toString().padLeft(2, '0')}',
                        style: TextStyle(fontFamily: 'DM Sans', fontSize: 14, color: context.hTextSecondary))
                    : TextButton(
                        onPressed: _isResending ? null : _resendOtp,
                        child: _isResending
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(HBotColors.primary)))
                            : Text(AppStrings.get('resend_code'), style: const TextStyle(fontFamily: 'DM Sans', fontSize: 14, fontWeight: FontWeight.w600, color: HBotColors.primary)),
                      ),
              ),


            ],
          ),
        ),
      ),
    );
  }
}
