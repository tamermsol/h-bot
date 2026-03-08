import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'env.dart';
import 'screens/auth_wrapper.dart';
import 'theme/app_theme.dart';
import 'services/app_lifecycle_manager.dart';
import 'services/enhanced_mqtt_service.dart';
import 'services/smart_home_service.dart';
import 'services/scene_trigger_scheduler.dart';
import 'services/location_trigger_monitor.dart';
import 'services/device_state_cache.dart';
import 'services/scene_command_executor.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnon);

  // Initialize device state cache for instant UI feedback
  await DeviceStateCache().initialize();

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
    final themeService = Provider.of<ThemeService>(context);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeService.isDarkMode
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: themeService.isDarkMode
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    // Enable edge-to-edge mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return MaterialApp(
      title: 'HBOT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode,
      home: const AuthWrapper(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
