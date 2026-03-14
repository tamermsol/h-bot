import 'package:flutter/material.dart';
import 'dart:async';
import '../models/device.dart';
import '../models/tasmota_device_info.dart';
import '../services/tasmota_mqtt_service.dart';
import '../repos/devices_repo.dart';
import '../theme/app_theme.dart';
import '../utils/channel_detection_utils.dart';
import '../utils/phosphor_icons.dart';

/// Widget for controlling multi-channel Tasmota devices with MQTT
class DeviceControlWidget extends StatefulWidget {
  final Device device;
  final TasmotaMqttService mqttService;

  const DeviceControlWidget({
    super.key,
    required this.device,
    required this.mqttService,
  });

  @override
  State<DeviceControlWidget> createState() => _DeviceControlWidgetState();
}

class _DeviceControlWidgetState extends State<DeviceControlWidget> {
  final DevicesRepo _devicesRepo = DevicesRepo();
  final Map<int, bool> _channelStates = {};
  final Map<int, String> _channelNames = {};
  final Map<int, String> _channelTypes = {}; // 'light' or 'switch'
  StreamSubscription? _mqttSubscription;
  bool _isConnected = false;
  bool _hasRealtime = false;

  @override
  void initState() {
    super.initState();
    _initializeDevice();
    _loadChannelNames();
  }

  @override
  void dispose() {
    _mqttSubscription?.cancel();
    super.dispose();
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
      // Initialize channel states
      for (int i = 1; i <= widget.device.effectiveChannels; i++) {
        _channelStates[i] = false;
      }

      // Connect to MQTT if not already connected
      if (widget.mqttService.connectionStatus !=
          MqttConnectionStatus.connected) {
        await widget.mqttService.connect();
      }

      // Subscribe to device state updates (MQTT is authoritative)
      if (widget.device.tasmotaTopicBase != null) {
        await _subscribeToDeviceUpdates();

        // Request current status
        await widget.mqttService.requestStatus(widget.device.tasmotaTopicBase!);
      }

      setState(() {
        _isConnected = true;
      });
    } catch (e) {
      debugPrint('Error initializing device control: $e');
    }
  }

  Future<void> _subscribeToDeviceUpdates() async {
    if (widget.device.tasmotaTopicBase == null) return;

    try {
      // Subscribe to all state topics for this device
      final topicBase = widget.device.tasmotaTopicBase!;

      // Listen to device-specific MQTT messages
      final deviceStream = widget.mqttService.getDeviceStream(topicBase);
      if (deviceStream != null) {
        _mqttSubscription = deviceStream.listen((message) {
          _handleMqttMessage(message);
        });
        // mark that we have realtime data available
        _hasRealtime = true;
      }

      // Note: Power state topic subscriptions are handled by the MQTT service
    } catch (e) {
      debugPrint('Error subscribing to device updates: $e');
    }
  }

  void _handleMqttMessage(Map<String, dynamic> message) {
    try {
      final topic = message['topic'] as String;
      final payload = message['payload'];

      // Parse power state updates
      if (topic.contains('/POWER')) {
        final channelMatch = RegExp(r'POWER(\d+)').firstMatch(topic);
        if (channelMatch != null) {
          final channel = int.parse(channelMatch.group(1)!);
          final isOn = payload == 'ON' || payload == true;

          setState(() {
            _channelStates[channel] = isOn;
          });
        } else if (topic.endsWith('/POWER')) {
          // Single channel device
          final isOn = payload == 'ON' || payload == true;
          setState(() {
            _channelStates[1] = isOn;
          });
        }
      }

      // Handle status responses with multiple power states
      if (payload is Map<String, dynamic>) {
        for (int i = 1; i <= widget.device.effectiveChannels; i++) {
          if (payload.containsKey('POWER$i')) {
            final isOn = payload['POWER$i'] == 'ON';
            setState(() {
              _channelStates[i] = isOn;
            });
          }
        }

        // Handle single POWER key for single-channel devices
        if (payload.containsKey('POWER') && widget.device.channels == 1) {
          final isOn = payload['POWER'] == 'ON';
          setState(() {
            _channelStates[1] = isOn;
          });
        }
      }
    } catch (e) {
      debugPrint('Error handling MQTT message: $e');
    }
  }

  Future<void> _toggleChannel(int channel) async {
    if (widget.device.tasmotaTopicBase == null) return;

    try {
      final currentState = _channelStates[channel] ?? false;
      final newState = !currentState;

      // Send MQTT command
      await widget.mqttService.setPower(
        widget.device.tasmotaTopicBase!,
        channel,
        newState,
      );

      // Optimistically update UI
      setState(() {
        _channelStates[channel] = newState;
      });
    } catch (e) {
      debugPrint('Error toggling channel $channel: $e');

      // Show error to user
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(HBotSpacing.space4),
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device header
            Row(
              children: [
                Icon(_getDeviceIcon(), size: 24, color: HBotColors.primary),
                const SizedBox(width: HBotSpacing.space2),
                Expanded(
                  child: Text(
                    widget.device.deviceName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: HBotColors.textPrimaryLight,
                    ),
                  ),
                ),
                // Connection status indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),

            const SizedBox(height: HBotSpacing.space4),

            // Channel controls (only enabled when realtime MQTT is available)
            if (widget.device.channels == 1)
              _buildSingleChannelControl()
            else
              _buildMultiChannelControls(),

            if (!_hasRealtime)
              Padding(
                padding: const EdgeInsets.only(top: HBotSpacing.space2),
                child: Text(
                  'No realtime data (MQTT not available)',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: HBotColors.warning),
                ),
              ),

            // Device info
            const SizedBox(height: HBotSpacing.space2),
            Text(
              '${ChannelDetectionUtils.getChannelCountDisplayName(widget.device.effectiveChannels)} • ${widget.device.deviceType.name}',
              style: const TextStyle(
                fontSize: 12,
                color: HBotColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleChannelControl() {
    final isOn = _channelStates[1] ?? false;

    return SwitchListTile(
      title: const Text('Power'),
      value: isOn,
      onChanged: _isConnected ? (value) => _toggleChannel(1) : null,
    );
  }

  Widget _buildMultiChannelControls() {
    return Column(
      children: [
        for (int i = 1; i <= widget.device.effectiveChannels; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _getChannelName(i),
                    style: const TextStyle(
                      fontSize: 14,
                      color: HBotColors.textPrimaryLight,
                    ),
                  ),
                ),
                Switch(
                  value: _channelStates[i] ?? false,
                  onChanged: _isConnected ? (value) => _toggleChannel(i) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _getDeviceIcon() {
    switch (widget.device.deviceType) {
      case DeviceType.relay:
        return HBotIcons.power;
      case DeviceType.dimmer:
        return HBotIcons.lightbulb;
      case DeviceType.shutter:
        return HBotIcons.shutter;
      case DeviceType.sensor:
        return HBotIcons.thermometer;
      case DeviceType.other:
        return HBotIcons.deviceUnknown;
    }
  }
}
