import 'package:flutter/material.dart';
import 'dart:async';
import '../models/device.dart';
import '../services/mqtt_device_manager.dart';
import '../services/smart_home_service.dart';
import '../repos/devices_repo.dart';
import '../widgets/shutter_control_widget.dart';
import '../widgets/settings_tile.dart';
import 'shutter_calibration_screen.dart';
import 'shutter_manual_calibration_screen.dart';
import 'device_timers_screen.dart';
import 'share_device_screen.dart';

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

class _DeviceControlScreenState extends State<DeviceControlScreen>
    with SingleTickerProviderStateMixin {
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

  // Refresh animation
  bool _isRefreshing = false;
  late AnimationController _refreshAnimController;

  // 3-dot menu
  bool _menuOpen = false;

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _refreshAnimController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentDevice = widget.device;
    _deviceState = _createDefaultDeviceState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _initializeDeviceControl();
    _loadChannelNames();
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUSINESS LOGIC — preserved exactly from original
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _loadChannelNames() async {
    try {
      debugPrint(
        'Loading channel names and types for device ${widget.device.id}',
      );
      final deviceWithChannels = await _devicesRepo.getDeviceWithChannels(
        widget.device.id,
      );
      if (deviceWithChannels != null && mounted) {
        setState(() {
          for (int i = 1; i <= widget.device.effectiveChannels; i++) {
            final channelLabel = deviceWithChannels.getChannelLabel(i);
            if (channelLabel != 'Channel $i') {
              _channelNames[i] = channelLabel;
            }
            final channelType = deviceWithChannels.getChannelType(i);
            _channelTypes[i] = channelType;
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load channel names: $e');
    }
  }

  Future<void> _initializeDeviceControl() async {
    try {
      setState(() => _isLoading = true);

      final cachedState = await _loadCachedDeviceState();
      if (cachedState != null && mounted) {
        setState(() {
          _deviceState = cachedState;
          _isLoading = false;
        });
      }

      final isConnected = _mqttManager.connectionState.toString().contains('connected');

      if (isConnected) {
        try {
          if (widget.device.tasmotaTopicBase != null) {
            Future.microtask(() async {
              try {
                _mqttManager.mqttService.publishStatus5(widget.device.tasmotaTopicBase!);
              } catch (e) {
                debugPrint('Status5 publish error: $e');
              }
            });
          }
        } catch (e) {
          debugPrint('Failed to start probe: $e');
        }
        await _registerAndListenToDevice();
      } else {
        _mqttManager.connectionStateStream.listen((state) {
          if (state.toString().contains('connected') && mounted) {
            try {
              if (widget.device.tasmotaTopicBase != null) {
                Future.microtask(() async {
                  try {
                    _mqttManager.mqttService.publishStatus5(widget.device.tasmotaTopicBase!);
                  } catch (e) {
                    debugPrint('Status5 on-connect error: $e');
                  }
                });
              }
            } catch (e) {
              debugPrint('Failed to start probe on connect: $e');
            }
            _registerAndListenToDevice();
          }
        });
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error initializing device control: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerAndListenToDevice() async {
    try {
      _stateSubscription?.cancel();
      _stateSubscription = _service
          .watchCombinedDeviceState(widget.device.id)
          .listen((state) {
        if (mounted) {
          setState(() => _deviceState = state);
        }
      });

      final existingState = _mqttManager.getDeviceState(widget.device.id);
      if (existingState != null && mounted) {
        final sanitized = Map<String, dynamic>.from(existingState)
          ..remove('online')
          ..remove('connected');
        final availability = _mqttManager.getDeviceAvailability(widget.device.id);
        final lastSeen = _mqttManager.getLastSeen(widget.device.id);
        if (availability != null) sanitized['availability'] = availability;
        if (lastSeen != null) sanitized['lastSeen'] = lastSeen.millisecondsSinceEpoch;
        setState(() {
          if (_deviceState == null || _deviceState!['source'] == 'database') {
            _deviceState = sanitized;
          }
        });
      }

      await _mqttManager.registerDevice(widget.device);

      _stateSubscription?.cancel();
      _stateSubscription = _service
          .watchCombinedDeviceState(widget.device.id)
          .listen((state) {
        if (mounted) setState(() => _deviceState = state);
      });

      await _mqttManager.requestDeviceStateImmediate(widget.device.id);
      Future.delayed(const Duration(milliseconds: 100), () {
        _mqttManager.requestDeviceState(widget.device.id);
      });
    } catch (e) {
      debugPrint('Error registering device: $e');
    }
  }

  Future<void> _toggleChannel(int channel) async {
    if (!_isDeviceControllable()) return;
    try {
      final currentState = _getChannelState(channel);
      try {
        final existing = _mqttManager.getDeviceState(widget.device.id);
        if (existing == null) await _mqttManager.registerDevice(widget.device);
      } catch (e) {
        debugPrint('Device registration attempt before toggle failed: $e');
      }
      await _mqttManager.setChannelPower(widget.device.id, channel, !currentState);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to control channel $channel: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  bool _isDeviceOnline() {
    final health = _deviceState?['health'] as String?;
    if (health == 'OFFLINE') return false;

    if (_deviceState != null && _deviceState!.containsKey('online')) {
      final o = _deviceState!['online'];
      if (o is bool) return o;
      if (o is String) return o.toLowerCase() == 'online' || o.toLowerCase() == 'true';
    }

    DateTime? lastSeen = _parseLastSeenFromState(_deviceState);
    int telePeriod = (_deviceState != null && _deviceState!['TelePeriod'] is int)
        ? _deviceState!['TelePeriod'] as int
        : (_mqttManager.mqttService.getTelemetryPeriodSeconds(widget.device.id) ?? 60);
    final ttlSecs = (telePeriod * 2.5).clamp(60, 300).toInt();

    if (lastSeen != null) {
      final fresh = DateTime.now().difference(lastSeen) < Duration(seconds: ttlSecs);
      if (fresh) return true;
    }

    final availability = _mqttManager.getDeviceAvailability(widget.device.id);
    final mgrLastSeen = _mqttManager.getLastSeen(widget.device.id);

    if (mgrLastSeen != null) {
      final fresh = DateTime.now().difference(mgrLastSeen) < Duration(seconds: ttlSecs);
      if (fresh) return true;
    }

    final offline = availability == 'offline';
    return !offline;
  }

  bool _isDeviceControllable() {
    return widget.device.tasmotaTopicBase != null &&
        widget.device.tasmotaTopicBase!.isNotEmpty;
  }

  bool _canSendCommands() {
    final connected = _mqttManager.connectionState.toString().contains('connected');
    final serviceHealthy = _mqttManager.mqttService.isHealthy;
    bool presence = false;
    try {
      presence = _isDeviceOnline();
    } catch (_) {
      presence = false;
    }

    if (!presence) {
      final availability = _mqttManager.getDeviceAvailability(widget.device.id);
      final lastSeen = _mqttManager.getLastSeen(widget.device.id);
      if (availability != null && availability.toLowerCase() == 'online') {
        presence = true;
      } else if (lastSeen != null) {
        final telePeriod = _mqttManager.mqttService.getTelemetryPeriodSeconds(widget.device.id) ?? 60;
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

  String _getChannelName(int channel) {
    return _channelNames[channel] ?? 'Channel $channel';
  }

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

  Future<void> _updateChannelName(int channel, String newName) async {
    final trimmedName = newName.trim();
    final finalName = trimmedName.isEmpty ? _getDefaultChannelName(channel) : trimmedName;
    setState(() => _channelNames[channel] = finalName);
    try {
      await _devicesRepo.renameChannelPersistent(
        deviceId: widget.device.id,
        channelNo: channel,
        newLabel: finalName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Channel $channel renamed successfully'), backgroundColor: const Color(0xFF22C55E), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      setState(() => _channelNames[channel] = _getDefaultChannelName(channel));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename channel: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _updateChannelType(int channel, String newType) async {
    if (newType != 'light' && newType != 'switch') return;
    final oldType = _channelTypes[channel] ?? 'light';
    setState(() => _channelTypes[channel] = newType);
    try {
      await _devicesRepo.updateChannelType(deviceId: widget.device.id, channelNo: channel, channelType: newType);
      if (mounted) {
        final typeName = newType == 'light' ? 'Light' : 'Switch';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Channel $channel changed to $typeName'), backgroundColor: const Color(0xFF22C55E), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      setState(() => _channelTypes[channel] = oldType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update channel type: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _renameDevice(String newName) async {
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device name cannot be empty')));
      return;
    }
    if (newName == _currentDevice.deviceName) { Navigator.pop(context); return; }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 12), Text('Renaming device...')]), duration: Duration(seconds: 10)),
    );
    try {
      await _devicesRepo.renameDevicePersistent(deviceId: widget.device.id, newName: newName);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device renamed successfully'), backgroundColor: Color(0xFF22C55E)));
        setState(() {
          _currentDevice = _currentDevice.copyWith(displayName: newName, nameIsCustom: true);
        });
        widget.onDeviceChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to rename device: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  Future<void> _moveDeviceToRoom(String? roomId) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))), SizedBox(width: 12), Text('Moving device...')]), duration: Duration(seconds: 2)),
        );
      }
      final updatedDevice = roomId == null
          ? await _service.updateDevice(_currentDevice.id, clearRoom: true)
          : await _service.updateDevice(_currentDevice.id, roomId: roomId);
      if (mounted) setState(() => _currentDevice = updatedDevice);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(roomId != null ? 'Device moved to room successfully' : 'Device moved to main area'), backgroundColor: const Color(0xFF22C55E), duration: const Duration(seconds: 2)));
        widget.onDeviceChanged?.call();
        Future.delayed(const Duration(milliseconds: 500), () { if (mounted) Navigator.pop(context); });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to move device: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  Future<void> _deleteDevice() async {
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: const Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: Color(0xFF0883FD)), SizedBox(width: 16), Text('Removing device...', style: TextStyle(fontFamily: 'Inter'))]),
          ),
        );
      }
      await _service.deleteDevice(widget.device.id);
      if (mounted) Navigator.pop(context);
      widget.onDeviceChanged?.call();
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Device "${widget.device.deviceName}" deleted successfully'), backgroundColor: const Color(0xFF22C55E), duration: const Duration(seconds: 3)));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      String errorMessage;
      if (e.toString().contains('Device not found')) {
        errorMessage = 'This device has already been deleted or no longer exists.';
      } else if (e.toString().contains('Network error')) {
        errorMessage = 'Unable to connect to the server. Please check your internet connection and try again.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'The operation timed out. Please try again.';
      } else {
        errorMessage = 'An unexpected error occurred while deleting the device. Please try again later.';
      }
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 24), SizedBox(width: 8), Text('Remove Failed', style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600))]),
            content: Text(errorMessage, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF6B7280))),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Color(0xFF0883FD))))],
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _loadCachedDeviceState() async {
    try {
      final mqttState = _mqttManager.getDeviceState(widget.device.id);
      if (mqttState != null) {
        final sanitized = Map<String, dynamic>.from(mqttState)..remove('online')..remove('connected')..remove('availability');
        return sanitized;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading cached device state: $e');
      return null;
    }
  }

  Future<void> _refreshDeviceStatus() async {
    setState(() => _isRefreshing = true);
    _refreshAnimController.repeat();
    try {
      final isConnected = _mqttManager.connectionState.toString().contains('connected');
      if (!isConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MQTT not connected. Please check your connection.'), backgroundColor: Color(0xFFF59E0B)));
        }
        return;
      }
      await _mqttManager.registerDevice(widget.device);
      await _mqttManager.requestDeviceStateImmediate(widget.device.id);
      await _mqttManager.requestDeviceState(widget.device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device status refreshed'), backgroundColor: Color(0xFF22C55E), duration: Duration(seconds: 2)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to refresh: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        _refreshAnimController.stop();
        _refreshAnimController.reset();
        setState(() => _isRefreshing = false);
      }
    }
  }

  Map<String, dynamic> _createDefaultDeviceState() {
    final Map<String, dynamic> state = {'status': 'initializing'};
    for (int i = 1; i <= widget.device.effectiveChannels; i++) {
      state['POWER$i'] = 'OFF';
    }
    return state;
  }

  DateTime? _parseLastSeenFromState(Map<String, dynamic>? state) {
    if (state == null) return null;
    final ls = state['lastSeen'] ?? state['last_seen'] ?? state['lastSeenMs'];
    if (ls == null) return null;
    if (ls is DateTime) return ls;
    if (ls is int) { try { return DateTime.fromMillisecondsSinceEpoch(ls); } catch (_) { return null; } }
    if (ls is String) { try { return DateTime.parse(ls); } catch (_) { return null; } }
    return null;
  }

  String _getHbotModelName() {
    switch (_currentDevice.deviceType) {
      case DeviceType.shutter: return 'Hbot-Shutter';
      case DeviceType.relay:
        final channelCount = _currentDevice.channels ?? _currentDevice.channelCount ?? 0;
        switch (channelCount) {
          case 2: return 'Hbot-2Ch';
          case 4: return 'Hbot-4Ch';
          case 8: return 'Hbot-8Ch';
          default: return 'Hbot-Relay';
        }
      case DeviceType.dimmer: return 'Hbot-Dimmer';
      case DeviceType.sensor: return 'Hbot-Sensor';
      case DeviceType.other: return 'Hbot-Device';
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // UI — rewritten to match v0 DeviceControlScreen.tsx exactly
  // ═══════════════════════════════════════════════════════════════════

  // Type icon config matching v0
  static const _typeIconCfg = <DeviceType, _DeviceTypeCfg>{
    DeviceType.relay: _DeviceTypeCfg(icon: Icons.power_settings_new, color: Color(0xFF3B82F6), bg: Color(0xFFEFF6FF)),
    DeviceType.dimmer: _DeviceTypeCfg(icon: Icons.lightbulb_outline, color: Color(0xFFF59E0B), bg: Color(0xFFFFFBEB)),
    DeviceType.sensor: _DeviceTypeCfg(icon: Icons.thermostat, color: Color(0xFF10B981), bg: Color(0xFFECFDF5)),
    DeviceType.shutter: _DeviceTypeCfg(icon: Icons.blinds, color: Color(0xFF8B5CF6), bg: Color(0xFFF5F3FF)),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () {
          if (_menuOpen) setState(() => _menuOpen = false);
        },
        child: Column(
          children: [
            // ── App Bar per v0 ──
            SafeArea(
              bottom: false,
              child: _buildAppBar(),
            ),
            // ── Scrollable body ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0883FD)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        children: [
                          // Device header card
                          _buildDeviceHeader(),
                          // Type-specific control
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildTypeControl(),
                          ),
                          // Details section
                          if (!_isLoading) ...[
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _buildDetailsSection(),
                            ),
                          ],
                          if (_showDebugInfo) ...[
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _buildDebugInfo(),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// AppBar: back (36x36 rounded-xl), name centered 16px bold truncated max 180px,
  /// right: Timer + Refresh + MoreVertical (each 36x36 rounded-xl)
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      child: Row(
        children: [
          // Back button
          _V0AppBarButton(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1F2937)),
          ),
          // Centered title
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  _currentDevice.deviceName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // Right actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Timer icon (for relay/dimmer)
              if (_currentDevice.deviceType == DeviceType.relay ||
                  _currentDevice.deviceType == DeviceType.dimmer)
                _V0AppBarButton(
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
                  child: const Icon(Icons.timer, size: 19, color: Color(0xFF4B5563)),
                ),
              // Refresh icon with spin animation
              _V0AppBarButton(
                onTap: _refreshDeviceStatus,
                child: RotationTransition(
                  turns: _isRefreshing ? _refreshAnimController : const AlwaysStoppedAnimation(0),
                  child: const Icon(Icons.refresh, size: 17, color: Color(0xFF4B5563)),
                ),
              ),
              // 3-dot menu
              _buildMoreMenu(),
            ],
          ),
        ],
      ),
    );
  }

  /// Three-dot menu with dropdown per v0
  Widget _buildMoreMenu() {
    // Build menu items per v0
    final menuItems = <_MenuItem>[
      _MenuItem(icon: Icons.edit, label: 'Rename Device', color: const Color(0xFF1F2937), onTap: () { setState(() => _menuOpen = false); _showDeviceRenameDialog(); }),
      _MenuItem(icon: Icons.drive_file_move_outlined, label: 'Move to Room', color: const Color(0xFF1F2937), onTap: () { setState(() => _menuOpen = false); _showMoveToRoomDialog(); }),
      _MenuItem(icon: Icons.share, label: 'Share Device', color: const Color(0xFF1F2937), onTap: () { setState(() => _menuOpen = false); Navigator.push(context, MaterialPageRoute(builder: (context) => ShareDeviceScreen(device: widget.device))); }),
      _MenuItem(icon: Icons.info_outline, label: 'Show Device Info', color: const Color(0xFF1F2937), onTap: () { setState(() { _menuOpen = false; _showDebugInfo = !_showDebugInfo; }); }),
      if (_currentDevice.deviceType == DeviceType.shutter) ...[
        _MenuItem(icon: Icons.settings, label: 'Auto Calibrate', color: const Color(0xFF1F2937), onTap: () { setState(() => _menuOpen = false); _navigateToCalibration(); }),
        _MenuItem(icon: Icons.settings, label: 'Manual Calibrate', color: const Color(0xFF1F2937), onTap: () { setState(() => _menuOpen = false); _navigateToManualCalibration(); }),
      ],
      _MenuItem(icon: Icons.delete_outline, label: 'Delete', color: const Color(0xFFEF4444), onTap: () { setState(() => _menuOpen = false); _showDeleteConfirmationDialog(); }),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _V0AppBarButton(
          onTap: () {
            setState(() => _menuOpen = !_menuOpen);
          },
          child: const Icon(Icons.more_vert, size: 19, color: Color(0xFF4B5563)),
        ),
        if (_menuOpen)
          Positioned(
            right: 0,
            top: 40,
            child: GestureDetector(
              onTap: () {}, // prevent bubble
              child: Container(
                width: 232,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8)),
                  ],
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(menuItems.length, (i) {
                      final item = menuItems[i];
                      return InkWell(
                        onTap: item.onTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: i > 0
                                ? const Border(top: BorderSide(color: Color(0xFFF3F4F6), width: 1))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(item.icon, size: 16, color: item.color),
                              const SizedBox(width: 12),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: item.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Device header card per v0: 64x64 type icon circle + name + room + online status
  Widget _buildDeviceHeader() {
    final cfg = _typeIconCfg[_currentDevice.deviceType] ?? _typeIconCfg[DeviceType.relay]!;
    final isOnline = _isDeviceOnline();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Row(
          children: [
            // 64x64 type icon circle
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cfg.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(cfg.icon, size: 28, color: cfg.color),
            ),
            const SizedBox(width: 16),
            // Name + room + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentDevice.deviceName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Room: 12px #9CA3AF
                  Text(
                    _currentDevice.roomId != null ? 'Room' : 'No Room',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Online status dot + text
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Route to type-specific control widget
  Widget _buildTypeControl() {
    switch (_currentDevice.deviceType) {
      case DeviceType.relay:
        return _buildRelayControl();
      case DeviceType.dimmer:
        return _buildDimmerControl();
      case DeviceType.shutter:
        return _buildShutterControl();
      case DeviceType.sensor:
        return _buildSensorDisplay();
      default:
        return _buildRelayControl();
    }
  }

  // ─── RELAY CONTROL per v0 ───
  Widget _buildRelayControl() {
    final channels = widget.device.effectiveChannels;
    final isOnline = _isDeviceOnline();

    return Column(
      children: List.generate(channels == 0 ? 1 : channels, (index) {
        final channel = index + 1;
        final isOn = _getChannelState(channel);
        final channelName = _getChannelName(channel);

        return Padding(
          padding: EdgeInsets.only(bottom: index < (channels == 0 ? 0 : channels - 1) ? 16 : 0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Column(
              children: [
                // 128x128 circular toggle button
                GestureDetector(
                  onTap: isOnline ? () => _toggleChannel(channel) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isOn
                          ? const LinearGradient(
                              begin: Alignment(-0.5, -0.5),
                              end: Alignment(0.5, 0.5),
                              colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
                            )
                          : null,
                      color: isOn ? null : const Color(0xFFF0F2F5),
                      border: isOn ? null : Border.all(color: const Color(0xFFE5E7EB), width: 2),
                      boxShadow: isOn
                          ? [const BoxShadow(color: Color(0x610883FD), blurRadius: 36, offset: Offset(0, 14))]
                          : null,
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: isOnline ? 1.0 : 0.4,
                        child: Icon(
                          Icons.power_settings_new,
                          size: 44,
                          color: isOn ? Colors.white : const Color(0xFFC9CDD6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Channel name + ON/OFF
                Text(
                  channelName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOn ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isOn ? const Color(0xFF0883FD) : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ─── DIMMER CONTROL per v0 ───
  Widget _buildDimmerControl() {
    final isOn = _getChannelState(1);
    final isOnline = _isDeviceOnline();
    // Get brightness from device state
    int brightness = 0;
    if (_deviceState != null) {
      final dimmer = _deviceState!['Dimmer'];
      if (dimmer is int) brightness = dimmer;
      if (dimmer is String) brightness = int.tryParse(dimmer) ?? 0;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          // 128x128 circular toggle — dimmer uses amber gradient
          GestureDetector(
            onTap: isOnline ? () => _toggleChannel(1) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isOn
                    ? const LinearGradient(
                        begin: Alignment(-0.5, -0.5),
                        end: Alignment(0.5, 0.5),
                        colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                      )
                    : null,
                color: isOn ? null : const Color(0xFFF0F2F5),
                border: isOn ? null : Border.all(color: const Color(0xFFE5E7EB), width: 2),
                boxShadow: isOn
                    ? [const BoxShadow(color: Color(0x61F59E0B), blurRadius: 36, offset: Offset(0, 14))]
                    : null,
              ),
              child: Center(
                child: Opacity(
                  opacity: isOnline ? 1.0 : 0.4,
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 44,
                    color: isOn ? Colors.white : const Color(0xFFC9CDD6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Channel name + ON/OFF
          Text(
            _getChannelName(1),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isOn ? 'ON' : 'OFF',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isOn ? const Color(0xFFF59E0B) : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 20),
          // Brightness slider per v0
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      const Text(
                        'Brightness',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$brightness%',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFF59E0B),
                  inactiveTrackColor: const Color(0xFFE5E7EB),
                  thumbColor: const Color(0xFFF59E0B),
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: brightness.toDouble(),
                  min: 0,
                  max: 100,
                  onChanged: (isOnline && isOn)
                      ? (val) {
                          // Send dimmer command via MQTT
                          _mqttManager.publishCommand(
                            widget.device.id,
                            'Dimmer ${val.round()}',
                          );
                        }
                      : null,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('0%', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFFC9CDD6))),
                  Text('100%', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFFC9CDD6))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── SHUTTER CONTROL — delegates to existing widget ───
  Widget _buildShutterControl() {
    return ShutterControlWidget(
      device: widget.device,
      mqttManager: _mqttManager,
      shutterIndex: 1,
    );
  }

  // ─── SENSOR DISPLAY per v0 — 2-column grid ───
  Widget _buildSensorDisplay() {
    // Extract sensor data from device state
    double? temperature;
    double? humidity;
    if (_deviceState != null) {
      // Try various paths for sensor data
      final snsData = _deviceState!['StatusSNS'] ?? _deviceState;
      if (snsData is Map<String, dynamic>) {
        // Look for common sensor keys
        for (final key in ['AM2301', 'DHT11', 'BME280', 'BMP280', 'SHT30', 'SHT3X', 'DS18B20']) {
          final sensor = snsData[key];
          if (sensor is Map<String, dynamic>) {
            final temp = sensor['Temperature'];
            if (temp != null) temperature = (temp is num) ? temp.toDouble() : double.tryParse(temp.toString());
            final hum = sensor['Humidity'];
            if (hum != null) humidity = (hum is num) ? hum.toDouble() : double.tryParse(hum.toString());
            break;
          }
        }
        // Direct Temperature/Humidity keys
        if (temperature == null) {
          final temp = snsData['Temperature'];
          if (temp != null) temperature = (temp is num) ? temp.toDouble() : double.tryParse(temp.toString());
        }
        if (humidity == null) {
          final hum = snsData['Humidity'];
          if (hum != null) humidity = (hum is num) ? hum.toDouble() : double.tryParse(hum.toString());
        }
      }
    }

    return Row(
      children: [
        // Temperature card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
            ),
            child: Column(
              children: [
                // 44x44 icon circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.thermostat, size: 22, color: Color(0xFF10B981)),
                ),
                const SizedBox(height: 12),
                // Value: 32px bold
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: temperature != null ? '${temperature.toStringAsFixed(1)}' : '--',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                          height: 1.0,
                        ),
                      ),
                      const TextSpan(
                        text: '°C',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Temperature',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Humidity card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDBEAFE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.water_drop, size: 22, color: Color(0xFF3B82F6)),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: humidity != null ? '${humidity.round()}' : '--',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                          height: 1.0,
                        ),
                      ),
                      const TextSpan(
                        text: '%',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Humidity',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Details Section ───
  Widget _buildDetailsSection() {
    String? power;
    String? todayEnergy;
    String? signalStrength;
    String? ipAddress;
    String? firmware;

    if (_deviceState != null) {
      final energyData = _deviceState!['ENERGY'] ?? _deviceState!['StatusSNS']?['ENERGY'];
      if (energyData is Map<String, dynamic>) {
        final powerVal = energyData['Power'];
        if (powerVal != null) power = '${powerVal}W';
        final todayVal = energyData['Today'];
        if (todayVal != null) todayEnergy = '${todayVal} kWh';
      }
      final wifi = _deviceState!['Wifi'] ?? _deviceState!['StatusSTS']?['Wifi'];
      if (wifi is Map<String, dynamic>) {
        final rssi = wifi['RSSI'] ?? wifi['Signal'];
        if (rssi != null) signalStrength = '$rssi dBm';
      }
      final statusNet = _deviceState!['StatusNET'];
      if (statusNet is Map<String, dynamic>) {
        ipAddress = statusNet['IPAddress'] as String? ?? statusNet['IP'] as String?;
      }
      final statusFWR = _deviceState!['StatusFWR'];
      if (statusFWR is Map<String, dynamic>) {
        firmware = statusFWR['Version'] as String?;
      }
    }

    final hasDetails = power != null || todayEnergy != null ||
        signalStrength != null || ipAddress != null || firmware != null;

    if (!hasDetails) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DETAILS',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
        SettingsTileGroup(
          children: [
            if (power != null)
              SettingsTile(
                icon: Icons.bolt,
                title: 'Power',
                subtitle: power,
                showDivider: todayEnergy != null || signalStrength != null || ipAddress != null || firmware != null,
                trailing: const SizedBox.shrink(),
              ),
            if (todayEnergy != null)
              SettingsTile(
                icon: Icons.electric_meter,
                title: 'Today',
                subtitle: todayEnergy,
                showDivider: signalStrength != null || ipAddress != null || firmware != null,
                trailing: const SizedBox.shrink(),
              ),
            if (signalStrength != null)
              SettingsTile(
                icon: Icons.wifi,
                title: 'Signal',
                subtitle: signalStrength,
                showDivider: ipAddress != null || firmware != null,
                trailing: const SizedBox.shrink(),
              ),
            if (ipAddress != null)
              SettingsTile(
                icon: Icons.lan,
                title: 'IP Address',
                subtitle: ipAddress,
                showDivider: firmware != null,
                trailing: const SizedBox.shrink(),
              ),
            if (firmware != null)
              SettingsTile(
                icon: Icons.system_update,
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

  Widget _buildDebugInfo() {
    String? macAddress = _currentDevice.macAddress;
    String? ipAddress;
    String modelName;
    const String manufacturer = 'HBOT';

    if (_deviceState != null) {
      final statusNet = _deviceState!['StatusNET'];
      if (statusNet is Map<String, dynamic>) {
        ipAddress = statusNet['IPAddress'] as String?;
        ipAddress ??= statusNet['IP'] as String?;
      }
    }
    modelName = _getHbotModelName();

    return SettingsTileGroup(
      title: 'Device Information',
      children: [
        SettingsTile(icon: Icons.business, title: 'Manufacturer', subtitle: manufacturer, trailing: const SizedBox.shrink()),
        SettingsTile(icon: Icons.devices, title: 'Device Model', subtitle: modelName, trailing: const SizedBox.shrink()),
        SettingsTile(icon: Icons.memory, title: 'MAC Address', subtitle: macAddress ?? 'Unknown', trailing: const SizedBox.shrink()),
        SettingsTile(icon: Icons.lan, title: 'IP Address', subtitle: ipAddress ?? 'Unknown', showDivider: false, trailing: const SizedBox.shrink()),
      ],
    );
  }

  // ─── Dialogs — preserved from original ───

  void _showDeviceRenameDialog() {
    final controller = TextEditingController(text: _currentDevice.deviceName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Device', style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
        content: TextField(
          controller: controller,
          style: const TextStyle(fontFamily: 'Inter', color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            labelText: 'Device Name',
            hintText: 'Enter a custom name for your device',
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0883FD), width: 2)),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(onPressed: () => _renameDevice(controller.text.trim()), child: const Text('Save', style: TextStyle(color: Color(0xFF0883FD)))),
        ],
      ),
    );
  }

  void _showMoveToRoomDialog() async {
    if (_currentDevice.homeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot move device: No home assigned'), backgroundColor: Color(0xFFEF4444)));
      return;
    }
    try {
      final rooms = await _service.getRooms(_currentDevice.homeId!);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Move to Room', style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select a room for this device:', style: TextStyle(color: Color(0xFF6B7280))),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.home, color: Color(0xFF0883FD)),
                            title: const Text('No Room', style: TextStyle(color: Color(0xFF1F2937))),
                            subtitle: const Text('Place device in the main area', style: TextStyle(color: Color(0xFF6B7280))),
                            selected: _currentDevice.roomId == null,
                            selectedTileColor: const Color(0xFF0883FD).withOpacity(0.1),
                            onTap: () { Navigator.pop(context); _moveDeviceToRoom(null); },
                          ),
                          const Divider(),
                          if (rooms.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...rooms.map((room) => ListTile(
                              leading: const Icon(Icons.door_front_door, color: Color(0xFF0883FD)),
                              title: Text(room.name, style: const TextStyle(color: Color(0xFF1F2937))),
                              selected: _currentDevice.roomId == room.id,
                              selectedTileColor: const Color(0xFF0883FD).withOpacity(0.1),
                              onTap: () { Navigator.pop(context); _moveDeviceToRoom(room.id); },
                            )),
                          ] else
                            const Padding(padding: EdgeInsets.all(16), child: Text('No rooms available.', style: TextStyle(color: Color(0xFF9CA3AF)), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load rooms: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Device?', style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
        content: const Text(
          'This will remove the device from all rooms and scenes. This action cannot be undone.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(
            onPressed: () { Navigator.pop(context); _deleteDevice(); },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showChannelRenameDialog(int channel) {
    final controller = TextEditingController(text: _getChannelName(channel));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename ${_getChannelName(channel)}', style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
        content: TextField(
          controller: controller,
          style: const TextStyle(fontFamily: 'Inter', color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            hintText: 'Enter channel name',
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0883FD), width: 2)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(onPressed: () { _updateChannelName(channel, controller.text); Navigator.pop(context); }, child: const Text('Save', style: TextStyle(color: Color(0xFF0883FD)))),
        ],
      ),
    );
  }

  void _showChannelOptionsDialog(int channel) {
    final channelType = _channelTypes[channel] ?? 'light';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(alignment: Alignment.centerLeft, child: Text(_getChannelName(channel), style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)))),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF4B5563)),
                title: const Text('Rename Channel', style: TextStyle(fontFamily: 'Inter')),
                onTap: () { Navigator.pop(context); _showChannelRenameDialog(channel); },
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Align(alignment: Alignment.centerLeft, child: Text('CHANNEL TYPE', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: Color(0xFF9CA3AF))))),
              ListTile(
                leading: Icon(Icons.lightbulb_outline, color: channelType == 'light' ? const Color(0xFF0883FD) : const Color(0xFF4B5563)),
                title: Text('Light', style: TextStyle(fontFamily: 'Inter', color: channelType == 'light' ? const Color(0xFF0883FD) : null)),
                onTap: () { Navigator.pop(context); _updateChannelType(channel, 'light'); },
              ),
              ListTile(
                leading: Icon(Icons.power_settings_new, color: channelType == 'switch' ? const Color(0xFF0883FD) : const Color(0xFF4B5563)),
                title: Text('Switch', style: TextStyle(fontFamily: 'Inter', color: channelType == 'switch' ? const Color(0xFF0883FD) : null)),
                onTap: () { Navigator.pop(context); _updateChannelType(channel, 'switch'); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCalibration() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ShutterCalibrationScreen(device: widget.device)));
  }

  void _navigateToManualCalibration() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ShutterManualCalibrationScreen(device: widget.device)));
  }
}

// ─── Helper classes ───

class _DeviceTypeCfg {
  final IconData icon;
  final Color color;
  final Color bg;
  const _DeviceTypeCfg({required this.icon, required this.color, required this.bg});
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.color, required this.onTap});
}

/// AppBar button: 36x36 rounded-xl
class _V0AppBarButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _V0AppBarButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }
}
