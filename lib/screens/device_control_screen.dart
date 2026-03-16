import 'package:flutter/material.dart';
import 'dart:async';
import '../models/device.dart';
import '../services/mqtt_device_manager.dart';
import '../services/smart_home_service.dart';
import '../repos/devices_repo.dart';
import '../theme/app_theme.dart';
import '../utils/channel_detection_utils.dart';
import '../widgets/shutter_control_widget.dart';
import '../widgets/channel_grid.dart';
import 'shutter_calibration_screen.dart';
import 'shutter_manual_calibration_screen.dart';
import 'device_timers_screen.dart';
import 'share_device_screen.dart';
import '../widgets/responsive_shell.dart';
import 'activity_log_screen.dart';
import '../services/device_event_tracker.dart';
import '../services/activity_log_service.dart';

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
  String? _firmwareVersion;
  bool _isUpdatingFirmware = false;
  StreamSubscription? _stateSubscription;

  // Local device instance that can be updated
  late Device _currentDevice;

  // Channel management
  final Map<int, String> _channelNames = {};
  final Map<int, String> _channelTypes = {}; // 'light' or 'switch'

  @override
  void dispose() {
    _stateSubscription?.cancel();
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
    _firmwareVersion = widget.device.metaJson?['version'] as String?;
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
        _mqttManager.connectionStateStream.listen((state) {
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
            content: Text('Failed to control channel $channel: $e'),
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
      backgroundColor: context.hBackground,
      appBar: AppBar(
        backgroundColor: context.hBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.hTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _currentDevice.deviceName,
          style: TextStyle(
            color: context.hTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Timer button (for relay and dimmer devices - lights)
          if (_currentDevice.deviceType == DeviceType.relay ||
              _currentDevice.deviceType == DeviceType.dimmer)
            IconButton(
              icon: const Icon(
                Icons.timer_outlined,
                color: HBotColors.primary,
              ),
              onPressed: () {
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
              tooltip: 'Set Timers',
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: context.hTextPrimary),
            onPressed: _refreshDeviceStatus,
            tooltip: 'Refresh device status',
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: context.hTextPrimary,
            ),
            onPressed: _showDeviceOptions,
          ),
        ],
      ),
      body: ResponsiveShell(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: HBotColors.primary),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: HBotLayout.isTablet(context) ? HBotSpacing.space6 : HBotSpacing.space5,
                  vertical: HBotSpacing.space6,
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
    );
  }

  /// Device header - shows only device name (status indicators removed)
  Widget _buildDeviceHeader() {
    return Column(
      children: [
        Text(
          _currentDevice.deviceName,
          style: TextStyle(
            color: context.hTextPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Show device options menu
  void _showDeviceOptions() {
    _isBottomSheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.hCard,
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
                  leading: Icon(
                    Icons.edit,
                    color: context.hTextPrimary,
                  ),
                  title: Text(
                    'Rename Device',
                    style: TextStyle(color: context.hTextPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeviceRenameDialog();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.room,
                    color: context.hTextPrimary,
                  ),
                  title: Text(
                    'Move to Room',
                    style: TextStyle(color: context.hTextPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showMoveToRoomDialog();
                  },
                ),
                // Shutter calibration options (only for shutter devices)
                if (widget.device.deviceType == DeviceType.shutter) ...[
                  ListTile(
                    leading: Icon(
                      Icons.tune,
                      color: context.hTextPrimary,
                    ),
                    title: Text(
                      'Auto Calibrate Shutter',
                      style: TextStyle(color: context.hTextPrimary),
                    ),
                    subtitle: Text(
                      'Measure time automatically',
                      style: TextStyle(color: context.hTextTertiary, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToCalibration();
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.timer,
                      color: context.hTextPrimary,
                    ),
                    title: Text(
                      'Manual Calibrate Shutter',
                      style: TextStyle(color: context.hTextPrimary),
                    ),
                    subtitle: Text(
                      'Enter times directly',
                      style: TextStyle(color: context.hTextTertiary, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToManualCalibration();
                    },
                  ),
                ],
                // Share Device option
                ListTile(
                  leading: Icon(
                    Icons.share_outlined,
                    color: context.hTextPrimary,
                  ),
                  title: Text(
                    'Share Device',
                    style: TextStyle(color: context.hTextPrimary),
                  ),
                  subtitle: Text(
                    'Share with other users via QR code',
                    style: TextStyle(color: context.hTextTertiary, fontSize: 12),
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
                  leading: Icon(Icons.system_update, color: context.hTextPrimary),
                  title: Text('Firmware Update', style: TextStyle(color: context.hTextPrimary)),
                  subtitle: Text(
                    _firmwareVersion ?? 'Check for updates',
                    style: TextStyle(color: context.hTextTertiary, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showFirmwareDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.history, color: context.hTextPrimary),
                  title: Text('Activity Log', style: TextStyle(color: context.hTextPrimary)),
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
                    color: context.hTextPrimary,
                  ),
                  title: Text(
                    _showDebugInfo ? 'Hide Device Info' : 'Show Device Info',
                    style: TextStyle(color: context.hTextPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _showDebugInfo = !_showDebugInfo;
                    });
                  },
                ),
                Divider(color: context.hTextTertiary),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete Device',
                    style: TextStyle(color: Colors.red),
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

    return Card(
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Information',
              style: TextStyle(
                color: context.hTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),
            _buildInfoRow('Manufacturer', manufacturer),
            const SizedBox(height: HBotSpacing.space2),
            _buildInfoRow('Device Model', modelName),
            const SizedBox(height: HBotSpacing.space2),
            _buildInfoRow('Mac address', macAddress ?? 'Unknown'),
            const SizedBox(height: HBotSpacing.space2),
            _buildInfoRow('IP Address', ipAddress ?? 'Unknown'),
          ],
        ),
      ),
    );
  }

  /// Build a single info row with label and value
  Widget _buildInfoRow(String label, String value) {

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.grey[900],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
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

  /// Build single channel control with large circular power button
  Widget _buildSingleChannelControl() {
    final isOn = _getChannelState(1);
    final canControl = _canSendCommands();

    return Center(
      child: GestureDetector(
        onTap: canControl ? () => _toggleChannel(1) : null,
        child: AnimatedContainer(
          duration: HBotDurations.medium,
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOn
                ? HBotColors.primary.withOpacity(0.1)
                : context.hCard,
            border: Border.all(
              color: isOn ? HBotColors.primary : context.hBorder,
              width: 3,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _channelTypes[1] == 'switch'
                    ? Icons.power_settings_new
                    : Icons.lightbulb,
                size: 48,
                color: isOn ? HBotColors.primary : HBotColors.iconDefault,
              ),
              const SizedBox(height: HBotSpacing.space2),
              Text(
                isOn ? 'ON' : 'OFF',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isOn ? HBotColors.primary : context.hTextSecondary,
                ),
              ),
            ],
          ),
        ),
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
    for (int i = 1; i <= widget.device.effectiveChannels; i++) {
      try {
        await _mqttManager.setChannelPower(
          widget.device.id,
          i,
          on,
        );
      } catch (e) {
        debugPrint('Failed to set channel $i: $e');
      }
    }
  }

  /// Show channel rename dialog
  void _showChannelRenameDialog(int channel) {
    final controller = TextEditingController(text: _getChannelName(channel));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.hCard,
        title: Text('Rename ${_getChannelName(channel)}'),
        content: TextField(
          controller: controller,
          style: TextStyle(color: context.hTextPrimary),
          decoration: InputDecoration(
            hintText: 'Enter channel name',
            hintStyle: TextStyle(color: context.hTextTertiary),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _updateChannelName(channel, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
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
        backgroundColor: context.hCard,
        title: Text('${_getChannelName(channel)} Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: HBotColors.primary),
              title: Text(
                'Rename Channel',
                style: TextStyle(color: context.hTextPrimary),
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
                    : context.hTextSecondary,
              ),
              title: Text(
                'Light',
                style: TextStyle(color: context.hTextPrimary),
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
                    : context.hTextSecondary,
              ),
              title: Text(
                'Switch',
                style: TextStyle(color: context.hTextPrimary),
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
            child: const Text('Close'),
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
            content: Text('Channel $channel renamed successfully'),
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
            content: Text('Failed to rename channel: $e'),
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
        final typeName = newType == 'light' ? 'Light' : 'Switch';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Channel $channel changed to $typeName'),
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
            content: Text('Failed to update channel type: $e'),
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
        backgroundColor: context.hCard,
        title: const Text('Rename Device'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Device Name',
            border: OutlineInputBorder(),
            hintText: 'Enter a custom name for your device',
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _renameDevice(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Rename the device with persistent storage
  Future<void> _renameDevice(String newName) async {
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device name cannot be empty')),
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
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Renaming device...'),
          ],
        ),
        duration: Duration(seconds: 10),
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
          const SnackBar(
            content: Text('Device renamed successfully'),
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
            content: Text('Failed to rename device: $e'),
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
        const SnackBar(
          content: Text('Cannot move device: No home assigned'),
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
          backgroundColor: context.hCard,
          title: const Text('Move to Room'),
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
                    style: TextStyle(color: context.hTextSecondary),
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
                                color: context.hTextPrimary,
                              ),
                            ),
                            subtitle: Text(
                              'Place device in the main area',
                              style: TextStyle(color: context.hTextSecondary),
                            ),
                            selected: _currentDevice.roomId == null,
                            selectedTileColor: HBotColors.primary.withOpacity(0.1),
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
                                    color: context.hTextPrimary,
                                  ),
                                ),
                                selected: _currentDevice.roomId == room.id,
                                selectedTileColor: HBotColors.primary
                                    .withOpacity(0.1),
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
                                style: TextStyle(color: context.hTextTertiary),
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
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error loading rooms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load rooms: $e'),
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
          const SnackBar(
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
                Text('Moving device...'),
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
            content: Text('Failed to move device: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show delete confirmation dialog
  void _showFirmwareDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.hCard,
          title: const Text('Firmware Update'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Version',
                style: TextStyle(
                  fontSize: 12,
                  color: context.hTextTertiary,
                  fontFamily: 'DM Sans',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _firmwareVersion ?? 'Unknown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.hTextPrimary,
                  fontFamily: 'DM Sans',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This will check for and install the latest Tasmota firmware. '
                'The device will restart during the update.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.hTextSecondary,
                  fontFamily: 'DM Sans',
                ),
              ),
              if (_isUpdatingFirmware) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(color: HBotColors.primary),
                const SizedBox(height: 8),
                Text(
                  'Updating firmware... Device will restart.',
                  style: TextStyle(
                    fontSize: 12,
                    color: HBotColors.primary,
                    fontFamily: 'DM Sans',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (!_isUpdatingFirmware)
              ElevatedButton.icon(
                onPressed: () async {
                  setDialogState(() {});
                  setState(() => _isUpdatingFirmware = true);
                  setDialogState(() {});
                  try {
                    // Send Tasmota OTA upgrade command
                    await _mqttManager.publishCommand(
                      widget.device.id,
                      'Upgrade 1',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Firmware update initiated. Device will restart.'),
                          backgroundColor: HBotColors.primary,
                        ),
                      );
                    }
                    // Log the event
                    DeviceEventTracker().logEvent(
                      deviceId: widget.device.id,
                      deviceName: _currentDevice.deviceName,
                      eventType: ActivityEventType.firmwareUpdate,
                      description: 'Firmware update initiated',
                      details: 'Current version: ${_firmwareVersion ?? "unknown"}',
                    );
                    Navigator.pop(ctx);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to start update: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isUpdatingFirmware = false);
                  }
                },
                icon: const Icon(Icons.system_update, size: 18),
                label: const Text('Update Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HBotColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.hCard,
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Device'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${widget.device.deviceName}"?',
              style: TextStyle(
                color: context.hTextPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone. All device data, settings, and channel configurations will be permanently removed.',
              style: TextStyle(color: context.hTextSecondary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.hTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDevice();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
            backgroundColor: context.hCard,
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: HBotColors.primary),
                SizedBox(width: 16),
                Text(
                  'Deleting device...',
                  style: TextStyle(color: context.hTextPrimary),
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
            backgroundColor: context.hCard,
            title: Row(
              children: [
                Icon(errorIcon, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Delete Failed'),
              ],
            ),
            content: Text(
              errorMessage,
              style: TextStyle(color: context.hTextPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
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
          const SnackBar(
            content: Text('Device status refreshed'),
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
            content: Text('Failed to refresh: $e'),
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
