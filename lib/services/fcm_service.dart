import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM Background message: ${message.messageId}');
}

/// Handles FCM token registration and push notification lifecycle.
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _supabase = Supabase.instance.client;
  String? _currentToken;
  bool _initialized = false;

  /// Initialize FCM — call after Firebase.initializeApp() and auth
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS will show prompt, Android auto-grants)
    // Skip permission request on simulator to avoid blocking dialog
    if (!(Platform.isIOS && kDebugMode)) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('FCM Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _setupToken();
        _setupForegroundHandler();
        _setupTokenRefresh();
      }
    } else {
      debugPrint('FCM: Skipping permission request in iOS debug mode');
    }
  }

  /// Get and register the FCM token
  Future<void> _setupToken() async {
    try {
      // For iOS, get APNs token first
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        debugPrint('APNs token: ${apnsToken != null ? "received" : "null"}');
        if (apnsToken == null) {
          // Wait a moment and retry
          await Future.delayed(const Duration(seconds: 2));
          await _messaging.getAPNSToken();
        }
      }

      _currentToken = await _messaging.getToken();
      debugPrint('FCM Token: ${_currentToken?.substring(0, 20)}...');

      if (_currentToken != null) {
        await _registerToken(_currentToken!);
      }
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  /// Register token in Supabase fcm_tokens table
  Future<void> _registerToken(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Get current app locale
      final locale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;

      await _supabase.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'device_info': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        'locale': locale,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,token');

      debugPrint('FCM token registered for user $userId');
    } catch (e) {
      debugPrint('FCM token registration error: $e');
    }
  }

  /// Handle foreground messages
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM Foreground message: ${message.notification?.title}');
      // In-app notifications are handled by BroadcastService via Supabase
      // FCM foreground messages can trigger a local notification or refresh
    });

    // Handle notification tap (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM Notification tapped: ${message.notification?.title}');
      // Could navigate to specific screen based on message.data
    });
  }

  /// Listen for token refreshes
  void _setupTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM Token refreshed');
      _currentToken = newToken;
      await _registerToken(newToken);
    });
  }

  /// Remove token on logout
  Future<void> removeToken() async {
    if (_currentToken == null) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('fcm_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', _currentToken!);
      debugPrint('FCM token removed');
    } catch (e) {
      debugPrint('FCM token removal error: $e');
    }
    _currentToken = null;
    _initialized = false;
  }

  /// Get current token (for debugging)
  String? get currentToken => _currentToken;
}
