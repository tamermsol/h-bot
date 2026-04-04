import 'package:flutter/material.dart';
import 'dart:async';
import '../models/device.dart';
import '../services/mqtt_device_manager.dart';
import '../services/smart_home_service.dart';
import '../repos/devices_repo.dart';
import '../repos/device_management_repo.dart';
import '../theme/app_theme.dart';
import '../widgets/shutter_control_widget.dart';
import '../l10n/app_strings.dart';
import '../widgets/channel_grid.dart';
import 'shutter_calibration_screen.dart';
import 'shutter_manual_calibration_screen.dart';
import 'device_timers_screen.dart';
import 'share_device_screen.dart';
import '../widgets/responsive_shell.dart';
import '../widgets/design_system.dart';
import 'activity_log_screen.dart';

/// Dedicated screen for controlling a specific device
class DeviceControlScreen extends StatefulWidget {
  final Device device;
  final VoidCallback? onDeviceChanged;

  const DeviceControlScreen({
    super.key,
    required this.device,
    this.onDeviceChanged,
  });

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  final MqttDeviceManager _mqttManager = MqttDeviceManager();
  final DevicesRepo _devicesRepo = DevicesRepo();
  final SmartHomeService _service = SmartHomeService();

  Map<String, dynamic>? _deviceState;
  bool _isLoading = true;
  bool _showDebugInfo = false;
  bool _isBottomSheetOpen = false;
  // firmware fields removed
  StreamSubscription? _stateSubscription;
  StreamSubscription? _connectionStateSubscription;

  // Local device instance that can be updated
  late Device _currentDevice;

