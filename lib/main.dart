import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'env.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'services/app_lifecycle_manager.dart';
import 'services/enhanced_mqtt_service.dart';
import 'services/smart_home_service.dart';
import 'services/scene_trigger_scheduler.dart';
import 'services/location_trigger_monitor.dart';
import 'services/device_state_cache.dart';
import 'services/scene_command_executor.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';
import 'services/notification_service.dart';
import 'l10n/app_strings.dart';

/// Background callback for home widget toggle actions.
/// This runs in a separate isolate when user taps toggle on widget.
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  WidgetsFlutterBinding.ensureInitialized();

  if (uri.host == 'toggle' || uri.host == 'shutter') {
    final deviceId = uri.queryParameters['deviceId'];
    final topic = uri.queryParameters['topic'];
    final action = uri.host; // 'toggle' or 'shutter'

    if (deviceId == null || topic == null) return;

    debugPrint('🏠 Widget action: $action on $deviceId');

    // 1. Update widget visually FIRST (instant feedback)
    if (action == 'toggle') {
      final newState = uri.queryParameters['state'] ?? 'OFF';
      for (int i = 0; i < 4; i++) {
        final storedId = await HomeWidget.getWidgetData<String>('device_${i}_id');
        if (storedId == deviceId) {
          await HomeWidget.saveWidgetData('device_${i}_state', newState);
          break;
        }
      }
    }
    await HomeWidget.updateWidget(androidName: 'HBotDeviceWidget');

    // 2. Send MQTT command directly from background
    try {
      final client = MqttServerClient(
        '203.161.35.95',
        'hbot-widget-${DateTime.now().millisecondsSinceEpoch}',
      );
      client.port = 1883;
      client.secure = false; // plain MQTT on local broker
      client.keepAlivePeriod = 10;
      client.connectTimeoutPeriod = 5000;

      final connMsg = MqttConnectMessage()
          .withClientIdentifier(client.clientIdentifier)
          .authenticateAs('admin', 'P@ssword1')
          .startClean();
      client.connectionMessage = connMsg;

      await client.connect();

      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        String cmdTopic;
        String payload;

        if (action == 'shutter') {
          final direction = uri.queryParameters['direction'] ?? 'stop';
          cmdTopic = 'cmnd/$topic/ShutterPosition1';
          payload = direction == 'up' ? '0' : direction == 'down' ? '100' : 'STOP';
        } else {
          final newState = uri.queryParameters['state'] ?? 'OFF';
          cmdTopic = 'cmnd/$topic/POWER0';
          payload = newState;
        }

        final builder = MqttClientPayloadBuilder();
        builder.addString(payload);
        client.publishMessage(cmdTopic, MqttQos.atLeastOnce, builder.payload!);
        debugPrint('🏠 Widget MQTT sent: $cmdTopic = $payload');

        // Brief delay to ensure message is sent
        await Future.delayed(const Duration(milliseconds: 300));
        client.disconnect();
      }
    } catch (e) {
      debugPrint('⚠️ Widget MQTT error: $e');
      // Store as pending for when app opens
      await HomeWidget.saveWidgetData('pending_toggle_device', deviceId);
      await HomeWidget.saveWidgetData('pending_toggle_state',
          uri.queryParameters['state'] ?? uri.queryParameters['direction'] ?? '');
    }
  }
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler to prevent unhandled Flutter errors from crashing the app
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    debugPrint('Stack: ${details.stack}');
  };

  // Custom error widget — show a retry screen instead of grey/blank screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFFF3B30)),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exceptionAsString(),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnon);
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }

  // Initialize device state cache for instant UI feedback
  try {
    await DeviceStateCache().initialize();
  } catch (e) {
    debugPrint('DeviceStateCache init failed: $e');
  }

  // Initialize local notifications
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService init failed: $e');
  }

  // Register home widget background callback for toggle actions
  try {
    HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
  } catch (e) {
    debugPrint('HomeWidget callback registration failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => LocaleService()),
      ],
      child: const SmartHomeApp(),
    ),
  );
}

class SmartHomeApp extends StatefulWidget {
  const SmartHomeApp({super.key});

  @override
  State<SmartHomeApp> createState() => _SmartHomeAppState();
}

class _SmartHomeAppState extends State<SmartHomeApp> {
  final _lifecycleManager = AppLifecycleManager();
  final _sceneTriggerScheduler = SceneTriggerScheduler();
  final _locationTriggerMonitor = LocationTriggerMonitor();
  final _sceneCommandExecutor = SceneCommandExecutor();
  final _mqttService = EnhancedMqttService();
  final _smartHomeService = SmartHomeService();

  StreamSubscription<AuthState>? _authSubscription;
  bool _servicesStarted = false;

  @override
  void initState() {
    super.initState();

    // CRITICAL: Database persistence is DISABLED for device state
    // Database should ONLY store metadata (device name, topic, type, etc.)
    // Device state (ON/OFF, position, brightness, etc.) comes ONLY from MQTT real-time data
    _mqttService.persistRealtimeToDb = false; // Keep disabled - state is MQTT-only

    // Initialize lifecycle manager
    // Provide service singletons so lifecycle manager can trigger reconnection
    _lifecycleManager.initialize(
      mqttService: _mqttService,
      smartHomeService: _smartHomeService,
    );

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
          _handleAuthStateChanged(authState.session);
        });

    // Handle already-authenticated users on app startup
    _handleAuthStateChanged(Supabase.instance.client.auth.currentSession);
  }

  void _handleAuthStateChanged(Session? session) {
    final isAuthenticated = session != null;

    if (isAuthenticated && !_servicesStarted) {
      _sceneTriggerScheduler.start();
      _locationTriggerMonitor.start();
      _sceneCommandExecutor.start();
      _servicesStarted = true;
    } else if (!isAuthenticated && _servicesStarted) {
      _sceneTriggerScheduler.stop();
      _locationTriggerMonitor.stop();
      _sceneCommandExecutor.stop();
      _servicesStarted = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _lifecycleManager.dispose();
    _sceneTriggerScheduler.stop();
    _locationTriggerMonitor.stop();
    _sceneCommandExecutor.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeService, LocaleService>(
      builder: (context, themeService, localeService, _) {
        final isDark = themeService.isDarkMode;

        // Keep AppStrings in sync with locale service
        AppStrings.setLocale(localeService.locale);

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        );

        // Enable edge-to-edge mode
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

        return MaterialApp(
          title: 'HBOT',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeService.themeMode,
          locale: localeService.isArabic ? const Locale('ar') : const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        );
      },
    );
  }
}

