import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../demo/demo_data.dart';
import '../theme/app_theme.dart';
import '../models/home.dart';
import '../models/room.dart';
import '../models/device.dart';
import '../repos/homes_repo.dart';
import '../repos/rooms_repo.dart';
import '../repos/devices_repo.dart';
import '../repos/device_management_repo.dart';
import '../services/mqtt_device_manager.dart';
import '../services/smart_home_service.dart';
import '../services/device_event_tracker.dart';
import 'package:home_widget/home_widget.dart';
import '../services/home_widget_service.dart';
import '../services/current_home_service.dart';
import '../services/app_lifecycle_manager.dart';
import '../services/room_change_notifier.dart';
import '../widgets/background_image_picker.dart';
import '../widgets/design_system.dart';
import '../models/scene.dart';
import 'homes_screen.dart';
import 'add_device_flow_screen.dart';
import 'notifications_inbox_screen.dart';
import '../services/broadcast_service.dart';
// import '../widgets/ha_dashboard_section.dart';  // Hidden until production-ready
import 'device_control_screen.dart';
import '../l10n/app_strings.dart';

class HomeDashboardScreen extends StatefulWidget {
  final Function(String?)? onHomeNameChanged;

  const HomeDashboardScreen({super.key, this.onHomeNameChanged});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final HomesRepo _homesRepo = HomesRepo();
  final RoomsRepo _roomsRepo = RoomsRepo();
  final DevicesRepo _devicesRepo = DevicesRepo();

  /// MQTT manager singleton instance
  final MqttDeviceManager _mqttManager = MqttDeviceManager();

  /// Smart home service for combined real-time updates
  final SmartHomeService _smartHomeService = SmartHomeService();

  /// Current home service to track selected home
  final CurrentHomeService _currentHomeService = CurrentHomeService();

  List<Home> _homes = [];
  List<Room> _rooms = [];
  List<Device> _devices = [];
  List<Scene> _scenes = [];
  final Set<String> _executingScenes = {};
  Home? _selectedHome;
  String _selectedRoomFilter = 'All';
  bool _isLoading = true;
  bool _hasLoadError = false;
  bool _mqttConnected = false;
  TabController? _tabController;
  Timer? _stateRefreshTimer;
  Timer? _roomChangeDebounceTimer;
  StreamSubscription<void>? _roomChangeSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _authStateSubscription;
  StreamSubscription? _widgetClickedSubscription;
  final List<StreamSubscription> _deviceStateSubscriptions = [];

  // Queue for errors that occur during initialization
  final List<String> _errorQueue = [];

  // New features state variables
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortOption = 'name'; // 'name', 'recent', 'room', 'type'
  bool _isGridView = true; // true = grid view (default per design), false = list view
  bool _hideOfflineDevices = false;

  // Notification badge — hidden until first load completes
  int _unreadNotificationCount = 0;
  bool _notificationBadgeLoaded = false;
  final BroadcastService _broadcastService = BroadcastService();

  // SharedPreferences key for view preference
  static const String _viewPreferenceKey = 'dashboard_view_preference';

  // Safety timeout to prevent _isLoading from being stuck forever (grey screen)
  Timer? _loadingSafetyTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
    _loadViewPreference(); // Load saved view preference
    _loadData(); // Let _loadData handle MQTT initialization
    _loadUnreadNotificationCount(); // Load notification badge