  // Channel management
  final Map<int, String> _channelNames = {};
  final Map<int, String> _channelTypes = {}; // 'light' or 'switch'

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentDevice = widget.device; // Initialize with the passed device
    _deviceState = _createDefaultDeviceState();
    _initializeDeviceControl();
    _loadChannelNames();
    // Extract firmware version from device metadata
    // firmware version tracking removed
  }

  /// Load channel names from database
  Future<void> _loadChannelNames() async {
    try {
      debugPrint(
        '🔄 Loading channel names and types for device ${widget.device.id}',
      );

      final deviceWithChannels = await _devicesRepo.getDeviceWithChannels(
        widget.device.id,
      );

      if (deviceWithChannels != null && mounted) {
        debugPrint(
          '📦 Device with channels loaded: ${deviceWithChannels.channelLabels}',
        );

        setState(() {
          // Load custom channel names and types from the database
          for (int i = 1; i <= widget.device.effectiveChannels; i++) {
            final channelLabel = deviceWithChannels.getChannelLabel(i);
            if (channelLabel != 'Channel $i') {
              _channelNames[i] = channelLabel;
            }
            // Load channel type
            final channelType = deviceWithChannels.getChannelType(i);
            _channelTypes[i] = channelType;
            debugPrint(
              '📌 Channel $i: label="$channelLabel", type="$channelType"',
            );
          }
        });

        // Also check local SharedPreferences for labels (most reliable)
        for (int i = 1; i <= widget.device.effectiveChannels; i++) {
          final localLabel = await DeviceManagementRepo.getLocalChannelLabel(
            widget.device.id, i,
          );
          if (localLabel != null && localLabel.isNotEmpty && mounted) {
            setState(() {
              _channelNames[i] = localLabel;
            });
          }
        }

        debugPrint('✅ Loaded channel types: $_channelTypes');
      } else {
        debugPrint('⚠️ Device with channels is null or widget not mounted');
      }
    } catch (e) {
      debugPrint('❌ Failed to load channel names: $e');
      // Continue with default names if loading fails
    }
  }

  /// Initialize device control
  Future<void> _initializeDeviceControl() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // First, try to load cached state for immediate display
      final cachedState = await _loadCachedDeviceState();
      if (cachedState != null && mounted) {
        setState(() {
          _deviceState = cachedState;
          _isLoading = false;
        });
        debugPrint('📱 Loaded cached state: $cachedState');
      }

      // Check if MQTT is already connected
      final isConnected = _mqttManager.connectionState.toString().contains(
        'connected',
      );
      debugPrint('🔌 MQTT connection state: ${_mqttManager.connectionState}');

      if (isConnected) {
        // MQTT is connected, proceed with device registration
        // Aggressive probe: fire a Status 5 probe immediately to get authoritative
        // device metadata/state as soon as the detail page opens. We don't await
        // it here to avoid blocking UI; the probe may still update streams.
        try {
          if (widget.device.tasmotaTopicBase != null) {
            // Fire-and-forget lightweight Status 5 publish to nudge the device
            // to report its current state. This avoids the subscription
            // overhead of a full health check and is fast.
            Future.microtask(() async {
              try {
                _mqttManager.mqttService.publishStatus5(
                  widget.device.tasmotaTopicBase!,
                );
              } catch (e) {
                debugPrint('🔍 Aggressive Status5 publish error: $e');
              }
            });
          }
        } catch (e) {
          debugPrint('🔍 Failed to start aggressive probe: $e');
        }

        await _registerAndListenToDevice();
      } else {
        // MQTT not connected, listen for connection state changes
        debugPrint('⏳ MQTT not connected, waiting for connection...');
        _connectionStateSubscription = _mqttManager.connectionStateStream.listen((state) {
          if (state.toString().contains('connected') && mounted) {
            debugPrint('🔌 MQTT connected, registering device...');

            // Also trigger an aggressive probe on connect so the detail page
            // can learn device presence ASAP.
            try {
              if (widget.device.tasmotaTopicBase != null) {
                Future.microtask(() async {
                  try {
                    _mqttManager.mqttService.publishStatus5(
                      widget.device.tasmotaTopicBase!,
                    );
                  } catch (e) {
                    debugPrint('🔍 Aggressive Status5 on-connect error: $e');
                  }
                });
              }
            } catch (e) {
              debugPrint('🔍 Failed to start aggressive probe on connect: $e');
            }

            _registerAndListenToDevice();
          }
        });
      }

      // Always set loading to false after initial setup
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error initializing device control: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Register device and set up state listening
  Future<void> _registerAndListenToDevice() async {
    try {
      // Subscribe to combined state stream early so the UI receives DB/MQTT
      // updates even if we decide to skip auto-registration due to offline
      // heuristics below. This prevents the detail page from temporarily
      // showing the wrong presence compared to the all-devices view.
      _stateSubscription?.cancel();
      _stateSubscription = _service
          .watchCombinedDeviceState(widget.device.id)
          .listen((state) {
            if (_isBottomSheetOpen) return;
            if (mounted) {
              setState(() {
                // When a combined snapshot arrives, update device state
                _deviceState = state;
              });
              debugPrint(
                '📱 Combined device state updated from ${state['source']}: $state',
              );
            }
          });

      // If the MQTT manager already has an in-memory state snapshot, use it
      // as an initial view but sanitize manufactured 'online' fields.
      final existingState = _mqttManager.getDeviceState(widget.device.id);
      if (existingState != null && mounted) {
        final sanitized = Map<String, dynamic>.from(existingState)
          ..remove('online')
          ..remove('connected');

        final availability = _mqttManager.getDeviceAvailability(
          widget.device.id,
        );
        final lastSeen = _mqttManager.getLastSeen(widget.device.id);
        if (availability != null) sanitized['availability'] = availability;
        if (lastSeen != null) {
          sanitized['lastSeen'] = lastSeen.millisecondsSinceEpoch;
        }

        setState(() {
          // Only merge initial sanitized local state if we don't already have
          // a combined DB snapshot. This avoids overwriting a valid DB
          // presence with a freshly-initialized manager snapshot.
          if (_deviceState == null || _deviceState!['source'] == 'database') {
            _deviceState = sanitized;
          }
        });
        debugPrint('📱 Using existing device state (merged): $sanitized');
      }

      // Register device with MQTT manager
      // Guard: avoid auto-registering/subscribing if device appears clearly OFFLINE
      // Always register device when user opens the detail page. This
      // guarantees the page subscribes to MQTT topics and issues an
      // immediate probe/state request, ensuring the UI displays current
      // presence quickly. Skipping registration here caused long delays and
      // inconsistent presence between the list and detail views.

      await _mqttManager.registerDevice(widget.device);
      debugPrint('✅ Device registered successfully');

      // Listen to combined device state changes (MQTT + Database real-time)
      _stateSubscription?.cancel(); // Cancel any existing subscription
      _stateSubscription = _service
          .watchCombinedDeviceState(widget.device.id)
          .listen((state) {
            if (_isBottomSheetOpen) return;
            if (mounted) {
              setState(() {
                _deviceState = state;
              });
              debugPrint(
                '📱 Combined device state updated from ${state['source']}: $state',
              );
            }
          });

      // Request immediate fresh state from device for real-time display
      await _mqttManager.requestDeviceStateImmediate(widget.device.id);

      // Also request regular state for backup with reduced delay
      Future.delayed(const Duration(milliseconds: 100), () {
        _mqttManager.requestDeviceState(widget.device.id);
      });
    } catch (e) {
      debugPrint('❌ Error registering device: $e');
    }
  }

  Future<void> _toggleChannel(int channel) async {
    if (!_isDeviceControllable()) return;

    try {
      final currentState = _getChannelState(channel);
      // Ensure device is registered with MQTT manager before sending commands.
      // This protects against cases where registration didn't occur earlier
      // due to timing or connection state.
      try {
        final existing = _mqttManager.getDeviceState(widget.device.id);
        if (existing == null) {
          await _mqttManager.registerDevice(widget.device);
        }
      } catch (e) {
        // If registration fails, continue and let setChannelPower throw a descriptive error.
        debugPrint('Device registration attempt before toggle failed: $e');
      }

      await _mqttManager.setChannelPower(
        widget.device.id,
        channel,
        !currentState,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("error_control_channel")}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Check if device is online based on current state
  bool _isDeviceOnline() {
    // Prefer authoritative combined state when available (the stream sets
    // `_deviceState`). This prevents mismatches between the list view (which
    // uses the combined stream) and the detail screen.
    // If `_deviceState` contains explicit health/online/lastSeen information
    // use it. Otherwise fallback to the MQTT manager availability + lastSeen.

    // 1) Explicit health override
    final health = _deviceState?['health'] as String?;
    if (health == 'OFFLINE') return false;

    // 2) If combined state has an `online` flag, use it directly
    if (_deviceState != null && _deviceState!.containsKey('online')) {
      final o = _deviceState!['online'];
      if (o is bool) return o;
      if (o is String) {
        return o.toLowerCase() == 'online' || o.toLowerCase() == 'true';
      }
    }

    // 3) Derive from lastSeen + TelePeriod (TTL heuristic) using combined state
    DateTime? lastSeen = _parseLastSeenFromState(_deviceState);
    int telePeriod =
        (_deviceState != null && _deviceState!['TelePeriod'] is int)
        ? _deviceState!['TelePeriod'] as int
        : (_mqttManager.mqttService.getTelemetryPeriodSeconds(
                widget.device.id,
              ) ??
              60);

    final ttlSecs = (telePeriod * 2.5).clamp(60, 300).toInt();

    if (lastSeen != null) {
      final fresh =
          DateTime.now().difference(lastSeen) < Duration(seconds: ttlSecs);
      if (fresh) {
        debugPrint(
          '🔍 Presence (from combined state): lastSeen=$lastSeen, tele=$telePeriod, ttl=$ttlSecs -> ONLINE',
        );
        return true;
      }
      // Not fresh; fallthrough to MQTT LWT
    }

    // 4) Fallback to MQTT manager availability + lastSeen
    final availability = _mqttManager.getDeviceAvailability(
      widget.device.id,
    ); // 'online'|'offline'|null
    final mgrLastSeen = _mqttManager.getLastSeen(widget.device.id);

    if (mgrLastSeen != null) {
      final fresh =
          DateTime.now().difference(mgrLastSeen) < Duration(seconds: ttlSecs);
      if (fresh) {
        debugPrint(
          '🔍 Presence (from MQTT manager): lastSeen=$mgrLastSeen, tele=$telePeriod, ttl=$ttlSecs -> ONLINE',
        );
        return true;
      }
    }

    // Honor explicit LWT == 'offline' when nothing fresh
    final offline = availability == 'offline';
    debugPrint(
      '🔍 Presence fallback: availability=$availability, mgrLastSeen=$mgrLastSeen -> ${offline ? 'OFFLINE' : 'STALE/UNKNOWN'}',
    );
    // If we reach this fallback, return true when availability is not explicit
    // 'offline'. Previously this returned `!offline && false` which always
    // evaluated to false and caused real online devices to be shown as
    // offline until fresh telemetry arrived.
    return !offline;
  }

  /// Check if device is controllable
  bool _isDeviceControllable() {
    return widget.device.tasmotaTopicBase != null &&
        widget.device.tasmotaTopicBase!.isNotEmpty;
  }

  /// Check whether we can send control commands from the UI.
  /// We allow control when the device has a configured MQTT topic and
  /// the app's MQTT connection is currently connected. Presence (online/stale)
  /// is still shown in the header, but shouldn't block user-initiated commands.
  bool _canSendCommands() {
    final connected = _mqttManager.connectionState.toString().contains(
      'connected',
    );
    // Also allow when underlying MQTT service reports healthy connection
    final serviceHealthy = _mqttManager.mqttService.isHealthy;
    // Determine presence quickly from combined state or manager fallback
    bool presence = false;
    try {
      presence = _isDeviceOnline();
    } catch (_) {
      presence = false;
    }

    // Fallback: if _isDeviceOnline() is false but MQTT manager reports
    // availability='online' or lastSeen within TTL, allow commands so
    // devices that are actually online aren't blocked while streams sync.
    if (!presence) {
      final availability = _mqttManager.getDeviceAvailability(widget.device.id);
      final lastSeen = _mqttManager.getLastSeen(widget.device.id);
      if (availability != null && availability.toLowerCase() == 'online') {
        presence = true;
      } else if (lastSeen != null) {
        final telePeriod =
            _mqttManager.mqttService.getTelemetryPeriodSeconds(
              widget.device.id,
            ) ??
            60;
        final ttlSecs = (telePeriod * 2.5).clamp(60, 300).toInt();
        if (DateTime.now().difference(lastSeen) < Duration(seconds: ttlSecs)) {
          presence = true;
        }
      }
    }

    return _isDeviceControllable() && (connected || serviceHealthy) && presence;
  }

  bool _getChannelState(int channel) {
    if (_deviceState == null) return false;
    return _deviceState!['POWER$channel'] == 'ON' ||
        (_deviceState!['POWER$channel'] == true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HBotColors.darkBgTop,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: HBotIconButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text(
          'Device Control',
          style: TextStyle(
            fontFamily: 'Readex Pro',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // Timer button (for relay and dimmer devices - lights)
          if (_currentDevice.deviceType == DeviceType.relay ||
              _currentDevice.deviceType == DeviceType.dimmer)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: HBotIconButton(
                icon: Icons.timer_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceTimersScreen(
                        device: _currentDevice,
                        mqttManager: _mqttManager,
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: HBotIconButton(
              icon: Icons.refresh,
              onTap: _refreshDeviceStatus,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: HBotIconButton(
              icon: Icons.more_vert,
              onTap: _showDeviceOptions,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HBotColors.darkBgTop, HBotColors.darkBgBottom],
          ),
        ),
        child: ResponsiveShell(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: HBotColors.primary),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: HBotLayout.isTablet(context) ? HBotSpacing.space6 : HBotSpacing.space5,
                    right: HBotLayout.isTablet(context) ? HBotSpacing.space6 : HBotSpacing.space5,
                    top: MediaQuery.of(context).padding.top + kToolbarHeight + HBotSpacing.space4,
                    bottom: HBotSpacing.space6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDeviceHeader(),
                      const SizedBox(height: HBotSpacing.space6),
                      _buildChannelControls(),
                      const SizedBox(height: HBotSpacing.space6),
                      if (_showDebugInfo) ...[
                        const SizedBox(height: HBotSpacing.space6),
                        _buildDebugInfo(),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// Device header - hero gradient card with device info (Pixel's design)
  Widget _buildDeviceHeader() {
    final isOnline = _isDeviceOnline();
    final IconData deviceIcon;
    switch (_currentDevice.deviceType) {
      case DeviceType.shutter:
        deviceIcon = Icons.window;
      case DeviceType.relay:
        deviceIcon = Icons.power_settings_new;
      case DeviceType.dimmer:
        deviceIcon = Icons.lightbulb;
      case DeviceType.sensor:
        deviceIcon = Icons.sensors;
      case DeviceType.other:
        deviceIcon = Icons.devices;
    }

    // Location subtitle — device type description
    final String locationText = _currentDevice.deviceType.name[0].toUpperCase() +
        _currentDevice.deviceType.name.substring(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-1, -1),
          end: Alignment(1, 1),
          colors: [Color(0xFF1070AD), Color(0xFF0883FD), Color(0xFF2FB8EC)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66010510), // rgba(1,5,16,0.4)
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Radial glow overlay — top-right
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Center(
            child: Column(
              children: [
                // Device icon — 48x48 white stroke
                Icon(deviceIcon, size: 48, color: Colors.white),
                const SizedBox(height: HBotSpacing.space3),
                // Device name — 22px weight 700
                Text(
                  _currentDevice.deviceName,
                  style: const TextStyle(
                    fontFamily: 'Readex Pro',
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                // Location — 13px, 0.85 opacity
                const SizedBox(height: 4),
                Opacity(
                  opacity: 0.85,
                  child: Text(
                    locationText,
                    style: const TextStyle(
                      fontFamily: 'Readex Pro',
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: HBotSpacing.space3),
                // Connected badge — 4px 12px padding, 20px radius, rgba(52,211,153,0.25), 11px w600
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isOnline ? const Color(0xFF34D399) : HBotColors.error).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF34D399) : HBotColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'Connected' : 'Offline',
                        style: TextStyle(
                          fontFamily: 'Readex Pro',
                          color: isOnline ? const Color(0xFF34D399) : HBotColors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show device options menu
  void _showDeviceOptions() {
    _isBottomSheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HBotColors.sheetBackground,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: HBotSpacing.space6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.edit,
                    color: Colors.white,
                  ),
                  title: Text(
                    AppStrings.get('rename_device'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeviceRenameDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.room,
                    color: Colors.white,
                  ),
                  title: Text(
                    AppStrings.get('move_to_room'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showMoveToRoomDialog();
                  },
                ),
                // Shutter calibration options (only for shutter devices)
                if (widget.device.deviceType == DeviceType.shutter) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.tune,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Auto Calibrate Shutter',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Measure time automatically',
                      style: TextStyle(color: HBotColors.textMuted, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToCalibration();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.timer,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Manual Calibrate Shutter',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Enter times directly',
                      style: TextStyle(color: HBotColors.textMuted, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToManualCalibration();
                    },
                  ),
                ],
                // Share Device option
                ListTile(
                  leading: const Icon(
                    Icons.share_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Share Device',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Share with other users via QR code',
                    style: TextStyle(color: HBotColors.textMuted, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ShareDeviceScreen(device: widget.device),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.white),
                  title: Text(AppStrings.get('activity_log'), style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ActivityLogScreen(
                        deviceId: widget.device.id,
                        deviceName: _currentDevice.deviceName,
                      ),
                    ));
                  },
                ),
                ListTile(
                  leading: Icon(
                    _showDebugInfo ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white,
                  ),
                  title: Text(
                    _showDebugInfo ? 'Hide Device Info' : 'Show Device Info',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _showDebugInfo = !_showDebugInfo;
                    });
                  },
                ),
                Divider(color: HBotColors.glassBorder),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    AppStrings.get('delete_device'),
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmationDialog();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      _isBottomSheetOpen = false;
      // Apply any pending state updates
      if (mounted) setState(() {});
    });
  }

  /// Navigate to shutter calibration screen
  void _navigateToCalibration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShutterCalibrationScreen(device: widget.device),
      ),
    );
  }

  /// Navigate to manual shutter calibration screen
  void _navigateToManualCalibration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ShutterManualCalibrationScreen(device: widget.device),
      ),
    );
  }

  /// Build device header with status and info

  /// Build device information section

  /// Build debug information section
  Widget _buildDebugInfo() {
    // Extract non-sensitive device information
    String? macAddress = _currentDevice.macAddress;
    String? ipAddress;
    String modelName;
    const String manufacturer = 'HBOT';

    // Try to get IP address from device state (StatusNET)
    if (_deviceState != null) {
      final statusNet = _deviceState!['StatusNET'];
      if (statusNet is Map<String, dynamic>) {
        ipAddress = statusNet['IPAddress'] as String?;
        // Also try alternative field names
        ipAddress ??= statusNet['IP'] as String?;
      }
    }

    // Determine model name based on device type and channel count
    modelName = _getHbotModelName();

    final infoRows = <MapEntry<String, String>>[
      MapEntry('Manufacturer', manufacturer),
      MapEntry('Device Model', modelName),
      MapEntry('Mac address', macAddress ?? 'Unknown'),
      MapEntry('IP Address', ipAddress ?? 'Unknown'),
    ];

    return HBotCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HBotSectionLabel('DEVICE INFO'),
          const SizedBox(height: 12),
          for (int i = 0; i < infoRows.length; i++) ...[
            if (i > 0)
              Divider(color: HBotColors.glassBorder, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildInfoRow(infoRows[i].key, infoRows[i].value),
            ),
          ],
        ],
      ),
    );
  }

  /// Build a single info row with label and value (flex space-between)
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Readex Pro',
            color: HBotColors.textMuted,
            fontSize: 12,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Readex Pro',
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  /// Get HBOT model name based on device type and channel count
  String _getHbotModelName() {
    switch (_currentDevice.deviceType) {
      case DeviceType.shutter:
        return 'Hbot-Shutter';
      case DeviceType.relay:
        // Determine model based on channel count
        final channelCount =
            _currentDevice.channels ?? _currentDevice.channelCount ?? 0;
        switch (channelCount) {
          case 2:
            return 'Hbot-2Ch';
          case 4:
            return 'Hbot-4Ch';
          case 8:
            return 'Hbot-8Ch';
          default:
            return 'Hbot-Relay';
        }
      case DeviceType.dimmer:
        return 'Hbot-Dimmer';
      case DeviceType.sensor:
        return 'Hbot-Sensor';
      case DeviceType.other:
        return 'Hbot-Device';
    }
  }

  /// Build channel controls with circular buttons matching the design
  /// Routes by device type: shutters → ShutterControlWidget, others → relay controls
  Widget _buildChannelControls() {
    // Route by device type (not channels)
    if (widget.device.deviceType == DeviceType.shutter) {
      return _buildShutterControl();
    } else if (widget.device.channels == 1) {
      return _buildSingleChannelControl();
    } else {
      return _buildMultiChannelGrid();
    }
  }

  /// Build shutter control (for shutter devices)
  Widget _buildShutterControl() {
    return ShutterControlWidget(
      device: widget.device,
      mqttManager: _mqttManager,
      shutterIndex: 1,
    );
  }

  /// Build single channel control — glass card with power row (Pixel's design)
  Widget _buildSingleChannelControl() {
    final isOn = _getChannelState(1);
    final canControl = _canSendCommands();
    final channelName = _channelNames[1] ?? (_channelTypes[1] == 'switch' ? 'Power' : 'Light');

    return HBotCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isOn
                  ? HBotColors.primary.withOpacity( 0.08)
                  : HBotColors.glassBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _channelTypes[1] == 'switch'
                  ? Icons.power_settings_new
                  : Icons.lightbulb,
              size: 22,
              color: isOn ? HBotColors.primary : HBotColors.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          // Label — 15px weight 600
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channelName,
                  style: const TextStyle(
                    fontFamily: 'Readex Pro',
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOn ? 'On' : 'Off',
                  style: TextStyle(
                    fontFamily: 'Readex Pro',
                    fontSize: 12,
                    color: HBotColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Power toggle — 56x30px, 15px radius, knob 26x26px
          GestureDetector(
            onTap: canControl ? () => _toggleChannel(1) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: isOn ? const Color(0xFF34D399) : const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build multi-channel controls using ChannelGrid
  Widget _buildMultiChannelGrid() {
    final canControl = _canSendCommands();
    final Map<int, bool> states = {};
    for (int i = 1; i <= widget.device.effectiveChannels; i++) {
      states[i] = _getChannelState(i);
    }

    return ChannelGrid(
      channelCount: widget.device.effectiveChannels,
      channelStates: states,
      channelNames: _channelNames,
      channelTypes: _channelTypes,
      canControl: canControl,
      onToggleChannel: (channel, value) => _toggleChannel(channel),
      onChannelLongPress: _showChannelOptionsDialog,
      onAllOn: () => _setAllChannels(true),
      onAllOff: () => _setAllChannels(false),
    );
  }

  /// Set all channels on or off
  Future<void> _setAllChannels(bool on) async {
    try {
      await _mqttManager.setBulkPower(widget.device.id, on);
    } catch (e) {
      debugPrint('Failed to set all channels: $e');
    }
  }

  /// Show channel rename dialog
  void _showChannelRenameDialog(int channel) {
    final controller = TextEditingController(text: _getChannelName(channel));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.sheetBackground,
        title: Text('${AppStrings.get('rename_channel')}: ${_getChannelName(channel)}'),
        content: TextField(
          controller: controller,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: AppStrings.get('rename_channel'),
            hintStyle: TextStyle(color: HBotColors.textMuted),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get('cancel')),
          ),
          TextButton(
            onPressed: () {
              _updateChannelName(channel, controller.text);
              Navigator.pop(context);
            },
            child: Text(AppStrings.get('save')),
          ),
        ],
      ),
    );
  }

  /// Show channel options dialog (rename and change type)
  void _showChannelOptionsDialog(int channel) {
    final channelType = _channelTypes[channel] ?? 'light';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.sheetBackground,
        title: Text('${_getChannelName(channel)} ${AppStrings.get('channel_options')}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: HBotColors.primary),
              title: Text(
                AppStrings.get('rename_channel'),
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showChannelRenameDialog(channel);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.lightbulb,
                color: channelType == 'light'
                    ? HBotColors.primary
                    : HBotColors.textMuted,
              ),
              title: Text(
                'Light',
                style: TextStyle(color: Colors.white),
              ),
              trailing: channelType == 'light'
                  ? const Icon(Icons.check, color: HBotColors.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _updateChannelType(channel, 'light');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.power_settings_new,
                color: channelType == 'switch'
                    ? HBotColors.primary
                    : HBotColors.textMuted,
              ),
              title: Text(
                'Switch',
                style: TextStyle(color: Colors.white),
              ),
              trailing: channelType == 'switch'
                  ? const Icon(Icons.check, color: HBotColors.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _updateChannelType(channel, 'switch');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get('close')),
          ),
        ],
      ),
    );
  }

  /// Get channel name (supports custom names)
  String _getChannelName(int channel) {
    return _channelNames[channel] ?? 'Channel $channel';
  }

  /// Update channel name with persistent storage
  Future<void> _updateChannelName(int channel, String newName) async {
    final trimmedName = newName.trim();
    final finalName = trimmedName.isEmpty
        ? _getDefaultChannelName(channel)
        : trimmedName;

    // Update local state immediately for responsive UI
    setState(() {
      _channelNames[channel] = finalName;
    });

    // Save to persistent storage
    try {
      await _devicesRepo.renameChannelPersistent(
        deviceId: widget.device.id,
        channelNo: channel,
        newLabel: finalName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("success_channel_renamed")}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert local state on error
      setState(() {
        _channelNames[channel] = _getDefaultChannelName(channel);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("error_rename_channel")}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Update channel type with persistent storage
  Future<void> _updateChannelType(int channel, String newType) async {
    if (newType != 'light' && newType != 'switch') {
      return;
    }

    final oldType = _channelTypes[channel] ?? 'light';

    // Update local state immediately for responsive UI
    setState(() {
      _channelTypes[channel] = newType;
    });

    // Save to persistent storage
    try {
      await _devicesRepo.updateChannelType(
        deviceId: widget.device.id,
        channelNo: channel,
        channelType: newType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("success_channel_type_changed")}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert local state on error
      setState(() {
        _channelTypes[channel] = oldType;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("error_update_channel_type")}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get default channel name
  String _getDefaultChannelName(int channel) {
    switch (widget.device.deviceType) {
      case DeviceType.relay:
        return 'Relay $channel';
      case DeviceType.dimmer:
        return 'Light $channel';
      case DeviceType.shutter:
        return 'Shutter $channel';
      default:
        return 'Channel $channel';
    }
  }

  // Device settings dialog removed — functionality is available via other menu items

  /// Show device rename dialog
  void _showDeviceRenameDialog() {
    final controller = TextEditingController(text: _currentDevice.deviceName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.sheetBackground,
        title: Text(AppStrings.get('rename_device')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppStrings.get('rename_device'),
            border: const OutlineInputBorder(),
            hintText: AppStrings.get('rename_device'),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get('cancel')),
          ),
          TextButton(
            onPressed: () => _renameDevice(controller.text.trim()),
            child: Text(AppStrings.get('save')),
          ),
        ],
      ),
    );
  }

  /// Rename the device with persistent storage
  Future<void> _renameDevice(String newName) async {
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('device_name_empty'))),
      );
      return;
    }

    if (newName == _currentDevice.deviceName) {
      Navigator.pop(context);
      return;
    }

    Navigator.pop(context); // Close dialog first

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(AppStrings.get('loading')),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      // Use the devices repo to rename the device
      await _devicesRepo.renameDevicePersistent(
        deviceId: widget.device.id,
        newName: newName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('device_renamed')),
            backgroundColor: Colors.green,
          ),
        );

        // Update the local device object with the new name
        setState(() {
          _currentDevice = _currentDevice.copyWith(
            displayName: newName,
            nameIsCustom: true,
          );
        });

        // Notify parent screens to refresh their device lists
        widget.onDeviceChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get('device_rename_failed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show move to room dialog
  void _showMoveToRoomDialog() async {
    if (_currentDevice.homeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('no_home_assigned')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Load available rooms for the device's home
      final rooms = await _service.getRooms(_currentDevice.homeId!);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: HBotColors.sheetBackground,
          title: Text(AppStrings.get('move_to_room')),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select a room for this device:',
                    style: TextStyle(color: HBotColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  // Scrollable list of rooms
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // No room option
                          ListTile(
                            leading: const Icon(
                              Icons.home_outlined,
                              color: HBotColors.primary,
                            ),
                            title: Text(
                              'No Room',
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              'Place device in the main area',
                              style: TextStyle(color: HBotColors.textMuted),
                            ),
                            selected: _currentDevice.roomId == null,
                            selectedTileColor: HBotColors.primary.withOpacity( 0.1),
                            onTap: () {
                              Navigator.pop(context);
                              _moveDeviceToRoom(null);
                            },
                          ),
                          const Divider(),
                          // Available rooms
                          if (rooms.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...rooms.map(
                              (room) => ListTile(
                                leading: const Icon(
                                  Icons.room,
                                  color: HBotColors.primary,
                                ),
                                title: Text(
                                  room.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                                selected: _currentDevice.roomId == room.id,
                                selectedTileColor: HBotColors.primary
                                    .withOpacity( 0.1),
                                onTap: () {
                                  Navigator.pop(context);
                                  _moveDeviceToRoom(room.id);
                                },
                              ),
                            ),
                          ] else ...[
                            Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'No rooms available. Create rooms from the home screen.',
                                style: TextStyle(color: HBotColors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.get('device_control_cancel')),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error loading rooms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("error_load_rooms")}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Move device to a specific room
  Future<void> _moveDeviceToRoom(String? roomId) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text(AppStrings.get('device_control_moving_device')),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Update device in database and get the updated device
      // If roomId is null, we want to clear the room assignment
      final updatedDevice = roomId == null
          ? await _service.updateDevice(_currentDevice.id, clearRoom: true)
          : await _service.updateDevice(_currentDevice.id, roomId: roomId);

      debugPrint(
        'Device ${_currentDevice.id} moved to room: ${roomId ?? "None"}',
      );

      // Update local device state to reflect the change immediately
      if (mounted) {
        setState(() {
          _currentDevice = updatedDevice;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              roomId != null
                  ? 'Device moved to room successfully'
                  : 'Device moved to main area',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Notify parent screen to refresh
        widget.onDeviceChanged?.call();

        // Navigate back to dashboard after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      debugPrint('Error moving device to room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("error_move_device")}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show delete confirmation dialog
  // Firmware update removed — no user-facing firmware references

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.sheetBackground,
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text(AppStrings.get('device_control_delete_device')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${widget.device.deviceName}"?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone. All device data, settings, and channel configurations will be permanently removed.',
              style: TextStyle(color: HBotColors.textMuted, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: HBotColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDevice();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppStrings.get('device_control_delete')),
          ),
        ],
      ),
    );
  }

  /// Delete the device
  Future<void> _deleteDevice() async {
    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: HBotColors.sheetBackground,
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: HBotColors.primary),
                SizedBox(width: 16),
                Text(
                  'Deleting device...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      }

      // Delete the device using the service
      await _service.deleteDevice(widget.device.id);

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Notify parent screen to refresh
      widget.onDeviceChanged?.call();

      // Navigate back to devices list and refresh
      if (mounted) {
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate device was deleted

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Device "${widget.device.deviceName}" deleted successfully',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (mounted) {
        Navigator.pop(context);
      }

      // Determine error message and icon based on error type
      String errorMessage;
      IconData errorIcon = Icons.error;

      if (e.toString().contains('Device not found')) {
        errorMessage =
            'This device has already been deleted or no longer exists.';
        errorIcon = Icons.info;
      } else if (e.toString().contains('Network error')) {
        errorMessage =
            'Unable to connect to the server. Please check your internet connection and try again.';
        errorIcon = Icons.wifi_off;
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'The operation timed out. Please try again.';
        errorIcon = Icons.timer_off;
      } else {
        errorMessage =
            'An unexpected error occurred while deleting the device. Please try again later.';
      }

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: HBotColors.sheetBackground,
            title: Row(
              children: [
                Icon(errorIcon, color: Colors.red),
                const SizedBox(width: 8),
                Text(AppStrings.get('device_control_delete_failed')),
              ],
            ),
            content: Text(
              errorMessage,
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppStrings.get('common_ok')),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Load cached device state for immediate display
  /// CRITICAL: State comes ONLY from MQTT cache, never from database
  Future<Map<String, dynamic>?> _loadCachedDeviceState() async {
    try {
      // ONLY get state from MQTT manager - no database fallback
      final mqttState = _mqttManager.getDeviceState(widget.device.id);
      if (mqttState != null) {
        debugPrint('📱 Using MQTT cached state: $mqttState');
        final sanitized = Map<String, dynamic>.from(mqttState)
          ..remove('online')
          ..remove('connected')
          ..remove('availability');
        return sanitized;
      }

      // No MQTT cache - return null and wait for MQTT update
      debugPrint(
        '📱 No MQTT cached state for ${widget.device.name}, waiting for MQTT update',
      );
      return null;
    } catch (e) {
      debugPrint('Error loading cached device state: $e');
      return null;
    }
  }

  /// Refresh device status
  Future<void> _refreshDeviceStatus() async {
    try {
      debugPrint('🔄 Refreshing device status for ${widget.device.deviceName}');

      // Check MQTT connection first
      final isConnected = _mqttManager.connectionState.toString().contains(
        'connected',
      );
      if (!isConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Not connected. Please check your connection.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Re-register device if needed
      await _mqttManager.registerDevice(widget.device);

      // Request immediate state
      await _mqttManager.requestDeviceStateImmediate(widget.device.id);

      // Also request regular state
      await _mqttManager.requestDeviceState(widget.device.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('device_control_device_status_refreshed')),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error refreshing device status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("error_refresh")}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Create default device state with all channels OFF
  Map<String, dynamic> _createDefaultDeviceState() {
    final Map<String, dynamic> state = {'status': 'initializing'};

    // Initialize all channels as OFF
    for (int i = 1; i <= widget.device.effectiveChannels; i++) {
      state['POWER$i'] = 'OFF';
    }

    return state;
  }

  /// Parse lastSeen value from a combined device state map.
  /// Supports int (ms since epoch), ISO8601 string, or DateTime.
  DateTime? _parseLastSeenFromState(Map<String, dynamic>? state) {
    if (state == null) return null;
    final ls = state['lastSeen'] ?? state['last_seen'] ?? state['lastSeenMs'];
    if (ls == null) return null;
    if (ls is DateTime) return ls;
    if (ls is int) {
      try {
        // if milliseconds
        return DateTime.fromMillisecondsSinceEpoch(ls);
      } catch (_) {
        return null;
      }
    }
    if (ls is String) {
      try {
        return DateTime.parse(ls);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
