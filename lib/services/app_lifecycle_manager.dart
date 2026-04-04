import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'enhanced_mqtt_service.dart';
import 'smart_home_service.dart';
import 'scene_trigger_scheduler.dart';
// import 'panel_mqtt_service.dart';  // Hidden until production-ready
// import '../repos/panels_repo.dart';  // Hidden until production-ready

/// Manages app lifecycle events and handles background/foreground transitions
/// Ensures MQTT connections and real-time subscriptions are properly maintained
class AppLifecycleManager with WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();
  factory AppLifecycleManager() => _instance;
  AppLifecycleManager._internal();

  bool _isInitialized = false;
  AppLifecycleState? _lastLifecycleState;
  DateTime? _backgroundTime;

  // Services that need lifecycle management
  EnhancedMqttService? _mqttService;
  SmartHomeService? _smartHomeService;
  SceneTriggerScheduler? _sceneTriggerScheduler;

  // Panel MQTT integration — hidden until production-ready
  // bool _panelMqttInitialized = false;

  // Configuration
  static const Duration _backgroundThreshold = Duration(minutes: 2);
  static const Duration _reconnectionDelay = Duration(seconds: 3);

  /// Initialize the lifecycle manager
  void initialize({
    EnhancedMqttService? mqttService,
    SmartHomeService? smartHomeService,
    SceneTriggerScheduler? sceneTriggerScheduler,
  }) {
    if (_isInitialized) return;

    _mqttService = mqttService;
    _smartHomeService = smartHomeService;
    _sceneTriggerScheduler = sceneTriggerScheduler;

    // Register as lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    // Start scene trigger scheduler if provided
    if (_sceneTriggerScheduler != null) {
      _sceneTriggerScheduler!.start();
      debugPrint('⏰ Scene Trigger Scheduler started');
    }

    // Panel MQTT — hidden until production-ready
    // _initPanelMqtt();

    debugPrint('🔄 App Lifecycle Manager initialized');
  }

  /// Clean up the lifecycle manager
  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
      debugPrint('🔄 App Lifecycle Manager disposed');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    debugPrint('🔄 App lifecycle state changed: ${state.name}');

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }

    _lastLifecycleState = state;
  }

  /// Handle app resumed (foreground)
  void _handleAppResumed() async {
    debugPrint('📱 App resumed - checking connections...');

    try {
      // Check if we were in background for a significant time
      final wasInBackgroundLong =
          _backgroundTime != null &&
          DateTime.now().difference(_backgroundTime!) > _backgroundThreshold;

      if (wasInBackgroundLong) {
        debugPrint(
          '⏰ App was in background for ${DateTime.now().difference(_backgroundTime!).inMinutes} minutes',
        );
        // Full reconnection already includes device state refresh
        await _performFullReconnection();
      } else {
        // Quick connection health check
        await _performHealthCheck();

        // CRITICAL: Always refresh device states when app resumes
        // This ensures we get the current real position from MQTT, even if the
        // device was controlled manually (physical switches) while app was closed
        debugPrint('🔄 Refreshing device states after app resume...');
        await _refreshDeviceStates();
      }

      _backgroundTime = null;
    } catch (e) {
      debugPrint('❌ Error handling app resume: $e');
    }
  }

  /// Handle app paused (background)
  void _handleAppPaused() {
    debugPrint('📱 App paused - marking background time');
    _backgroundTime = DateTime.now();

    // Optionally reduce MQTT keep-alive frequency to conserve battery
    _optimizeForBackground();
  }

  /// Handle app inactive (transitioning)
  void _handleAppInactive() {
    debugPrint('📱 App inactive');
    // App is transitioning between states, don't take action yet
  }

  /// Handle app detached (terminated)
  void _handleAppDetached() {
    debugPrint('📱 App detached - cleaning up connections');
    _cleanupConnections();
  }

  /// Handle app hidden (iOS specific)
  void _handleAppHidden() {
    debugPrint('📱 App hidden');
    _backgroundTime = DateTime.now();
  }

  /// Perform full reconnection after extended background time
  Future<void> _performFullReconnection() async {
    debugPrint('🔄 Performing full reconnection...');

    try {
      // Ensure MQTT service is initialized with current user if possible
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null && _mqttService != null) {
          await _mqttService!.initialize(user.id);
          debugPrint('🔑 MQTT service initialized for user: ${user.id}');
        }
      } catch (e) {
        debugPrint('⚠️ Could not initialize MQTT service from auth: $e');
      }
      // 1. Check MQTT connection health
      if (_mqttService != null) {
        final isHealthy = _mqttService!.isHealthy;
        debugPrint(
          '🔌 MQTT health check: ${isHealthy ? 'healthy' : 'unhealthy'}',
        );

        if (!isHealthy) {
          debugPrint('🔄 Reconnecting MQTT...');

          // Add delay to allow network to stabilize
          await Future.delayed(_reconnectionDelay);

          // Use force reconnection with device re-registration
          final reconnected = await _mqttService!.forceReconnectWithDevices();
          debugPrint(
            '🔌 MQTT reconnection: ${reconnected ? 'success' : 'failed'}',
          );
        }
      }

      // 2. Panel MQTT re-subscribe — hidden until production-ready
      // _panelMqttInitialized = false;
      // _initPanelMqtt();

      // 3. Check Supabase real-time connections
      await _checkSupabaseConnections();

      // 4. Refresh device states
      await _refreshDeviceStates();

      debugPrint('✅ Full reconnection completed');
    } catch (e) {
      debugPrint('❌ Error during full reconnection: $e');
    }
  }

  /// Perform quick health check
  Future<void> _performHealthCheck() async {
    debugPrint('🔍 Performing quick health check...');

    try {
      // Quick MQTT health check
      if (_mqttService != null && !_mqttService!.isHealthy) {
        debugPrint('⚠️ MQTT connection unhealthy, attempting reconnection...');
        await _mqttService!.reconnect();
      }

      debugPrint('✅ Health check completed');
    } catch (e) {
      debugPrint('❌ Error during health check: $e');
    }
  }

  /// Optimize connections for background operation
  void _optimizeForBackground() {
    debugPrint('🔋 Optimizing for background operation...');

    // Note: MQTT keep-alive optimization could be implemented here
    // For now, we rely on the OS to manage background network activity
  }

  /// Clean up connections when app is terminated
  void _cleanupConnections() {
    debugPrint('🧹 Cleaning up connections...');

    try {
      _mqttService?.disconnect();
    } catch (e) {
      debugPrint('❌ Error cleaning up connections: $e');
    }
  }

  // Panel MQTT initialization — hidden until production-ready
  // Future<void> _initPanelMqtt() async { ... }

  /// Check and restore Supabase real-time connections
  Future<void> _checkSupabaseConnections() async {
    debugPrint('📡 Checking Supabase connections...');

    try {
      // Check if Supabase client is still connected
      final client = Supabase.instance.client;

      // Test connection with a simple query
      await client
          .from('devices')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));

      debugPrint('✅ Supabase connection healthy');
    } catch (e) {
      debugPrint('⚠️ Supabase connection issue: $e');
      // Supabase should auto-reconnect, but we can trigger a refresh if needed
    }
  }

  /// Refresh device states after reconnection
  Future<void> _refreshDeviceStates() async {
    debugPrint('🔄 Refreshing device states...');

    try {
      if (_smartHomeService != null) {
        await _smartHomeService!.refreshAllDeviceStates();
      }
    } catch (e) {
      debugPrint('❌ Error refreshing device states: $e');
    }
  }

  /// Get current lifecycle state
  AppLifecycleState? get currentState => _lastLifecycleState;

  /// Check if app was recently in background
  bool get wasRecentlyInBackground {
    return _backgroundTime != null &&
        DateTime.now().difference(_backgroundTime!) < _backgroundThreshold;
  }

  /// Get time spent in background
  Duration? get backgroundDuration {
    return _backgroundTime != null
        ? DateTime.now().difference(_backgroundTime!)
        : null;
  }
}
