import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/home.dart';
import '../models/room.dart';
import '../models/device.dart';
import '../repos/homes_repo.dart';
import '../repos/rooms_repo.dart';
import '../repos/devices_repo.dart';
import '../services/mqtt_device_manager.dart';
import '../services/smart_home_service.dart';
import '../services/device_event_tracker.dart';
import '../services/home_widget_service.dart';
import '../services/current_home_service.dart';
import '../services/app_lifecycle_manager.dart';
import '../services/room_change_notifier.dart';
import '../widgets/background_image_picker.dart';
import 'homes_screen.dart';
import 'add_device_flow_screen.dart';
import 'notifications_settings_screen.dart';
import '../widgets/responsive_shell.dart';
import 'device_control_screen.dart';

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
  Home? _selectedHome;
  String _selectedRoomFilter = 'All';
  bool _isLoading = true;
  bool _mqttConnected = false;
  TabController? _tabController;
  Timer? _stateRefreshTimer;
  StreamSubscription<void>? _roomChangeSubscription;

  // Queue for errors that occur during initialization
  final List<String> _errorQueue = [];

  // New features state variables
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortOption = 'name'; // 'name', 'recent', 'room', 'type'
  bool _isGridView = true; // true = grid view (default per design), false = list view
  bool _hideOfflineDevices = false;

  // SharedPreferences key for view preference
  static const String _viewPreferenceKey = 'dashboard_view_preference';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
    _loadViewPreference(); // Load saved view preference
    _loadData(); // Let _loadData handle MQTT initialization

    // Listen to auth state changes to reload data when user becomes available
    _setupAuthListener();

    // Initialize app lifecycle manager with services
    _initializeLifecycleManager();

    // Listen for room changes from anywhere in the app
    _roomChangeSubscription = RoomChangeNotifier().roomChanges.listen((_) {
      debugPrint('🔔 Room change notification received, reloading rooms...');
      _reloadRoomsOnly();
    });
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
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
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
          const SnackBar(
            content: Text('Reconnecting...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
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
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Connection restored'),
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
                  const Row(
                    children: [
                      Icon(Icons.error, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Failed to restore connection'),
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
                label: 'Diagnose',
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
                const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Connection recovery error'),
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
              label: 'Details',
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
    _roomChangeSubscription?.cancel(); // Cancel room change subscription
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
      setState(() => _isLoading = true);

      // Check for authenticated user first with retry mechanism
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

      debugPrint('Authenticated user found: ${user.id}');

      // Load homes
      _homes = await _homesRepo.listMyHomes();
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

        // Load rooms, owned devices, and shared devices in parallel
        final futures = await Future.wait([
          _roomsRepo.listRooms(_selectedHome!.id),
          _devicesRepo.listDevicesByHome(_selectedHome!.id),
          _devicesRepo.listSharedDevices(),
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

        // Setup tab controller for rooms
        _setupTabController();

        // Initialize MQTT with user and home ID and start connection in
        // background. We must not block the UI first paint on MQTT.
        debugPrint(
          'Initializing MQTT (background) for user: ${user.id} and home: ${_selectedHome!.id}',
        );
        await _mqttManager.initialize(user.id, homeId: _selectedHome!.id);

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
        _mqttManager.connectionStateStream.listen((state) {
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
        });
      }
    } finally {
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
        for (final device in devicesList) {
          _smartHomeService.watchCombinedDeviceState(device.id).listen((state) {
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
        }

        // Request initial state for all devices after registration and listener setup
        // This ensures the dashboard shows current device states immediately
        debugPrint(
          '🔄 Requesting initial state for all ${devicesList.length} devices',
        );
        await _requestInitialDeviceStates(devicesList);
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
                content: const Text('Error connecting to devices'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Retry',
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
        const Duration(seconds: 5),
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
              content: Text('Refreshed ${controllableDevices.length} devices'),
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
          const SnackBar(
            content: Text('Unable to refresh devices. Please try again.'),
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
    if (hour < 5) return 'Good night 🌙';
    if (hour < 12) return 'Good morning ☀️';
    if (hour < 18) return 'Good afternoon';
    if (hour < 22) return 'Good evening';
    return 'Good night 🌙';
  }

  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Background image
          if (_selectedHome?.backgroundImageUrl != null &&
              _selectedHome!.backgroundImageUrl!.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
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
              if (_homes.isNotEmpty && _devices.isNotEmpty) _buildSearchBar(),
              if (_homes.isNotEmpty && _rooms.isNotEmpty)
                Container(
                  key: ValueKey('tabs_${_rooms.map((r) => r.id).join("_")}'),
                  margin: const EdgeInsets.only(top: HBotSpacing.space2),
                  child: _buildTabBar(),
                ),
              Expanded(child: _buildContent()),
            ],
          ),
          // FAB
          if (_homes.isNotEmpty)
            Positioned(
              right: HBotSpacing.space5,
              bottom: HBotSpacing.space5,
              child: FloatingActionButton(
                onPressed: _showAddMenu,
                child: const Icon(Icons.add, size: 28),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
          // Title row: Home name + actions
          Row(
            children: [
              GestureDetector(
                onTap: _homes.length > 1 ? _showHomeSelector : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedHome?.name ?? 'My Home',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: context.hTextPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (_homes.length > 1) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: context.hTextSecondary,
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
              // Notification bell
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                color: HBotColors.iconDefault,
                iconSize: 24,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen())),
              ),
              // Settings menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: HBotColors.iconDefault, size: 24),
                onSelected: (v) {
                  switch (v) {
                    case 'add_device': _showAddMenu(); break;
                    case 'background': _showHomeBackgroundDialog(); break;
                    case 'manage_homes': _showHomeSelector(); break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'add_device',
                    child: ListTile(leading: Icon(Icons.add_circle_outline),
                      title: Text('Add Device'), contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(value: 'background',
                    child: ListTile(leading: Icon(Icons.wallpaper_outlined),
                      title: Text('Background'), contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(value: 'manage_homes',
                    child: ListTile(leading: Icon(Icons.home_work_outlined),
                      title: Text('Manage Homes'), contentPadding: EdgeInsets.zero)),
                ],
              ),
            ],
          ),

          const SizedBox(height: HBotSpacing.space2),

          // Greeting
          Row(
            children: [
              Text(
                _greeting,
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.hTextSecondary,
                ),
              ),
              const Spacer(),
              Text(
                'v1.0.0 (122)',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: context.hTextTertiary,
                ),
              ),
            ],
          ),

          const SizedBox(height: HBotSpacing.space1),

          // Device count
          if (_devices.isNotEmpty)
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: context.hTextSecondary,
                ),
                children: [
                  TextSpan(
                    text: '${_devices.length}',
                    style: const TextStyle(
                      color: HBotColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: ' device${_devices.length == 1 ? '' : 's'}',
                  ),
                ],
              ),
            ),
        ],
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
          backgroundColor: context.hCard,
          title: const Text('Dashboard Background Image'),
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
                        content: Text('Failed to update background: $e'),
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
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
      height: 44,
      decoration: BoxDecoration(
        color: context.hCard,
        borderRadius: HBotRadius.mediumRadius,
        border: Border.all(color: context.hBorder, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 14,
                color: context.hTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search devices...',
                hintStyle: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 14,
                  color: context.hTextTertiary,
                ),
                prefixIcon: const Icon(Icons.search, color: HBotColors.iconDefault, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: HBotColors.iconDefault, size: 18),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        }),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: HBotSpacing.space4,
                  vertical: 12,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Filter button
          Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: context.hBorder, width: 1)),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, color: HBotColors.iconDefault, size: 20),
              onPressed: _showOptionsMenu,
              tooltip: 'Filter and sort',
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    if (_tabController == null) return const SizedBox.shrink();

    return TabBar(
      key: ValueKey(_rooms.map((r) => r.name).join(',')),
      controller: _tabController,
      isScrollable: true,
      labelColor: Colors.white,
      unselectedLabelColor: context.hTextSecondary,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        gradient: HBotColors.primaryGradient,
        borderRadius: HBotRadius.fullRadius,
      ),
      dividerHeight: 0,
      labelStyle: const TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w500, fontSize: 14),
      unselectedLabelStyle: const TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w400, fontSize: 14),
      padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
      labelPadding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space4),
      tabAlignment: TabAlignment.start,
      tabs: [
        const Tab(text: 'All'),
        ..._rooms.map((room) => Tab(text: room.name)),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_homes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.home_outlined,
        title: 'No homes yet',
        subtitle: 'Create your first home to get started',
        actionText: 'Create Home',
        onAction: _showAddMenu,
      );
    }

    if (_filteredDevices.isEmpty) {
      // Show appropriate empty state message
      String emptyTitle = 'No devices yet';
      String emptySubtitle =
          'Add your first device to start controlling your home';

      if (_searchQuery.isNotEmpty) {
        emptyTitle = 'No devices found';
        emptySubtitle = 'Try a different search term';
      } else if (_hideOfflineDevices && _devices.isNotEmpty) {
        emptyTitle = 'All devices are offline';
        emptySubtitle = 'Check your device connections';
      }

      return _buildEmptyState(
        icon: Icons.devices_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionText: 'Add Device',
        onAction: _showAddMenu,
      );
    }

    // Return grid or list view based on user preference
    if (_isGridView) {
      return _buildDeviceGrid();
    } else {
      return _buildDeviceList();
    }
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      itemCount: _filteredDevices.length,
      itemBuilder: (context, index) {
        final device = _filteredDevices[index];
        return _buildDeviceCardWrapper(device);
      },
    );
  }

  Widget _buildDeviceGrid() {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    final columns = width >= 900 ? 4 : (isTablet ? 3 : 2);
    final spacing = isTablet ? HBotSpacing.space4 : HBotSpacing.space3;
    final hPadding = isTablet ? HBotSpacing.space6 : HBotSpacing.space4;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(hPadding, HBotSpacing.space4, hPadding, 80),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: isTablet ? 1.1 : 1.0,
      ),
      itemCount: _filteredDevices.length,
      itemBuilder: (context, index) {
        final device = _filteredDevices[index];
        return _buildDeviceCardWrapper(device, isGridView: true);
      },
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
              decoration: const BoxDecoration(
                color: HBotColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: HBotColors.primary),
            ),
            const SizedBox(height: HBotSpacing.space5),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.hTextPrimary,
              ),
            ),
            const SizedBox(height: HBotSpacing.space2),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 14,
                color: context.hTextSecondary,
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
        bool isOnline = false;
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

        return Card(
          color: context.hCard,
          margin: isGridView
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(
                  horizontal: HBotSpacing.space4,
                  vertical: HBotSpacing.space2,
                ),
          child: InkWell(
            onTap: () => _navigateToDeviceControl(device),
            borderRadius: BorderRadius.circular(HBotRadius.medium),
            child: Padding(
              padding: const EdgeInsets.all(
                6,
              ), // Reduced from 12 to 6 for maximum compactness
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
                        // Left side: device name only (simplified)
                        Expanded(
                          child: Text(
                            device.deviceName,
                            style: TextStyle(
                              color: context.hTextPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Right side: controls (shutter buttons or toggle switch)
                        device.deviceType == DeviceType.shutter
                            ? _buildShutterControls(
                                device,
                                shutterPosition,
                                shutterDirection,
                                isControllable,
                                isOnline,
                              )
                            : Column(
                                children: [
                                  if (!isControllable)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Text(
                                        'No realtime (no topic)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.orange),
                                      ),
                                    ),
                                  // FETCH-FIRST: Show loading indicator while waiting for initial state
                                  if (waitingForInitialState)
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              HBotColors.primary,
                                            ),
                                      ),
                                    )
                                  else
                                    Switch(
                                      value: deviceState,
                                      onChanged:
                                          isControllable &&
                                              _mqttConnected &&
                                              isOnline
                                          ? (value) =>
                                                _toggleDevice(device, value)
                                          : null,
                                    ),
                                ],
                              ),
                      ],
                    ),
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
    int shutterDirection, // 0=stopped, 1=opening, -1=closing
    bool waitingForInitialState, // FETCH-FIRST: loading indicator flag
  ) {
    final textPrimary = context.hTextPrimary;
    final textHint = context.hTextTertiary;

    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Large device icon at the top - compact with online status indicator
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(4), // Reduced from 8 to 4
                decoration: BoxDecoration(
                  color:
                      // Show blue background only when device is ONLINE AND ON
                      (isOnline &&
                          (deviceState ||
                              (device.deviceType == DeviceType.shutter &&
                                  shutterPosition > 0)))
                      ? HBotColors.primary.withOpacity(0.2)
                      : (Colors
                                  .white), // White background for better contrast in Light Mode
                  borderRadius: BorderRadius.circular(HBotRadius.medium),
                ),
                child: Icon(
                  _getDeviceIcon(device.deviceType),
                  color:
                      // Show blue icon only when device is ONLINE AND ON
                      (isOnline &&
                          (deviceState ||
                              (device.deviceType == DeviceType.shutter &&
                                  shutterPosition > 0)))
                      ? HBotColors.primary
                      : (AppTheme
                                  .lightTextSecondary), // Better contrast in Light Mode
                  size: 32, // Reduced from 36 to 32 for maximum compactness
                ),
              ),
              // Online/Offline status indicator dot
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.red.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2), // Minimal spacing
        // Device name - centered and allow wrapping to 2 lines
        SizedBox(
          width: double.infinity,
          child: Text(
            device.deviceName,
            style: TextStyle(
              fontFamily: 'DM Sans',
              color: context.hTextPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
        const SizedBox(height: 2), // Minimal spacing
        // Controls
        if (device.deviceType == DeviceType.shutter)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Position indicator above buttons
              Text(
                '$shutterPosition%',
                style: const TextStyle(
                  color: HBotColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Shutter control buttons - larger and easier to tap
              // MODIFICATION 1: Removed optimistic position updates
              // MODIFICATION 2: Buttons disabled at physical limits with dimmed appearance
              // Button order: Close/Stop/Open (matches list view)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Close button (dimmed at 0%)
                  SizedBox(
                    width: 32, // Reduced from 36 to 32
                    height: 32, // Reduced from 36 to 32
                    child: IconButton(
                      icon: const Icon(Icons.arrow_downward),
                      onPressed:
                          isControllable &&
                              _mqttConnected &&
                              isOnline &&
                              shutterPosition > 0
                          ? () => _controlShutter(device, 'close')
                          : null,
                      color: isControllable && _mqttConnected && isOnline
                          ? (shutterPosition > 0
                                ? textPrimary
                                : textPrimary.withOpacity(0.3))
                          : textHint,
                      padding: EdgeInsets.zero,
                      tooltip: 'Close',
                      iconSize: 16, // Reduced from 18 to 16
                    ),
                  ),
                  const SizedBox(width: 2), // Reduced spacing
                  // Stop button (always enabled when online)
                  SizedBox(
                    width: 32, // Reduced from 36 to 32
                    height: 32, // Reduced from 36 to 32
                    child: IconButton(
                      icon: const Icon(Icons.stop),
                      onPressed: isControllable && _mqttConnected && isOnline
                          ? () => _controlShutter(device, 'stop')
                          : null,
                      color: isControllable && _mqttConnected && isOnline
                          ? textPrimary
                          : textHint,
                      padding: EdgeInsets.zero,
                      tooltip: 'Stop',
                      iconSize: 16, // Reduced from 18 to 16
                    ),
                  ),
                  const SizedBox(width: 2), // Reduced spacing
                  // Open button (dimmed at 100%)
                  SizedBox(
                    width: 32, // Reduced from 36 to 32
                    height: 32, // Reduced from 36 to 32
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed:
                          isControllable &&
                              _mqttConnected &&
                              isOnline &&
                              shutterPosition < 100
                          ? () => _controlShutter(device, 'open')
                          : null,
                      color: isControllable && _mqttConnected && isOnline
                          ? (shutterPosition < 100
                                ? textPrimary
                                : textPrimary.withOpacity(0.3))
                          : textHint,
                      padding: EdgeInsets.zero,
                      tooltip: 'Open',
                      iconSize: 16, // Reduced from 18 to 16
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          Center(
            // FETCH-FIRST: Show loading indicator while waiting for initial state
            child: waitingForInitialState
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        HBotColors.primary,
                      ),
                    ),
                  )
                : Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: deviceState,
                      onChanged: isControllable && _mqttConnected && isOnline
                          ? (value) => _toggleDevice(device, value)
                          : null,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
          ),
      ],
    );
  }

  void _updateHomeWidget() {
    // Send first 4 devices to home screen widget with actual MQTT state
    final widgetDevices = _devices.take(4).map((d) {
      bool isOn = false;
      final mqttState = _mqttManager.getDeviceState(d.id);
      if (mqttState != null) {
        // Check POWER or POWER1..N for on state
        if (mqttState['POWER'] == 'ON' || mqttState['POWER'] == true) {
          isOn = true;
        }
        for (int i = 1; i <= d.effectiveChannels; i++) {
          if (mqttState['POWER$i'] == 'ON' || mqttState['POWER$i'] == true) {
            isOn = true;
            break;
          }
        }
      }
      return WidgetDevice(
        id: d.id,
        name: d.deviceName,
        isOn: isOn,
        type: d.deviceType.name,
      );
    }).toList();
    HomeWidgetService.updateDeviceStates(widgetDevices);
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

  /// Build shutter control buttons (Close/Stop/Open + position label)
  /// MODIFICATION 1: Removed optimistic position updates - position only updates from real MQTT data
  /// MODIFICATION 2: Buttons disabled at physical limits (Up at 100%, Down at 0%)
  Widget _buildShutterControls(
    Device device,
    int position,
    int direction, // 0=stopped, 1=opening, -1=closing
    bool isControllable,
    bool isOnline,
  ) {
    final canControl = isControllable && _mqttConnected && isOnline;
    final textPrimary = context.hTextPrimary;
    final textHint = context.hTextTertiary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Position label
        Text(
          '$position%',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: HBotColors.primary,
          ),
        ),
        const SizedBox(height: 8),

        // Control buttons row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button (dimmed at 0%)
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 20),
              onPressed: canControl && position > 0
                  ? () => _controlShutter(device, 'close')
                  : null,
              color: canControl
                  ? (position > 0
                        ? textPrimary
                        : textPrimary.withOpacity(0.3))
                  : textHint,
              tooltip: 'Close',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 4),

            // Stop button (always enabled when controllable)
            IconButton(
              icon: const Icon(Icons.stop, size: 20),
              onPressed: canControl
                  ? () => _controlShutter(device, 'stop')
                  : null,
              color: canControl ? textPrimary : textHint,
              tooltip: 'Stop',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 4),

            // Open button (dimmed at 100%)
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 20),
              onPressed: canControl && position < 100
                  ? () => _controlShutter(device, 'open')
                  : null,
              color: canControl
                  ? (position < 100
                        ? textPrimary
                        : textPrimary.withOpacity(0.3))
                  : textHint,
              tooltip: 'Open',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ],
    );
  }

  /// Control shutter (open/close/stop)
  Future<void> _controlShutter(Device device, String action) async {
    try {
      if (!_mqttConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Text('Connection lost. Please check your network.'),
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
            content: Text('Failed to control shutter: ${e.toString()}'),
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
            content: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Text('Connection lost. Please check your network.'),
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
            content: Text('Failed to control ${device.name}: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Debug',
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
      backgroundColor: context.hCard,
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
                      color: context.hTextTertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: HBotSpacing.space4),
                Text(
                  'View & Filter Options',
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
                    title: const Text('Dashboard Background'),
                    subtitle: const Text('Set background image'),
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
                  title: const Text('View Mode'),
                  subtitle: Text(_isGridView ? 'Grid View' : 'List View'),
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
                  title: const Text('Hide Offline Devices'),
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
                    'Sort By',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.hTextSecondary,
                    ),
                  ),
                ),

                _buildSortOption('Name (A-Z)', 'name', Icons.sort_by_alpha),
                _buildSortOption('Recently Added', 'recent', Icons.access_time),
                _buildSortOption('Room', 'room', Icons.room_outlined),
                _buildSortOption(
                  'Device Type',
                  'type',
                  Icons.category_outlined,
                ),

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
            : context.hTextSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? HBotColors.primary
              : context.hTextPrimary,
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
      backgroundColor: context.hCard,
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
                'Select Home',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: HBotSpacing.space4),
              ..._homes.map(
                (home) => ListTile(
                  title: Text(home.name),
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
      backgroundColor: context.hCard,
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
                color: context.hTextTertiary,
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
                title: const Text('Create Your First Home'),
                subtitle: const Text(
                  'Start by creating a home to organize your devices',
                ),
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
                          'Select a home first to add devices',
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
                title: const Text('Add Device'),
                subtitle: Text(
                  _selectedHome != null
                      ? 'Add a device to ${_selectedHome!.name}'
                      : 'Add a device (select home first)',
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
                title: const Text('Create New Home'),
                subtitle: const Text('Add another home to manage'),
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
          backgroundColor: context.hCard,
          title: Text('Add Device to ${_selectedHome!.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.wifi, color: HBotColors.primary),
                title: const Text('HBOT Device'),
                subtitle: const Text('Add HBOT device via Wi-Fi'),
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
              child: const Text('Cancel'),
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
          backgroundColor: context.hCard,
          title: const Text('Select Home for Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please select a home where you want to add the device:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (_homes.isNotEmpty) ...[
                const Text(
                  'Existing Homes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._homes.map(
                  (home) => ListTile(
                    leading: const Icon(Icons.home),
                    title: Text(home.name),
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
                title: const Text('Create New Home'),
                subtitle: const Text('Create a new home first'),
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
              child: const Text('Cancel'),
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
          backgroundColor: context.hCard,
          title: const Text('Create Home First'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home_outlined, size: 64, color: HBotColors.primary),
              SizedBox(height: 16),
              Text(
                'You need to create a home before adding devices.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'A home is a container for organizing your smart devices.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.hTextTertiary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
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
              style: ElevatedButton.styleFrom(
                backgroundColor: HBotColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Home'),
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
          backgroundColor: context.hCard,
          title: Row(
            children: [
              Icon(
                _mqttConnected ? Icons.wifi : Icons.wifi_off,
                color: _mqttConnected ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text('Connection Diagnostics'),
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
              child: const Text('Close'),
            ),
            if (_mqttConnected)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _refreshDeviceStates();
                },
                child: const Text('Refresh States'),
              ),
            if (!_mqttConnected)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _retryMqttConnection();
                },
                child: const Text('Retry Connection'),
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
