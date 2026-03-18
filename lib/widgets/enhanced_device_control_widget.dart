import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import '../models/device.dart';
import '../services/mqtt_device_manager.dart';
import '../repos/devices_repo.dart';
import '../widgets/mqtt_debug_sheet.dart';
import '../widgets/shutter_control_widget.dart';
import '../widgets/channel_grid.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';

/// Enhanced widget for controlling devices with the new MQTT device manager
class EnhancedDeviceControlWidget extends StatefulWidget {
  final Device device;
  final MqttDeviceManager? mqttManager;
  final bool showBulkControls;

  const EnhancedDeviceControlWidget({
    super.key,
    required this.device,
    this.mqttManager,
    this.showBulkControls = true,
  });

  @override
  State<EnhancedDeviceControlWidget> createState() =>
      _EnhancedDeviceControlWidgetState();
}

class _EnhancedDeviceControlWidgetState
    extends State<EnhancedDeviceControlWidget> {
  late MqttDeviceManager _mqttManager;
  final DevicesRepo _devicesRepo = DevicesRepo();
  final Map<int, bool> _channelStates = {};
  final Map<int, String> _channelNames = {};
  final Map<int, String> _channelTypes = {}; // 'light' or 'switch'
  StreamSubscription? _deviceStateSubscription;
  StreamSubscription? _connectionStateSubscription;
  MqttConnectionState _connectionState = MqttConnectionState.disconnected;
  bool _isOptimistic = false;
  bool _hasRealtime = false;
  Timer? _stateRefreshTimer;

  @override
  void initState() {
    super.initState();
    _mqttManager = widget.mqttManager ?? MqttDeviceManager();
    _initializeDevice();
    _loadChannelNames();
    _startPeriodicStateRefresh();
  }

  @override
  void dispose() {
    _deviceStateSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _stateRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(EnhancedDeviceControlWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If device changed, re-initialize
    if (oldWidget.device.id != widget.device.id) {
      _initializeDevice();
      _loadChannelNames();
    }
  }

  /// Load channel names from database
  Future<void> _loadChannelNames() async {
    try {
      final deviceWithChannels = await _devicesRepo.getDeviceWithChannels(
        widget.device.id,
      );
      if (deviceWithChannels != null && mounted) {
        setState(() {
          // Load custom channel names and types from the database
          for (int i = 1; i <= widget.device.effectiveChannels; i++) {
            final channelLabel = deviceWithChannels.getChannelLabel(i);
            if (channelLabel != 'Channel $i') {
              _channelNames[i] = channelLabel;
            }
            // Load channel type
            _channelTypes[i] = deviceWithChannels.getChannelType(i);
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load channel names: $e');
      // Continue with default names if loading fails
    }
  }

  /// Get channel name (supports custom names)
  String _getChannelName(int channel) {
    return _channelNames[channel] ?? 'Channel $channel';
  }

  Future<void> _initializeDevice() async {
    try {
      // DON'T initialize channel states to false - wait for real state
      // This prevents flickering from false → true transitions

      // Listen to connection state changes
      _connectionStateSubscription = _mqttManager.connectionStateStream.listen((
        state,
      ) {
        if (mounted) {
          setState(() {
            _connectionState = state;
          });

          // When connection is established, immediately request state
          if (state == MqttConnectionState.connected) {
            debugPrint(
              '🔌 Device ${widget.device.name}: MQTT connected, requesting state',
            );
            _requestCurrentState();
          }
        }
      });

      // Set initial connection state
      _connectionState = _mqttManager.connectionState;

      // Register device with MQTT manager
      await _mqttManager.registerDevice(widget.device);

      // Listen to device state updates (MQTT authoritative)
      final stream = _mqttManager.getDeviceStateStream(widget.device.id);
      if (stream != null) {
        _deviceStateSubscription = stream.listen((state) {
          _hasRealtime = true;
          _handleDeviceStateUpdate(state);
        });
      }

      // Get cached state immediately if available (prevents initial false state)
      final cachedState = _mqttManager.getDeviceState(widget.device.id);
      if (cachedState != null) {
        debugPrint('📦 Device ${widget.device.name}: Loading cached state');
        _handleDeviceStateUpdate(cachedState);
      }

      // Request immediate state for real-time display
      debugPrint('🔄 Device ${widget.device.name}: Requesting initial state');
      await _requestCurrentState();

      // Request again after a short delay (some devices need time to respond)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _requestCurrentState();
        }
      });
    } catch (e) {
      debugPrint('Error initializing enhanced device control: $e');
    }
  }

  /// Request current state from the device
  Future<void> _requestCurrentState() async {
    try {
      // Use immediate state request for faster response
      await _mqttManager.requestDeviceStateImmediate(widget.device.id);

      // Also request regular state as backup
      await Future.delayed(const Duration(milliseconds: 100));
      await _mqttManager.requestDeviceState(widget.device.id);
    } catch (e) {
      debugPrint('Error requesting device state: $e');
    }
  }

  /// Start periodic state refresh to keep UI in sync
  void _startPeriodicStateRefresh() {
    // Refresh state every 30 seconds to ensure UI stays in sync
    _stateRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _connectionState == MqttConnectionState.connected) {
        debugPrint('🔄 Device ${widget.device.name}: Periodic state refresh');
        _requestCurrentState();
      }
    });
  }

  void _handleDeviceStateUpdate(Map<String, dynamic> state) {
    if (!mounted) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final wasOptimistic = _isOptimistic;
    final newIsOptimistic = state.containsKey('optimistic');

    // Log incoming state for debugging
    final powerStates = <String, dynamic>{};
    for (int i = 1; i <= widget.device.effectiveChannels; i++) {
      final powerKey = 'POWER$i';
      if (state.containsKey(powerKey)) {
        powerStates[powerKey] = state[powerKey];
      }
    }

    debugPrint(
      '📥 [${widget.device.name}] State update received at $timestamp: '
      'optimistic=$newIsOptimistic, powers=$powerStates',
    );

    // Update channel states from MQTT messages
    bool hasStateChanges = false;
    final Map<int, bool> newChannelStates = {};

    for (int i = 1; i <= widget.device.effectiveChannels; i++) {
      final powerKey = 'POWER$i';
      if (state.containsKey(powerKey)) {
        final powerValue = state[powerKey];
        bool newState = false;

        if (powerValue is String) {
          newState = powerValue.toUpperCase() == 'ON';
        } else if (powerValue is bool) {
          newState = powerValue;
        }

        // Get current state (null if not yet initialized)
        final currentState = _channelStates[i];

        // Determine if we should update:
        // 1. State value actually changed
        // 2. First time setting state (currentState == null)
        // 3. Confirming optimistic state with same value (wasOptimistic && !newIsOptimistic && same value)
        final valueChanged = currentState != newState;
        final firstTimeSet = currentState == null;
        final confirmingOptimistic =
            wasOptimistic && !newIsOptimistic && currentState == newState;

        if (valueChanged || firstTimeSet) {
          newChannelStates[i] = newState;
          hasStateChanges = true;

          debugPrint(
            '📊 [${widget.device.name}] Channel $i: ${currentState ?? 'null'} → $newState '
            '(valueChanged=$valueChanged, firstTimeSet=$firstTimeSet, optimistic=$newIsOptimistic)',
          );
        } else if (confirmingOptimistic) {
          // Optimistic state confirmed - just update the flag, don't change value
          debugPrint(
            '✅ [${widget.device.name}] Channel $i: Optimistic state confirmed ($newState)',
          );
        } else {
          // No change needed
          debugPrint(
            '⏭️  [${widget.device.name}] Channel $i: No change ($currentState), skipping',
          );
        }
      }
    }

    // Determine if we need to call setState
    final needsUpdate = hasStateChanges || (wasOptimistic && !newIsOptimistic);

    if (needsUpdate) {
      debugPrint(
        '🔄 [${widget.device.name}] Calling setState: hasStateChanges=$hasStateChanges, '
        'optimisticChange=${wasOptimistic && !newIsOptimistic}',
      );

      setState(() {
        _isOptimistic = newIsOptimistic;

        // Apply all state changes at once
        for (final entry in newChannelStates.entries) {
          _channelStates[entry.key] = entry.value;
        }
      });

      if (hasStateChanges) {
        debugPrint(
          '✅ [${widget.device.name}] State updated successfully: $_channelStates',
        );
      }
    } else {
      debugPrint('⏭️  [${widget.device.name}] No setState needed (no changes)');
    }
  }

  Future<void> _setChannelState(int channel, bool on) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final currentState = _channelStates[channel];

    debugPrint(
      '👆 [${widget.device.name}] User action at $timestamp: '
      'Channel $channel: $currentState → $on',
    );

    try {
      await _mqttManager.setChannelPower(widget.device.id, channel, on);

      debugPrint(
        '✅ [${widget.device.name}] Command sent successfully: Channel $channel = $on',
      );
    } catch (e) {
      debugPrint(
        '❌ [${widget.device.name}] Error setting channel $channel to ${on ? 'ON' : 'OFF'}: $e',
      );

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

  Future<void> _turnAllOn() async {
    try {
      await _mqttManager.turnAllChannelsOn(widget.device.id);
      debugPrint('✅ All channels ON command sent');
    } catch (e) {
      debugPrint('❌ Error turning all channels on: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('enhanced_device_control_failed_to_turn_all_channels_on')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _turnAllOff() async {
    try {
      await _mqttManager.turnAllChannelsOff(widget.device.id);
      debugPrint('✅ All channels OFF command sent');
    } catch (e) {
      debugPrint('❌ Error turning all channels off: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('enhanced_device_control_failed_to_turn_all_channels_off')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDebugSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MqttDebugSheet(mqttManager: _mqttManager),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(HBotSpacing.space4),
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device header - status indicators removed
            Row(
              children: [
                Icon(_getDeviceIcon(), size: 24, color: HBotColors.primary),
                const SizedBox(width: HBotSpacing.space2),
                Expanded(
                  child: Text(
                    widget.device.deviceName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.hTextPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: HBotSpacing.space4),

            // Channel controls - different UI for shutter devices
            if (widget.device.deviceType == DeviceType.shutter)
              ShutterControlWidget(
                device: widget.device,
                mqttManager: _mqttManager,
                shutterIndex: 1,
              )
            else if (widget.device.channels == 1)
              _buildSingleChannelControl()
            else
              _buildChannelGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleChannelControl() {
    final isOn = _channelStates[1] ?? false;
    final isConnected = _connectionState == MqttConnectionState.connected;

    return SwitchListTile(
      title: Text(AppStrings.get('enhanced_device_control_power')),
      value: isOn,
      onChanged: isConnected ? (value) => _setChannelState(1, value) : null,
    );
  }

  Widget _buildChannelGrid() {
    final isConnected = _connectionState == MqttConnectionState.connected;

    return ChannelGrid(
      channelCount: widget.device.effectiveChannels,
      channelStates: _channelStates,
      channelNames: _channelNames,
      channelTypes: _channelTypes,
      canControl: isConnected,
      compact: true,
      onToggleChannel: (channel, value) => _setChannelState(channel, value),
      onAllOn: _turnAllOn,
      onAllOff: _turnAllOff,
    );
  }

  IconData _getDeviceIcon() {
    switch (widget.device.deviceType) {
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
}
