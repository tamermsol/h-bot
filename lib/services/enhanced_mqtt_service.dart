import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device.dart';
import '../utils/mqtt_debug_helper.dart';
import 'device_state_cache.dart';
// repo import removed: devices case-discovery persistence disabled

/// Connection error types for better error handling
enum ConnectionErrorType {
  sslError,
  timeout,
  networkError,
  authError,
  connectionRefused,
  unknown,
}

/// Recovery strategy for different error types
class RecoveryStrategy {
  final bool shouldRetry;
  final int maxRetries;
  final Duration baseDelay;
  final bool requiresNetworkCheck;

  const RecoveryStrategy({
    required this.shouldRetry,
    required this.maxRetries,
    required this.baseDelay,
    required this.requiresNetworkCheck,
  });
}

/// Represents a queued MQTT command
class _QueuedCommand {
  final String topic;
  final String payload;
  final MqttQos qos;
  final bool retain;
  final DateTime timestamp;
  final int priority; // Lower number = higher priority

  _QueuedCommand({
    required this.topic,
    required this.payload,
    required this.priority,
    this.qos = MqttQos.atLeastOnce,
    this.retain = false,
  }) : timestamp = DateTime.now();
}

/// Enhanced MQTT service with TLS support for device control
class EnhancedMqttService {
  static const String _brokerHost = 'y3ae1177.ala.eu-central-1.emqxsl.com';
  static const int _brokerPort = 8883;
  static const String _username = 'admin';
  static const String _password = 'P@ssword1';

  MqttServerClient? _client;
  String? _clientId;
  String? _userId;

  // Connection state
  MqttConnectionState _connectionState = MqttConnectionState.disconnected;
  final StreamController<MqttConnectionState> _connectionStateController =
      StreamController<MqttConnectionState>.broadcast();

  // Device management
  final Map<String, Device> _registeredDevices = {};
  final Map<String, StreamController<Map<String, dynamic>>>
  _deviceStateControllers = {};
  final Map<String, Map<String, dynamic>> _deviceStates = {};

  // Persistent cache for instant UI feedback on app startup
  final DeviceStateCache _stateCache = DeviceStateCache();

  // Message handling
  final StreamController<MqttReceivedMessage<MqttMessage>> _messageController =
      StreamController<MqttReceivedMessage<MqttMessage>>.broadcast();

  // Optimized message throttling and debouncing for better responsiveness
  final Map<String, Timer> _commandThrottleTimers = {};
  final Map<String, Timer> _stateRequestTimers = {};
  static const Duration _commandThrottleDelay = Duration(
    milliseconds: 10,
  ); // Reduced from 50ms
  static const Duration _stateRequestDelay = Duration(
    milliseconds: 20,
  ); // Reduced from 100ms
  static const Duration _connectionTimeout = Duration(seconds: 15);
  static const Duration _commandTimeout = Duration(seconds: 5);

  // Retained message handling
  final Map<String, DateTime> _lastMessageTimestamps = {};
  final Set<String> _processedRetainedTopics = {};
  DateTime? _connectionTimestamp;

  // Per-device health tracking
  final Map<String, DateTime> _deviceLastSeen =
      {}; // last telemetry/result/STATE time
  final Map<String, String> _deviceLWT = {}; // 'online' or 'offline'
  final Map<String, DateTime> _deviceLWTTimestamp = {};
  // Last ping result (internet reachability) tracking
  final Map<String, DateTime> _deviceLastPing = {};
  final Map<String, bool?> _deviceLastPingReachable =
      {}; // null = ack only / unknown
  final Map<String, Completer<bool>> _pendingProbes = {};
  Timer? _deviceHealthMonitorTimer;
  static const Duration _deviceHealthCheckInterval = Duration(
    seconds: 5,
  ); // Check every 5 seconds for very fast offline detection
  // Telemetry timing estimation (per-device)
  final Map<String, DateTime> _deviceLastTelemetry = {};
  final Map<String, Duration> _deviceTelemetryPeriod = {};

  // Track devices waiting for initial state from physical Tasmota device
  // This enables "fetch-first" approach where UI waits for real device state
  final Set<String> _devicesWaitingForInitialState = {};
  final Map<String, Completer<void>> _initialStateCompleters = {};

  // Subscription tracking
  final Set<String> _activeSubscriptions = {};

  // We no longer attempt case-variant SUBSCRIBE or temporary probe subscribes.
  // Each device must provide the exact canonical topic base (stored in
  // device.tasmotaTopicBase) and we will use that exact string for all
  // subscribes and publishes. SUBACK failures are treated as permission/ACL
  // errors and are not retried with alternate casing.

  // Recent publishes tracking to filter out broker-echoes of our own publishes.
  // Key: "<topic>|<payload>" -> timestamp
  final Map<String, DateTime> _recentPublishes = {};

  // Periodic state polling for real-time synchronization with dynamic intervals
  final Map<String, Timer> _statePollingTimers = {};

  // Dynamic polling interval based on device count for better performance
  Duration get _statePollingInterval {
    final deviceCount = _registeredDevices.length;
    if (deviceCount <= 1) {
      return const Duration(
        seconds: 10,
      ); // Single device - frequent polling (reduced from 30s)
    } else if (deviceCount <= 5) {
      return const Duration(
        seconds: 20,
      ); // Few devices - moderate polling (reduced from 1min)
    } else {
      return const Duration(
        seconds: 30,
      ); // Many devices - reduced polling (reduced from 2min)
    }
  }

  // Command queuing with batching support
  final Map<String, List<_QueuedCommand>> _commandQueues = {};
  final Map<String, bool> _processingQueues = {};

  // Message batching for performance optimization
  final List<Map<String, dynamic>> _pendingStatePersistence = [];
  Timer? _statePersistenceBatchTimer;

  // Debug logging
  final List<String> _debugMessages = [];
  final StreamController<String> _debugController =
      StreamController<String>.broadcast();

  // Connection monitoring and automatic reconnection
  Timer? _connectionMonitorTimer;
  Timer? _reconnectionTimer;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 5;
  static const Duration _connectionMonitorInterval = Duration(seconds: 30);
  static const Duration _baseReconnectionDelay = Duration(seconds: 2);
  DateTime? _lastSuccessfulConnection;
  DateTime? _lastConnectionAttempt;
  bool _isReconnecting = false;
  ConnectionErrorType? _lastErrorType;
  RecoveryStrategy? _currentRecoveryStrategy;

  // Network connectivity monitoring
  bool _hasNetworkConnectivity = true;
  // When true, only persist 'online' = true to DB when Ping-derived online is true.
  // This prevents physical power-only indications from marking DB online.
  // (Previously used for Ping-based probing; retained for future toggles.)
  // final bool _requirePingForPersistence = true;
  StreamSubscription? _connectivitySubscription;
  final bool _networkChangeDetectionEnabled = true;

  // Singleton pattern
  static final EnhancedMqttService _instance = EnhancedMqttService._internal();
  factory EnhancedMqttService() => _instance;
  EnhancedMqttService._internal();

  /// When true, the service will persist realtime device states to the DB.
  /// Disabled by default to keep DB strictly for metadata unless explicit
  /// persistence is enabled by higher-level services.
  bool persistRealtimeToDb = false;

  // ------------------------
  // Test hooks (used only by unit tests)
  // ------------------------
  // Allows tests to inject a custom probe handler to simulate device responses
  Future<bool> Function(Device device)? _probeHandlerOverride;

  /// Set a custom probe handler (for tests)
  void setProbeHandlerForTests(Future<bool> Function(Device device)? handler) {
    _probeHandlerOverride = handler;
  }

  /// Test helper: set device last seen timestamp
  void setTestDeviceLastSeen(String deviceId, DateTime? ts) {
    if (ts == null) {
      _deviceLastSeen.remove(deviceId);
    } else {
      _deviceLastSeen[deviceId] = ts;
    }
  }

  /// Test helper: set device LWT value
  void setTestDeviceLWT(String deviceId, String? lwt) {
    if (lwt == null) {
      _deviceLWT.remove(deviceId);
      _deviceLWTTimestamp.remove(deviceId);
    } else {
      _deviceLWT[deviceId] = lwt;
      _deviceLWTTimestamp[deviceId] = DateTime.now();
    }
  }

  /// Test helper: evaluate device health using the internal evaluator
  /// Exposed for unit tests only.
  Future<Map<String, dynamic>> evaluateDeviceHealthForTests(
    Device device, {
    int telePeriodSeconds = 60,
    int sleepIntervalSeconds = 0,
    bool performProbe = false,
  }) async {
    return await _evaluateDeviceHealth(
      device,
      telePeriodSeconds: telePeriodSeconds,
      sleepIntervalSeconds: sleepIntervalSeconds,
      performProbe: performProbe,
    );
  }

  /// Test helper: register a device in internal maps without performing MQTT subscriptions
  void setTestRegisterDevice(Device device) {
    _registeredDevices[device.id] = device;
    _deviceStates[device.id] = {
      'online': false,
      'connected': false,
      'status': 'test-registered',
      'channels': device.channels,
      'name': device.name,
    };
    // Initialize POWER keys
    for (int i = 1; i <= device.effectiveChannels; i++) {
      _deviceStates[device.id]!['POWER$i'] = 'OFF';
    }
    // Initialize shutter states for shutter devices (test helper)
    if (device.deviceType == DeviceType.shutter) {
      for (int i = 1; i <= 4; i++) {
        _deviceStates[device.id]!['Shutter$i'] = 0;
      }
    }
  }

  /// Initialize the MQTT service with user ID
  Future<void> initialize(String userId) async {
    _userId = userId;
    _clientId = 'msol-app/$userId/${DateTime.now().millisecondsSinceEpoch}';
    _addDebugMessage('Initialized MQTT service for user: $userId');
    // Allow callers to await any future initialization steps in the future
    return;
  }

  /// Check if a device is waiting for initial state from physical Tasmota device
  bool isWaitingForInitialState(String deviceId) {
    return _devicesWaitingForInitialState.contains(deviceId);
  }

  /// Wait for initial state to be received from physical Tasmota device
  /// Returns true if state was received, false if timeout occurred
  /// Timeout defaults to 5 seconds
  Future<bool> waitForInitialState(
    String deviceId, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = _initialStateCompleters[deviceId];
    if (completer == null || completer.isCompleted) {
      // Already received or not waiting
      return true;
    }

    try {
      await completer.future.timeout(timeout);
      return true;
    } on TimeoutException {
      _addDebugMessage(
        '⚠️ Timeout waiting for initial state for device: $deviceId',
      );

      // Clean up on timeout
      _devicesWaitingForInitialState.remove(deviceId);
      _initialStateCompleters.remove(deviceId);
      _deviceStates[deviceId]?.remove('waitingForInitialState');

      return false;
    }
  }

  /// Get connection state stream
  Stream<MqttConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// Get current connection state
  MqttConnectionState get connectionState => _connectionState;

  /// Get debug messages stream
  Stream<String> get debugStream => _debugController.stream;

  /// Get recent debug messages
  List<String> get recentDebugMessages => _debugMessages.take(50).toList();

