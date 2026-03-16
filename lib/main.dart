import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'services/notification_service.dart';

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
        'y3ae1177.ala.eu-central-1.emqxsl.com',
        'hbot-widget-${DateTime.now().millisecondsSinceEpoch}',
      );
      client.port = 8883;
      client.secure = true;
      client.keepAlivePeriod = 10;
      client.connectTimeoutPeriod = 5000;
      client.securityContext = SecurityContext()
        ..setTrustedCertificatesBytes(utf8.encode(_emqxCaCert));

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

// EMQX Cloud CA certificate for TLS connections from widget background
const String _emqxCaCert = '''
-----BEGIN CERTIFICATE-----
MIIDrzCCApegAwIBAgIQCDvgVpBCRrGhdWrJWZHHSjANBgkqhkiG9w0BAQUFADBh
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBD
QTAeFw0wNjExMTAwMDAwMDBaFw0zMTExMTAwMDAwMDBaMGExCzAJBgNVBAYTAlVT
MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
b20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IENBMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4jvhEXLeqKTTo1eqUKKPC3eQyaKl7hLOllsB
CSDMAZOnTjC3U/dDxGkAV53ijSLdhwZAAIEJzs4bg7/fzTtxRuLWZscFs3YnFo97
nh6Vfe63SKMI2tavegw5BmV/Sl0fvBf4q77uKNd0f3p4mVmFaG5cIzJLv07A6Fpt
43C/dxC//AH2hdmoRBBYMql1GNXRor5H4idq9Joz+EkIYIvUX7Q6hL+hqkpMfT7P
T19sdl6gSzeRntwi5m3OFBqOasv+zbMUZBfHWymeMr/y7vrTC0LUq7dBMtoM1O/4
gdW7jVg/tRvoSSiicNoxBN33shbyTApOB6jtSj1etX+jkMOvJwIDAQABo2MwYTAO
BgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUA95QNVbR
TLtm8KPiGxvDl7I90VUwHwYDVR0jBBgwFoAUA95QNVbRTLtm8KPiGxvDl7I90VUw
DQYJKoZIhvcNAQEFBQADggEBAMucN6pIExIK+t1EnE9SsPTfrgT1eXkIoyQY/Esr
hMAtudXH/vTBH1jLuG2cenTnmCmrEbXjcKChzUyImZOMkXDiqw8cvpOp/2PV5Adg
06O/nVsJ8dWO41P0jmP6P6fbtGbfYmbW0W5BjfIttep3Sp+dWOIrWcBAI+0tKIJF
PnlUkiaY4IBIqDfv8NZ5YBberOgOzW6sRBc4L0na4UU+Krk2U886UAb3LujEV0ls
YSEY1QSteDwsOoBrp+uvFRTp2InBuThs4pFsiv9kuXclVzDAGySj4dzp30d8tbQk
CAUw7C29C79Fv1C5qfPrmAESrciIxpg0X40KPMbp1ZWVbd4=
-----END CERTIFICATE-----''';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnon);

  // Initialize device state cache for instant UI feedback
  await DeviceStateCache().initialize();

  // Initialize local notifications
  await NotificationService().initialize();

  // Register home widget background callback for toggle actions
  HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
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
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        final isDark = themeService.isDarkMode;
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
          home: const SplashScreen(),
        );
      },
    );
  }
}

