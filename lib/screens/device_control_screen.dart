import 'package:flutter/material.dart';
import 'dart:async';
import '../models/device.dart';
import '../services/mqtt_device_manager.dart';
import '../services/smart_home_service.dart';
import '../repos/devices_repo.dart';
import '../theme/app_theme.dart';
import '../utils/channel_detection_utils.dart';
import '../widgets/shutter_control_widget.dart';
import '../widgets/settings_tile.dart';
import 'shutter_calibration_screen.dart';
import 'shutter_manual_calibration_screen.dart';
import 'device_timers_screen.dart';
import 'share_device_screen.dart';
import '../utils/phosphor_icons.dart';

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
            backgroundColor: HBotColors.error,
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
      backgroundColor: HBotColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: HBotColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(HBotIcons.back, color: HBotColors.textPrimaryLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _currentDevice.deviceName,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: HBotColors.textPrimaryLight,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Timer button (for relay and dimmer devices - lights)
          if (_currentDevice.deviceType == DeviceType.relay ||
              _currentDevice.deviceType == DeviceType.dimmer)
            IconButton(
              icon: Icon(
                HBotIcons.timer,
                color: HBotColors.iconDefault,
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
            icon: Icon(HBotIcons.settings, color: HBotColors.iconDefault),
            onPressed: _showDeviceOptions,
            tooltip: 'Device settings',
          ),
          IconButton(
            icon: Icon(
              HBotIcons.more,
              color: HBotColors.iconDefault,
            ),
            onPressed: _showDeviceOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: HBotColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: HBotSpacing.space5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: HBotSpacing.space4),
                  _buildChannelControls(),
                  const SizedBox(height: HBotSpacing.space7),
                  _buildDetailsSection(),
                  if (_showDebugInfo) ...[
                    const SizedBox(height: HBotSpacing.space4),
                    _buildDebugInfo(),
                  ],
                  const SizedBox(height: HBotSpacing.space8),
                ],
              ),
            ),
    );
  }

  /// Build the Details section with device info (power, signal, IP, firmware)
  Widget _buildDetailsSection() {
    // Extract device details from state
    String? power;
    String? todayEnergy;
    String? signalStrength;
    String? ipAddress;
    String? firmware;

    if (_deviceState != null) {
      // Power consumption
      final energyData = _deviceState!['ENERGY'] ?? _deviceState!['StatusSNS']?['ENERGY'];
      if (energyData is Map<String, dynamic>) {
        final powerVal = energyData['Power'];
        if (powerVal != null) power = '${powerVal}W';
        final todayVal = energyData['Today'];
        if (todayVal != null) todayEnergy = '${todayVal} kWh';
      }

      // Signal strength
      final wifi = _deviceState!['Wifi'] ?? _deviceState!['StatusSTS']?['Wifi'];
      if (wifi is Map<String, dynamic>) {
        final rssi = wifi['RSSI'] ?? wifi['Signal'];
        if (rssi != null) signalStrength = '$rssi dBm';
      }

      // IP Address
      final statusNet = _deviceState!['StatusNET'];
      if (statusNet is Map<String, dynamic>) {
        ipAddress = statusNet['IPAddress'] as String? ?? statusNet['IP'] as String?;
      }

      // Firmware
      final statusFWR = _deviceState!['StatusFWR'];
      if (statusFWR is Map<String, dynamic>) {
        firmware = statusFWR['Version'] as String?;
      }
    }

    // Only show details section if we have any data
    final hasDetails = power != null || todayEnergy != null ||
        signalStrength != null || ipAddress != null || firmware != null;

    if (!hasDetails) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: HBotSpacing.space1,
            bottom: HBotSpacing.space2,
          ),
          child: Text(
            'DETAILS',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: HBotColors.textTertiaryLight,
            ),
          ),
        ),
        SettingsTileGroup(
          children: [
            if (power != null)
              SettingsTile(
                icon: HBotIcons.bolt,
                title: 'Power',
                subtitle: power,
                showDivider: todayEnergy != null || signalStrength != null || ipAddress != null || firmware != null,
                trailing: const SizedBox.shrink(),
              ),
            if (todayEnergy != null)
              SettingsTile(
                icon: HBotIcons.meter,
                title: 'Today',
                subtitle: todayEnergy,
                showDivider: signalStrength != null || ipAddress != null || firmware != null,
                trailing: const SizedBox.shrink(),
              ),
            if (signalStrength != null)
              SettingsTile(
                icon: HBotIcons.wifi,
                title: 'Signal',
                subtitle: signalStrength,
                showDivider: ipAddress != null || firmware != null,
                trailing: const SizedBox.shrink(),
              ),
            if (ipAddress != null)
              SettingsTile(
                icon: HBotIcons.lan,
                title: 'IP Address',
                subtitle: ipAddress,
                showDivider: firmware != null,
                trailing: const SizedBox.shrink(),
              ),
            if (firmware != null)
              SettingsTile(
                icon: HBotIcons.firmware,
                title: 'Firmware',
                subtitle: firmware,
                showDivider: false,
                trailing: const SizedBox.shrink(),
              ),
          ],
        ),
      ],
    );
  }

  /// Show device options menu
  void _showDeviceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HBotColors.cardLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HBotRadius.large)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: HBotSpacing.space4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: HBotSpacing.space4),
                  decoration: BoxDecoration(
                    color: HBotColors.neutral300,
                    borderRadius: HBotRadius.fullRadius,
                  ),
                ),
                _buildBottomSheetTile(
                  icon: HBotIcons.edit,
                  title: 'Rename Device',
                  onTap: () {
                    Navigator.pop(context);
                    _showDeviceRenameDialog();
                  },
                ),
                _buildBottomSheetTile(
                  icon: HBotIcons.room,
                  title: 'Move to Room',
                  onTap: () {
                    Navigator.pop(context);
                    _showMoveToRoomDialog();
                  },
                ),
                // Shutter calibration options (only for shutter devices)
                if (widget.device.deviceType == DeviceType.shutter) ...[
                  _buildBottomSheetTile(
                    icon: HBotIcons.tune,
                    title: 'Auto Calibrate Shutter',
                    subtitle: 'Measure time automatically',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToCalibration();
                    },
                  ),
                  _buildBottomSheetTile(
                    icon: HBotIcons.timer,
                    title: 'Manual Calibrate Shutter',
                    subtitle: 'Enter times directly',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToManualCalibration();
                    },
                  ),
                ],
                // Share Device option
                _buildBottomSheetTile(
                  icon: HBotIcons.share,
                  title: 'Share Device',
                  subtitle: 'Share with other users via QR code',
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
                _buildBottomSheetTile(
                  icon: HBotIcons.refresh,
                  title: 'Refresh Status',
                  onTap: () {
                    Navigator.pop(context);
                    _refreshDeviceStatus();
                  },
                ),
                _buildBottomSheetTile(
                  icon: _showDebugInfo ? HBotIcons.visibilityOff : HBotIcons.visibility,
                  title: _showDebugInfo ? 'Hide Device Info' : 'Show Device Info',
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _showDebugInfo = !_showDebugInfo;
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space4),
                  child: Divider(color: HBotColors.neutral200, height: 1),
                ),
                _buildBottomSheetTile(
                  icon: HBotIcons.delete,
                  title: 'Remove Device',
                  titleColor: HBotColors.error,
                  iconColor: HBotColors.error,
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
    );
  }

  /// Bottom sheet tile matching design system
  Widget _buildBottomSheetTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: subtitle != null ? 64 : 52,
        padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? HBotColors.iconDefault,
              size: 24,
            ),
            const SizedBox(width: HBotSpacing.space3),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: titleColor ?? HBotColors.textPrimaryLight,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: HBotColors.textTertiaryLight,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  /// Build debug information section using SettingsTileGroup
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
        ipAddress ??= statusNet['IP'] as String?;
      }
    }

    // Determine model name based on device type and channel count
    modelName = _getHbotModelName();

    return SettingsTileGroup(
      title: 'Device Information',
      children: [
        SettingsTile(
          icon: HBotIcons.building,
          title: 'Manufacturer',
          subtitle: manufacturer,
          trailing: const SizedBox.shrink(),
        ),
        SettingsTile(
          icon: HBotIcons.devices,
          title: 'Device Model',
          subtitle: modelName,
          trailing: const SizedBox.shrink(),
        ),
        SettingsTile(
          icon: HBotIcons.memory,
          title: 'MAC Address',
          subtitle: macAddress ?? 'Unknown',
          trailing: const SizedBox.shrink(),
        ),
        SettingsTile(
          icon: HBotIcons.lan,
          title: 'IP Address',
          subtitle: ipAddress ?? 'Unknown',
          showDivider: false,
          trailing: const SizedBox.shrink(),
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
      return _buildMultiChannelControls();
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

  /// Build single channel control with 180x180 control card per design spec
  Widget _buildSingleChannelControl() {
    final isOn = _getChannelState(1);
    final canControl = _isDeviceControllable();
    final isOnline = _isDeviceOnline();
    final channelType = _channelTypes[1] ?? 'light';
    final isLight = channelType == 'light';

    return Column(
      children: [
        const SizedBox(height: HBotSpacing.space8),
        // Control card: 180x180, surfaceCard bg, borderDefault, radiusXL
        Center(
          child: AnimatedContainer(
            duration: HBotDurations.medium,
            curve: HBotCurves.standard,
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: HBotColors.cardLight,
              borderRadius: HBotRadius.xlRadius,
              border: Border.all(
                color: HBotColors.borderLight,
                width: 1.5,
              ),
              boxShadow: HBotShadows.small,
            ),
            child: Stack(
              children: [
                // Unreachable overlay
                if (!isOnline)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: HBotColors.neutral50.withOpacity(0.7),
                        borderRadius: HBotRadius.xlRadius,
                      ),
                      child: const Center(
                        child: Text(
                          'Unreachable',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: HBotColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Icon + state text
                if (isOnline)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: HBotDurations.medium,
                          child: Icon(
                            isLight ? HBotIcons.lightbulb : HBotIcons.power,
                            key: ValueKey(isOn),
                            size: 48,
                            color: isOn ? HBotColors.primary : HBotColors.neutral400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: HBotDurations.fast,
                          child: Text(
                            isOn ? 'ON' : 'OFF',
                            key: ValueKey(isOn),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isOn ? HBotColors.primary : HBotColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Toggle: centered, space6 below control card
        const SizedBox(height: HBotSpacing.space6),
        Center(
          child: Transform.scale(
            scale: 1.2,
            child: Switch(
              value: isOn,
              onChanged: canControl && isOnline
                  ? (_) => _toggleChannel(1)
                  : null,
              activeColor: HBotColors.primary,
              activeTrackColor: HBotColors.primary.withOpacity(0.3),
              inactiveTrackColor: HBotColors.toggleTrackOff,
            ),
          ),
        ),
      ],
    );
  }

  /// Build multi-channel controls with grid of control cards
  Widget _buildMultiChannelControls() {
    final canControl = _isDeviceControllable();
    final isOnline = _isDeviceOnline();
    final layout = ChannelDetectionUtils.getOptimalGridLayout(
      widget.device.effectiveChannels,
    );
    final columns = layout['columns'] ?? 2;

    return Column(
      children: [
        const SizedBox(height: HBotSpacing.space4),
        // Grid of channel control cards
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: HBotSpacing.space3,
            mainAxisSpacing: HBotSpacing.space3,
            childAspectRatio: 0.85,
          ),
          itemCount: widget.device.effectiveChannels,
          itemBuilder: (context, index) {
            final channel = index + 1;
            final isOn = _getChannelState(channel);

            return _buildChannelControlCard(
              channel: channel,
              isOn: isOn,
              canControl: canControl && isOnline,
            );
          },
        ),
      ],
    );
  }

  /// Build a channel control card matching the design spec
  /// Card with icon, channel name, state text, and toggle
  Widget _buildChannelControlCard({
    required int channel,
    required bool isOn,
    required bool canControl,
  }) {
    final channelType = _channelTypes[channel] ?? 'light';
    final isLight = channelType == 'light';

    return GestureDetector(
      onLongPress: () => _showChannelOptionsDialog(channel),
      child: AnimatedContainer(
        duration: HBotDurations.medium,
        curve: HBotCurves.standard,
        decoration: BoxDecoration(
          color: HBotColors.cardLight,
          borderRadius: HBotRadius.largeRadius,
          border: Border(
            left: BorderSide(
              color: isOn ? HBotColors.primary : HBotColors.borderLight,
              width: isOn ? 3 : 1,
            ),
            top: BorderSide(color: HBotColors.borderLight, width: 1),
            right: BorderSide(color: HBotColors.borderLight, width: 1),
            bottom: BorderSide(color: HBotColors.borderLight, width: 1),
          ),
          boxShadow: HBotShadows.small,
        ),
        child: Padding(
          padding: const EdgeInsets.all(HBotSpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              AnimatedSwitcher(
                duration: HBotDurations.medium,
                child: Icon(
                  isLight ? HBotIcons.lightbulb : HBotIcons.power,
                  key: ValueKey('$channel-$isOn'),
                  size: 28,
                  color: isOn ? HBotColors.primary : HBotColors.neutral400,
                ),
              ),
              const SizedBox(height: HBotSpacing.space2),
              // Channel name
              Text(
                _getChannelName(channel),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: HBotColors.textPrimaryLight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: HBotSpacing.space1),
              // State text
              AnimatedSwitcher(
                duration: HBotDurations.fast,
                child: Text(
                  isOn ? 'ON' : 'OFF',
                  key: ValueKey('state-$channel-$isOn'),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isOn ? HBotColors.primary : HBotColors.textSecondaryLight,
                  ),
                ),
              ),
              const Spacer(),
              // Toggle switch
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 24,
                  child: FittedBox(
                    child: Switch(
                      value: isOn,
                      onChanged: canControl
                          ? (_) => _toggleChannel(channel)
                          : null,
                      activeColor: HBotColors.primary,
                      activeTrackColor: HBotColors.primary.withOpacity(0.3),
                      inactiveTrackColor: HBotColors.toggleTrackOff,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show channel rename dialog
  void _showChannelRenameDialog(int channel) {
    final controller = TextEditingController(text: _getChannelName(channel));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.cardLight,
        shape: RoundedRectangleBorder(borderRadius: HBotRadius.largeRadius),
        title: Text(
          'Rename ${_getChannelName(channel)}',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: HBotColors.textPrimaryLight,
          ),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: HBotColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: 'Enter channel name',
            hintStyle: const TextStyle(color: HBotColors.textTertiaryLight),
            filled: true,
            fillColor: HBotColors.neutral50,
            border: OutlineInputBorder(
              borderRadius: HBotRadius.mediumRadius,
              borderSide: const BorderSide(color: HBotColors.borderLight, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: HBotRadius.mediumRadius,
              borderSide: const BorderSide(color: HBotColors.borderLight, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: HBotRadius.mediumRadius,
              borderSide: const BorderSide(color: HBotColors.borderFocused, width: 2),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: HBotColors.textSecondaryLight),
            ),
          ),
          TextButton(
            onPressed: () {
              _updateChannelName(channel, controller.text);
              Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: HBotColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// Show channel options dialog (rename and change type)
  void _showChannelOptionsDialog(int channel) {
    final channelType = _channelTypes[channel] ?? 'light';

    showModalBottomSheet(
      context: context,
      backgroundColor: HBotColors.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HBotRadius.large)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: HBotSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: HBotSpacing.space3),
                decoration: BoxDecoration(
                  color: HBotColors.neutral300,
                  borderRadius: HBotRadius.fullRadius,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HBotSpacing.space5,
                  vertical: HBotSpacing.space2,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _getChannelName(channel),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: HBotColors.textPrimaryLight,
                    ),
                  ),
                ),
              ),
              _buildBottomSheetTile(
                icon: HBotIcons.edit,
                title: 'Rename Channel',
                onTap: () {
                  Navigator.pop(context);
                  _showChannelRenameDialog(channel);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HBotSpacing.space5,
                  vertical: HBotSpacing.space2,
                ),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CHANNEL TYPE',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: HBotColors.textTertiaryLight,
                    ),
                  ),
                ),
              ),
              _buildBottomSheetTile(
                icon: HBotIcons.lightbulb,
                title: 'Light',
                iconColor: channelType == 'light' ? HBotColors.primary : HBotColors.iconDefault,
                titleColor: channelType == 'light' ? HBotColors.primary : null,
                onTap: () {
                  Navigator.pop(context);
                  _updateChannelType(channel, 'light');
                },
              ),
              _buildBottomSheetTile(
                icon: HBotIcons.power,
                title: 'Switch',
                iconColor: channelType == 'switch' ? HBotColors.primary : HBotColors.iconDefault,
                titleColor: channelType == 'switch' ? HBotColors.primary : null,
                onTap: () {
                  Navigator.pop(context);
                  _updateChannelType(channel, 'switch');
                },
              ),
            ],
          ),
        ),
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
            backgroundColor: HBotColors.success,
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
            backgroundColor: HBotColors.error,
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
            backgroundColor: HBotColors.success,
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
            backgroundColor: HBotColors.error,
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
        backgroundColor: HBotColors.cardLight,
        shape: RoundedRectangleBorder(borderRadius: HBotRadius.largeRadius),
        title: const Text(
          'Rename Device',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: HBotColors.textPrimaryLight,
          ),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: HBotColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            labelText: 'Device Name',
            hintText: 'Enter a custom name for your device',
            filled: true,
            fillColor: HBotColors.neutral50,
            border: OutlineInputBorder(
              borderRadius: HBotRadius.mediumRadius,
              borderSide: const BorderSide(color: HBotColors.borderLight, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: HBotRadius.mediumRadius,
              borderSide: const BorderSide(color: HBotColors.borderLight, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: HBotRadius.mediumRadius,
              borderSide: const BorderSide(color: HBotColors.borderFocused, width: 2),
            ),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: HBotColors.textSecondaryLight),
            ),
          ),
          TextButton(
            onPressed: () => _renameDevice(controller.text.trim()),
            child: const Text(
              'Save',
              style: TextStyle(color: HBotColors.primary),
            ),
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
            backgroundColor: HBotColors.success,
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
            backgroundColor: HBotColors.error,
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
          backgroundColor: HBotColors.error,
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
          backgroundColor: HBotColors.cardLight,
          shape: RoundedRectangleBorder(borderRadius: HBotRadius.largeRadius),
          title: const Text(
            'Move to Room',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HBotColors.textPrimaryLight,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select a room for this device:',
                    style: TextStyle(color: HBotColors.textSecondaryLight),
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
                            leading: Icon(
                              HBotIcons.home,
                              color: HBotColors.primary,
                            ),
                            title: Text(
                              'No Room',
                              style: TextStyle(
                                color: HBotColors.textPrimaryLight,
                              ),
                            ),
                            subtitle: const Text(
                              'Place device in the main area',
                              style: TextStyle(color: HBotColors.textSecondaryLight),
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
                                leading: Icon(
                                  HBotIcons.room,
                                  color: HBotColors.primary,
                                ),
                                title: Text(
                                  room.name,
                                  style: TextStyle(
                                    color: HBotColors.textPrimaryLight,
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
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'No rooms available. Create rooms from the home screen.',
                                style: TextStyle(color: HBotColors.textTertiaryLight),
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
            backgroundColor: HBotColors.error,
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
            backgroundColor: HBotColors.success,
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
            backgroundColor: HBotColors.error,
          ),
        );
      }
    }
  }

  /// Show delete confirmation dialog (destructive dialog per design spec)
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.cardLight,
        shape: RoundedRectangleBorder(borderRadius: HBotRadius.largeRadius),
        title: const Text(
          'Remove Device?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: HBotColors.textPrimaryLight,
          ),
        ),
        content: const Text(
          'This will remove the device from all rooms and scenes. This action cannot be undone.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: HBotColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Inter',
                color: HBotColors.textSecondaryLight,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDevice();
            },
            style: TextButton.styleFrom(
              foregroundColor: HBotColors.error,
            ),
            child: const Text(
              'Remove',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
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
            backgroundColor: HBotColors.cardLight,
            shape: RoundedRectangleBorder(borderRadius: HBotRadius.largeRadius),
            content: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: HBotColors.primary),
                SizedBox(width: 16),
                Text(
                  'Removing device...',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: HBotColors.textPrimaryLight,
                  ),
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
            backgroundColor: HBotColors.success,
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
      IconData errorIcon = HBotIcons.error;

      if (e.toString().contains('Device not found')) {
        errorMessage =
            'This device has already been deleted or no longer exists.';
        errorIcon = HBotIcons.info;
      } else if (e.toString().contains('Network error')) {
        errorMessage =
            'Unable to connect to the server. Please check your internet connection and try again.';
        errorIcon = HBotIcons.wifiOff;
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'The operation timed out. Please try again.';
        errorIcon = HBotIcons.timerOff;
      } else {
        errorMessage =
            'An unexpected error occurred while deleting the device. Please try again later.';
      }

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: HBotColors.cardLight,
            shape: RoundedRectangleBorder(borderRadius: HBotRadius.largeRadius),
            title: Row(
              children: [
                Icon(errorIcon, color: HBotColors.error, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Remove Failed',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: HBotColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            content: Text(
              errorMessage,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: HBotColors.textSecondaryLight,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: HBotColors.primary),
                ),
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
                'MQTT not connected. Please check your connection.',
              ),
              backgroundColor: HBotColors.warning,
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
            backgroundColor: HBotColors.success,
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
            backgroundColor: HBotColors.error,
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