    // Safety net: if loading hasn't completed in 20 seconds, force it off
    _loadingSafetyTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && _isLoading) {
        debugPrint('⚠️ Loading safety timeout hit — forcing _isLoading=false');
        setState(() {
          _isLoading = false;
          _hasLoadError = true;
        });
      }
    });

    // Listen to auth state changes to reload data when user becomes available
    _setupAuthListener();

    // Initialize app lifecycle manager with services
    _initializeLifecycleManager();

    // Listen for room changes from anywhere in the app
    _roomChangeSubscription = RoomChangeNotifier().roomChanges.listen((_) {
      debugPrint('🔔 Room change notification received, debouncing reload...');
      _roomChangeDebounceTimer?.cancel();
      _roomChangeDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        debugPrint('🔔 Debounce elapsed, reloading rooms...');
        _reloadRoomsOnly();
      });
    });

    // Handle home widget launch URIs
    _widgetClickedSubscription = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload rooms when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed, reloading rooms...');
      _reloadRoomsOnly();
    }
  }

  /// Load the saved view preference from SharedPreferences
  Future<void> _loadViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedViewPreference = prefs.getBool(_viewPreferenceKey);
      if (savedViewPreference != null && mounted) {
        setState(() {
          _isGridView = savedViewPreference;
        });
        debugPrint(
          '📱 Loaded view preference: ${_isGridView ? "Grid" : "List"}',
        );
      }
    } catch (e) {
      debugPrint('Error loading view preference: $e');
    }
  }

  /// Load unread broadcast notification count for the bell badge.
  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await _broadcastService.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
          _notificationBadgeLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading unread notification count: $e');
    }
  }

  /// Save the view preference to SharedPreferences
  Future<void> _saveViewPreference(bool isGridView) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_viewPreferenceKey, isGridView);
      debugPrint('💾 Saved view preference: ${isGridView ? "Grid" : "List"}');
    } catch (e) {
      debugPrint('Error saving view preference: $e');
    }
  }

  void _initializeLifecycleManager() {
    // Initialize lifecycle manager with MQTT and SmartHome services
    final lifecycleManager = AppLifecycleManager();
    lifecycleManager.initialize(
      mqttService: _mqttManager.mqttService,
      smartHomeService: _smartHomeService,
    );
  }

  void _setupAuthListener() {
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final user = data.session?.user;

      // If user just signed in and we don't have homes loaded, reload data
      if (event == AuthChangeEvent.signedIn && user != null && _homes.isEmpty) {
        debugPrint('User signed in, reloading data...');
        _loadData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Show any queued errors
    if (_errorQueue.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          for (final error in _errorQueue) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
          _errorQueue.clear();
        }
      });
    }
  }

  Future<void> _retryMqttConnection() async {
    try {
      debugPrint('🔄 Retrying MQTT connection with comprehensive recovery...');

      // Show a transient snackbar to indicate retry started
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('reconnecting')),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Use comprehensive connection state recovery
      final connected = await _mqttManager.mqttService
          .performConnectionStateRecovery();

      if (mounted) {
        setState(() {
          _mqttConnected = connected;
        });
      }

      // Clear any existing snackbars
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      if (connected) {
        debugPrint('✅ MQTT comprehensive recovery successful');

        // Show success message with connection stats
        if (mounted) {
          final stats = _mqttManager.mqttService.connectionStats;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(AppStrings.get('connection_restored')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Devices: ${stats['registered_devices']}, Subscriptions: ${stats['active_subscriptions']}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        debugPrint('❌ MQTT comprehensive recovery failed');

        // Show detailed failure message
        if (mounted) {
          final stats = _mqttManager.mqttService.connectionStats;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(AppStrings.get('connection_failed')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Attempts: ${stats['reconnection_attempts']}/${stats['max_reconnection_attempts']}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  if (stats['last_error_type'] != null)
                    Text(
                      'Error: ${stats['last_error_type']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: AppStrings.get('home_dashboard_diagnose'),
                textColor: Colors.white,
                onPressed: _showMqttDebugInfo,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ MQTT retry error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(AppStrings.get('connection_error')),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: AppStrings.get('home_dashboard_details'),
              textColor: Colors.white,
              onPressed: _showMqttDebugInfo,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer
    _loadingSafetyTimer?.cancel();
    _roomChangeDebounceTimer?.cancel();
    _roomChangeSubscription?.cancel(); // Cancel room change subscription
    _connectionStateSubscription?.cancel();
    _authStateSubscription?.cancel();
    _widgetClickedSubscription?.cancel();
    // Cancel device state subscriptions to prevent memory leaks
    for (final sub in _deviceStateSubscriptions) {
      sub.cancel();
    }
    _deviceStateSubscriptions.clear();
    // Clean up resources
    _tabController?.dispose();
    _stateRefreshTimer?.cancel();
    _searchController.dispose();

    // Clean up MQTT manager and clear all subscriptions
    debugPrint('Cleaning up MQTT manager...');
    try {
      _mqttManager.dispose();
    } catch (e) {
      debugPrint('Error disposing MQTT manager: $e');
    }

    super.dispose();
  }

  /// Reload only rooms data (lightweight refresh for room name changes)
  Future<void> _reloadRoomsOnly() async {
    if (_selectedHome == null) return;

    try {
      debugPrint('🔄 Reloading rooms only...');
      final rooms = await _roomsRepo.listRooms(_selectedHome!.id);

      if (mounted) {
        setState(() {
          _rooms = rooms;
        });
        debugPrint('✅ Rooms reloaded: ${_rooms.map((r) => r.name).join(", ")}');

        // Recreate tab controller with new room names
        _setupTabController();
      }
    } catch (e) {
      debugPrint('❌ Error reloading rooms: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasLoadError = false;
      });

      // Check for authenticated user first with retry mechanism
      String userId;
      if (isDemoMode) {
        userId = 'demo-user-001';
        debugPrint('Demo mode: using demo user');
      } else {
        User? user = Supabase.instance.client.auth.currentUser;

        // If no user, wait a bit for auth state to propagate and retry
        if (user == null) {
          debugPrint('No authenticated user found, waiting for auth state...');
          await Future.delayed(const Duration(milliseconds: 500));
          user = Supabase.instance.client.auth.currentUser;

          // If still no user after waiting, try one more time
          if (user == null) {
            debugPrint('Still no authenticated user, waiting longer...');
            await Future.delayed(const Duration(seconds: 1));
            user = Supabase.instance.client.auth.currentUser;
          }
        }

        if (user == null) {
          throw Exception('No authenticated user after retries');
        }
        userId = user.id;
        debugPrint('Authenticated user found: $userId');
      }

      // Load homes (with timeout to prevent grey screen hang)
      _homes = await _homesRepo.listMyHomes().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏰ listMyHomes timed out after 10s');
          return <Home>[];
        },
      );
      debugPrint(
        'Loaded ${_homes.length} homes: ${_homes.map((h) => h.name).join(', ')}',
      );

      if (_homes.isNotEmpty) {
        // Try to load the previously selected home
        final savedHomeId = await _currentHomeService.getCurrentHomeId();
        if (savedHomeId != null) {
          final matchingHome = _homes
              .where((h) => h.id == savedHomeId)
              .firstOrNull;
          if (matchingHome != null) {
            _selectedHome = matchingHome;
            debugPrint(
              'Restored previously selected home: ${_selectedHome!.name}',
            );
          } else {
            // Saved home ID is invalid, select first home and update storage
            _selectedHome = _homes.first;
            debugPrint(
              'Saved home ID ($savedHomeId) not found, auto-selected first home: ${_selectedHome!.name}',
            );
            await _currentHomeService.setCurrentHomeId(_selectedHome!.id);
          }
        } else {
          _selectedHome = _homes.first;
          debugPrint('Auto-selected first home: ${_selectedHome!.name}');
          // Save this as the current home
          await _currentHomeService.setCurrentHomeId(_selectedHome!.id);
        }

        // Notify parent about home name change
        widget.onHomeNameChanged?.call(_selectedHome!.name);

        // Load rooms, owned devices, and shared devices in parallel (with timeout)
        final futures = await Future.wait([
          _roomsRepo.listRooms(_selectedHome!.id).timeout(
            const Duration(seconds: 10),
            onTimeout: () => <Room>[],
          ),
          _devicesRepo.listDevicesByHome(_selectedHome!.id).timeout(
            const Duration(seconds: 10),
            onTimeout: () => <Device>[],
          ),
          _devicesRepo.listSharedDevices().timeout(
            const Duration(seconds: 10),
            onTimeout: () => <Device>[],
          ),
        ]);

        if (mounted) {
          setState(() {
            _rooms = futures[0] as List<Room>;
            final ownedDevices = futures[1] as List<Device>;
            final sharedDevices = futures[2] as List<Device>;
            // Combine owned and shared devices
            _devices = [...ownedDevices, ...sharedDevices];
          });
          // Register device names for activity tracking
          for (final d in _devices) {
            DeviceEventTracker().registerDevice(d.id, d.deviceName);
          }
          // Update home screen widget with device data
          _updateHomeWidget();
          debugPrint(
            '✅ Rooms loaded and state updated: ${_rooms.map((r) => r.name).join(", ")}',
          );
          debugPrint(
            '✅ Loaded ${(futures[1] as List<Device>).length} owned devices and ${(futures[2] as List<Device>).length} shared devices',
          );
        }

        // Load scenes for quick-action row (non-blocking)
        _smartHomeService.getScenes(_selectedHome!.id).timeout(
          const Duration(seconds: 8),
          onTimeout: () => <Scene>[],
        ).then((scenes) {
          if (mounted) setState(() => _scenes = scenes);
        }).catchError((_) {
          // Scenes failing shouldn't block dashboard
        });

        // Setup tab controller for rooms
        _setupTabController();

        // Initialize MQTT with user and home ID and start connection in
        // background. We must not block the UI first paint on MQTT.
        debugPrint(
          'Initializing MQTT (background) for user: $userId and home: ${_selectedHome!.id}',
        );
        await _mqttManager.initialize(userId, homeId: _selectedHome!.id);

        // Start connection in background using ensureConnected (non-blocking)
        Future.microtask(() async {
          final connected = await _mqttManager.mqttService.ensureConnected();
          if (mounted) {
            setState(() {
              _mqttConnected = connected;
            });
          }

          if (connected) {
            debugPrint('MQTT connected successfully (background)');
            // Register devices after connection established
            await _registerDevicesWithMqtt();
          } else {
            debugPrint('Failed to connect to MQTT (background)');
            // Attempt a retry later, UI remains available
            if (mounted) {
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted && !_mqttConnected) {
                  _retryMqttConnection();
                }
              });
            }
          }
        });

        // Listen to connection state changes
        _connectionStateSubscription = _mqttManager.connectionStateStream.listen((state) {
          if (mounted) {
            setState(() {
              _mqttConnected = state.toString().contains('connected');
            });
          }
        });

        // Registration will happen when background connect completes.
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      _errorQueue.add('Error loading data: $e');
      if (mounted) {
        setState(() {
          _mqttConnected = false;
          _hasLoadError = true;
        });
      }
    } finally {
      _loadingSafetyTimer?.cancel();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerDevicesWithMqtt() async {
    // Safety checks first
    if (!_mqttConnected) {
      debugPrint('Registering devices in background; MQTT not yet connected');
      // Still attempt registration in background; EnhancedMqttService will
      // perform connection as needed. Do not block UI.
    }

    if (_selectedHome == null) {
      debugPrint('Cannot register devices: No home selected');
      return;
    }

    try {
      // Convert DeviceWithState to Device objects for MQTT registration
      final List<Device> devicesList = _devices
          .where(
            (d) => d.tasmotaTopicBase != null && d.tasmotaTopicBase!.isNotEmpty,
          )
          .toList();

      if (devicesList.isEmpty) {
        debugPrint('No controllable devices found');
        return;
      }

      debugPrint('Registering ${devicesList.length} devices with MQTT');

      // CRITICAL FIX: Register devices in batches and WAIT for completion
      // before setting up state listeners. This ensures cached states are
      // available when watchCombinedDeviceState is called, preventing flicker.
      const batchSize = 5;
      Future.microtask(() async {
        // Ensure the MQTT service is making a connection attempt
        await _mqttManager.mqttService.ensureConnected();

        for (var i = 0; i < devicesList.length; i += batchSize) {
          final end = (i + batchSize < devicesList.length)
              ? i + batchSize
              : devicesList.length;
          final batch = devicesList.sublist(i, end);

          try {
            await _mqttManager.registerDevices(batch);
            debugPrint('Registered batch of ${batch.length} devices');
          } catch (e) {
            debugPrint('Error registering device batch: $e');
          }

          // Small delay between batches
          if (end < devicesList.length) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }

        debugPrint('All devices registered with MQTT');

        // ✅ CRITICAL FIX: Set up combined state change listeners AFTER registration
        // This ensures cached states are loaded and available when watchCombinedDeviceState
        // is called, preventing the OFF flash/flicker on app startup
        // Cancel any existing device state subscriptions before creating new ones
        for (final sub in _deviceStateSubscriptions) {
          sub.cancel();
        }
        _deviceStateSubscriptions.clear();

        for (final device in devicesList) {
          final sub = _smartHomeService.watchCombinedDeviceState(device.id).listen((state) {
            if (mounted) {
              debugPrint(
                '\ud83d\udcf1 Combined state update for ${device.name}: ${state['source']} - ${state['POWER1'] ?? 'N/A'}',
              );
              setState(() {
                // State update will trigger UI refresh via _getDeviceState
              });
              // Also update home screen widget with latest states
              _updateHomeWidget();
            }
          });
          _deviceStateSubscriptions.add(sub);
        }

        // Request initial state for all devices after registration and listener setup
        // This ensures the dashboard shows current device states immediately
        debugPrint(
          '🔄 Requesting initial state for all ${devicesList.length} devices',
        );
        await _requestInitialDeviceStates(devicesList);

        // Process any pending widget toggle action
        _processPendingWidgetToggle();
      });
    } catch (e, stack) {
      debugPrint('Error registering devices with MQTT: $e');
      debugPrint('Stack trace: $stack');
      _errorQueue.add('Error connecting to devices');

      // Schedule error message for next frame
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.get('home_dashboard_error_connecting_to_devices')),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: AppStrings.get('home_dashboard_retry'),
                  textColor: Colors.white,
                  onPressed: () => _registerDevicesWithMqtt(),
                ),
              ),
            );
          }
        });
      }
    }
  }

  /// Request initial state for all devices to populate dashboard
  /// OPTIMIZED: Single request per device, parallel execution for faster loading
  Future<void> _requestInitialDeviceStates(List<Device> devices) async {
    try {
      debugPrint(
        '🔄 Dashboard: Starting OPTIMIZED initial state request for ${devices.length} devices',
      );

      // OPTIMIZATION: Request all devices in parallel with minimal delay
      // Since we now load fresh data from database, we only need one MQTT request
      // to update to real-time state, not multiple redundant requests
      final futures = <Future>[];

      for (final device in devices) {
        // Add small stagger (10ms per device) to avoid overwhelming broker
        final delay = Duration(milliseconds: futures.length * 10);

        futures.add(
          Future.delayed(delay, () async {
            try {
              debugPrint(
                '🔄 Dashboard: Requesting state for ${device.name} (${device.deviceType})',
              );

              // Single immediate state request - database already has fresh data
              await _mqttManager.requestDeviceStateImmediate(device.id);

              debugPrint('✅ State requested for ${device.name}');
            } catch (e) {
              debugPrint(
                '❌ Error requesting state for device ${device.name}: $e',
              );
              // Continue with other devices even if one fails
            }
          }),
        );
      }

      // Wait for all requests to complete (with timeout)
      await Future.wait(futures).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏰ Initial state request timeout - continuing anyway');
          return [];
        },
      );

      debugPrint('✅ Initial state requested for all ${devices.length} devices');

      // Start periodic refresh after initial state request
      _startPeriodicStateRefresh();
    } catch (e) {
      debugPrint('❌ Error requesting initial device states: $e');
    }
  }

  /// Start periodic state refresh to keep dashboard in sync
  void _startPeriodicStateRefresh() {
    // Cancel existing timer if any
    _stateRefreshTimer?.cancel();

    // Refresh state every 10 seconds to ensure dashboard stays in sync
    // This is more aggressive to catch external changes (physical switches, other apps)
    _stateRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _mqttConnected) {
        final controllableDevices = _devices
            .where(
              (d) =>
                  d.tasmotaTopicBase != null && d.tasmotaTopicBase!.isNotEmpty,
            )
            .toList();

        if (controllableDevices.isNotEmpty) {
          debugPrint(
            '🔄 Periodic state refresh for ${controllableDevices.length} devices',
          );

          // Request state for all devices (especially important for shutters)
          for (final device in controllableDevices) {
            _mqttManager.requestDeviceState(device.id);

            // Extra request for shutters to ensure position is up-to-date
            if (device.deviceType == DeviceType.shutter) {
              Future.delayed(const Duration(milliseconds: 100), () {
                _mqttManager.requestDeviceStateImmediate(device.id);
              });
            }
          }
        }
      }
    });

    debugPrint('✅ Started periodic state refresh (every 10 seconds)');
  }

  /// Manually refresh device states
  Future<void> _refreshDeviceStates() async {
    if (!_mqttConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to refresh devices. Please check your connection.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final controllableDevices = _devices
          .where((d) => d.tasmotaTopicBase != null)
          .map((d) => d.id)
          .toList();

      if (controllableDevices.isNotEmpty) {
        await _mqttManager.requestMultipleDeviceStates(controllableDevices);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppStrings.get("dashboard_refreshed")} ${controllableDevices.length} ${AppStrings.get("common_devices")}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error refreshing device states: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('home_dashboard_unable_to_refresh_devices_please_try_again')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setupTabController() {
    // Save the current tab index before disposing
    final currentIndex = _tabController?.index ?? 0;

    _tabController?.dispose();
    final tabs = ['All', ..._rooms.map((room) => room.name)];

    debugPrint(
      '🔄 Setting up tab controller with rooms: ${_rooms.map((r) => r.name).join(", ")}',
    );

    // Determine the initial index to restore the user's previous tab selection
    int initialIndex = 0;
    if (currentIndex < tabs.length) {
      // If the previous index is still valid, use it
      initialIndex = currentIndex;
    } else if (_selectedRoomFilter != 'All') {
      // If the previous room filter is still valid, find its index
      try {
        final roomIndex = _rooms.indexWhere(
          (r) => r.name == _selectedRoomFilter,
        );
        if (roomIndex != -1) {
          initialIndex = roomIndex + 1; // +1 because "All" is at index 0
        }
      } catch (e) {
        debugPrint('Could not restore previous tab: $_selectedRoomFilter');
      }
    }

    _tabController = TabController(
      length: tabs.length,
      vsync: this,
      initialIndex: initialIndex,
    );

    // Update the room filter to match the initial index
    if (initialIndex == 0) {
      _selectedRoomFilter = 'All';
    } else if (initialIndex - 1 < _rooms.length) {
      _selectedRoomFilter = _rooms[initialIndex - 1].name;
    }

    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        setState(() {
          if (_tabController!.index == 0) {
            _selectedRoomFilter = 'All';
          } else {
            _selectedRoomFilter = _rooms[_tabController!.index - 1].name;
          }
        });
      }
    });
  }

  List<Device> get _filteredDevices {
    List<Device> filtered = _devices;

    // Filter by room
    if (_selectedRoomFilter != 'All') {
      try {
        final room = _rooms.firstWhere((r) => r.name == _selectedRoomFilter);
        filtered = filtered
            .where((device) => device.roomId == room.id)
            .toList();
      } catch (e) {
        debugPrint(
          'Could not find room for filter: $_selectedRoomFilter, showing all devices',
        );
        // If room not found, show all devices (don't filter)
      }
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((device) {
        return device.deviceName.toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
      }).toList();
    }

    // Note: Offline device filtering is handled in the UI layer
    // where we have access to real-time device state streams

    // Sort devices
    switch (_sortOption) {
      case 'name':
        filtered.sort((a, b) => a.deviceName.compareTo(b.deviceName));
        break;
      case 'recent':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'room':
        filtered.sort((a, b) {
          final roomA = _getRoomName(a.roomId);
          final roomB = _getRoomName(b.roomId);
          return roomA.compareTo(roomB);
        });
        break;
      case 'type':
        filtered.sort(
          (a, b) => a.deviceType.toString().compareTo(b.deviceType.toString()),
        );
        break;
    }

    return filtered;
  }

    String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return '${AppStrings.get("greeting_good_night")} 🌙';
    if (hour < 12) return '${AppStrings.get("greeting_good_morning")} ☀️';
    if (hour < 18) return AppStrings.get("greeting_good_afternoon");
    if (hour < 22) return AppStrings.get("greeting_good_evening");
    return '${AppStrings.get("greeting_good_night")} 🌙';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Background image
          if (_selectedHome?.backgroundImageUrl != null &&
              _selectedHome!.backgroundImageUrl!.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: _selectedHome!.backgroundImageUrl!.startsWith('assets/')
                    ? Image.asset(
                        _selectedHome!.backgroundImageUrl!,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(_selectedHome!.backgroundImageUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
              ),
            ),
          Column(
            children: [
              _buildHeader(),
              if (isDemoMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  color: HBotColors.primary.withOpacity(0.10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_outline, size: 14, color: HBotColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Demo Mode — data is simulated',
                        style: TextStyle(
                          fontFamily: 'Readex Pro',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: HBotColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_homes.isNotEmpty && _rooms.isNotEmpty)
                Container(
                  key: ValueKey('tabs_${_rooms.map((r) => r.id).join("_")}'),
                  margin: const EdgeInsets.only(top: HBotSpacing.space3),
                  child: _buildRoomPills(),
                ),
              // Scenes quick-action row
              if (_homes.isNotEmpty && _scenes.isNotEmpty)
                _buildScenesRow(),
              // Devices section header with grid/list toggle
              if (_homes.isNotEmpty && _filteredDevices.isNotEmpty)
                _buildDevicesSectionHeader(),
              Expanded(child: _buildContent()),
            ],
          ),
          // FAB
          if (_homes.isNotEmpty)
            Positioned(
              right: HBotSpacing.space5,
              bottom: HBotSpacing.space5,
              child: FloatingActionButton(
                backgroundColor: HBotColors.primary,
                foregroundColor: Colors.white,
                onPressed: _showAddMenu,
                child: const Icon(Icons.add, size: 28),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    // Determine user's name for the hero card
    final user = Supabase.instance.client.auth.currentUser;
    final String userName = user?.userMetadata?['display_name'] as String?
        ?? user?.userMetadata?['full_name'] as String?
        ?? user?.email?.split('@').first
        ?? 'Home';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HBotSpacing.space5,
        HBotSpacing.space3,
        HBotSpacing.space5,
        HBotSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar: Logo left, notification bell + settings right
          Row(
            children: [
              // HBot long logo
              GestureDetector(
                onTap: _homes.length > 1 ? _showHomeSelector : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/branding/hbot_logo_text.png',
                      height: 24,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.home,
                        color: HBotColors.primary,
                        size: 28,
                      ),
                    ),
                    if (_homes.length > 1) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: HBotColors.textMuted,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              // MQTT indicator
              if (!_mqttConnected)
                Padding(
                  padding: const EdgeInsets.only(right: HBotSpacing.space2),
                  child: hbotStatusDot(color: HBotColors.error, size: 8),
                ),
              // Notification bell — glass icon button
              HBotIconButton(
                icon: Icons.notifications_outlined,
                badge: (_notificationBadgeLoaded && _unreadNotificationCount > 0)
                    ? const HBotNotifDot()
                    : null,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsInboxScreen(),
                    ),
                  );
                  _loadUnreadNotificationCount();
                },
              ),
              const SizedBox(width: 8),
              // Settings — glass icon button with popup
              _buildSettingsButton(),
            ],
          ),

          const SizedBox(height: HBotSpacing.space4),

          // HERO CARD — full-width gradient card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(HBotSpacing.space5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment(-1, -1),
                end: Alignment(1, 1),
                colors: [Color(0xFF1070AD), Color(0xFF0883FD), Color(0xFF2FB8EC)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0883FD).withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative radial glow circle top-right
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text(
                      _greeting,
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // "{User name}'s Home" title
                    Text(
                      isDemoMode ? 'Demo Home' : "$userName's Home",
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    // Stats row — frosted stat cards
                    Row(
                      children: [
                        _buildHeroStatCard(
                          '${_devices.length}',
                          AppStrings.get("dashboard_device_count_plural"),
                        ),
                        const SizedBox(width: HBotSpacing.space3),
                        _buildHeroStatCard(
                          '${_rooms.length}',
                          'Rooms',
                        ),
                        const SizedBox(width: HBotSpacing.space3),
                        _buildHeroStatCard(
                          _mqttConnected ? '${_scenes.length}' : '!',
                          _mqttConnected ? 'Scenes' : 'Offline',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Settings glass icon button with popup menu
  Widget _buildSettingsButton() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      color: HBotColors.sheetBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HBotColors.glassBorder, width: 1),
      ),
      onSelected: (v) {
        switch (v) {
          case 'add_device': _showAddMenu(); break;
          case 'background': _showHomeBackgroundDialog(); break;
          case 'manage_homes': _showHomeSelector(); break;
          case 'filter': _showOptionsMenu(); break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'add_device',
          child: ListTile(leading: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 20),
            title: Text(AppStrings.get('add_device'), style: const TextStyle(color: Colors.white, fontSize: 14)), contentPadding: EdgeInsets.zero, dense: true)),
        PopupMenuItem(value: 'filter',
          child: ListTile(leading: const Icon(Icons.tune, color: Colors.white70, size: 20),
            title: Text(AppStrings.get('home_dashboard_filter_and_sort'), style: const TextStyle(color: Colors.white, fontSize: 14)), contentPadding: EdgeInsets.zero, dense: true)),
        PopupMenuItem(value: 'background',
          child: ListTile(leading: const Icon(Icons.wallpaper_outlined, color: Colors.white70, size: 20),
            title: Text(AppStrings.get('background'), style: const TextStyle(color: Colors.white, fontSize: 14)), contentPadding: EdgeInsets.zero, dense: true)),
        PopupMenuItem(value: 'manage_homes',
          child: ListTile(leading: const Icon(Icons.home_work_outlined, color: Colors.white70, size: 20),
            title: Text(AppStrings.get('manage_homes'), style: const TextStyle(color: Colors.white, fontSize: 14)), contentPadding: EdgeInsets.zero, dense: true)),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: HBotColors.glassBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HBotColors.glassBorder, width: 1),
        ),
        child: const Icon(Icons.settings_outlined, size: 20, color: HBotColors.textMuted),
      ),
    );
  }

  /// Frosted stat card for hero card — value 18px/700, label 11px
  Widget _buildHeroStatCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHomeBackgroundDialog() {
    if (_selectedHome == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HBotColors.sheetBackground,
          title: Text(AppStrings.get('dashboard_background')),
          content: SingleChildScrollView(
            child: BackgroundImagePicker(
              currentImageUrl: _selectedHome!.backgroundImageUrl,
              userId: user.id,
              type: 'home',
              entityId: _selectedHome!.id,
              onImageSelected: (imageUrl) async {
                try {
                  await _homesRepo.updateHomeBackgroundImage(
                    _selectedHome!.id,
                    imageUrl,
                  );

                  // Reload homes to get updated data
                  await _loadData();

                  if (mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${AppStrings.get("error_update_background")}: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.get('close')),
            ),
          ],
        );
      },
    );
  }

  /// Horizontal scrollable room pills (Pixel's design)
  Widget _buildRoomPills() {
    if (_tabController == null) return const SizedBox.shrink();

    final tabs = [AppStrings.get('home_dashboard_all'), ..._rooms.map((r) => r.name)];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isActive = _tabController!.index == index;
          return HBotPillTab(
            label: tabs[index],
            isActive: isActive,
            onTap: () {
              _tabController!.animateTo(index);
              setState(() {
                if (index == 0) {
                  _selectedRoomFilter = 'All';
                } else {
                  _selectedRoomFilter = _rooms[index - 1].name;
                }
              });
            },
          );
        },
      ),
    );
  }

  /// Horizontal scrollable scenes quick-action chips (Pixel's design)
  Widget _buildScenesRow() {
    // Scene icon/gradient mapping
    IconData sceneIcon(Scene s, int index) {
      if (s.iconCode != null) {
        return IconData(s.iconCode!, fontFamily: 'MaterialIcons');
      }
      final icons = [
        Icons.wb_sunny_rounded,
        Icons.shield_rounded,
        Icons.nightlight_round,
        Icons.power_settings_new_rounded,
      ];
      return icons[index % icons.length];
    }

    return Container(
      margin: const EdgeInsets.only(top: HBotSpacing.space3),
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
        itemCount: _scenes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final scene = _scenes[index];
          final isExecuting = _executingScenes.contains(scene.id);
          return GestureDetector(
            onTap: isExecuting
                ? null
                : () async {
                    setState(() => _executingScenes.add(scene.id));
                    try {
                      await _smartHomeService.runScene(scene.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${scene.name} executed'),
                            backgroundColor: HBotColors.primary,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to run ${scene.name}'),
                            backgroundColor: HBotColors.error,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _executingScenes.remove(scene.id));
                      }
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: HBotColors.glassBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HBotColors.glassBorder, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isExecuting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(HBotColors.primary),
                      ),
                    )
                  else
                    Icon(
                      sceneIcon(scene, index),
                      size: 14,
                      color: HBotColors.primary,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    scene.name,
                    style: const TextStyle(
                      fontFamily: 'Readex Pro',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Devices section header with label and grid/list toggle (Pixel's design)
  Widget _buildDevicesSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HBotSpacing.space5,
        HBotSpacing.space4,
        HBotSpacing.space5,
        HBotSpacing.space1,
      ),
      child: Row(
        children: [
          const HBotSectionLabel('DEVICES'),
          const Spacer(),
          GestureDetector(
            onTap: () {
              final newValue = !_isGridView;
              setState(() => _isGridView = newValue);
              _saveViewPreference(newValue);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: HBotColors.glassBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HBotColors.glassBorder, width: 1),
              ),
              child: Icon(
                _isGridView ? Icons.grid_view_rounded : Icons.view_list_rounded,
                size: 18,
                color: HBotColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: HBotColors.primary),
            const SizedBox(height: 16),
            Text(
              AppStrings.get('loading'),
              style: const TextStyle(
                color: HBotColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasLoadError && _homes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: HBotColors.textMuted),
              const SizedBox(height: 16),
              Text(
                AppStrings.get('error_loading_data'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.get('check_connection_retry'),
                style: const TextStyle(
                  fontSize: 14,
                  color: HBotColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasLoadError = false;
                  });
                  _loadData();
                },
                icon: const Icon(Icons.refresh),
                label: Text(AppStrings.get('retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_homes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.home_outlined,
        title: AppStrings.get('no_homes_title'),
        subtitle: AppStrings.get('no_homes_subtitle'),
        actionText: AppStrings.get('create_new_home'),
        onAction: _showAddMenu,
      );
    }

    if (_filteredDevices.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(
              icon: Icons.devices_outlined,
              title: _searchQuery.isNotEmpty
                  ? AppStrings.get('search')
                  : AppStrings.get('no_devices_title'),
              subtitle: AppStrings.get('no_devices_subtitle'),
              actionText: AppStrings.get('add_device'),
              onAction: _showAddMenu,
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        // Native device grid or list
        if (_isGridView)
          _buildDeviceGridSliver()
        else
          _buildDeviceListSliver(),
      ],
    );
  }

  Widget _buildDeviceGridSliver() {
    return SliverPadding(
      padding: const EdgeInsets.only(
        left: HBotSpacing.space4,
        right: HBotSpacing.space4,
        top: HBotSpacing.space4,
        bottom: 80,
      ),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: HBotSpacing.space3,
          crossAxisSpacing: HBotSpacing.space3,
          childAspectRatio: 0.95,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildDeviceCardWrapper(_filteredDevices[index], isGridView: true),
          childCount: _filteredDevices.length,
        ),
      ),
    );
  }

  Widget _buildDeviceListSliver() {
    return SliverPadding(
      padding: const EdgeInsets.only(
        left: HBotSpacing.space4,
        right: HBotSpacing.space4,
        top: HBotSpacing.space4,
        bottom: 80,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: HBotSpacing.space3),
            child: _buildDeviceCardWrapper(_filteredDevices[index]),
          ),
          childCount: _filteredDevices.length,
        ),
      ),
    );
  }

  Widget _buildDeviceCardWrapper(Device device, {bool isGridView = false}) {
    // Wrapper to handle offline device filtering with real-time state
    return StreamBuilder<Map<String, dynamic>>(
      stream: _smartHomeService.watchCombinedDeviceState(device.id),
      builder: (context, snapshot) {
        // Check if device should be hidden when offline filter is enabled
        if (_hideOfflineDevices && snapshot.hasData) {
          final merged = snapshot.data;
          bool isOnline = false;

          if (merged != null && merged.containsKey('online')) {
            final online = merged['online'];
            if (online is bool) {
              isOnline = online;
            } else if (online is String) {
              isOnline =
                  online.toLowerCase() == 'online' ||
                  online.toLowerCase() == 'true';
            }
          }

          // Hide offline devices
          if (!isOnline) {
            return const SizedBox.shrink();
          }
        }

        return _buildDeviceCard(device, isGridView: isGridView);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: HBotColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: HBotColors.primary),
            ),
            const SizedBox(height: HBotSpacing.space5),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: HBotSpacing.space2),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 14,
                color: HBotColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HBotSpacing.space6),
            SizedBox(
              height: 52,
              child: Container(
                decoration: hbotPrimaryButtonDecoration(),
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: HBotSpacing.space6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: HBotRadius.mediumRadius,
                    ),
                  ),
                  child: Text(actionText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(Device device, {bool isGridView = false}) {
    // Use combined realtime stream so UI prefers MQTT over stale DB values
    return StreamBuilder<Map<String, dynamic>>(
      stream: _smartHomeService.watchCombinedDeviceState(device.id),
      builder: (context, snapshot) {
        final merged = snapshot.data;

        final isControllable =
            device.tasmotaTopicBase != null &&
            device.tasmotaTopicBase!.isNotEmpty;

        // Determine online/health using merged state (MQTT authoritative)
        // When no MQTT data yet (merged == null), default to true to avoid
        // false "offline" flicker during the initial MQTT connection window.
        // The MQTT status dot in the app bar already signals disconnection.
        bool isOnline = merged == null ? true : (device.online ?? false);
        String? health;
        DateTime? lastSeen;
        int telePeriod = 60;
        bool deviceState = false;
        int shutterPosition = 0; // For shutter devices
        int shutterDirection =
            0; // For shutter direction: 0=stopped, 1=opening, -1=closing

        // FETCH-FIRST: Check if device is waiting for initial state from physical device
        bool waitingForInitialState = false;
        if (merged != null && merged.containsKey('waitingForInitialState')) {
          waitingForInitialState = merged['waitingForInitialState'] == true;
        }

        if (merged != null) {
          health = merged['health'] as String?;
          if (merged.containsKey('lastSeen')) {
            final ls = merged['lastSeen'];
            if (ls is int) lastSeen = DateTime.fromMillisecondsSinceEpoch(ls);
            if (ls is String) {
              try {
                lastSeen = DateTime.parse(ls);
              } catch (_) {}
            }
          }
          if (merged.containsKey('online')) {
            final o = merged['online'];
            if (o is bool) isOnline = o;
            if (o is String) {
              isOnline =
                  o.toLowerCase() == 'online' || o.toLowerCase() == 'true';
            }
          }

          final t = merged['TelePeriod'];
          if (t is int) telePeriod = t;

          // Branch: shutters vs relays/dimmers
          if (device.deviceType == DeviceType.shutter) {
            // For shutters: get position and direction from merged state (Shutter1)
            final shutterData = merged['Shutter1'];
            if (shutterData is int) {
              shutterPosition = shutterData.clamp(0, 100);
            } else if (shutterData is double) {
              shutterPosition = shutterData.round().clamp(0, 100);
            } else if (shutterData is String) {
              shutterPosition = int.tryParse(shutterData)?.clamp(0, 100) ?? 0;
            } else if (shutterData is Map<String, dynamic>) {
              // Handle object form: {"Position": 50, "Direction": 1, ...}
              final pos = shutterData['Position'];
              if (pos is int) {
                shutterPosition = pos.clamp(0, 100);
              } else if (pos is double) {
                shutterPosition = pos.round().clamp(0, 100);
              } else if (pos is String) {
                shutterPosition = int.tryParse(pos)?.clamp(0, 100) ?? 0;
              }

              // Extract direction for blue glow indicator
              final dir = shutterData['Direction'];
              if (dir is int) {
                shutterDirection = dir;
              }
            }
            debugPrint(
              '📊 Dashboard: ${device.name} position from merged state: $shutterPosition%, direction: $shutterDirection',
            );
          } else {
            // For relays/dimmers: compute device power state from merged (MQTT only)
            if (device.effectiveChannels > 1) {
              for (int i = 1; i <= device.effectiveChannels; i++) {
                final p = merged['POWER$i'];
                if (p == 'ON' || p == true) {
                  deviceState = true;
                  break;
                }
              }
            } else {
              final p1 = merged['POWER1'];
              final p = merged['POWER'];
              deviceState = p1 == 'ON' || p1 == true || p == 'ON' || p == true;
            }
          }
        } else {
          // If no merged MQTT data, try manager cached MQTT snapshot as best-effort
          final mqttState = _mqttManager.getDeviceState(device.id);
          if (mqttState != null) {
            if (device.deviceType == DeviceType.shutter) {
              // For shutters: get position from Shutter1
              shutterPosition = _mqttManager.getShutterPosition(device.id, 1);
            } else {
              // For relays/dimmers: compute power state
              if (device.effectiveChannels > 1) {
                for (int i = 1; i <= device.effectiveChannels; i++) {
                  final p = mqttState['POWER$i'];
                  if (p == 'ON' || p == true) {
                    deviceState = true;
                    break;
                  }
                }
              } else {
                final p1 = mqttState['POWER1'];
                final p = mqttState['POWER'];
                deviceState =
                    p1 == 'ON' || p1 == true || p == 'ON' || p == true;
              }
            }
          }
        }

        // TTL calculation for freshness (used if health not explicit)
        final ttlSecs = (telePeriod * 2.5).clamp(60, 300).toInt();
        if (health == null &&
            merged != null &&
            merged.containsKey('lastSeen')) {
          if (lastSeen != null) {
            final fresh =
                DateTime.now().difference(lastSeen) <
                Duration(seconds: ttlSecs);
            if (fresh) isOnline = true;
          }
        }

        // Glass card wrapper for Pixel's design
        final bool isActive = isOnline && (deviceState || (device.deviceType == DeviceType.shutter && shutterPosition > 0));
        return GestureDetector(
          onTap: () => _navigateToDeviceControl(device),
          child: HBotCard(
            borderRadius: 18,
            borderColor: isActive ? HBotColors.glassBorderActive : null,
            padding: isGridView
                ? const EdgeInsets.all(12)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: isGridView
                ? _buildGridCardContent(
                    device,
                    deviceState,
                    shutterPosition,
                    isOnline,
                    isControllable,
                    merged,
                    shutterDirection,
                    waitingForInitialState,
                  )
                : Row(
                    children: [
                      // Device icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isActive
                              ? HBotColors.primary.withOpacity(0.08)
                              : HBotColors.glassBackground,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _getDeviceIcon(device.deviceType),
                          color: isActive ? HBotColors.primary : HBotColors.textMuted,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Device name + status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              device.deviceName,
                              style: const TextStyle(
                                fontFamily: 'Readex Pro',
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOnline ? (deviceState ? 'On' : 'Off') : 'Offline',
                              style: TextStyle(
                                fontFamily: 'Readex Pro',
                                fontSize: 12,
                                color: isOnline ? HBotColors.textMuted : HBotColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right side: controls
                      device.deviceType == DeviceType.shutter
                          ? _buildShutterControls(
                              device,
                              shutterPosition,
                              shutterDirection,
                              isControllable,
                              isOnline,
                            )
                          : waitingForInitialState
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(HBotColors.primary),
                                  ),
                                )
                              : SizedBox(
                                  width: 56,
                                  height: 30,
                                  child: Switch(
                                    value: deviceState,
                                    onChanged: isControllable && _mqttConnected && isOnline
                                        ? (value) => _toggleDevice(device, value)
                                        : null,
                                    activeColor: HBotColors.primary,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildGridCardContent(
    Device device,
    bool deviceState,
    int shutterPosition,
    bool isOnline,
    bool isControllable,
    Map<String, dynamic>? merged,
    int shutterDirection,
    bool waitingForInitialState,
  ) {
    final bool isActive = isOnline && (deviceState || (device.deviceType == DeviceType.shutter && shutterPosition > 0));
    final canControl = isControllable && _mqttConnected && isOnline;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: device icon + toggle/shutter arrows
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device icon container (44x44, radius 14) with offline red dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? HBotColors.primary.withOpacity(0.08)
                        : HBotColors.glassBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getDeviceIcon(device.deviceType),
                    color: isActive ? HBotColors.primary : HBotColors.textMuted,
                    size: 22,
                  ),
                ),
                if (!isOnline)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: hbotStatusDot(color: HBotColors.error, size: 8),
                  ),
              ],
            ),
            // Shutter: UP / DOWN labeled buttons
            if (device.deviceType == DeviceType.shutter)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildShutterMiniBtn(
                    label: 'UP',
                    enabled: canControl && shutterPosition < 100,
                    onTap: () => _controlShutter(device, 'open'),
                  ),
                  const SizedBox(height: 5),
                  _buildShutterMiniBtn(
                    label: 'DOWN',
                    enabled: canControl && shutterPosition > 0,
                    onTap: () => _controlShutter(device, 'close'),
                  ),
                ],
              )
            else if (waitingForInitialState)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(HBotColors.primary),
                ),
              )
            else
              SizedBox(
                width: 48,
                height: 28,
                child: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: deviceState,
                    onChanged: canControl
                        ? (value) => _toggleDevice(device, value)
                        : null,
                    activeColor: HBotColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        ),
        // Bottom section: device name + status
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.deviceName,
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              device.deviceType == DeviceType.shutter
                  ? (isOnline ? '$shutterPosition%' : 'Offline')
                  : (isOnline ? (deviceState ? 'On' : 'Off') : 'Offline'),
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: device.deviceType == DeviceType.shutter && isOnline
                    ? HBotColors.primary
                    : (isOnline ? HBotColors.textMuted : HBotColors.error),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    debugPrint('🏠 Widget URI received: $uri');

    if (uri.host == 'toggle') {
      final deviceId = uri.queryParameters['deviceId'];
      final newState = uri.queryParameters['state'];
      if (deviceId != null && newState != null) {
        // Wait a moment for MQTT to be ready, then send the command
        Future.delayed(const Duration(milliseconds: 500), () {
          _executeWidgetToggle(deviceId, newState == 'ON');
        });
      }
    } else if (uri.host == 'device') {
      // Navigate to specific device
      final deviceId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
      if (deviceId != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          final device = _devices.where((d) => d.id == deviceId).firstOrNull;
          if (device != null) {
            _navigateToDeviceControl(device);
          }
        });
      }
    }
  }

  Future<void> _executeWidgetToggle(String deviceId, bool on) async {
    debugPrint('🏠 Widget toggle: $deviceId → ${on ? "ON" : "OFF"}');
    final device = _devices.where((d) => d.id == deviceId).firstOrNull;
    if (device == null) {
      debugPrint('⚠️ Widget toggle: device $deviceId not found');
      return;
    }

    // Send MQTT command
    await _mqttManager.mqttService.sendBulkPowerCommand(device.id, on);

    // Update widget immediately with new state
    _updateHomeWidget();

    // Show a brief snackbar confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${device.deviceName} turned ${on ? "ON" : "OFF"}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _processPendingWidgetToggle() async {
    final pending = await HomeWidgetService.getPendingToggle();
    if (pending == null) return;

    debugPrint('🏠 Processing widget toggle: ${pending.deviceId} → ${pending.state}');

    // Find the device
    final device = _devices.where((d) => d.id == pending.deviceId).firstOrNull;
    if (device == null) return;

    // Send MQTT toggle command via the underlying EnhancedMqttService
    final on = pending.state == 'ON';
    await _mqttManager.mqttService.sendBulkPowerCommand(device.id, on);
  }

  void _updateHomeWidget() async {
    // Build MQTT state map for all devices
    final Map<String, Map<String, dynamic>> mqttStates = {};
    for (final d in _devices) {
      final state = _mqttManager.getDeviceState(d.id);
      if (state != null) {
        mqttStates[d.id] = state;
      }
    }

    // Update widget slot states (respects channel-level config from native activity)
    HomeWidgetService.updateWidgetStates(mqttStates);

    // Save ALL devices for the native widget config picker
    final allWidgetDevices = _devices.map((d) {
      bool isOn = false;
      final mqttState = mqttStates[d.id];
      if (mqttState != null) {
        if (mqttState['POWER'] == 'ON' || mqttState['POWER'] == true) isOn = true;
        for (int i = 1; i <= d.effectiveChannels; i++) {
          if (mqttState['POWER$i'] == 'ON' || mqttState['POWER$i'] == true) { isOn = true; break; }
        }
      }
      return WidgetDevice(
        id: d.id,
        name: d.deviceName,
        isOn: isOn,
        type: d.deviceType.name,
        topicBase: d.deviceTopicBase ?? d.id,
        channels: d.effectiveChannels,
      );
    }).toList();

    // Load channel labels from database + local storage for multi-channel devices
    final Map<String, Map<int, String>> channelLabels = {};
    for (final d in _devices) {
      if (d.effectiveChannels > 1) {
        final labels = <int, String>{};
        try {
          final dwc = await _devicesRepo.getDeviceWithChannels(d.id);
          if (dwc != null) {
            for (int ch = 1; ch <= d.effectiveChannels; ch++) {
              labels[ch] = dwc.getChannelLabel(ch);
            }
          }
        } catch (_) {}
        // Override with local labels (most reliable)
        for (int ch = 1; ch <= d.effectiveChannels; ch++) {
          final localLabel = await DeviceManagementRepo.getLocalChannelLabel(d.id, ch);
          if (localLabel != null && localLabel.isNotEmpty) {
            labels[ch] = localLabel;
          }
        }
        if (labels.isNotEmpty) channelLabels[d.id] = labels;
      }
    }

    HomeWidgetService.saveAllDevicesForConfig(allWidgetDevices, channelLabels: channelLabels);
  }

  void _navigateToDeviceControl(Device device) async {
    final deviceObj = device;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceControlScreen(
          device: deviceObj,
          onDeviceChanged: () {
            // Refresh dashboard data when device is changed (e.g., moved to different room)
            _loadData();
          },
        ),
      ),
    );

    // If device was deleted, refresh the device list
    if (result == true) {
      _loadData();
    }
  }

  String _getRoomName(String? roomId) {
    if (roomId == null) {
      return 'No Room';
    }
    try {
      return _rooms.firstWhere((room) => room.id == roomId).name;
    } catch (e) {
      return 'Unknown Room';
    }
  }

  /// Get icon for device type
  IconData _getDeviceIcon(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.relay:
        return Icons.power_settings_new;
      case DeviceType.dimmer:
        return Icons.lightbulb_outline;
      case DeviceType.shutter:
        return Icons.window;
      case DeviceType.sensor:
        return Icons.sensors;
      case DeviceType.other:
        return Icons.device_unknown;
    }
  }

  /// Shutter mini button — used in grid cards
  Widget _buildShutterMiniBtn({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: HBotDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: enabled
              ? HBotColors.primary.withOpacity(0.14)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? HBotColors.primary.withOpacity(0.35)
                : Colors.white.withOpacity(0.07),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Readex Pro',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: enabled
                ? HBotColors.primary
                : HBotColors.textMuted.withOpacity(0.35),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// Build shutter control buttons for list view — UP / STOP / DOWN text buttons
  Widget _buildShutterControls(
    Device device,
    int position,
    int direction, // 0=stopped, 1=opening, -1=closing
    bool isControllable,
    bool isOnline,
  ) {
    final canControl = isControllable && _mqttConnected && isOnline;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Position %
        Text(
          '$position%',
          style: const TextStyle(
            fontFamily: 'Readex Pro',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: HBotColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        _buildShutterListBtn(
          label: 'DOWN',
          enabled: canControl && position > 0,
          onTap: () => _controlShutter(device, 'close'),
        ),
        const SizedBox(width: 6),
        _buildShutterListBtn(
          label: 'STOP',
          enabled: canControl,
          onTap: () => _controlShutter(device, 'stop'),
          isStop: true,
        ),
        const SizedBox(width: 6),
        _buildShutterListBtn(
          label: 'UP',
          enabled: canControl && position < 100,
          onTap: () => _controlShutter(device, 'open'),
        ),
      ],
    );
  }

  Widget _buildShutterListBtn({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    bool isStop = false,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: HBotDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? (isStop
                  ? Colors.white.withOpacity(0.08)
                  : HBotColors.primary.withOpacity(0.14))
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? (isStop
                    ? Colors.white.withOpacity(0.15)
                    : HBotColors.primary.withOpacity(0.35))
                : Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Readex Pro',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: enabled
                ? (isStop ? Colors.white.withOpacity(0.7) : HBotColors.primary)
                : HBotColors.textMuted.withOpacity(0.35),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// Control shutter (open/close/stop)
  Future<void> _controlShutter(Device device, String action) async {
    try {
      if (!_mqttConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Text(AppStrings.get('home_dashboard_connection_lost_please_check_your_network')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Normalize action to lowercase for case-insensitive matching
      final normalizedAction = action.toLowerCase();

      switch (normalizedAction) {
        case 'open':
          await _mqttManager.openShutter(device.id, 1);
          debugPrint('Sent OPEN command to shutter ${device.name}');
          break;
        case 'close':
          await _mqttManager.closeShutter(device.id, 1);
          debugPrint('Sent CLOSE command to shutter ${device.name}');
          break;
        case 'stop':
          await _mqttManager.stopShutter(device.id, 1);
          debugPrint('Sent STOP command to shutter ${device.name}');
          break;
      }
    } catch (e) {
      debugPrint('Error controlling shutter ${device.name}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("error_control_shutter")}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleDevice(Device device, bool value) async {
    try {
      // Check if device has MQTT topic (is controllable)
      if (device.tasmotaTopicBase == null || device.tasmotaTopicBase!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Device ${device.name} is not configured for control',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check MQTT connection
      if (!_mqttConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Text(AppStrings.get('dashboard_connection_lost_please_check_your_network')),
              ],
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _retryMqttConnection,
            ),
          ),
        );
        return;
      }

      // Send control command via MQTT
      // Use bulk control for all devices (single and multi-channel)
      // This uses POWER0 command which controls all channels simultaneously
      await _mqttManager.setBulkPower(device.id, value);

      // The UI will update automatically when the device responds via MQTT
      debugPrint('Sent ${value ? 'ON' : 'OFF'} command to ${device.name}');
    } catch (e) {
      debugPrint('Error controlling device ${device.name}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("error_control_device")}: ${device.name} - ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: AppStrings.get('home_dashboard_debug'),
              textColor: Colors.white,
              onPressed: _showMqttDebugInfo,
            ),
          ),
        );
      }
    }
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HBotColors.sheetBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(HBotSpacing.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: HBotColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: HBotSpacing.space4),
                Text(
                  AppStrings.get('home_dashboard_view_filter_options'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: HBotSpacing.space4),

                // Dashboard Background option (only if home is selected)
                if (_selectedHome != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: HBotColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        color: HBotColors.primary,
                      ),
                    ),
                    title: Text(AppStrings.get('dashboard_background')),
                    subtitle: Text(AppStrings.get('background')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      _showHomeBackgroundDialog();
                    },
                  ),
                  const Divider(),
                ],

                // View mode toggle
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _isGridView ? Icons.grid_view : Icons.view_list,
                    color: HBotColors.primary,
                  ),
                  title: Text(AppStrings.get('view_mode')),
                  subtitle: Text(_isGridView ? AppStrings.get('grid_view') : AppStrings.get('list_view')),
                  trailing: Switch(
                    value: _isGridView,
                    onChanged: (value) {
                      setState(() {
                        _isGridView = value;
                      });
                      _saveViewPreference(value);
                      Navigator.pop(context);
                    },
                    activeTrackColor: HBotColors.primary,
                  ),
                  onTap: () {
                    final newValue = !_isGridView;
                    setState(() {
                      _isGridView = newValue;
                    });
                    _saveViewPreference(newValue);
                    Navigator.pop(context);
                  },
                ),

                // Hide offline devices toggle
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.visibility_off,
                    color: HBotColors.primaryLight,
                  ),
                  title: Text(AppStrings.get('hide_offline')),
                  trailing: Switch(
                    value: _hideOfflineDevices,
                    onChanged: (value) {
                      setState(() {
                        _hideOfflineDevices = value;
                      });
                      Navigator.pop(context);
                    },
                    activeTrackColor: HBotColors.primaryLight,
                  ),
                  onTap: () {
                    setState(() {
                      _hideOfflineDevices = !_hideOfflineDevices;
                    });
                    Navigator.pop(context);
                  },
                ),

                const Divider(),

                // Sort options
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: HBotSpacing.space2,
                  ),
                  child: Text(
                    AppStrings.get('sort_by'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: HBotColors.textMuted,
                    ),
                  ),
                ),

                _buildSortOption(AppStrings.get('sort_name'), 'name', Icons.sort_by_alpha),
                _buildSortOption(AppStrings.get('sort_recent'), 'recent', Icons.access_time),
                _buildSortOption(AppStrings.get('sort_room'), 'room', Icons.room_outlined),
                _buildSortOption(AppStrings.get('sort_type'), 'type', Icons.category_outlined),

                const SizedBox(height: HBotSpacing.space4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, IconData icon) {
    final isSelected = _sortOption == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: isSelected
            ? HBotColors.primary
            : HBotColors.textMuted,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? HBotColors.primary
              : Colors.white,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: HBotColors.primary)
          : null,
      onTap: () {
        setState(() {
          _sortOption = value;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showHomeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HBotColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HBotRadius.large),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(HBotSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.get('select_home'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: HBotSpacing.space4),
              ..._homes.map(
                (home) => ListTile(
                  title: Text(home.name == 'My Home' ? AppStrings.get('my_home_default') : home.name),
                  trailing: _selectedHome?.id == home.id
                      ? Icon(Icons.check, color: HBotColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _selectHome(home);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectHome(Home home) async {
    debugPrint('_selectHome called for home: ${home.name}');

    setState(() {
      _selectedHome = home;
      _isLoading = true;
    });

    // Notify parent about home name change
    widget.onHomeNameChanged?.call(home.name);

    // Save the selected home ID to shared preferences
    await _currentHomeService.setCurrentHomeId(home.id);

    debugPrint(
      'Home selected and state updated. Selected home: ${_selectedHome?.name}',
    );

    try {
      // Check for authenticated user first
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Load rooms and devices in parallel
      final futures = await Future.wait([
        _roomsRepo.listRooms(home.id),
        _devicesRepo.listDevicesByHome(home.id),
      ]);

      _rooms = futures[0] as List<Room>;
      _devices = futures[1] as List<Device>;

      // Update MQTT manager with new home ID
      debugPrint('Updating MQTT for home: ${home.id}');
      await _mqttManager.initialize(user.id, homeId: home.id);

      // Connect MQTT if not already connected
      if (!_mqttConnected) {
        final connected = await _mqttManager.connect();
        if (mounted) {
          setState(() {
            _mqttConnected = connected;
          });
        }
      }

      // Register devices with MQTT manager
      if (_mqttConnected) {
        await _registerDevicesWithMqtt();
      }

      _setupTabController();
    } catch (e) {
      debugPrint('Error loading home data: $e');
      _errorQueue.add('Error loading home data: $e');
      if (mounted) {
        setState(() {
          _mqttConnected = false;
        });
        // Schedule error message for next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Unable to load home data. Please check your connection and try again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HBotColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HBotColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: HBotSpacing.space6),
            Text(
              _getAddMenuTitle(),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: HBotSpacing.space6),

            // Show different options based on current state
            if (_homes.isEmpty) ...[
              // No homes exist - prioritize home creation
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HBotColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.home_work_outlined,
                    color: HBotColors.primary,
                  ),
                ),
                title: Text(AppStrings.get('create_first_home')),
                subtitle: Text(AppStrings.get('create_first_home_subtitle')),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomesScreen(
                        onHomeChanged: () {
                          _loadData();
                        },
                      ),
                    ),
                  );
                  // Reload data when returning from HomesScreen to catch any changes
                  _loadData();
                },
              ),
            ] else ...[
              // Homes exist - show both options
              if (_selectedHome == null) ...[
                // No home selected - guide user to select first
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.get('select_home_first'),
                          style: TextStyle(color: Colors.orange[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HBotColors.primaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.devices_outlined,
                    color: HBotColors.primaryLight,
                  ),
                ),
                title: Text(AppStrings.get('add_device')),
                subtitle: Text(
                  _selectedHome != null
                      ? '${AppStrings.get('add_device_subtitle')} ${_selectedHome!.name}'
                      : AppStrings.get('add_device_no_home'),
                ),
                enabled: _selectedHome != null,
                onTap: () {
                  Navigator.pop(context);
                  _showAddDeviceDialog();
                },
              ),
              const SizedBox(height: HBotSpacing.space2),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HBotColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.home_work_outlined,
                    color: HBotColors.primary,
                  ),
                ),
                title: Text(AppStrings.get('create_new_home')),
                subtitle: Text(AppStrings.get('create_new_home_subtitle')),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomesScreen(
                        onHomeChanged: () {
                          _loadData();
                        },
                      ),
                    ),
                  );
                  // Reload data when returning from HomesScreen to catch any changes
                  _loadData();
                },
              ),
            ],
            const SizedBox(height: HBotSpacing.space4),
          ],
        ),
      ),
    );
  }

  String _getAddMenuTitle() {
    if (_homes.isEmpty) {
      return 'Get Started';
    } else if (_selectedHome == null) {
      return 'Select a home first';
    } else {
      return 'What would you like to add?';
    }
  }

  void _showAddDeviceDialog() {
    debugPrint(
      '_showAddDeviceDialog called. Selected home: ${_selectedHome?.name}, Homes count: ${_homes.length}',
    );

    // Check if we have a selected home
    if (_selectedHome == null && _homes.isNotEmpty) {
      debugPrint(
        'No home selected but homes exist. Showing home selection dialog.',
      );
      // Show home selection first
      _showHomeSelectionForDevice();
      return;
    }

    if (_homes.isEmpty) {
      debugPrint('No homes exist. Showing create home first dialog.');
      // No homes exist, guide user to create one first
      _showCreateHomeFirstDialog();
      return;
    }

    debugPrint(
      'Proceeding with device addition for home: ${_selectedHome!.name}',
    );

    // Normal device addition flow
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HBotColors.sheetBackground,
          title: Text('${AppStrings.get('add_device')} - ${_selectedHome!.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.wifi, color: HBotColors.primary),
                title: Text(AppStrings.get('hbot_device')),
                subtitle: Text(AppStrings.get('hbot_device_subtitle')),
                onTap: () {
                  Navigator.pop(context);
                  _addTasmotaDevice();
                },
              ),

            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.get('cancel')),
            ),
          ],
        );
      },
    );
  }

  void _addTasmotaDevice() {
    debugPrint(
      '_addTasmotaDevice called. Selected home: ${_selectedHome?.name}',
    );

    if (_selectedHome == null) {
      debugPrint(
        'No home selected in _addTasmotaDevice. Showing home selection dialog.',
      );
      _showHomeSelectionForDevice();
      return;
    }

    // Determine which room to assign the device to based on current tab
    Room? targetRoom;
    if (_selectedRoomFilter != 'All') {
      try {
        targetRoom = _rooms.firstWhere((r) => r.name == _selectedRoomFilter);
        debugPrint(
          'User is on room tab: ${targetRoom.name}, will pre-assign device to this room',
        );
      } catch (e) {
        debugPrint('Could not find room for filter: $_selectedRoomFilter');
      }
    }

    debugPrint(
      'Navigating to AddDeviceFlowScreen for home: ${_selectedHome!.name}, room: ${targetRoom?.name ?? "None"}',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDeviceFlowScreen(
          home: _selectedHome!,
          room: targetRoom,
          onDeviceAdded: () {
            // Refresh dashboard data
            _loadData();
          },
        ),
      ),
    );
  }

  void _showHomeSelectionForDevice() {
    debugPrint(
      '_showHomeSelectionForDevice called. Available homes: ${_homes.map((h) => h.name).join(', ')}',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HBotColors.sheetBackground,
          title: Text(AppStrings.get('select_home_for_device')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.get('select_home_for_device_subtitle'),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (_homes.isNotEmpty) ...[
                Text(
                  AppStrings.get('select_home'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._homes.map(
                  (home) => ListTile(
                    leading: const Icon(Icons.home),
                    title: Text(home.name == 'My Home' ? AppStrings.get('my_home_default') : home.name),
                    onTap: () {
                      debugPrint('User selected home: ${home.name}');
                      Navigator.pop(context);
                      _selectHome(home);
                      // After selecting home, proceed with device addition
                      Future.delayed(const Duration(milliseconds: 300), () {
                        debugPrint(
                          'Proceeding with device addition after home selection',
                        );
                        _addTasmotaDevice();
                      });
                    },
                  ),
                ),
                const Divider(),
              ],
              ListTile(
                leading: const Icon(Icons.add_home),
                title: Text(AppStrings.get('create_new_home')),
                subtitle: Text(AppStrings.get('create_new_home_subtitle')),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomesScreen(
                        onHomeChanged: () {
                          // Refresh the dashboard when homes change
                          _loadData();
                        },
                      ),
                    ),
                  );
                  // Reload data when returning from HomesScreen to catch any changes
                  _loadData();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.get('cancel')),
            ),
          ],
        );
      },
    );
  }

  void _showCreateHomeFirstDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HBotColors.sheetBackground,
          title: Text(AppStrings.get('create_home_first')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home_outlined, size: 64, color: HBotColors.primary),
              SizedBox(height: 16),
              Text(
                AppStrings.get('create_home_first_subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.get('create_first_home_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(color: HBotColors.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.get('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomesScreen(
                      onHomeChanged: () {
                        _loadData();
                      },
                    ),
                  ),
                );
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: HBotColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(AppStrings.get('create_new_home')),
            ),
          ],
        );
      },
    );
  }

  void _showMqttDebugInfo() {
    final user = Supabase.instance.client.auth.currentUser;
    final debugMessages = _mqttManager.debugMessages;
    final stats = _mqttManager.mqttService.connectionStats;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HBotColors.sheetBackground,
          title: Row(
            children: [
              Icon(
                _mqttConnected ? Icons.wifi : Icons.wifi_off,
                color: _mqttConnected ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(AppStrings.get('home_dashboard_connection_diagnostics')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Connection Status
                _buildDebugSection('Connection Status', [
                  'State: ${_mqttConnected ? "Connected" : "Disconnected"}',
                  'Client State: ${stats['client_state'] ?? "Unknown"}',
                  'Monitoring: ${stats['monitoring_active'] == true ? "Active" : "Inactive"}',
                ]),

                // User & Home Info
                _buildDebugSection('Configuration', [
                  'User ID: ${user?.id ?? "None"}',
                  'Home ID: ${_selectedHome?.id ?? "None"}',
                  'Devices: ${_devices.length}',
                ]),

                // Connection Statistics
                _buildDebugSection('Connection Statistics', [
                  'Registered Devices: ${stats['registered_devices'] ?? 0}',
                  'Active Subscriptions: ${stats['active_subscriptions'] ?? 0}',
                  'Reconnection Attempts: ${stats['reconnection_attempts'] ?? 0}/${stats['max_reconnection_attempts'] ?? 0}',
                  'Network Connectivity: ${stats['has_network_connectivity'] == true ? "Available" : "Unavailable"}',
                ]),

                // Error Information
                if (stats['last_error_type'] != null ||
                    stats['current_recovery_strategy'] != null)
                  _buildDebugSection('Error Information', [
                    if (stats['last_error_type'] != null)
                      'Last Error: ${stats['last_error_type']}',
                    if (stats['current_recovery_strategy'] != null)
                      'Recovery Strategy: ${stats['current_recovery_strategy']['should_retry'] == true ? "Retry" : "No Retry"}',
                    if (stats['current_recovery_strategy'] != null)
                      'Max Retries: ${stats['current_recovery_strategy']['max_retries']}',
                  ]),

                // Timestamps
                if (stats['last_successful_connection'] != null ||
                    stats['last_connection_attempt'] != null)
                  _buildDebugSection('Timestamps', [
                    if (stats['last_successful_connection'] != null)
                      'Last Success: ${_formatTimestamp(stats['last_successful_connection'])}',
                    if (stats['last_connection_attempt'] != null)
                      'Last Attempt: ${_formatTimestamp(stats['last_connection_attempt'])}',
                  ]),

                // Debug Messages
                Text(
                  'Debug Messages:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: HBotColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      debugMessages.isNotEmpty
                          ? debugMessages.join('\n')
                          : 'No debug messages',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.get('close')),
            ),
            if (_mqttConnected)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _refreshDeviceStates();
                },
                child: Text(AppStrings.get('home_dashboard_refresh_states')),
              ),
            if (!_mqttConnected)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _retryMqttConnection();
                },
                child: Text(AppStrings.get('home_dashboard_retry_connection')),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDebugSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: HBotColors.primary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text('• $item', style: const TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Never';
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Invalid';
    }
  }
}
