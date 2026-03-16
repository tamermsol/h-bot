import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnon);

  // Initialize device state cache for instant UI feedback
  await DeviceStateCache().initialize();

  // Initialize local notifications
  await NotificationService().initialize();

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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Enable edge-to-edge mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return MaterialApp(
      title: 'HBOT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}

