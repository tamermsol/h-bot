import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Custom OTP email service that sends branded verification emails
/// via our own SMTP (Supabase Edge Function) instead of Supabase's built-in emails.
class EmailOtpService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Generate a 6-digit OTP code
  String _generateOtp() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  /// Send OTP for email verification (signup)
  Future<void> sendSignupOtp(String email) async {
    await _sendOtp(email, 'signup');
  }

  /// Send OTP for password reset
  Future<void> sendResetOtp(String email) async {
    await _sendOtp(email, 'reset');
  }

  /// Core OTP sending logic
  Future<void> _sendOtp(String email, String type) async {
    try {
      final otp = _generateOtp();
      debugPrint('📧 Sending $type OTP to: $email');

      // 1. Store OTP in database (invalidate previous codes first)
      await _supabase
          .from('otp_codes')
          .update({'used': true})
          .eq('email', email.toLowerCase())
          .eq('type', type)
          .eq('used', false);

      // 2. Insert new OTP
      await _supabase.from('otp_codes').insert({
        'email': email.toLowerCase(),
        'code': otp,
        'type': type,
        'expires_at': DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        'used': false,
      });

      // 3. Send email via Edge Function
      final response = await _supabase.functions.invoke(
        'send-otp-email',
        body: {
          'email': email.toLowerCase(),
          'otp': otp,
          'type': type,
        },
        headers: {
          'x-api-secret': const String.fromEnvironment('OTP_API_SECRET', defaultValue: 'hbot-otp-secret-2026'),
        },
      );

      if (response.status != 200) {
        final body = response.data;
        debugPrint('❌ Edge function error: $body');
        throw Exception('Failed to send verification email. Please try again.');
      }

      debugPrint('✅ OTP email sent to $email');
    } catch (e) {
      debugPrint('❌ Error sending OTP: $e');
      if (e.toString().contains('Failed to send')) rethrow;
      throw Exception('Failed to send verification email. Please check your connection.');
    }
  }

  /// Verify an OTP code
  Future<bool> verifyOtp(String email, String code, String type) async {
    try {
      debugPrint('🔐 Verifying $type OTP for: $email');

      final response = await _supabase
          .from('otp_codes')
          .select()
          .eq('email', email.toLowerCase())
          .eq('code', code)
          .eq('type', type)
          .eq('used', false)
          .gte('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ Invalid or expired OTP');
        return false;
      }

      // Mark as used
      await _supabase
          .from('otp_codes')
          .update({'used': true})
          .eq('id', response['id']);

      debugPrint('✅ OTP verified for $email');
      return true;
    } catch (e) {
      debugPrint('❌ OTP verification error: $e');
      return false;
    }
  }

  /// Resend OTP (just calls send again)
  Future<void> resendSignupOtp(String email) async {
    await sendSignupOtp(email);
  }

  Future<void> resendResetOtp(String email) async {
    await sendResetOtp(email);
  }
}
