import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for Alexa App-to-App Account Linking.
///
/// This implements Amazon's documented flow:
/// 1. User taps "Link with Alexa" in our app
/// 2. We generate a PKCE code challenge and state token
/// 3. We open the Alexa app's account linking consent URL
/// 4. User approves → Alexa app redirects back to our app with auth code
/// 5. Our backend exchanges the code for an access token
///
/// Reference: https://developer.amazon.com/en-US/docs/alexa/account-linking/app-to-app-account-linking-starting-from-your-app.html
class AlexaAccountLinkingService {
  // ─── Configuration ─────────────────────────────────────────────
  // These must be set from the Amazon Developer Console:
  // 1. Create a Login with Amazon (LWA) Security Profile
  // 2. Enable Account Linking in the Alexa Skill settings
  // 3. Set the redirect URI to your app's deep link

  /// LWA Security Profile client ID (from Amazon Developer Console)
  /// Format: amzn1.application-oa2-client.XXXXXXXXX
  static const String clientId = String.fromEnvironment(
    'ALEXA_LWA_CLIENT_ID',
    defaultValue: 'amzn1.application-oa2-client.b136c9d0dcf84ad8811ab061dd590e7a',
  );

  /// Redirect URI — must match what's configured in Amazon Developer Console
  /// This is the App Link (Android) / Universal Link (iOS) that Alexa redirects to
  static const String redirectUri = 'https://h-bot.tech/alexa/callback';

  /// Skill stage: 'live' for published skills, 'development' for testing
  /// Using 'development' since the skill may not be certified/published yet
  static const String skillStage = 'development';

  // ─── Alexa App Detection ───────────────────────────────────────
  static const String _alexaPackageName = 'com.amazon.dee.app';
  static const int _requiredMinVersionCode = 866607211;

  // ─── URLs ──────────────────────────────────────────────────────
  static const String _alexaConsentUrl =
      'https://alexa.amazon.com/spa/skill-account-linking-consent';
  static const String _lwaFallbackUrl = 'https://www.amazon.com/ap/oa';

  // ─── PKCE State ────────────────────────────────────────────────
  static String? _codeVerifier;
  static String? _state;

  /// Check if the Alexa LWA client ID is configured
  static bool get isConfigured => clientId.isNotEmpty;

  /// Generate a cryptographically secure random string
  static String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Generate PKCE code verifier and challenge (S256)
  static ({String verifier, String challenge}) _generatePkce() {
    final verifier = _generateRandomString(64);
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    final challenge = base64Url.encode(digest.bytes).replaceAll('=', '');
    return (verifier: verifier, challenge: challenge);
  }

  /// Build the Alexa app consent URL for app-to-app account linking
  static String _buildAlexaAppUrl({
    required String state,
    required String codeChallenge,
  }) {
    final params = {
      'fragment': 'skill-account-linking-consent',
      'client_id': clientId,
      'scope': 'alexa::skills:account_linking',
      'skill_stage': skillStage,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    };
    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_alexaConsentUrl?$queryString';
  }

  /// Build the LWA fallback URL (for when Alexa app is not installed)
  static String _buildLwaFallbackUrl({
    required String state,
    required String codeChallenge,
  }) {
    final params = {
      'client_id': clientId,
      'scope': 'alexa::skills:account_linking',
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    };
    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_lwaFallbackUrl?$queryString';
  }

  /// Initiate the Alexa account linking flow.
  /// Tries the Alexa app's consent screen first, falls back to LWA in browser.
  /// Returns true if the URL was launched successfully.
  static Future<bool> initiateAccountLinking() async {
    if (!isConfigured) {
      debugPrint('⚠️ Alexa LWA client_id not configured');
      return false;
    }

    // Generate PKCE and state
    final pkce = _generatePkce();
    _codeVerifier = pkce.verifier;
    _state = _generateRandomString(32);

    final alexaUrl = _buildAlexaAppUrl(
      state: _state!,
      codeChallenge: pkce.challenge,
    );

    final lwaUrl = _buildLwaFallbackUrl(
      state: _state!,
      codeChallenge: pkce.challenge,
    );

    // Try opening the Alexa app's consent page directly first
    try {
      final alexaUri = Uri.parse(alexaUrl);
      final canOpen = await canLaunchUrl(alexaUri);
      if (canOpen) {
        final launched = await launchUrl(
          alexaUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          debugPrint('✅ Opened Alexa app consent page');
          debugPrint('   URL: $alexaUrl');
          return true;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Alexa app not available: $e');
    }

    // Fallback: open LWA OAuth consent page in browser
    try {
      final launched = await launchUrl(
        Uri.parse(lwaUrl),
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        debugPrint('✅ Opened LWA consent page (browser fallback)');
        debugPrint('   URL: $lwaUrl');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Could not open LWA consent page: $e');
    }

    return false;
  }

  /// Handle the redirect callback from Alexa/LWA.
  /// Call this when your app receives a deep link to the redirect URI.
  /// Returns the authorization code and state, or null on error.
  static Map<String, String>? handleCallback(Uri uri) {
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      debugPrint('❌ Alexa account linking error: $error');
      debugPrint('   Description: ${uri.queryParameters['error_description']}');
      return null;
    }

    if (code == null || state == null) {
      debugPrint('❌ Missing code or state in callback');
      return null;
    }

    // Validate state matches what we sent
    if (state != _state) {
      debugPrint('❌ State mismatch — possible CSRF attack');
      return null;
    }

    debugPrint('✅ Received Alexa auth code');
    return {
      'code': code,
      'state': state,
      'code_verifier': _codeVerifier ?? '',
    };
  }

  /// Get the stored code verifier for the token exchange
  static String? get codeVerifier => _codeVerifier;
}