  /// Connect to MQTT broker with TLS
  Future<bool> connect() async {
    if (kIsWeb) {
      _addDebugMessage('MQTT not supported on web - connect() skipped');
      return false;
    }

    // If we're already connecting, wait for that to complete
    if (_connectionState == MqttConnectionState.connecting) {
      _addDebugMessage('Already attempting to connect, waiting...');
      await Future.delayed(const Duration(seconds: 2));
      return _connectionState == MqttConnectionState.connected;
    }

    // If already connected, return true
    if (_connectionState == MqttConnectionState.connected) {
      return true;
    }

    // Check initialization
    if (_userId == null || _clientId == null) {
      _addDebugMessage('MQTT service not initialized');
      throw Exception('MQTT service not initialized. Call initialize() first.');
    }

    // Reset client if it exists
    _client?.disconnect();
    _client = null;

    try {
      _setConnectionState(MqttConnectionState.connecting);
      _addDebugMessage('Connecting to MQTT broker: $_brokerHost:$_brokerPort');

      _client = MqttServerClient(_brokerHost, _clientId!);

      // Configure client with settings requested for stable persistent sessions
      _client!.port = _brokerPort;
      _client!.secure = true;
      _client!.keepAlivePeriod = 60; // User requested 60s keepalive
      _client!.connectTimeoutPeriod = _connectionTimeout.inMilliseconds;
      _client!.autoReconnect = true; // enable automatic reconnect
      _client!.resubscribeOnAutoReconnect = true; // resubscribe on reconnect
      _client!.logging(on: kDebugMode); // Only log in debug mode

      // Set up event handlers
      _client!.onAutoReconnect = _onAutoReconnect;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.onUnsubscribed = _onUnsubscribed;
      _client!.onAutoReconnect = _onAutoReconnect;

      // Setup ping handling
      _client!.pongCallback = () {
        _addDebugMessage('Ping response received - connection alive');
        _updateAllDevicesOnline();
      };

      // Use MQTT v3.1.1
      _client!.setProtocolV311();

      // Set up TLS context with CA certificate
      if (!kIsWeb) {
        try {
          final context = SecurityContext();
          final caCertData = await rootBundle.load('assets/ca.crt');
          context.setTrustedCertificatesBytes(caCertData.buffer.asUint8List());
          _client!.securityContext = context;
          _addDebugMessage('TLS context configured with CA certificate');
        } catch (e) {
          _addDebugMessage('Error setting up TLS: $e');
          // Continue without custom CA cert - use system defaults
        }
      }

      // Allow self-signed certificates for testing (remove in production)
      _client!.onBadCertificate = (dynamic certificate) {
        _addDebugMessage('Warning: Accepting bad certificate for testing');
        return true;
      };

      // Event handlers are already set above, no need to duplicate

      // Message handler will be set up after successful connection

      // Create connection message with authentication and last will
      _addDebugMessage('Creating connection message with clientId: $_clientId');

      if (_clientId == null) {
        _addDebugMessage('ERROR: Client ID is null!');
        _setConnectionState(MqttConnectionState.disconnected);
        return false;
      }

      final willTopic = 'client/$_clientId/status';
      final willMessage = 'offline';
      // Build connection message. We intentionally do NOT call startClean()
      // so that the session is persistent (cleanSession=false) and broker
      // may retain subscriptions when supported.
      final connMess = MqttConnectMessage()
          .withClientIdentifier(_clientId!)
          .authenticateAs(_username, _password)
          .withWillQos(MqttQos.atLeastOnce)
          .withWillMessage(willMessage)
          .withWillTopic(willTopic);

      _addDebugMessage('MQTT client connecting with credentials: $_username');
      _client!.connectionMessage = connMess;

      try {
        await _client!.connect();
      } catch (e) {
        _addDebugMessage('Exception during connect: $e');
        _setConnectionState(MqttConnectionState.disconnected);
        return false;
      }

      if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
        _setConnectionState(MqttConnectionState.connected);
        _addDebugMessage('MQTT client connected');

        // Set up message handler after successful connection
        _client!.updates?.listen(_onMessage);

        // Resubscribe to all devices
        await _resubscribeAllDevices();

        // Start automatic connection monitoring
        _startConnectionMonitoring();

        // Reset reconnection attempts on successful connection
        _reconnectionAttempts = 0;
        _lastSuccessfulConnection = DateTime.now();

        return true;
      } else {
        _addDebugMessage(
          'ERROR: MQTT client connection failed - disconnecting, status is ${_client?.connectionStatus}',
        );
        _client?.disconnect();
        _setConnectionState(MqttConnectionState.disconnected);
        return false;
      }
    } catch (e, stackTrace) {
      _setConnectionState(MqttConnectionState.faulted);
      _addDebugMessage('Connection error: $e\nStack trace: $stackTrace');

      // Analyze error type for better handling
      final errorType = _analyzeConnectionError(e);
      final strategy = _getRecoveryStrategy(errorType);

      _addDebugMessage(
        'Error type: $errorType, Recovery strategy: ${strategy.shouldRetry ? "retry" : "no retry"}',
      );

      if (errorType == ConnectionErrorType.sslError) {
        _addDebugMessage('SSL/TLS error detected. CA cert path: assets/ca.crt');
      } else if (errorType == ConnectionErrorType.authError) {
        _addDebugMessage('Authentication error - check credentials');
      } else if (errorType == ConnectionErrorType.networkError) {
        _addDebugMessage('Network error - check connectivity');
      }

      return false;
    }
  }

  /// Disconnect from MQTT broker
  Future<void> disconnect() async {
    try {
      _addDebugMessage('Disconnecting from MQTT broker');

      // Stop connection monitoring
      _stopConnectionMonitoring();

      _client?.disconnect();
      _setConnectionState(MqttConnectionState.disconnected);
    } catch (e) {
      _addDebugMessage('Disconnect error: $e');
    }
  }

  /// Reconnect to MQTT broker (manual reconnection)
  Future<bool> reconnect() async {
    _addDebugMessage('Manual reconnection requested');

    // Stop automatic reconnection attempts
    _stopConnectionMonitoring();

    // Disconnect first if connected
    if (_connectionState == MqttConnectionState.connected) {
      await disconnect();
      await Future.delayed(const Duration(seconds: 2));
    }

    // Attempt to reconnect
    final connected = await connect();

    if (connected) {
      // Reset reconnection attempts on successful manual reconnection
      _reconnectionAttempts = 0;
    }

    return connected;
  }

  /// Check if MQTT connection is healthy
  bool get isHealthy {
    return _connectionState == MqttConnectionState.connected &&
        _client?.connectionStatus?.state == MqttConnectionState.connected;
  }

  /// Whether the MQTT client is currently connected
  bool get isConnected => _connectionState == MqttConnectionState.connected;

  /// Publish a retained message to a topic (for panel config, status, etc.)
  Future<void> publishRetained(String topic, String payload) async {
    await _publishMessage(topic, payload, retain: true);
  }

  /// Force reconnection with full device re-registration (for app lifecycle)
  Future<bool> forceReconnectWithDevices() async {
    _addDebugMessage(
      '🔄 Force reconnection with device re-registration requested',
    );

    try {
      // Disconnect first
      await disconnect();
      await Future.delayed(const Duration(seconds: 2));

      // Reconnect
      final connected = await connect();

      if (connected) {
        // Re-register all devices
        await _resubscribeAllDevices();

        // Request fresh state for all devices in parallel for faster reconnection
        await Future.wait(
          _registeredDevices.values.map((device) async {
            try {
              await _requestDeviceState(device);
            } catch (e) {
              _addDebugMessage('Error requesting state for ${device.name}: $e');
            }
          }),
        );

        _addDebugMessage(
          '✅ Force reconnection with devices completed successfully',
        );
      } else {
        _addDebugMessage('❌ Force reconnection failed');
      }

      return connected;
    } catch (e) {
      _addDebugMessage('❌ Error during force reconnection: $e');
      return false;
    }
  }

  /// Start automatic connection monitoring
  void _startConnectionMonitoring() {
    _stopConnectionMonitoring(); // Stop any existing monitoring

    _connectionMonitorTimer = Timer.periodic(_connectionMonitorInterval, (
      timer,
    ) {
      _performConnectionHealthCheck();
    });

    // Start periodic per-device health checks
    _deviceHealthMonitorTimer = Timer.periodic(_deviceHealthCheckInterval, (_) {
      _checkAllDevicesHealth();
    });

    // Start network change detection if enabled
    if (_networkChangeDetectionEnabled) {
      _startNetworkChangeDetection();
    }

    _addDebugMessage('🔍 Started automatic connection monitoring');
  }

  /// Stop automatic connection monitoring
  void _stopConnectionMonitoring() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = null;
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
    // Stop per-device health monitor
    _deviceHealthMonitorTimer?.cancel();
    _deviceHealthMonitorTimer = null;

    // Complete any pending probes as false (cleanup)
    for (final entry in _pendingProbes.entries) {
      final c = entry.value;
      try {
        if (!c.isCompleted) c.complete(false);
      } catch (_) {}
    }
    _pendingProbes.clear();

    // Stop network change detection
    _stopNetworkChangeDetection();
  }

  /// Start network change detection
  void _startNetworkChangeDetection() {
    if (!kIsWeb) {
      try {
        // Note: This would require connectivity_plus package
        // For now, we'll implement a simple periodic network check
        _addDebugMessage(
          '🌐 Network change detection started (periodic check mode)',
        );
      } catch (e) {
        _addDebugMessage('❌ Failed to start network change detection: $e');
      }
    }
  }

  /// Stop network change detection
  void _stopNetworkChangeDetection() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Perform connection health check and trigger reconnection if needed
  Future<void> _performConnectionHealthCheck() async {
    if (_isReconnecting) {
      _addDebugMessage(
        '⏳ Reconnection already in progress, skipping health check',
      );
      return;
    }

    try {
      // Check if connection is healthy
      if (!isHealthy) {
        _addDebugMessage(
          '⚠️ Connection health check failed - triggering automatic reconnection',
        );
        await _attemptAutomaticReconnection();
      } else {
        // Connection is healthy, reset reconnection attempts
        if (_reconnectionAttempts > 0) {
          _addDebugMessage(
            '✅ Connection restored, resetting reconnection attempts',
          );
          _reconnectionAttempts = 0;
        }
        _lastSuccessfulConnection = DateTime.now();
      }
    } catch (e) {
      _addDebugMessage('❌ Error during connection health check: $e');
    }
  }

  /// Attempt automatic reconnection with exponential backoff
  Future<void> _attemptAutomaticReconnection() async {
    if (_isReconnecting) {
      _addDebugMessage('⏳ Reconnection already in progress');
      return;
    }

    // Use error-specific recovery strategy if available
    final maxAttempts =
        _currentRecoveryStrategy?.maxRetries ?? _maxReconnectionAttempts;

    if (_reconnectionAttempts >= maxAttempts) {
      _addDebugMessage(
        '❌ Maximum reconnection attempts reached ($maxAttempts), stopping automatic reconnection',
      );
      return;
    }

    _isReconnecting = true;
    _reconnectionAttempts++;
    _lastConnectionAttempt = DateTime.now();

    // Calculate delay based on recovery strategy or use exponential backoff
    Duration delay;
    if (_currentRecoveryStrategy != null) {
      delay = Duration(
        seconds:
            _currentRecoveryStrategy!.baseDelay.inSeconds *
            _reconnectionAttempts,
      );
    } else {
      delay = Duration(
        seconds:
            _baseReconnectionDelay.inSeconds *
            (1 << (_reconnectionAttempts - 1)),
      );
    }

    _addDebugMessage(
      '🔄 Automatic reconnection attempt $_reconnectionAttempts/$maxAttempts (delay: ${delay.inSeconds}s)',
    );

    try {
      // Wait for backoff delay
      await Future.delayed(delay);

      // Check network connectivity if required by strategy
      if (_currentRecoveryStrategy?.requiresNetworkCheck ?? true) {
        if (!await _checkNetworkConnectivity()) {
          _addDebugMessage(
            '❌ No network connectivity, postponing reconnection',
          );
          _isReconnecting = false;
          return;
        }
      }

      // Attempt reconnection
      final connected = await forceReconnectWithDevices();

      if (connected) {
        _addDebugMessage('✅ Automatic reconnection successful');
        _reconnectionAttempts = 0;
        _lastSuccessfulConnection = DateTime.now();
        _lastErrorType = null;
        _currentRecoveryStrategy = null;
      } else {
        _addDebugMessage('❌ Automatic reconnection failed');
        // Schedule next attempt
        _scheduleNextReconnectionAttempt();
      }
    } catch (e) {
      _addDebugMessage('❌ Error during automatic reconnection: $e');

      // Analyze the new error and update recovery strategy
      _lastErrorType = _analyzeConnectionError(e);
      _currentRecoveryStrategy = _getRecoveryStrategy(_lastErrorType!);

      _addDebugMessage(
        'Updated recovery strategy based on error: $_lastErrorType',
      );

      _scheduleNextReconnectionAttempt();
    } finally {
      _isReconnecting = false;
    }
  }

  /// Schedule next reconnection attempt
  void _scheduleNextReconnectionAttempt() {
    if (_reconnectionAttempts < _maxReconnectionAttempts) {
      final nextDelay = Duration(
        seconds:
            _baseReconnectionDelay.inSeconds * (1 << _reconnectionAttempts),
      );

      _addDebugMessage(
        '⏰ Scheduling next reconnection attempt in ${nextDelay.inSeconds}s',
      );

      _reconnectionTimer = Timer(nextDelay, () {
        _attemptAutomaticReconnection();
      });
    }
  }

  /// Check network connectivity
  Future<bool> _checkNetworkConnectivity() async {
    try {
      // Simple connectivity check
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      _hasNetworkConnectivity = result.isNotEmpty;
      return _hasNetworkConnectivity;
    } catch (e) {
      _hasNetworkConnectivity = false;
      _addDebugMessage('❌ Network connectivity check failed: $e');
      return false;
    }
  }

  /// Analyze connection error and determine appropriate recovery strategy
  ConnectionErrorType _analyzeConnectionError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('handshakefailed') ||
        errorString.contains('certificate') ||
        errorString.contains('ssl') ||
        errorString.contains('tls')) {
      return ConnectionErrorType.sslError;
    } else if (errorString.contains('timeout') ||
        errorString.contains('connection timeout')) {
      return ConnectionErrorType.timeout;
    } else if (errorString.contains('network') ||
        errorString.contains('unreachable') ||
        errorString.contains('no route')) {
      return ConnectionErrorType.networkError;
    } else if (errorString.contains('authentication') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden')) {
      return ConnectionErrorType.authError;
    } else if (errorString.contains('refused') ||
        errorString.contains('connection refused')) {
      return ConnectionErrorType.connectionRefused;
    } else {
      return ConnectionErrorType.unknown;
    }
  }

  /// Get recovery strategy based on error type
  RecoveryStrategy _getRecoveryStrategy(ConnectionErrorType errorType) {
    switch (errorType) {
      case ConnectionErrorType.sslError:
        return RecoveryStrategy(
          shouldRetry: true,
          maxRetries: 3,
          baseDelay: const Duration(seconds: 5),
          requiresNetworkCheck: false,
        );
      case ConnectionErrorType.timeout:
        return RecoveryStrategy(
          shouldRetry: true,
          maxRetries: 5,
          baseDelay: const Duration(seconds: 2),
          requiresNetworkCheck: true,
        );
      case ConnectionErrorType.networkError:
        return RecoveryStrategy(
          shouldRetry: true,
          maxRetries: 10,
          baseDelay: const Duration(seconds: 5),
          requiresNetworkCheck: true,
        );
      case ConnectionErrorType.authError:
        return RecoveryStrategy(
          shouldRetry: false,
          maxRetries: 0,
          baseDelay: Duration.zero,
          requiresNetworkCheck: false,
        );
      case ConnectionErrorType.connectionRefused:
        return RecoveryStrategy(
          shouldRetry: true,
          maxRetries: 3,
          baseDelay: const Duration(seconds: 10),
          requiresNetworkCheck: true,
        );
      case ConnectionErrorType.unknown:
        return RecoveryStrategy(
          shouldRetry: true,
          maxRetries: 3,
          baseDelay: const Duration(seconds: 3),
          requiresNetworkCheck: true,
        );
    }
  }

  /// Get connection status for debugging
  String get connectionStatusDebug {
    return 'State: $_connectionState, Client: ${_client?.connectionStatus?.state}, '
        'Broker: $_brokerHost:$_brokerPort, User: $_username';
  }

  /// Get detailed connection statistics for debugging
  Map<String, dynamic> get connectionStats {
    return {
      'connection_state': _connectionState.toString(),
      'client_state': _client?.connectionStatus?.state.toString(),
      'reconnection_attempts': _reconnectionAttempts,
      'max_reconnection_attempts': _maxReconnectionAttempts,
      'is_reconnecting': _isReconnecting,
      'has_network_connectivity': _hasNetworkConnectivity,
      'last_successful_connection': _lastSuccessfulConnection
          ?.toIso8601String(),
      'last_connection_attempt': _lastConnectionAttempt?.toIso8601String(),
      'monitoring_active': _connectionMonitorTimer?.isActive ?? false,
      'registered_devices': _registeredDevices.length,
      'active_subscriptions': _activeSubscriptions.length,
      'last_error_type': _lastErrorType?.toString(),
      'current_recovery_strategy': _currentRecoveryStrategy != null
          ? {
              'should_retry': _currentRecoveryStrategy!.shouldRetry,
              'max_retries': _currentRecoveryStrategy!.maxRetries,
              'base_delay_seconds':
                  _currentRecoveryStrategy!.baseDelay.inSeconds,
              'requires_network_check':
                  _currentRecoveryStrategy!.requiresNetworkCheck,
            }
          : null,
    };
  }

  /// Perform comprehensive connection state recovery
  Future<bool> performConnectionStateRecovery() async {
    _addDebugMessage('🔄 Starting comprehensive connection state recovery');

    try {
      // 1. Check network connectivity first
      final hasNetwork = await _checkNetworkConnectivity();
      if (!hasNetwork) {
        _addDebugMessage(
          '❌ No network connectivity - cannot recover connection',
        );
        return false;
      }

      // 2. Check current connection health
      if (isHealthy) {
        _addDebugMessage('✅ Connection is already healthy');
        return true;
      }

      // 3. Stop any ongoing reconnection attempts
      _stopConnectionMonitoring();

      // 4. Reset connection state
      _reconnectionAttempts = 0;
      _lastErrorType = null;
      _currentRecoveryStrategy = null;

      // 5. Perform clean disconnect and reconnect
      await disconnect();
      await Future.delayed(const Duration(seconds: 3));

      // 6. Attempt fresh connection
      final connected = await connect();

      if (connected) {
        _addDebugMessage('✅ Connection state recovery successful');

        // 7. Verify device registrations
        await _verifyDeviceRegistrations();

        return true;
      } else {
        _addDebugMessage('❌ Connection state recovery failed');
        return false;
      }
    } catch (e) {
      _addDebugMessage('❌ Error during connection state recovery: $e');
      return false;
    }
  }

  /// Verify and restore device registrations after reconnection
  Future<void> _verifyDeviceRegistrations() async {
    _addDebugMessage('🔍 Verifying device registrations...');

    final deviceCount = _registeredDevices.length;
    if (deviceCount == 0) {
      _addDebugMessage('ℹ️ No devices registered');
      return;
    }

    int successfulRegistrations = 0;
    for (final device in _registeredDevices.values) {
      try {
        // Re-subscribe to device topics
        await _subscribeToDevice(device);

        // Request fresh device state
        await _requestDeviceState(device);

        successfulRegistrations++;
        _addDebugMessage('✅ Verified registration for device: ${device.name}');
      } catch (e) {
        _addDebugMessage(
          '❌ Failed to verify registration for device ${device.name}: $e',
        );
      }
    }

    _addDebugMessage(
      '📊 Device registration verification complete: $successfulRegistrations/$deviceCount successful',
    );
  }

  /// Handle network connectivity changes
  // ignore: unused_element
  void _onNetworkConnectivityChanged(bool hasConnectivity) {
    final previousState = _hasNetworkConnectivity;
    _hasNetworkConnectivity = hasConnectivity;

    _addDebugMessage(
      '🌐 Network connectivity changed: ${previousState ? "connected" : "disconnected"} → ${hasConnectivity ? "connected" : "disconnected"}',
    );

    if (!previousState && hasConnectivity) {
      // Network restored - attempt connection recovery
      _addDebugMessage('🔄 Network restored, attempting connection recovery');
      Future.microtask(() => performConnectionStateRecovery());
    } else if (previousState && !hasConnectivity) {
      // Network lost - mark connection as problematic
      _addDebugMessage('⚠️ Network lost, connection may be affected');
      _setConnectionState(MqttConnectionState.disconnected);
    }
  }

  /// Register a device for MQTT control
  Future<void> registerDevice(Device device) async {
    if (device.tasmotaTopicBase == null) {
      throw Exception('Device ${device.name} has no MQTT topic base');
    }

    // CRITICAL FIX FOR ISSUE 1: Check if device is already registered
    // If already registered, skip the slow initialization (especially database queries)
    // This prevents the ~2-second delay when reopening the shutter detail page
    final bool alreadyRegistered =
        _registeredDevices.containsKey(device.id) &&
        _deviceStateControllers.containsKey(device.id) &&
        _deviceStates.containsKey(device.id);

    if (alreadyRegistered) {
      _addDebugMessage(
        '⚡ Device already registered: ${device.name} - skipping slow initialization',
      );

      // Update the device reference in case it changed
      _registeredDevices[device.id] = device;

      // Request fresh state to ensure UI is up-to-date
      final stateTopic = 'cmnd/${device.tasmotaTopicBase}/STATE';
      _publishMessage(stateTopic, '').catchError((e) {
        _addDebugMessage('⚠️ State request error: $e');
      });

      return; // Skip the rest of initialization
    }

    _registeredDevices[device.id] = device;
    _addDebugMessage(
      'Registering device: ${device.name} (${device.tasmotaTopicBase}) with ${device.channels} channels',
    );

    // Generate debug information for this device
    final expectedTopics = MqttDebugHelper.generateExpectedTopics(
      device.tasmotaTopicBase!,
      device.effectiveChannels,
    );
    _addDebugMessage('Expected subscription patterns:');
    for (final pattern in expectedTopics['subscriptions']!) {
      _addDebugMessage('  - $pattern');
    }

    // Create state controller if it doesn't exist
    if (!_deviceStateControllers.containsKey(device.id)) {
      _deviceStateControllers[device.id] =
          StreamController<Map<String, dynamic>>.broadcast();
    }

    // Initialize device state. IMPORTANT: do NOT set an explicit 'online'
    // flag here. Emitting an initial 'online: false' can incorrectly override
    // the authoritative DB snapshot in UIs that merge MQTT + DB state. By
    // omitting 'online' until we have telemetry/LWT/ probe evidence, the
    // combined state merge will prefer the DB snapshot when available.
    _deviceStates[device.id] = {
      'connected': false,
      'status': 'initializing',
      'channels': device.channels,
      'name': device.name,
      'type': device.deviceType.toString(),
    };

    // CACHE-FIRST APPROACH for relay/dimmer devices
    // Load cached power states for instant display, then MQTT will update with fresh device state
    // This prevents OFF flash/flicker while ensuring we get actual device state via MQTT request
    if (device.effectiveChannels > 0 &&
        device.deviceType != DeviceType.shutter) {
      // Load cached power states for instant UI feedback (prevents OFF flash)
      // The MQTT state request below will update with actual device state
      final cachedPowerStates = await _stateCache.getAllPowerStates(device.id);

      for (int i = 1; i <= device.effectiveChannels; i++) {
        // Use cached state if available, otherwise default to 'OFF'
        final cachedState = cachedPowerStates[i] ?? 'OFF';
        _deviceStates[device.id]!['POWER$i'] = cachedState;

        if (cachedPowerStates[i] != null) {
          _addDebugMessage(
            '💡 Loaded cached power state (temporary): ${device.name} POWER$i = $cachedState - will update from device via MQTT',
          );
        } else {
          _addDebugMessage(
            'Initialized power state: ${device.name} POWER$i = OFF (no cache) - will update from device via MQTT',
          );
        }
      }
    }

    // Initialize shutter states for shutter devices
    // CRITICAL: Load from CACHE for instant display, then MQTT will update with fresh device position
    // This prevents 0% flash while ensuring we get actual device position via MQTT request
    if (device.deviceType == DeviceType.shutter) {
      // Load cached positions for instant UI feedback (prevents 0% flash)
      // The MQTT state request below will update with actual device position
      final cachedPositions = await _stateCache.getAllShutterPositions(
        device.id,
      );

      for (int i = 1; i <= 4; i++) {
        // Use cached position if available, otherwise default to 0
        final cachedPosition = cachedPositions[i] ?? 0;

        // Store as object with Direction, Target, Tilt
        _deviceStates[device.id]!['Shutter$i'] = {
          'Position': cachedPosition,
          'Direction': 0, // Assume stopped on initialization
          'Target': cachedPosition,
          'Tilt': 0,
        };

        if (cachedPositions[i] != null) {
          _addDebugMessage(
            '📦 Loaded cached shutter position (temporary): ${device.name} Shutter$i = $cachedPosition% - will update from device via MQTT',
          );
        } else {
          _addDebugMessage(
            'Initialized shutter state: ${device.name} Shutter$i = 0% (no cache) - will update from device via MQTT',
          );
        }
      }
    }

    // CACHE-FIRST: Emit initial cached state for all devices
    // This provides instant UI feedback while waiting for fresh MQTT data
    // Both shutters and lights now use cache-first approach
    if (device.deviceType == DeviceType.shutter) {
      _deviceStateControllers[device.id]?.add(_deviceStates[device.id]!);
      _addDebugMessage(
        '📤 Emitted initial cached state for shutter: ${device.name}',
      );
    } else if (device.effectiveChannels > 0) {
      _deviceStateControllers[device.id]?.add(_deviceStates[device.id]!);
      _addDebugMessage(
        '📤 Emitted initial cached state for light: ${device.name}',
      );
    }

    // Ensure MQTT connection
    if (_connectionState != MqttConnectionState.connected) {
      _addDebugMessage('Connecting to MQTT broker for device: ${device.name}');
      final connected = await connect();
      if (!connected) {
        _addDebugMessage('Failed to connect to MQTT broker');
        _deviceStates[device.id]!['status'] = 'connection failed';

        // Emit connection failure state
        _deviceStateControllers[device.id]?.add(_deviceStates[device.id]!);
        return;
      }
    }

    // Subscribe to device topics
    await _subscribeToDevice(device);

    // Request initial state - use STATE command for faster bulk retrieval
    // instead of requesting each channel individually
    final stateTopic = 'cmnd/${device.tasmotaTopicBase}/STATE';
    await _publishMessage(stateTopic, '');
    _addDebugMessage('Requested initial STATE for all channels');

    // For shutter devices, also request explicit shutter position to ensure fresh data
    if (device.deviceType == DeviceType.shutter) {
      // Request ShutterPosition1 to get current position from physical device
      // This will trigger a stat/RESULT response with actual device position
      final shutterPositionTopic =
          'cmnd/${device.tasmotaTopicBase}/ShutterPosition1';
      await _publishMessage(shutterPositionTopic, '');
      _addDebugMessage(
        '🪟 Requested fresh shutter position from device: ${device.name}',
      );
    }

    _addDebugMessage('Device registration completed: ${device.name}');

    // Configure Tasmota device for proper status reporting IMMEDIATELY
    // CRITICAL: Run configuration immediately (fire-and-forget) to ensure device
    // is ready for first control command without delay
    configureTasmotaStatusReporting(device.id).catchError((e) {
      _addDebugMessage('⚠️ Configuration error for ${device.name}: $e');
    });
  }

  /// Unregister a device
  Future<void> unregisterDevice(String deviceId) async {
    final device = _registeredDevices.remove(deviceId);
    if (device != null) {
      _addDebugMessage('Unregistering device: ${device.name}');

      // Unsubscribe from device topics
      _unsubscribeFromDevice(device);

      // Stop periodic state polling
      _stopStatePolling(deviceId);

      // Close state controller
      await _deviceStateControllers[deviceId]?.close();
      _deviceStateControllers.remove(deviceId);
      _deviceStates.remove(deviceId);

      // Clean up health tracking for this device
      _deviceLastSeen.remove(deviceId);
      _deviceLWT.remove(deviceId);
      _deviceLWTTimestamp.remove(deviceId);
      final pending = _pendingProbes.remove(deviceId);
      if (pending != null && !pending.isCompleted) {
        try {
          pending.complete(false);
        } catch (_) {}
      }

      _addDebugMessage('Device unregistered successfully: ${device.name}');
    }
  }

  /// Get device state stream
  Stream<Map<String, dynamic>>? getDeviceStateStream(String deviceId) {
    return _deviceStateControllers[deviceId]?.stream;
  }

  /// Get registered device by ID
  Device? getRegisteredDevice(String deviceId) {
    return _registeredDevices[deviceId];
  }

  /// Get current device state
  Map<String, dynamic>? getDeviceState(String deviceId) {
    return _deviceStates[deviceId];
  }

  /// Public: get the last-seen timestamp for a device (telemetry/result/STATE)
  DateTime? getDeviceLastSeen(String deviceId) => _deviceLastSeen[deviceId];

  /// Public: get the LWT availability value for a device (normalized to 'online'|'offline' or null)
  String? getDeviceAvailability(String deviceId) {
    final v = _deviceLWT[deviceId];
    if (v == null) return null;
    final norm = v.toLowerCase();
    if (norm == 'online' || norm == 'offline') return norm;
    return null;
  }

  /// Public: get the estimated telemetry period in seconds for a device, if known
  int? getTelemetryPeriodSeconds(String deviceId) =>
      _deviceTelemetryPeriod[deviceId]?.inSeconds;

  /// Get active subscriptions for debugging
  Set<String> get activeSubscriptions => Set.from(_activeSubscriptions);

  /// Get debug messages for troubleshooting
  List<String> get debugMessages => List.from(_debugMessages);

  /// Ensure the service starts a connection attempt in the background and
  /// return a future that completes once connection attempt finishes.
  /// This method is safe to call without awaiting; callers that need to
  /// wait may await the returned future. It will not block the UI when
  /// invoked without awaiting.
  Future<bool> ensureConnected({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Fire-and-forget connection attempt if not connected
    if (_connectionState == MqttConnectionState.connected) return true;

    // If already connecting, wait a short while then report current state
    if (_connectionState == MqttConnectionState.connecting) {
      try {
        await Future.delayed(const Duration(milliseconds: 250));
      } catch (_) {}
      return _connectionState == MqttConnectionState.connected;
    }

    // Start connect in a microtask and return a future that waits for it
    final completer = Completer<bool>();
    Future.microtask(() async {
      try {
        final connected = await connect();
        if (!completer.isCompleted) completer.complete(connected);
      } catch (e) {
        if (!completer.isCompleted) completer.complete(false);
      }
    });

    // Respect optional timeout but do not block callers who don't await
    try {
      return await completer.future.timeout(timeout, onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  /// Send power command to device with queuing, throttling, and timeout handling
  Future<void> sendPowerCommand(String deviceId, int channel, bool on) async {
    final device = _registeredDevices[deviceId];
    if (device == null) {
      throw Exception('Device not registered: $deviceId');
    }

    if (_connectionState != MqttConnectionState.connected) {
      throw Exception('MQTT not connected');
    }

    // Don't apply optimistic update here - let the device manager handle it
    // This prevents double optimistic updates that can cause state conflicts

    // Queue the command for processing with timeout
    final topic = 'cmnd/${device.tasmotaTopicBase}/POWER$channel';
    final payload = on ? 'ON' : 'OFF';

    _addDebugMessage(
      '🔧 Sending command to ${device.name} (${device.channels}ch): $topic = $payload',
    );

    try {
      await _queueCommand(deviceId, topic, payload, priority: 1).timeout(
        _commandTimeout,
      ); // High priority for user commands with timeout

      _addDebugMessage('✅ Command queued successfully');
    } catch (e) {
      if (e is TimeoutException) {
        _addDebugMessage(
          '⏰ Command timeout for device $deviceId channel $channel',
        );
        throw Exception('Command timeout - device may be offline');
      }
      _addDebugMessage('❌ Command failed: $e');
      rethrow;
    }
  }

  /// Send bulk power command to all channels using POWER0
  Future<void> sendBulkPowerCommand(String deviceId, bool on) async {
    final device = _registeredDevices[deviceId];
    if (device == null) {
      throw Exception('Device not registered: $deviceId');
    }

    if (_connectionState != MqttConnectionState.connected) {
      throw Exception('MQTT not connected');
    }

    // Use POWER0 to control all channels simultaneously
    final topic = 'cmnd/${device.tasmotaTopicBase}/POWER0';
    final payload = on ? 'ON' : 'OFF';

    try {
      await _queueCommand(deviceId, topic, payload, priority: 1).timeout(
        _commandTimeout,
      ); // High priority for user commands with timeout

      _addDebugMessage('Sent bulk power command: $topic = $payload');
    } catch (e) {
      if (e is TimeoutException) {
        _addDebugMessage('Bulk command timeout for device $deviceId');
        throw Exception('Command timeout - device may be offline');
      }
      rethrow;
    }
  }

  /// Request device status
  /// Test connection with diagnostics
  Future<bool> testConnection() async {
    _addDebugMessage('Testing connection to $_brokerHost:$_brokerPort');
    _addDebugMessage('Using client ID: $_clientId');

    try {
      final success = await connect();
      if (success) {
        _addDebugMessage('Successfully connected to broker');

        // Test publish to a diagnostic topic
        final testTopic = 'diagnostic/${_clientId!}/test';
        await _publishMessage(testTopic, 'test message');
        _addDebugMessage('Successfully published to test topic');

        return true;
      } else {
        _addDebugMessage('Failed to connect to broker');
        return false;
      }
    } catch (e) {
      _addDebugMessage('Test connection failed: $e');
      return false;
    }
  }

  Future<void> requestDeviceStatus(String deviceId) async {
    final device = _registeredDevices[deviceId];
    if (device == null) return;

    if (_connectionState != MqttConnectionState.connected) return;

    // Use STATE command for immediate, comprehensive state retrieval
    final stateTopic = 'cmnd/${device.tasmotaTopicBase}/STATE';
    await _queueCommand(
      deviceId,
      stateTopic,
      '',
      priority: 1, // High priority for immediate state requests
    );

    _addDebugMessage('Requested STATE for device: ${device.name}');

    // CRITICAL FIX: For shutter devices, also request explicit shutter position
    // This ensures we get the current real position from the physical device,
    // even if it was changed manually via physical switches while app was closed
    if (device.deviceType == DeviceType.shutter) {
      // Request ShutterPosition1 to get current position from physical device
      // This will trigger a stat/RESULT response with actual device position
      final shutterPositionTopic =
          'cmnd/${device.tasmotaTopicBase}/ShutterPosition1';
      await _queueCommand(
        deviceId,
        shutterPositionTopic,
        '',
        priority: 1, // High priority for immediate state requests
      );
      _addDebugMessage(
        '🪟 Requested fresh shutter position from device: ${device.name}',
      );
    }
  }

  /// Request device state immediately without throttling (for page loads)
  Future<void> requestDeviceStateImmediate(String deviceId) async {
    final device = _registeredDevices[deviceId];
    if (device == null) return;

    if (_connectionState != MqttConnectionState.connected) return;

    // Send STATE command immediately for real-time state display
    final stateTopic = 'cmnd/${device.tasmotaTopicBase}/STATE';
    await _publishMessage(stateTopic, '');

    _addDebugMessage('Immediate STATE request for device: ${device.name}');

    // CRITICAL FIX: For shutter devices, also request explicit shutter position
    // This ensures we get the current real position from the physical device,
    // even if it was changed manually via physical switches while app was closed
    if (device.deviceType == DeviceType.shutter) {
      // Request ShutterPosition1 to get current position from physical device
      // This will trigger a stat/RESULT response with actual device position
      final shutterPositionTopic =
          'cmnd/${device.tasmotaTopicBase}/ShutterPosition1';
      await _publishMessage(shutterPositionTopic, '');
      _addDebugMessage(
        '🪟 Immediate shutter position request for device: ${device.name}',
      );
    }
  }

  /// Publish a lightweight Tasmota Status 5 probe (fire-and-forget).
  /// This avoids subscribing/unsubscribing to STATUS5 reply topics and is
  /// useful for aggressively nudging devices to report status when a UI
  /// detail page opens. It does not wait for or parse replies.
  Future<void> publishStatus5(String topicBase) async {
    if (_connectionState != MqttConnectionState.connected) return;
    if (topicBase.isEmpty) return;

    final statusTopic = 'cmnd/$topicBase/Status';
    try {
      await _publishMessage(statusTopic, '5');
      _addDebugMessage('Published lightweight Status 5 probe for $topicBase');
    } catch (e) {
      _addDebugMessage('Failed to publish Status 5 for $topicBase: $e');
    }
  }

  /// Control shutter - open
  Future<void> openShutter(String deviceId, int shutterIndex) async {
    final device = _registeredDevices[deviceId];
    if (device?.tasmotaTopicBase == null) return;

    if (_connectionState != MqttConnectionState.connected) {
      throw Exception('MQTT not connected');
    }

    // OPTIMISTIC UPDATE: Only update direction to 1 (opening)
    // DO NOT update position - let real MQTT telemetry update position progressively
    final shutterKey = 'Shutter$shutterIndex';
    final currentState = _deviceStates[deviceId]?[shutterKey];
    int currentPosition = 0;

    // Extract current position if available
    if (currentState is Map<String, dynamic>) {
      currentPosition = currentState['Position'] ?? 0;
    } else if (currentState is int) {
      currentPosition = currentState;
    }

    _deviceStates[deviceId] ??= {};
    _deviceStates[deviceId]![shutterKey] = {
      'Position': currentPosition, // Keep current position, don't jump to 100
      'Direction': 1, // Opening
      'Target': 100,
      'Tilt': 0,
    };
    _notifyDeviceStateChange(deviceId);
    _addDebugMessage(
      '🚀 Optimistic update: $shutterKey direction=1 (opening), position stays at $currentPosition%',
    );

    final topic = 'cmnd/${device!.tasmotaTopicBase}/ShutterOpen$shutterIndex';
    _addDebugMessage('🔧 Opening shutter $shutterIndex: $topic');

    try {
      await _queueCommand(
        deviceId,
        topic,
        '',
        priority: 1,
      ).timeout(_commandTimeout);
      _addDebugMessage('✅ Shutter open command queued successfully');

      // Request immediate state update to get actual position
      requestDeviceStateImmediate(deviceId).catchError((e) {
        _addDebugMessage('⚠️ State request error: $e');
      });
    } catch (e) {
      if (e is TimeoutException) {
        _addDebugMessage('⏰ Shutter command timeout for device $deviceId');
        throw Exception('Command timeout - device may be offline');
      }
      _addDebugMessage('❌ Shutter command failed: $e');
      rethrow;
    }
  }

  /// Control shutter - close
  Future<void> closeShutter(String deviceId, int shutterIndex) async {
    final device = _registeredDevices[deviceId];
    if (device?.tasmotaTopicBase == null) return;

    if (_connectionState != MqttConnectionState.connected) {
      throw Exception('MQTT not connected');
    }

    // OPTIMISTIC UPDATE: Only update direction to -1 (closing)
    // DO NOT update position - let real MQTT telemetry update position progressively
    final shutterKey = 'Shutter$shutterIndex';
    final currentState = _deviceStates[deviceId]?[shutterKey];
    int currentPosition = 0;

    // Extract current position if available
    if (currentState is Map<String, dynamic>) {
      currentPosition = currentState['Position'] ?? 0;
    } else if (currentState is int) {
      currentPosition = currentState;
    }

    _deviceStates[deviceId] ??= {};
    _deviceStates[deviceId]![shutterKey] = {
      'Position': currentPosition, // Keep current position, don't jump to 0
      'Direction': -1, // Closing
      'Target': 0,
      'Tilt': 0,
    };
    _notifyDeviceStateChange(deviceId);
    _addDebugMessage(
      '🚀 Optimistic update: $shutterKey direction=-1 (closing), position stays at $currentPosition%',
    );

    final topic = 'cmnd/${device!.tasmotaTopicBase}/ShutterClose$shutterIndex';
    _addDebugMessage('🔧 Closing shutter $shutterIndex: $topic');

    try {
      await _queueCommand(
        deviceId,
        topic,
        '',
        priority: 1,
      ).timeout(_commandTimeout);
      _addDebugMessage('✅ Shutter close command queued successfully');

      // Request immediate state update to get actual position
      requestDeviceStateImmediate(deviceId).catchError((e) {
        _addDebugMessage('⚠️ State request error: $e');
      });
    } catch (e) {
      if (e is TimeoutException) {
        _addDebugMessage('⏰ Shutter command timeout for device $deviceId');
        throw Exception('Command timeout - device may be offline');
      }
      _addDebugMessage('❌ Shutter command failed: $e');
      rethrow;
    }
  }

  /// Control shutter - stop
  Future<void> stopShutter(String deviceId, int shutterIndex) async {
    final device = _registeredDevices[deviceId];
    if (device?.tasmotaTopicBase == null) return;

    if (_connectionState != MqttConnectionState.connected) {
      throw Exception('MQTT not connected');
    }

    // OPTIMISTIC UPDATE: Set direction to 0 (stopped)
    // CRITICAL FIX FOR ISSUE 2: Update direction immediately for instant UI feedback
    final shutterKey = 'Shutter$shutterIndex';
    final currentState = _deviceStates[deviceId]?[shutterKey];
    int currentPosition = 0;

    // Extract current position if available
    if (currentState is Map<String, dynamic>) {
      currentPosition = currentState['Position'] ?? 0;
    } else if (currentState is int) {
      currentPosition = currentState;
    }

    _deviceStates[deviceId] ??= {};
    _deviceStates[deviceId]![shutterKey] = {
      'Position': currentPosition,
      'Direction': 0, // Stopped
      'Target': currentPosition,
      'Tilt': 0,
    };
    _notifyDeviceStateChange(deviceId);
    _addDebugMessage('🚀 Optimistic update: $shutterKey stopped (direction=0)');

    final topic = 'cmnd/${device!.tasmotaTopicBase}/ShutterStop$shutterIndex';
    _addDebugMessage('🔧 Stopping shutter $shutterIndex: $topic');

    try {
      await _queueCommand(
        deviceId,
        topic,
        '',
        priority: 1,
      ).timeout(_commandTimeout);
      _addDebugMessage('✅ Shutter stop command queued successfully');

      // Request immediate state update to get actual position after stop
      requestDeviceStateImmediate(deviceId).catchError((e) {
        _addDebugMessage('⚠️ State request error: $e');
      });
    } catch (e) {
      if (e is TimeoutException) {
        _addDebugMessage('⏰ Shutter command timeout for device $deviceId');
        throw Exception('Command timeout - device may be offline');
      }
      _addDebugMessage('❌ Shutter command failed: $e');
      rethrow;
    }
  }

  /// Control shutter - set position (0-100)
  Future<void> setShutterPosition(
    String deviceId,
    int shutterIndex,
    int position,
  ) async {
    final device = _registeredDevices[deviceId];
    if (device?.tasmotaTopicBase == null) return;

    if (_connectionState != MqttConnectionState.connected) {
      throw Exception('MQTT not connected');
    }

    // Clamp position between 0 and 100
    final clampedPosition = position.clamp(0, 100);

    // OPTIMISTIC UPDATE: Only update direction based on movement
    // DO NOT update position - let real MQTT telemetry update position progressively
    final shutterKey = 'Shutter$shutterIndex';
    final currentState = _deviceStates[deviceId]?[shutterKey];
    int currentPosition = 0;

    // Extract current position if available
    if (currentState is Map<String, dynamic>) {
      currentPosition = currentState['Position'] ?? 0;
    } else if (currentState is int) {
      currentPosition = currentState;
    }

    // Determine direction based on target vs current position
    int direction = 0;
    if (clampedPosition > currentPosition) {
      direction = 1; // Opening
    } else if (clampedPosition < currentPosition) {
      direction = -1; // Closing
    }

    _deviceStates[deviceId] ??= {};
    _deviceStates[deviceId]![shutterKey] = {
      'Position':
          currentPosition, // Keep current position, don't jump to target
      'Direction': direction,
      'Target': clampedPosition,
      'Tilt': 0,
    };
    _notifyDeviceStateChange(deviceId);
    _addDebugMessage(
      '🚀 Optimistic update: $shutterKey direction=$direction (target=$clampedPosition%), position stays at $currentPosition%',
    );

    final topic =
        'cmnd/${device!.tasmotaTopicBase}/ShutterPosition$shutterIndex';
    final payload = clampedPosition.toString();

    _addDebugMessage(
      '🔧 Setting shutter $shutterIndex position to $clampedPosition%: $topic',
    );

    try {
      await _queueCommand(
        deviceId,
        topic,
        payload,
        priority: 1,
      ).timeout(_commandTimeout);
      _addDebugMessage('✅ Shutter position command queued successfully');

      // Request immediate state update to get actual position
      requestDeviceStateImmediate(deviceId).catchError((e) {
        _addDebugMessage('⚠️ State request error: $e');
      });
    } catch (e) {
      if (e is TimeoutException) {
        _addDebugMessage('⏰ Shutter command timeout for device $deviceId');
        throw Exception('Command timeout - device may be offline');
      }
      _addDebugMessage('❌ Shutter command failed: $e');
      rethrow;
    }
  }

  /// Send custom command to device (for calibration and advanced features)
  Future<void> sendCustomCommand(
    String topicBase,
    String command,
    String payload,
  ) async {
    if (_connectionState != MqttConnectionState.connected) {
      throw Exception('MQTT not connected');
    }

    final topic = 'cmnd/$topicBase/$command';

    _addDebugMessage('📤 Sending custom command: $topic = $payload');

    try {
      await _publishMessage(topic, payload);
      _addDebugMessage('✅ Custom command sent successfully');
    } catch (e) {
      _addDebugMessage('❌ Custom command failed: $e');
      rethrow;
    }
  }

  /// Configure Tasmota device for proper status reporting
  /// OPTIMIZED: Minimal delays for fast first-command response
  Future<void> configureTasmotaStatusReporting(String deviceId) async {
    final device = _registeredDevices[deviceId];
    if (device?.tasmotaTopicBase == null) return;

    if (_connectionState != MqttConnectionState.connected) return;

    try {
      _addDebugMessage(
        '🔧 Configuring status reporting for device: ${device!.name} (${device.channels}ch)',
      );
      _addDebugMessage('📋 Device topic base: ${device.tasmotaTopicBase}');

      // SetOption19 1 - Enable status updates on physical button press
      _addDebugMessage('📤 Sending SetOption19=1 to enable status updates');
      await _publishMessage('cmnd/${device.tasmotaTopicBase}/SetOption19', '1');
      await Future.delayed(
        const Duration(milliseconds: 50),
      ); // OPTIMIZED: Minimal delay

      // SetOption30 1 - Enforce Home Assistant auto-discovery as JSON
      _addDebugMessage('📤 Sending SetOption30=1 for JSON format');
      await _publishMessage('cmnd/${device.tasmotaTopicBase}/SetOption30', '1');
      await Future.delayed(
        const Duration(milliseconds: 50),
      ); // OPTIMIZED: Minimal delay

      // Device-specific configuration based on channel count
      if (device.channels == 2) {
        // Additional configuration for 2-channel devices
        _addDebugMessage('🔧 Applying 2-channel specific configuration');

        // SetOption73 1 - Detach buttons from relays and send multi-press and hold MQTT messages
        _addDebugMessage(
          '📤 Sending SetOption73=1 for 2-channel button handling',
        );
        await _publishMessage(
          'cmnd/${device.tasmotaTopicBase}/SetOption73',
          '1',
        );
        await Future.delayed(
          const Duration(milliseconds: 50),
        ); // OPTIMIZED: Minimal delay

        // ButtonTopic - Set button topic to device topic for proper status reporting
        _addDebugMessage('📤 Setting ButtonTopic=${device.tasmotaTopicBase}');
        await _publishMessage(
          'cmnd/${device.tasmotaTopicBase}/ButtonTopic',
          device.tasmotaTopicBase!,
        );
        await Future.delayed(
          const Duration(milliseconds: 50),
        ); // OPTIMIZED: Minimal delay
      }

      // PowerRetain 0 - Don't retain power state messages
      await _publishMessage('cmnd/${device.tasmotaTopicBase}/PowerRetain', '0');
      await Future.delayed(
        const Duration(milliseconds: 50),
      ); // OPTIMIZED: Minimal delay

      // StatusRetain 0 - Don't retain status messages
      await _publishMessage(
        'cmnd/${device.tasmotaTopicBase}/StatusRetain',
        '0',
      );
      await Future.delayed(
        const Duration(milliseconds: 50),
      ); // OPTIMIZED: Minimal delay

      _addDebugMessage('✅ Tasmota configuration completed for: ${device.name}');

      // Request current state after configuration (no verification delay)
      await requestDeviceStateImmediate(deviceId);
    } catch (e) {
      _addDebugMessage('❌ Failed to configure Tasmota device: $e');
    }
  }

  /// Private methods

  void _setConnectionState(MqttConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void _addDebugMessage(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final debugMessage = '[$timestamp] $message';
    _debugMessages.insert(0, debugMessage);
    if (_debugMessages.length > 100) {
      _debugMessages.removeLast();
    }
    _debugController.add(debugMessage);
    if (kDebugMode) {
      print('MQTT: $message');
    }
  }

  Future<void> _subscribeToDevice(Device device) async {
    if (_client == null || device.tasmotaTopicBase == null) {
      _addDebugMessage('Cannot subscribe - client or topic is null');
      _updateDeviceStatus(device.id, 'error', 'MQTT client not ready');
      return;
    }

    if (_connectionState != MqttConnectionState.connected) {
      _addDebugMessage('Cannot subscribe - not connected to broker');
      _updateDeviceStatus(device.id, 'error', 'MQTT not connected');
      return;
    }

    try {
      // Update device status
      _updateDeviceStatus(device.id, 'connecting', 'Subscribing to topics');

      // Subscribe to robust patterns: stat/<base>/# will catch STATE, RESULT,
      // STATUS0..STATUS12 and similar. tele/<base>/LWT is the primary health
      // source. Do NOT subscribe to cmnd/*.
      final topics = [
        'stat/${device.tasmotaTopicBase}/#',
        'tele/${device.tasmotaTopicBase}/LWT',
      ];

      // Subscribe to all topics with consistent QoS, avoiding duplicates
      _addDebugMessage('📡 Subscribing to topics for device: ${device.name}');
      for (final topic in topics) {
        if (!_activeSubscriptions.contains(topic)) {
          _client!.subscribe(topic, MqttQos.atLeastOnce);
          _activeSubscriptions.add(topic);
          _addDebugMessage('✅ Subscribed to: $topic');
        } else {
          _addDebugMessage('⚠️ Already subscribed to: $topic');
        }
      }

      _addDebugMessage(
        '📊 Total active subscriptions: ${_activeSubscriptions.length}',
      );
      _addDebugMessage(
        '📋 Active subscriptions: ${_activeSubscriptions.toList()}',
      );

      // Update status after successful subscription
      _updateDeviceStatus(
        device.id,
        'subscribed',
        'Connected to device topics',
      );

      // Start periodic state polling for real-time synchronization
      _startStatePolling(device);
    } catch (e) {
      _addDebugMessage('Error subscribing to device topics: $e');
      _updateDeviceStatus(device.id, 'error', 'Failed to subscribe: $e');
    }
  }

  Future<void> _resubscribeAllDevices() async {
    for (final device in _registeredDevices.values) {
      await _subscribeToDevice(device);
    }
  }

  /// Unsubscribe from device topics
  void _unsubscribeFromDevice(Device device) {
    if (_client == null || device.tasmotaTopicBase == null) {
      _addDebugMessage('Cannot unsubscribe - client or topic is null');
      return;
    }

    if (_connectionState != MqttConnectionState.connected) {
      _addDebugMessage('Cannot unsubscribe - not connected to broker');
      return;
    }

    try {
      // Get the same topic patterns used in subscription
      final topics = [
        'stat/${device.tasmotaTopicBase}/#',
        'tele/${device.tasmotaTopicBase}/LWT',
      ];

      // Unsubscribe from topics and remove from tracking
      for (final topic in topics) {
        if (_activeSubscriptions.contains(topic)) {
          // Check if any other registered device uses this topic pattern
          bool topicStillNeeded = false;
          for (final otherDevice in _registeredDevices.values) {
            if (otherDevice.id != device.id &&
                otherDevice.tasmotaTopicBase != null &&
                topic.contains(otherDevice.tasmotaTopicBase!)) {
              topicStillNeeded = true;
              break;
            }
          }

          // Only unsubscribe if no other device needs this topic
          if (!topicStillNeeded) {
            _client!.unsubscribe(topic);
            _activeSubscriptions.remove(topic);
            _addDebugMessage('Unsubscribed from: $topic');
          } else {
            _addDebugMessage(
              'Keeping subscription (used by other device): $topic',
            );
          }
        }
      }
    } catch (e) {
      _addDebugMessage('Error unsubscribing from device topics: $e');
    }
  }

  /// Start periodic state polling for a device to ensure real-time synchronization
  void _startStatePolling(Device device) {
    // Cancel existing timer if any
    _statePollingTimers[device.id]?.cancel();

    // Start new periodic timer
    _statePollingTimers[device.id] = Timer.periodic(_statePollingInterval, (
      timer,
    ) {
      if (_connectionState == MqttConnectionState.connected) {
        // Request STATE to get all relay states at once
        requestDeviceStateImmediate(device.id);
        _addDebugMessage('Periodic state poll for device: ${device.name}');
      }
    });

    _addDebugMessage(
      'Started periodic state polling for device: ${device.name}',
    );
  }

  /// Stop periodic state polling for a device
  void _stopStatePolling(String deviceId) {
    _statePollingTimers[deviceId]?.cancel();
    _statePollingTimers.remove(deviceId);
  }

  Future<void> _requestDeviceState(Device device) async {
    // Use STATE command for faster bulk retrieval instead of individual channel requests
    final stateTopic = 'cmnd/${device.tasmotaTopicBase}/STATE';
    await _publishMessage(stateTopic, '');
  }

  Future<void> _publishMessage(
    String topic,
    String payload, {
    MqttQos qos = MqttQos.atLeastOnce,
    bool retain = false,
  }) async {
    if (_client == null) return;

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    // Track recent publishes to filter out broker echoes (some brokers
    // reflect publishes back to subscribers). We key by topic+payload and
    // keep a short-lived timestamp.
    try {
      final key = '$topic|$payload';
      _recentPublishes[key] = DateTime.now();
      // Trim old entries
      _recentPublishes.removeWhere(
        (k, v) => DateTime.now().difference(v).inSeconds > 5,
      ); // 5s window
    } catch (_) {}

    _client!.publishMessage(topic, qos, builder.payload!, retain: retain);
  }

  /// Queue a command for processing
  Future<void> _queueCommand(
    String deviceId,
    String topic,
    String payload, {
    int priority = 5,
  }) async {
    final command = _QueuedCommand(
      topic: topic,
      payload: payload,
      priority: priority,
      qos: MqttQos.atLeastOnce,
      retain: false,
    );

    // Add to device-specific queue
    _commandQueues[deviceId] ??= [];
    _commandQueues[deviceId]!.add(command);

    // Sort queue by priority (lower number = higher priority)
    _commandQueues[deviceId]!.sort((a, b) => a.priority.compareTo(b.priority));

    _addDebugMessage(
      'Queued command for $deviceId: $topic = $payload (priority: $priority)',
    );

    // Process the queue for this device
    _processCommandQueue(deviceId);
  }

  /// Process command queue for a specific device
  Future<void> _processCommandQueue(String deviceId) async {
    // Prevent concurrent processing of the same device queue
    if (_processingQueues[deviceId] == true) {
      return;
    }

    _processingQueues[deviceId] = true;

    try {
      final queue = _commandQueues[deviceId];
      if (queue == null || queue.isEmpty) {
        return;
      }

      while (queue.isNotEmpty) {
        final command = queue.removeAt(0);

        // Execute the command
        await _publishMessage(
          command.topic,
          command.payload,
          qos: command.qos,
          retain: command.retain,
        );

        _addDebugMessage(
          'Executed queued command: ${command.topic} = ${command.payload}',
        );

        // Minimal delay between commands for faster processing
        if (queue.isNotEmpty) {
          await Future.delayed(_commandThrottleDelay);
        }
      }
    } finally {
      _processingQueues[deviceId] = false;
    }
  }

  /// Update device state with enhanced reconciliation to prevent conflicts
  void _updateDeviceStateWithReconciliation(
    String deviceId,
    String command,
    String payload,
  ) {
    _deviceStates[deviceId] ??= {};

    // Check if this is an optimistic update that should be preserved
    final isOptimistic = _deviceStates[deviceId]!.containsKey('optimistic');
    final currentValue = _deviceStates[deviceId]![command];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Enhanced reconciliation logic for multi-device scenarios
    bool shouldUpdate = false;
    String updateReason = '';

    if (currentValue == null) {
      // No current value exists - always update
      shouldUpdate = true;
      updateReason = 'no_current_value';
    } else if (!isOptimistic) {
      // Not an optimistic state - update with actual device response
      shouldUpdate = true;
      updateReason = 'device_response';
    } else if (currentValue == payload) {
      // Optimistic state matches actual response - confirm and update
      shouldUpdate = true;
      updateReason = 'optimistic_confirmed';
    } else {
      // Optimistic state conflicts with actual response
      // Check timestamp to determine which is more recent
      final optimisticTimestamp =
          _deviceStates[deviceId]!['optimisticTimestamp'] as int?;
      final timeDiff = optimisticTimestamp != null
          ? timestamp - optimisticTimestamp
          : 0;

      if (timeDiff > 5000) {
        // If optimistic update is older than 5 seconds
        shouldUpdate = true;
        updateReason = 'optimistic_expired';
        _addDebugMessage(
          'Optimistic state expired (${timeDiff}ms old), accepting device response: $command = $payload',
        );
      } else {
        shouldUpdate = false;
        updateReason = 'optimistic_conflict';
        _addDebugMessage(
          'Preserving recent optimistic state: $command = $currentValue (device says: $payload)',
        );
      }
    }

    if (shouldUpdate) {
      _deviceStates[deviceId]![command] = payload;
      _deviceStates[deviceId]!['lastStateUpdate'] = timestamp;
      _deviceStates[deviceId]!['lastUpdateReason'] = updateReason;

      // Clear optimistic flags when we get confirmation
      if (isOptimistic &&
          (updateReason == 'optimistic_confirmed' ||
              updateReason == 'optimistic_expired')) {
        _deviceStates[deviceId]!.remove('optimistic');
        _deviceStates[deviceId]!.remove('optimisticTimestamp');
        _addDebugMessage(
          'Optimistic state resolved: $command = $payload (reason: $updateReason)',
        );
      }

      // Save power state to cache for instant display on next app startup
      if (command.startsWith('POWER')) {
        // Extract channel number from POWER1, POWER2, etc.
        final channelStr = command.substring(5); // Remove 'POWER' prefix
        final channel = int.tryParse(channelStr);
        if (channel != null && channel >= 1 && channel <= 8) {
          // Save to cache asynchronously (fire-and-forget)
          _stateCache.savePowerState(deviceId, channel, payload).catchError((
            e,
          ) {
            _addDebugMessage('⚠️ Failed to cache power state: $e');
          });
        }
      }

      // FETCH-FIRST FIX: Do NOT emit state change if waiting for initial state
      if (!_devicesWaitingForInitialState.contains(deviceId)) {
        _deviceStateControllers[deviceId]?.add(_deviceStates[deviceId]!);
        _addDebugMessage(
          'State updated: $command = $payload (reason: $updateReason)',
        );
      } else {
        _addDebugMessage(
          '⏸️ State updated internally but NOT emitted (waiting for initial state): $command = $payload',
        );
      }
    } else {
      _addDebugMessage(
        'State update skipped: $command = $payload (reason: $updateReason, current: $currentValue)',
      );
    }
  }

  void _updateAllDevicesOnline() {
    // Avoid marking every device as "online" based on connection-level
    // keepalive/pong responses. A connection-level pong only proves the
    // broker connection is alive, not that each individual device is
    // responsive. Instead, mark devices as "connected" to indicate the
    // app/broker link is up, but preserve the per-device 'online' flag
    // which is driven by LWT, telemetry freshness, and per-device probes.
    for (final deviceId in _deviceStates.keys) {
      final state = _deviceStates[deviceId];
      if (state == null) continue;

      // Mark broker-level connectivity; do not flip per-device 'online'.
      state['connected'] = true;
      state['lastBrokerPing'] = DateTime.now().toIso8601String();

      // FETCH-FIRST FIX: Only emit if not waiting for initial state
      if (!_devicesWaitingForInitialState.contains(deviceId)) {
        _deviceStateControllers[deviceId]?.add(
          Map<String, dynamic>.from(state),
        );
      }
    }
  }

  void _setAllDevicesOffline() {
    for (final deviceId in _deviceStates.keys) {
      _deviceStates[deviceId]?['online'] = false;

      // FETCH-FIRST FIX: Only emit if not waiting for initial state
      if (!_devicesWaitingForInitialState.contains(deviceId)) {
        _deviceStateControllers[deviceId]?.add(_deviceStates[deviceId]!);
      }
    }
  }

  // Event handlers - all non-blocking
  void _onConnected() {
    try {
      _connectionTimestamp = DateTime.now();
      _setConnectionState(MqttConnectionState.connected);
      _addDebugMessage('MQTT connected');

      // Clear retained message tracking for new connection
      _processedRetainedTopics.clear();
      _lastMessageTimestamps.clear();

      // Resubscribe to all devices after connection is established (non-blocking)
      Future.microtask(() async {
        try {
          await _resubscribeAllDevices().timeout(
            const Duration(seconds: 30),
            onTimeout: () => _addDebugMessage('Resubscription timed out'),
          );

          // Request state for all devices with timeout
          for (final device in _registeredDevices.values) {
            try {
              await _requestDeviceState(device).timeout(
                const Duration(seconds: 10),
                onTimeout: () => _addDebugMessage(
                  'Device state request timed out for ${device.id}',
                ),
              );
            } catch (e) {
              _addDebugMessage(
                'Error requesting state for device ${device.id}: $e',
              );
            }
          }
        } catch (e) {
          _addDebugMessage('Error resubscribing to devices: $e');
        }
      });
    } catch (e) {
      _addDebugMessage('Error in _onConnected: $e');
    }
  }

  void _onDisconnected() {
    try {
      _setConnectionState(MqttConnectionState.disconnected);
      _addDebugMessage('MQTT disconnected');
      _setAllDevicesOffline();

      // Trigger automatic reconnection if not manually disconnecting
      if (!_isReconnecting) {
        _addDebugMessage(
          '🔄 Unexpected disconnection detected, starting automatic reconnection',
        );
        Future.microtask(() => _attemptAutomaticReconnection());
      }
    } catch (e) {
      _addDebugMessage('Error in _onDisconnected: $e');
    }
  }

  void _onSubscribed(String topic) {
    _activeSubscriptions.add(topic);
    _addDebugMessage('Subscribed to: $topic');

    // Only request device state for stat topics to avoid redundant requests
    if (topic.contains('/stat/')) {
      // Try to find which device this subscription belongs to
      for (final device in _registeredDevices.values) {
        if (device.tasmotaTopicBase != null &&
            topic.contains(device.tasmotaTopicBase!)) {
          // Optimized device state request after successful subscription
          Future.delayed(_stateRequestDelay, () {
            requestDeviceStatus(device.id);
          });
          break;
        }
      }
    }
  }

  void _onUnsubscribed(String? topic) {
    if (topic != null) {
      _activeSubscriptions.remove(topic);
    }
    _addDebugMessage('Unsubscribed from: $topic');
  }

  void _onAutoReconnect() {
    try {
      _addDebugMessage('MQTT auto-reconnecting... (disabled for stability)');
      // Auto-reconnect is disabled to prevent blocking, use manual reconnect instead
      _setConnectionState(MqttConnectionState.connecting);
    } catch (e) {
      _addDebugMessage('Error in _onAutoReconnect: $e');
    }
  }

  void _updateDeviceStatus(String deviceId, String status, String message) {
    if (!_deviceStates.containsKey(deviceId)) return;

    _deviceStates[deviceId]!['status'] = status;
    _deviceStates[deviceId]!['statusMessage'] = message;
    _deviceStates[deviceId]!['lastStatusUpdate'] = DateTime.now()
        .toIso8601String();

    // Update online state based on explicit status values.
    // Do NOT mark device 'online' for transient/internal statuses like
    // 'subscribed' or 'connecting' because those reflect subscription
    // progress, not actual device presence. Presence must be derived from
    // LWT, telemetry freshness, or probe responses.
    final s = status.toLowerCase();
    bool onlineFlag = false;
    if (s == 'online' || s == 'confirmed' || s == 'available') {
      onlineFlag = true;
    }
    // Preserve any existing explicit online flag if status is neutral
    _deviceStates[deviceId]!['online'] = onlineFlag;

    _addDebugMessage('Device $deviceId status: $status - $message');

    // FETCH-FIRST FIX: Only emit if not waiting for initial state
    if (!_devicesWaitingForInitialState.contains(deviceId)) {
      _deviceStateControllers[deviceId]?.add(_deviceStates[deviceId]!);
    }
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final topic = message.topic;
      final mqttMessage = message.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        mqttMessage.payload.message,
      );

      final now = DateTime.now();

      // Enhanced retained message filtering
      bool isPotentiallyRetained = false;
      bool shouldSkipMessage = false;

      if (_connectionTimestamp != null) {
        final timeSinceConnection = now.difference(_connectionTimestamp!);
        isPotentiallyRetained =
            timeSinceConnection.inSeconds < 10; // Extended window

        // Check if this is a stale retained message
        if (isPotentiallyRetained) {
          final lastTimestamp = _lastMessageTimestamps[topic];
          if (lastTimestamp != null) {
            final timeSinceLastMessage = now.difference(lastTimestamp);
            // Skip if we received the same topic very recently (likely retained)
            if (timeSinceLastMessage.inMilliseconds < 100) {
              shouldSkipMessage = true;
            }
          }

          // CRITICAL FIX: Don't skip retained RESULT messages with shutter position data
          // These contain valid state information that should be processed immediately
          // to avoid waiting ~10 seconds for device response
          final isShutterPositionMessage =
              topic.contains('/RESULT') &&
              payload.contains('"Shutter') &&
              payload.contains('"Position"');

          // Also skip if we've already processed this topic recently
          // UNLESS it's a shutter position message (always process these for instant display)
          if (_processedRetainedTopics.contains(topic) &&
              !isShutterPositionMessage) {
            shouldSkipMessage = true;
          }
        }
      }

      // Track message timestamps
      _lastMessageTimestamps[topic] = now;

      // Skip stale retained messages
      if (shouldSkipMessage) {
        _addDebugMessage('Skipping stale retained message: $topic = $payload');
        continue;
      }

      if (isPotentiallyRetained) {
        _processedRetainedTopics.add(topic);
        _addDebugMessage(
          '📨 Received (potentially retained): $topic = $payload',
        );
      } else {
        _addDebugMessage('📨 Received: $topic = $payload');
      }

      // Enhanced debugging for topic validation
      final topicParts = topic.split('/');
      if (topicParts.length >= 2) {
        final topicBase = topicParts[1];

        // Find device with matching topic base
        Device? matchingDevice;
        for (final device in _registeredDevices.values) {
          if (device.tasmotaTopicBase == topicBase) {
            matchingDevice = device;
            break;
          }
        }

        if (matchingDevice != null) {
          final isExpected = MqttDebugHelper.isTopicExpected(
            topic,
            matchingDevice.tasmotaTopicBase!,
            matchingDevice.effectiveChannels,
          );

          if (!isExpected) {
            _addDebugMessage(
              '⚠️ Unexpected topic format for ${matchingDevice.name}: $topic',
            );
            final validation = MqttDebugHelper.validateTopic(
              topic,
              matchingDevice.tasmotaTopicBase!,
            );
            for (final issue in validation['issues'] as List<String>) {
              _addDebugMessage('   Issue: $issue');
            }
          } else {
            _addDebugMessage(
              '✅ Valid topic for ${matchingDevice.name} (${matchingDevice.channels}ch): $topic',
            );
          }
        } else {
          _addDebugMessage(
            '❓ No registered device found for topic base: $topicBase',
          );
          _addDebugMessage('   Registered devices:');
          for (final device in _registeredDevices.values) {
            _addDebugMessage(
              '     - ${device.name}: ${device.tasmotaTopicBase}',
            );
          }
        }
      }

      // Filter out broker-echo of our own publishes (topic+payload in recent publishes)
      try {
        final echoKey = '$topic|$payload';
        // We only treat such echoes as "our publish" if the topic is a cmnd/*
        // (we should not be subscribing to cmnd/* in normal operation). If a
        // recent publish exists but the topic is under stat/ or tele/, do not
        // ignore it — stat/ and tele/ messages are authoritative.
        final recent = _recentPublishes[echoKey];
        final wasRecent =
            recent != null && DateTime.now().difference(recent).inSeconds < 5;
        final topicPrefix = topicParts.isNotEmpty
            ? topicParts[0].toLowerCase()
            : '';
        if (wasRecent && topicPrefix == 'cmnd') {
          _addDebugMessage(
            'Ignoring broker-echo of our own publish (cmnd): $topic',
          );
          continue;
        }
      } catch (_) {}

      // Ignore cmnd/* topics as inbound telemetry - these are command topics
      final prefix = topicParts[0].toLowerCase();
      if (prefix == 'cmnd') {
        _addDebugMessage('Ignoring inbound cmnd topic: $topic');
        continue;
      }

      _processDeviceMessage(topic, payload);
    }
  }

  void _processDeviceMessage(String topic, String payload) {
    // Find device by topic with exact matching to prevent conflicts
    Device? targetDevice;
    String? deviceId;

    // Extract topic base from the topic for exact matching
    final topicParts = topic.split('/');
    if (topicParts.length < 2) {
      _addDebugMessage('Invalid topic format: $topic');
      return;
    }

    final topicBase =
        topicParts[1]; // e.g., "hbot_8857CC" from "stat/hbot_8857CC/POWER1"

    // Find device with exact topic base match to prevent conflicts between similar devices
    for (final entry in _registeredDevices.entries) {
      final device = entry.value;
      if (device.tasmotaTopicBase == topicBase) {
        targetDevice = device;
        deviceId = entry.key;
        _addDebugMessage(
          '✅ Exact topic match found: ${device.name} for topic: $topic',
        );
        break;
      }
    }

    if (targetDevice == null || deviceId == null) {
      _addDebugMessage(
        '❌ No matching device found for topic: $topic (topic base: $topicBase)',
      );
      _addDebugMessage('   Registered devices:');
      for (final device in _registeredDevices.values) {
        _addDebugMessage('     - ${device.name}: ${device.tasmotaTopicBase}');
      }
      return;
    }

    // Parse message and update device state
    try {
      final now = DateTime.now();

      // Promote deviceId to a local non-nullable alias to avoid nullable map key issues
      final String did = deviceId;

      // Update last-seen timestamp for this device (telemetry/result/STATE)
      _deviceLastSeen[did] = now;

      // Update telemetry timing estimate when telemetry-like payloads arrive
      // We treat tele/STATE, tele/..., stat/.../RESULT and tele/.../RESULT as telemetry events
      void updateTelemetryPeriodForDevice() {
        final prev = _deviceLastTelemetry[did];
        if (prev != null) {
          final diff = now.difference(prev);
          final prevPeriod = _deviceTelemetryPeriod[did];
          if (prevPeriod == null) {
            _deviceTelemetryPeriod[did] = diff;
          } else {
            // simple average to smooth period
            final avgMs =
                ((prevPeriod.inMilliseconds + diff.inMilliseconds) / 2).round();
            _deviceTelemetryPeriod[did] = Duration(milliseconds: avgMs);
          }
        }
        _deviceLastTelemetry[did] = now;
      }

      // Extract the command/state from topic
      final topicParts = topic.split('/');
      if (topicParts.length >= 3) {
        final prefix = topicParts[0].toLowerCase(); // stat, tele, etc.
        final command = topicParts.last;

        // Initialize state if needed. Default 'online' is false and will only
        // be set to true by an explicit Ping response (per user's requirement).
        _deviceStates[did] ??= {
          'online': false,
          'connected': false,
          'channels': targetDevice.channels,
        };

        // Handle different types of messages
        switch (prefix) {
          case 'stat':
            // Status messages indicate broker-level connectivity for this device
            // but do not by themselves prove device presence. We mark the
            // 'connected' flag so the UI can display broker/device-link health
            // separately from device presence which is only derived from Ping.
            _deviceStates[did]!['connected'] = true;
            if (command.startsWith('POWER')) {
              // CRITICAL FIX: Ignore empty payloads from retained MQTT messages
              // Empty payloads can overwrite valid cached states and cause flickering
              if (payload.trim().isEmpty) {
                _addDebugMessage(
                  '⚠️ Ignoring empty payload for $command (likely stale retained message)',
                );
                break; // Skip processing this message
              }

              // Update power state with reconciliation
              _updateDeviceStateWithReconciliation(did, command, payload);
              _addDebugMessage('Updated device state: $command = $payload');

              // Device responded; mark as online for immediate UI feedback
              _deviceStates[did]!['online'] = true;
              _deviceStates[did]!['health'] = 'ONLINE';
              _deviceLastSeen[did] = DateTime.now();

              // Immediately notify UI of state changes for real-time sync
              _notifyDeviceStateChange(did);
            } else if (command == 'RESULT') {
              // Handle status result messages (often from external control)
              try {
                _parseResultMessage(did, payload, targetDevice);
                _addDebugMessage('Received status result: $payload');

                // Device replied to a command/status request; mark online
                _deviceStates[did]!['online'] = true;
                _deviceStates[did]!['health'] = 'ONLINE';
                _deviceLastSeen[did] = DateTime.now();

                // Immediately notify UI of state changes for real-time sync
                _notifyDeviceStateChange(did);
              } catch (e) {
                _addDebugMessage('Error parsing status result: $e');
              }
            } else if (command.toLowerCase().startsWith('status')) {
              // Handle STATUSn messages (e.g. STATUS5) which are Tasmota replies
              // to cmnd/<topic>/Status <n>. Treat these as probe responses.
              try {
                // Update last-seen and attempt to extract useful state
                _deviceLastSeen[did] = DateTime.now();

                // Try to parse JSON payload and extract nested StatusSTS/Status
                if (payload.startsWith('{')) {
                  final Map<String, dynamic> parsed = Map<String, dynamic>.from(
                    jsonDecode(payload),
                  );

                  // Prefer StatusSTS (contains POWER/STATE info) if present
                  if (parsed.containsKey('StatusSTS')) {
                    try {
                      final sts = parsed['StatusSTS'];
                      if (sts != null) {
                        // Pass the nested object as JSON string to parseState
                        _parseStateMessage(did, jsonEncode(sts), targetDevice);
                      }
                    } catch (_) {}
                  }

                  // Also capture StatusNET top-level info for convenience
                  if (parsed.containsKey('StatusNET')) {
                    final statusNet = parsed['StatusNET'];
                    if (statusNet is Map) {
                      _deviceStates[did]!['StatusNET'] =
                          Map<String, dynamic>.from(statusNet);
                    }
                  }

                  // Parse shutter telemetry from STATUS8 (StatusSNS contains Shutter1)
                  _parseShutterTelemetry(did, parsed);
                }

                // Consider this a successful probe reply and mark device online
                _completePendingProbe(did, true);
                _deviceStates[did]!['online'] = true;
                _deviceStates[did]!['health'] = 'ONLINE';
                _deviceLastSeen[did] = DateTime.now();

                // Notify UI of any changes
                _notifyDeviceStateChange(did);
                _addDebugMessage(
                  'Handled STATUSx probe reply for $did: $command',
                );
              } catch (e) {
                _addDebugMessage('Error handling STATUS probe reply: $e');
              }
            }
            break;

          case 'tele':
            // Handle telemetry messages for real-time state synchronization
            if (command == 'LWT') {
              // Last Will and Testament - device online/offline status
              final isOnline = payload.toLowerCase() == 'online';
              _deviceStates[did]!['online'] = isOnline;
              _deviceStates[did]!['connected'] = isOnline;
              _deviceLWT[did] = payload;
              _deviceLWTTimestamp[did] = now;
              _addDebugMessage(
                'Device ${isOnline ? 'online' : 'offline'}: ${targetDevice.name}',
              );

              // Notify UI of online/offline status change
              _notifyDeviceStateChange(did);

              // Request fresh state when device comes online
              if (isOnline) {
                final capturedDeviceId = did;
                Future.delayed(_stateRequestDelay, () {
                  requestDeviceStateImmediate(capturedDeviceId);
                });
              }
            } else if (command == 'STATE') {
              // Parse full state update - update connected and telemetry timing,
              // but do not set 'online' here. Presence must be established via Ping.
              _deviceStates[did]!['connected'] = true;
              try {
                _parseStateMessage(did, payload, targetDevice);
                updateTelemetryPeriodForDevice();
                _addDebugMessage('Received device state update: $payload');

                // Device returned full STATE: treat as evidence of presence
                _deviceStates[did]!['online'] = true;
                _deviceStates[did]!['health'] = 'ONLINE';
                _deviceLastSeen[did] = DateTime.now();
                // Immediately notify UI of state changes for real-time sync
                _notifyDeviceStateChange(did);
                // If a probe was pending, complete it successfully
                _completePendingProbe(did, true);
              } catch (e) {
                _addDebugMessage('Error parsing device state: $e');
              }
            } else if (command == 'RESULT') {
              // Handle command results and physical button presses
              try {
                _parseResultMessage(did, payload, targetDevice);
                updateTelemetryPeriodForDevice();
                _addDebugMessage('Received device result: $payload');

                // Device responded: mark online and notify UI
                _deviceStates[did]!['online'] = true;
                _deviceStates[did]!['health'] = 'ONLINE';
                _deviceLastSeen[did] = DateTime.now();
                // Complete any pending probe for this device
                _completePendingProbe(did, true);

                // Immediately notify UI of state changes for real-time sync
                _notifyDeviceStateChange(did);
              } catch (e) {
                _addDebugMessage('Error parsing device result: $e');
              }
            } else if (command.startsWith('POWER')) {
              // CRITICAL FIX: Ignore empty payloads from retained MQTT messages
              // Empty payloads can overwrite valid cached states and cause flickering
              if (payload.trim().isEmpty) {
                _addDebugMessage(
                  '⚠️ Ignoring empty payload for $command (likely stale retained message)',
                );
                break; // Skip processing this message
              }

              // Handle direct power state updates from external sources. These
              // updates indicate activity on the device but do not change the
              // authoritative presence flag (Ping). We still mark the
              // connection as active.
              _deviceStates[did]!['connected'] = true;
              _updateDeviceStateWithReconciliation(did, command, payload);
              updateTelemetryPeriodForDevice();
              _addDebugMessage(
                'External power state change: $command = $payload',
              );

              // A power update can indicate the device is responsive; complete probe
              _completePendingProbe(did, true);
              // Treat POWER update as evidence of presence
              _deviceStates[did]!['online'] = true;
              _deviceStates[did]!['health'] = 'ONLINE';
              _deviceLastSeen[did] = DateTime.now();

              // Immediately notify UI of state changes for real-time sync
              _notifyDeviceStateChange(did);
            }
            break;

          case 'cmnd':
            // Command acknowledgments
            if (command.startsWith('POWER')) {
              // CRITICAL FIX: Ignore empty payloads from retained MQTT messages
              // Empty payloads can overwrite valid cached states and cause flickering
              if (payload.trim().isEmpty) {
                _addDebugMessage(
                  '⚠️ Ignoring empty payload for $command (likely stale retained message)',
                );
                break; // Skip processing this message
              }

              // Update power state with reconciliation
              _updateDeviceStateWithReconciliation(did, command, payload);
              _addDebugMessage('Command acknowledged: $command = $payload');

              // Command ack may satisfy a pending probe
              _completePendingProbe(did, true);

              // Immediately notify UI of state changes for real-time sync
              _notifyDeviceStateChange(did);
            } else if (command == 'STATE') {
              // Handle STATE command response (immediate state retrieval)
              try {
                _parseStateMessage(did, payload, targetDevice);
                _addDebugMessage('Received immediate STATE response: $payload');

                // Complete probe if waiting
                _completePendingProbe(did, true);

                // Immediately notify UI of state changes for real-time sync
                _notifyDeviceStateChange(did);
              } catch (e) {
                _addDebugMessage('Error parsing STATE response: $e');
              }
            }
            break;
        }

        // REMOVED: Redundant power state initialization and notification
        // The power states are already initialized when the device is registered
        // (with cached values from DeviceStateCache), and specific message handlers
        // above already call _notifyDeviceStateChange() when state actually changes.
        // This redundant notification was causing flickering by emitting state updates
        // on every MQTT message even when no state changed.
      }
    } catch (e) {
      _addDebugMessage('Error processing message: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    // First disconnect MQTT client
    await disconnect();

    // Stop connection monitoring and network detection
    _stopConnectionMonitoring();

    // Cancel all throttle timers
    for (final timer in _commandThrottleTimers.values) {
      timer.cancel();
    }
    _commandThrottleTimers.clear();

    for (final timer in _stateRequestTimers.values) {
      timer.cancel();
    }
    _stateRequestTimers.clear();

    // Clear state polling timers
    for (final timer in _statePollingTimers.values) {
      timer.cancel();
    }
    _statePollingTimers.clear();

    // Cancel batch persistence timer and process any pending states
    _statePersistenceBatchTimer?.cancel();
    _statePersistenceBatchTimer = null;
    if (_pendingStatePersistence.isNotEmpty) {
      await _processPendingStatePersistence();
    }

    // Clear command queues
    _commandQueues.clear();
    _processingQueues.clear();

    // Wait for any pending messages
    await Future.delayed(const Duration(milliseconds: 100));

    // Close state controllers first
    for (final controller in _deviceStateControllers.values) {
      await controller.close();
    }
    _deviceStateControllers.clear();

    // Close remaining controllers
    await _connectionStateController.close();
    await _messageController.close();
    await _debugController.close();
  }

  /// Parse STATE message and extract POWER1-POWER8 values
  void _parseStateMessage(String deviceId, String payload, Device device) {
    try {
      // Try to parse as JSON
      final Map<String, dynamic> stateData;
      if (payload.startsWith('{')) {
        stateData = Map<String, dynamic>.from(jsonDecode(payload));
      } else {
        // If not JSON, store as raw payload
        _deviceStates[deviceId]!['lastState'] = payload;
        return;
      }

      // Store raw state data
      _deviceStates[deviceId]!['lastState'] = stateData;

      // Extract POWER1-POWER8 values from the state
      for (int i = 1; i <= device.effectiveChannels; i++) {
        final powerKey = 'POWER$i';
        if (stateData.containsKey(powerKey)) {
          final powerValue = stateData[powerKey];
          _deviceStates[deviceId]![powerKey] = powerValue;
          _addDebugMessage('Extracted from STATE: $powerKey = $powerValue');
        }
      }

      // Extract additional useful information
      if (stateData.containsKey('Uptime')) {
        _deviceStates[deviceId]!['uptime'] = stateData['Uptime'];
      }
      if (stateData.containsKey('Wifi')) {
        final wifi = stateData['Wifi'];
        if (wifi is Map && wifi.containsKey('RSSI')) {
          _deviceStates[deviceId]!['rssi'] = wifi['RSSI'];
        }
      }
      // Capture StatusNET/Gateway info if present for gateway-first ping targets
      if (stateData.containsKey('StatusNET')) {
        final statusNet = stateData['StatusNET'];
        if (statusNet is Map) {
          _deviceStates[deviceId]!['StatusNET'] = Map<String, dynamic>.from(
            statusNet,
          );
          // Also store gateway at top-level for convenience
          final gw = statusNet['Gateway'] ?? statusNet['gateway'];
          if (gw is String && gw.isNotEmpty) {
            _deviceStates[deviceId]!['gateway'] = gw;
          }
        }
      }

      // Inspect for Ping info inside STATE/RESULT payloads too
      _inspectAndRecordPing(deviceId, stateData);

      // FETCH-FIRST: Complete initial state loading if this device was waiting
      if (_devicesWaitingForInitialState.contains(deviceId)) {
        _devicesWaitingForInitialState.remove(deviceId);
        _deviceStates[deviceId]!.remove('waitingForInitialState');

        // Complete the completer to signal that initial state is ready
        final completer = _initialStateCompleters.remove(deviceId);
        if (completer != null && !completer.isCompleted) {
          completer.complete();
          _addDebugMessage(
            '✅ ${device.name} initial state received from physical device (STATE message)',
          );
        }

        // NOW emit the state update to UI (this is the ONLY update for fetch-first)
        _deviceStateControllers[deviceId]?.add(
          Map<String, dynamic>.from(_deviceStates[deviceId]!),
        );
        _addDebugMessage('📤 Emitted initial state to UI for ${device.name}');
      }

      _addDebugMessage(
        'Successfully parsed STATE message for device: ${device.name}',
      );
    } catch (e) {
      _addDebugMessage('Error parsing STATE message: $e');
      // Store as raw payload if parsing fails
      _deviceStates[deviceId]!['lastState'] = payload;
    }
  }

  /// Parse RESULT message for physical button presses and command confirmations
  void _parseResultMessage(String deviceId, String payload, Device device) {
    try {
      // Try to parse as JSON
      final Map<String, dynamic> resultData;
      if (payload.startsWith('{')) {
        resultData = Map<String, dynamic>.from(jsonDecode(payload));
      } else {
        // If not JSON, store as raw payload
        _deviceStates[deviceId]!['lastResult'] = payload;
        return;
      }

      // Store raw result data
      _deviceStates[deviceId]!['lastResult'] = resultData;

      // Check for physical button presses
      if (resultData.containsKey('Button')) {
        final buttonData = resultData['Button'];
        if (buttonData is Map) {
          for (final entry in buttonData.entries) {
            final buttonKey = entry.key;
            final buttonValue = entry.value;
            _addDebugMessage(
              'Physical button press detected: $buttonKey = $buttonValue',
            );

            // Trigger immediate state refresh when physical button is pressed
            Future.delayed(_stateRequestDelay, () {
              requestDeviceStateImmediate(deviceId);
            });
          }
        }
      }

      // Extract POWER state changes from RESULT messages
      for (int i = 1; i <= device.effectiveChannels; i++) {
        final powerKey = 'POWER$i';
        if (resultData.containsKey(powerKey)) {
          final powerValue = resultData[powerKey];
          _updateDeviceStateWithReconciliation(
            deviceId,
            powerKey,
            powerValue.toString(),
          );
          _addDebugMessage(
            'Physical state change detected: $powerKey = $powerValue',
          );
        }
      }

      // Handle single POWER key for single-channel devices
      if (resultData.containsKey('POWER') && device.channels == 1) {
        final powerValue = resultData['POWER'];
        _updateDeviceStateWithReconciliation(
          deviceId,
          'POWER1',
          powerValue.toString(),
        );
        _addDebugMessage(
          'Physical state change detected: POWER1 = $powerValue',
        );
      }

      // Handle Shutter telemetry (Shutter1, Shutter2, etc.)
      _parseShutterTelemetry(deviceId, resultData);

      // FETCH-FIRST: Complete initial state loading if this device was waiting
      // RESULT messages can also contain POWER states (from command responses)
      if (_devicesWaitingForInitialState.contains(deviceId)) {
        // Check if we have at least one POWER state in the result
        bool hasPowerState = false;
        for (int i = 1; i <= device.effectiveChannels; i++) {
          if (resultData.containsKey('POWER$i')) {
            hasPowerState = true;
            break;
          }
        }
        if (!hasPowerState &&
            resultData.containsKey('POWER') &&
            device.channels == 1) {
          hasPowerState = true;
        }

        if (hasPowerState) {
          _devicesWaitingForInitialState.remove(deviceId);
          _deviceStates[deviceId]!.remove('waitingForInitialState');

          // Complete the completer to signal that initial state is ready
          final completer = _initialStateCompleters.remove(deviceId);
          if (completer != null && !completer.isCompleted) {
            completer.complete();
            _addDebugMessage(
              '✅ ${device.name} initial state received from physical device (RESULT message)',
            );
          }

          // NOW emit the state update to UI (this is the ONLY update for fetch-first)
          _deviceStateControllers[deviceId]?.add(
            Map<String, dynamic>.from(_deviceStates[deviceId]!),
          );
          _addDebugMessage('📤 Emitted initial state to UI for ${device.name}');
        }
      }

      _addDebugMessage(
        'Successfully parsed RESULT message for device: ${device.name}',
      );
      // Inspect RESULT payload for Ping info
      _inspectAndRecordPing(deviceId, resultData);
      // Also capture StatusNET from RESULT payloads if present
      if (resultData.containsKey('StatusNET')) {
        final statusNet = resultData['StatusNET'];
        if (statusNet is Map) {
          _deviceStates[deviceId]!['StatusNET'] = Map<String, dynamic>.from(
            statusNet,
          );
          final gw = statusNet['Gateway'] ?? statusNet['gateway'];
          if (gw is String && gw.isNotEmpty) {
            _deviceStates[deviceId]!['gateway'] = gw;
          }
        }
      }
    } catch (e) {
      _addDebugMessage('Error parsing RESULT message: $e');
      // Store as raw payload if parsing fails
      _deviceStates[deviceId]!['lastResult'] = payload;
    }
  }

  /// Parse shutter telemetry from RESULT or STATUS8 messages
  /// Handles Shutter1, Shutter2, etc. in both object and numeric forms
  void _parseShutterTelemetry(String deviceId, Map<String, dynamic> data) {
    try {
      // Check for Shutter1, Shutter2, etc.
      for (int i = 1; i <= 4; i++) {
        final shutterKey = 'Shutter$i';
        if (data.containsKey(shutterKey)) {
          final shutterValue = data[shutterKey];

          // Handle object form: {"Position": 50, "Direction": 1, "Target": 100, "Tilt": 0}
          if (shutterValue is Map<String, dynamic>) {
            final position = shutterValue['Position'];
            final direction = shutterValue['Direction'];
            final target = shutterValue['Target'];
            final tilt = shutterValue['Tilt'];

            // Sanitize position: clamp to 0..100, guard against NaN/Infinity
            int? sanitizedPosition;
            if (position is int) {
              sanitizedPosition = position.clamp(0, 100);
            } else if (position is double && position.isFinite) {
              sanitizedPosition = position.round().clamp(0, 100);
            } else if (position is String) {
              final parsed = int.tryParse(position);
              if (parsed != null) {
                sanitizedPosition = parsed.clamp(0, 100);
              }
            }

            // CRITICAL FIX FOR ISSUE 2: Store FULL shutter object with Direction, Target, Tilt
            // This ensures the widget receives direction data for real-time button glow updates
            // Previously only position was stored, causing direction to be lost
            if (sanitizedPosition != null) {
              // Store as object to preserve Direction, Target, Tilt
              _deviceStates[deviceId]![shutterKey] = {
                'Position': sanitizedPosition,
                'Direction': direction is int ? direction : 0,
                'Target': target is int
                    ? target.clamp(0, 100)
                    : sanitizedPosition,
                'Tilt': tilt is int ? tilt : 0,
              };
              _addDebugMessage(
                '🪟 Shutter $i position updated: $sanitizedPosition% (direction: $direction, target: $target)',
              );

              // Save to persistent cache for instant UI feedback on next app startup
              // CRITICAL: Fire-and-forget (no await) to prevent blocking MQTT processing
              _stateCache
                  .saveShutterPosition(deviceId, i, sanitizedPosition)
                  .catchError((e) {
                    _addDebugMessage('⚠️ Cache write error: $e');
                  });
            }
          }
          // Handle numeric form: just position (e.g., "Shutter1": 50)
          // Store as object for consistency, with direction = 0 (stopped)
          else if (shutterValue is int) {
            final sanitizedPosition = shutterValue.clamp(0, 100);
            _deviceStates[deviceId]![shutterKey] = {
              'Position': sanitizedPosition,
              'Direction': 0, // Assume stopped when only position is provided
              'Target': sanitizedPosition,
              'Tilt': 0,
            };
            _addDebugMessage(
              '🪟 Shutter $i position updated: $sanitizedPosition%',
            );

            // Save to persistent cache (fire-and-forget)
            _stateCache
                .saveShutterPosition(deviceId, i, sanitizedPosition)
                .catchError((e) {
                  _addDebugMessage('⚠️ Cache write error: $e');
                });
          } else if (shutterValue is double && shutterValue.isFinite) {
            final sanitizedPosition = shutterValue.round().clamp(0, 100);
            _deviceStates[deviceId]![shutterKey] = {
              'Position': sanitizedPosition,
              'Direction': 0, // Assume stopped when only position is provided
              'Target': sanitizedPosition,
              'Tilt': 0,
            };
            _addDebugMessage(
              '🪟 Shutter $i position updated: $sanitizedPosition%',
            );

            // Save to persistent cache (fire-and-forget)
            _stateCache
                .saveShutterPosition(deviceId, i, sanitizedPosition)
                .catchError((e) {
                  _addDebugMessage('⚠️ Cache write error: $e');
                });
          } else if (shutterValue is String) {
            final parsed = int.tryParse(shutterValue);
            if (parsed != null) {
              final sanitizedPosition = parsed.clamp(0, 100);
              _deviceStates[deviceId]![shutterKey] = {
                'Position': sanitizedPosition,
                'Direction': 0, // Assume stopped when only position is provided
                'Target': sanitizedPosition,
                'Tilt': 0,
              };
              _addDebugMessage(
                '🪟 Shutter $i position updated: $sanitizedPosition%',
              );

              // Save to persistent cache (fire-and-forget)
              _stateCache
                  .saveShutterPosition(deviceId, i, sanitizedPosition)
                  .catchError((e) {
                    _addDebugMessage('⚠️ Cache write error: $e');
                  });
            }
          }
        }
      }

      // Also check StatusSNS for shutter data (from STATUS8)
      final statusSNS = data['StatusSNS'] as Map<String, dynamic>?;
      if (statusSNS != null) {
        _parseShutterTelemetry(deviceId, statusSNS);
      }
    } catch (e) {
      _addDebugMessage('⚠️ Error parsing shutter telemetry: $e');
    }
  }

  /// Helper: inspect resultData for Ping info and record reachability
  void _inspectAndRecordPing(String deviceId, Map<String, dynamic> resultData) {
    try {
      // Tasmota ping may be an ack: {"Ping":"Done"} or a result map
      if (resultData.containsKey('Ping')) {
        final ping = resultData['Ping'];
        // If ack string (e.g. "Done") -> mark lastPing timestamp but reachability unknown
        if (ping is String) {
          _deviceLastPing[deviceId] = DateTime.now();
          _deviceLastPingReachable[deviceId] = null;
          _addDebugMessage('Ping ACK parsed for $deviceId -> $ping');
          // ack proves device processed command; update lastSeen and complete any pending probe
          _deviceLastSeen[deviceId] = DateTime.now();
          // Treat ack as proof of presence: set online and notify UI
          _deviceStates[deviceId] ??= {};
          _deviceStates[deviceId]!['online'] = true;
          _deviceStates[deviceId]!['health'] = 'ONLINE';
          _deviceStates[deviceId]!['lastPing'] = _deviceLastPing[deviceId]!
              .toIso8601String();
          _deviceStates[deviceId]!['lastPingReachable'] = null;
          _notifyDeviceStateChange(deviceId);
          _completePendingProbe(deviceId, true);
          return;
        }

        if (ping is Map) {
          // find any entry where Reachable is present
          for (final entry in ping.entries) {
            final host = entry.key;
            final data = entry.value;
            if (data is Map && data.containsKey('Reachable')) {
              final reachable = data['Reachable'];
              if (reachable is bool) {
                _deviceLastPing[deviceId] = DateTime.now();
                _deviceLastPingReachable[deviceId] = reachable;
                _addDebugMessage(
                  'Ping parsed for $deviceId -> host=$host reachable=$reachable',
                );
                // consider device responsive and update lastSeen
                _deviceLastSeen[deviceId] = DateTime.now();
                // Update device state to reflect ping-based presence and reachability
                _deviceStates[deviceId] ??= {};
                _deviceStates[deviceId]!['online'] = true;
                _deviceStates[deviceId]!['health'] = 'ONLINE';
                _deviceStates[deviceId]!['lastPing'] =
                    _deviceLastPing[deviceId]!.toIso8601String();
                _deviceStates[deviceId]!['lastPingReachable'] = reachable;
                _notifyDeviceStateChange(deviceId);
                // Complete any pending probe
                _completePendingProbe(deviceId, true);
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      // ignore parse errors
    }
  }

  // (Removed) _selectPingTargetForDevice - not needed for Status 5 probing

  /// (Removed) _selectPingTargetForTopicBase - Status 5 probing does not require an external target.

  /// Immediately notify UI components of device state changes for real-time sync
  void _notifyDeviceStateChange(String deviceId) {
    if (_deviceStateControllers.containsKey(deviceId)) {
      final currentState = _deviceStates[deviceId];
      if (currentState != null) {
        // FETCH-FIRST FIX: Do NOT emit state updates if device is waiting for initial state
        // This prevents flickering by suppressing intermediate state updates
        if (_devicesWaitingForInitialState.contains(deviceId)) {
          _addDebugMessage(
            '⏸️ Suppressing state update for $deviceId - waiting for initial state from physical device',
          );
          return;
        }

        // Create a copy to avoid reference issues
        final stateUpdate = Map<String, dynamic>.from(currentState);

        // Add timestamp for change tracking
        stateUpdate['lastUpdated'] = DateTime.now().millisecondsSinceEpoch;

        // Emit the state change immediately
        _deviceStateControllers[deviceId]!.add(stateUpdate);

        // Persist state to database for multi-device synchronization only when
        // the service is explicitly configured to do so. Default behavior
        // keeps DB as metadata-only and relies on MQTT for live state.
        if (persistRealtimeToDb) {
          _persistDeviceStateToDatabase(deviceId, stateUpdate);
        }

        _addDebugMessage('Notified UI of state change for device: $deviceId');
      }
    }
  }

  /// Persist device state to Supabase database for cross-device synchronization
  Future<void> _persistDeviceStateToDatabase(
    String deviceId,
    Map<String, dynamic> state,
  ) async {
    try {
      // Normalize values for persistence
      final bool online = state['online'] == true;
      final Map<String, dynamic> stateJson = Map<String, dynamic>.from(state);

      // Add to batch queue
      _pendingStatePersistence.add({
        'device_id': deviceId,
        'reported_at': DateTime.now().toIso8601String(),
        'online': online,
        'state_json': stateJson,
      });

      // Start batch timer if not already running
      _statePersistenceBatchTimer ??= Timer(
        const Duration(milliseconds: 500),
        () {
          _processPendingStatePersistence();
        },
      );

      _addDebugMessage(
        'Queued state for batch persistence: $deviceId (batch size: ${_pendingStatePersistence.length})',
      );
    } catch (e) {
      _addDebugMessage('Failed to queue state persistence for $deviceId: $e');
    }
  }

  /// Process pending state persistence in batches for better performance
  Future<void> _processPendingStatePersistence() async {
    if (_pendingStatePersistence.isEmpty) {
      _statePersistenceBatchTimer = null;
      return;
    }

    final batch = List<Map<String, dynamic>>.from(_pendingStatePersistence);
    _pendingStatePersistence.clear();
    _statePersistenceBatchTimer = null;

    try {
      final supabase = Supabase.instance.client;

      // Use upsert with multiple records for better performance
      await supabase.from('device_state').upsert(batch);

      _addDebugMessage(
        '✅ Successfully persisted batch of ${batch.length} device states to database',
      );

      // Also update shutter_states table for shutter devices
      await _updateShutterStates(batch);
    } catch (e) {
      _addDebugMessage(
        '❌ Failed to persist batch of ${batch.length} device states: $e',
      );

      // Retry individual records on batch failure
      for (final record in batch) {
        Future.delayed(const Duration(seconds: 1), () async {
          try {
            final supabase = Supabase.instance.client;
            await supabase.from('device_state').upsert([record]);

            _addDebugMessage(
              '✅ Successfully persisted individual state on retry for device: ${record['device_id']}',
            );

            // Also try to update shutter state for this record
            await _updateShutterStates([record]);
          } catch (retryError) {
            _addDebugMessage(
              '❌ Failed to persist individual state on retry for device ${record['device_id']}: $retryError',
            );
          }
        });
      }
    }
  }

  /// Update shutter_states table for shutter devices in the batch
  Future<void> _updateShutterStates(List<Map<String, dynamic>> batch) async {
    try {
      final supabase = Supabase.instance.client;

      for (final record in batch) {
        final deviceId = record['device_id'] as String;
        final stateJson = record['state_json'] as Map<String, dynamic>?;

        if (stateJson == null) continue;

        // Check if this device has shutter data (Shutter1, Shutter2, etc.)
        for (int i = 1; i <= 4; i++) {
          final shutterKey = 'Shutter$i';
          if (stateJson.containsKey(shutterKey)) {
            final shutterValue = stateJson[shutterKey];

            int? position;
            int? direction;
            int? target;

            // Parse shutter data (can be int, Map, etc.)
            if (shutterValue is int) {
              position = shutterValue.clamp(0, 100);
            } else if (shutterValue is double) {
              position = shutterValue.round().clamp(0, 100);
            } else if (shutterValue is Map<String, dynamic>) {
              final pos = shutterValue['Position'];
              if (pos is int) {
                position = pos.clamp(0, 100);
              } else if (pos is double) {
                position = pos.round().clamp(0, 100);
              }

              final dir = shutterValue['Direction'];
              if (dir is int) {
                direction = dir;
              }

              final tgt = shutterValue['Target'];
              if (tgt is int) {
                target = tgt.clamp(0, 100);
              }
            }

            // Only update if we have valid position data
            if (position != null) {
              try {
                await supabase.rpc(
                  'upsert_shutter_state',
                  params: {
                    'p_device_id': deviceId,
                    'p_position': position,
                    'p_direction': direction ?? 0,
                    'p_target': target ?? position,
                    'p_tilt': null,
                  },
                );

                _addDebugMessage(
                  '✅ Updated shutter_states for device $deviceId: position=$position%',
                );
              } catch (e) {
                _addDebugMessage(
                  '⚠️ Failed to update shutter_states for device $deviceId: $e',
                );
              }
            }
          }
        }
      }
    } catch (e) {
      _addDebugMessage('⚠️ Error updating shutter states: $e');
    }
  }

  /// Complete a pending probe for a device (if any)
  void _completePendingProbe(String deviceId, bool success) {
    final completer = _pendingProbes.remove(deviceId);
    if (completer != null && !completer.isCompleted) {
      try {
        completer.complete(success);
      } catch (_) {}
    }
  }

  /// Periodic health check across all registered devices
  void _checkAllDevicesHealth() {
    // Evaluate health for all devices using the Tasmota-style rules
    for (final entry in _registeredDevices.entries) {
      final deviceId = entry.key;
      final device = entry.value;

      // Run evaluation asynchronously per-device to avoid blocking the periodic timer
      Future.microtask(() async {
        try {
          final report = await _evaluateDeviceHealth(
            device,
            telePeriodSeconds:
                _deviceTelemetryPeriod[deviceId]?.inSeconds ?? 60,
            sleepIntervalSeconds: 0,
            performProbe:
                false, // Disable probing in periodic check for faster evaluation
          );

          // Map report.state to boolean online flag (only ONLINE => true)
          final state = report['state'] as String;
          final online = state == 'ONLINE';
          final connected = online;

          _deviceStates[deviceId] ??= {};
          _deviceStates[deviceId]!['health'] = state;
          _deviceStates[deviceId]!['online'] = online;
          _deviceStates[deviceId]!['connected'] = connected;
          _deviceStates[deviceId]!['lastHealthCheck'] = report['checkedAt'];

          // Notify UI of health status change
          _notifyDeviceStateChange(deviceId);

          _addDebugMessage(
            'Health Eval: $deviceId (${device.name}) -> $state (${report['reason']})',
          );
        } catch (e) {
          _addDebugMessage('Health Eval error for ${device.name}: $e');
        }
      });
    }
  }

  /// Evaluate health for a single device following the user's Tasmota rules.
  Future<Map<String, dynamic>> _evaluateDeviceHealth(
    Device device, {
    int telePeriodSeconds = 60,
    int sleepIntervalSeconds = 0,
    bool performProbe = true,
  }) async {
    final deviceId = _registeredDevices.entries
        .firstWhere(
          (e) => e.value == device,
          orElse: () => MapEntry('', device),
        )
        .key;

    if (deviceId.isEmpty) {
      return {
        'state': 'OFFLINE',
        'checkedAt': DateTime.now().toIso8601String(),
        'lwt': 'Unknown',
        'lastSeenAgo': null,
        'respondedToCmd': false,
        'reason': 'device not registered',
      };
    }

    final lwt = _deviceLWT[deviceId] ?? 'Unknown';
    final lastSeen = _deviceLastSeen[deviceId];
    final lastPing = _deviceLastPing[deviceId];
    final lastPingReachable = _deviceLastPingReachable[deviceId] == true;
    bool responded = false;

    // Optionally perform a single active probe (STATUS 0) and wait up to 3s for response
    if (performProbe) {
      try {
        final probeFuture = _probeDeviceHealth(
          device,
        ).timeout(const Duration(seconds: 3), onTimeout: () => false);
        responded = await probeFuture;
        if (responded) {
          // Update lastSeen to now when probe responded
          _deviceLastSeen[deviceId] = DateTime.now();
        }
      } catch (_) {
        responded = false;
      }
    }

    final checkedAt = DateTime.now();
    // Very aggressive offline detection: 1.2x TelePeriod with minimum of 30 seconds
    // This means devices will be marked offline quickly after missing telemetry
    final freshWindow = (1.2 * telePeriodSeconds) > 30
        ? (1.2 * telePeriodSeconds).toInt()
        : 30;

    // Apply resolution rules in order
    String state;
    String reason;

    final lwtNorm = lwt.toLowerCase();

    // If we have a recent successful ping, treat as ONLINE
    if (lastPing != null && lastPingReachable) {
      final pingAgeSec = checkedAt.difference(lastPing).inSeconds;
      if (pingAgeSec <= (2 * telePeriodSeconds)) {
        state = 'ONLINE';
        reason = 'Recent ping reachable';
        return {
          'state': state,
          'checkedAt': checkedAt.toIso8601String(),
          'lwt': lwt,
          'lastSeenAgo': lastSeen == null
              ? null
              : checkedAt.difference(lastSeen).inMilliseconds,
          'respondedToCmd': responded,
          'reason': reason,
        };
      }
    }

    if (lwtNorm == 'offline' && responded == false) {
      state = 'OFFLINE';
      reason = 'LWT indicates Offline and no probe response';
    } else if (responded == true) {
      state = 'ONLINE';
      reason = 'Device responded to active probe';
    } else if (lastSeen != null &&
        checkedAt.difference(lastSeen).inSeconds <= freshWindow) {
      state = 'ONLINE';
      reason = 'Recent telemetry within freshness window';
    } else if (sleepIntervalSeconds > 0 &&
        lastSeen != null &&
        checkedAt.difference(lastSeen).inSeconds <=
            (sleepIntervalSeconds + 2)) {
      state = 'ASLEEP';
      reason = 'Within deep-sleep grace window';
    } else if (lwtNorm == 'online' &&
        (lastSeen == null ||
            checkedAt.difference(lastSeen).inSeconds > freshWindow)) {
      state = 'STALE';
      reason = 'LWT Online but telemetry is stale';
    } else {
      state = 'OFFLINE';
      reason = 'No LWT/response and telemetry stale or absent';
    }

    final lastSeenAgo = lastSeen == null
        ? null
        : checkedAt.difference(lastSeen).inMilliseconds;

    return {
      'state': state,
      'checkedAt': checkedAt.toIso8601String(),
      'lwt': lwt,
      'lastSeenAgo': lastSeenAgo,
      'respondedToCmd': responded,
      'reason': reason,
    };
  }

  /// Actively probe a device by requesting STATE and waiting for a short response window
  Future<bool> _probeDeviceHealth(Device device) async {
    final deviceId = _registeredDevices.entries
        .firstWhere(
          (e) => e.value == device,
          orElse: () => MapEntry('', device),
        )
        .key;

    if (deviceId.isEmpty) return false;

    // If a test override is provided, allow it to run even when not connected
    if (_probeHandlerOverride != null) {
      try {
        final result = await _probeHandlerOverride!(device);
        return result;
      } catch (e) {
        // fallthrough to normal probing
      }
    }

    if (_connectionState != MqttConnectionState.connected) return false;

    // If a probe is already pending, return its future
    if (_pendingProbes.containsKey(deviceId)) {
      try {
        return await _pendingProbes[deviceId]!.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () => false,
        );
      } catch (_) {
        return false;
      }
    }

    final completer = Completer<bool>();
    _pendingProbes[deviceId] = completer;

    try {
      // If a test override is provided, use it
      if (_probeHandlerOverride != null) {
        try {
          final result = await _probeHandlerOverride!(device);
          // Clean up pending probe
          final pending = _pendingProbes.remove(deviceId);
          if (pending != null && !pending.isCompleted) {
            try {
              pending.complete(result);
            } catch (_) {}
          }
          return result;
        } catch (e) {
          // fallthrough to normal probing
        }
      }
      // Use adaptive timeout: at least 3s, or 2x telemetry period
      final tele = _deviceTelemetryPeriod[deviceId];
      final timeoutMs = (tele != null) ? (tele.inMilliseconds * 2) : 3000;

      // Use Tasmota Status 5 command as presence probe (provides network/status metadata)
      final storedBase = device.tasmotaTopicBase!;

      // Publish probe using the stored canonical topic base. Do NOT attempt
      // to modify the stored case or perform temporary probe subscriptions.
      final statusTopic = 'cmnd/$storedBase/Status';

      // Status 5 provides detailed metadata; publish with '5' as payload
      await _publishMessage(statusTopic, '5');
      _addDebugMessage('Probe published Status 5 to $storedBase');

      // Wait for a response completed in _processDeviceMessage
      var result = false;
      try {
        result = await completer.future.timeout(
          Duration(milliseconds: timeoutMs),
          onTimeout: () => false,
        );
      } catch (_) {
        result = false;
      }

      // If no response and LWT indicates online, retry once before giving up (flaky wifi)
      final lwt = _deviceLWT[deviceId]?.toLowerCase() ?? 'unknown';
      if (!result && lwt == 'online') {
        _addDebugMessage(
          'Probe retry: no response, LWT online -> retrying Status 5 once',
        );
        // Publish Status 5 again
        try {
          await _publishMessage(statusTopic, '5');
        } catch (_) {}

        try {
          result = await Future.any([
            completer.future,
            Future.delayed(Duration(milliseconds: timeoutMs), () => false),
          ]);
        } catch (_) {
          result = false;
        }
      }

      // Clean up pending probe (if not already completed by _completePendingProbe)
      final pending = _pendingProbes.remove(deviceId);
      if (pending != null && !pending.isCompleted) {
        try {
          pending.complete(result);
        } catch (_) {}
      }
      // Do not unsubscribe from STATUSx topics — we subscribe to stat/<base>/#
      // and keep subscriptions active across the session and reconnects.

      return result;
    } catch (e) {
      _addDebugMessage('Probe error for ${device.name}: $e');
      if (!completer.isCompleted) {
        try {
          completer.complete(false);
        } catch (_) {}
      }
      _pendingProbes.remove(deviceId);
      return false;
    }
  }

  /// Perform a single Tasmota-style health check for a topic base.
  ///
  /// Inputs:
  /// - topicBase (e.g., "Hbot_1234")
  /// - telePeriodSeconds: default telemetry period (60)
  /// - sleepIntervalSeconds: deep-sleep interval (0 if not deep sleep)
  ///
  /// Returns a map with fields: state, checkedAt, lwt, lastSeenAgo, respondedToCmd, reason
  Future<Map<String, dynamic>> performTasmotaHealthCheck(
    String topicBase, {
    int telePeriodSeconds = 60,
    int sleepIntervalSeconds = 0,
  }) async {
    if (_client == null || _connectionState != MqttConnectionState.connected) {
      throw Exception('MQTT client not connected');
    }

    // Find registered device by topicBase
    Device? device;
    for (final d in _registeredDevices.values) {
      if (d.tasmotaTopicBase == topicBase) {
        device = d;
        break;
      }
    }

    if (device == null) {
      throw Exception('No registered device with topic base: $topicBase');
    }

    // Publish a probe (do not change subscriptions). The device should reply
    // on stat/<base>/STATUS5 which is already covered by the permanent
    // subscription stat/<base>/#.
    try {
      final statusTopic = 'cmnd/$topicBase/Status';
      await _publishMessage(statusTopic, '5');
      _addDebugMessage('HealthCheck($topicBase): Published Status 5 probe');
    } catch (e) {
      _addDebugMessage('HealthCheck($topicBase): Failed to publish probe: $e');
    }

    // Wait briefly for any responses to be processed by the main message handler
    await Future.delayed(const Duration(seconds: 3));

    // Rely on existing device last-seen and LWT maps to compute health
    final eval = await _evaluateDeviceHealth(
      device,
      telePeriodSeconds: telePeriodSeconds,
      sleepIntervalSeconds: sleepIntervalSeconds,
      performProbe: false,
    );

    return eval;
  }
}
