import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../theme/app_theme.dart';
import '../utils/phosphor_icons.dart';
import '../widgets/smart_input_field.dart';
import '../widgets/background_container.dart';
import '../services/smart_home_service.dart';
import '../services/mqtt_device_manager.dart';
import '../models/home.dart';
import '../models/room.dart';
import '../models/device.dart';
import 'add_device_flow_screen.dart';
import 'device_control_screen.dart';

class DevicesScreen extends StatefulWidget {
  final Home? home;
  final Room? room;
  final VoidCallback? onDeviceChanged;

  const DevicesScreen({super.key, this.home, this.room, this.onDeviceChanged});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final SmartHomeService _service = SmartHomeService();
  final MqttDeviceManager _mqttManager = MqttDeviceManager();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  List<Device> _devices = [];
  bool _isLoading = true;
  bool _mqttConnected = false;

  final List<String> _categories = [
    'All',
    'Lighting',
    'Climate',
    'Shutters',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _initializeMqtt();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeMqtt() async {
    // Check current connection state
    final currentState = _mqttManager.mqttService.connectionState;
    if (mounted) {
      setState(() {
        _mqttConnected = currentState == MqttConnectionState.connected;
      });
    }

    // Listen to MQTT connection state changes
    _mqttManager.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _mqttConnected = state == MqttConnectionState.connected;
        });
      }
    });
  }

  Future<void> _loadDevices() async {
    if (widget.home == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      setState(() => _isLoading = true);
      final devices = widget.room != null
          ? await _service.getDevicesByRoom(widget.room!.id)
          : await _service.getDevicesByHome(widget.home!.id);
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load devices: $e'),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    }
  }

  List<Device> get _filteredDevices {
    return _devices.where((device) {
      final matchesCategory =
          _selectedCategory == 'All' ||
          _getDeviceCategory(device.deviceType) == _selectedCategory;
      final matchesSearch =
          _searchController.text.isEmpty ||
          device.deviceName.toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );
      return matchesCategory && matchesSearch;
    }).toList();
  }

  String _getDeviceCategory(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.relay:
      case DeviceType.dimmer:
        return 'Lighting';
      case DeviceType.sensor:
        return 'Climate';
      case DeviceType.shutter:
        return 'Shutters';
      case DeviceType.other:
        return 'Other';
    }
  }

  IconData _getDeviceIcon(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.relay:
      case DeviceType.dimmer:
        return HBotIcons.lightbulb;
      case DeviceType.sensor:
        return HBotIcons.thermometer;
      case DeviceType.shutter:
        return HBotIcons.shutter;
      case DeviceType.other:
        return HBotIcons.deviceUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.room != null
        ? '${widget.room!.name} Devices'
        : widget.home != null
        ? '${widget.home!.name} Devices'
        : 'All Devices';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? HBotColors.backgroundLight
          : HBotColors.backgroundLight,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: isDark
            ? HBotColors.backgroundLight
            : HBotColors.backgroundLight,
        elevation: 0,
        actions: [
          if (widget.home != null)
            IconButton(
              icon: Icon(HBotIcons.add),
              onPressed: () {
                _showAddDeviceDialog();
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background image layer (only for room view)
          if (widget.room?.backgroundImageUrl != null &&
              widget.room!.backgroundImageUrl!.isNotEmpty)
            Positioned.fill(
              child: BackgroundContainer(
                backgroundImageUrl: widget.room!.backgroundImageUrl,
                overlayColor:
                    Colors.black, // Always use black for better contrast
                overlayOpacity: isDark
                    ? 0.3
                    : 0.6, // Increased to 0.6 for better text visibility in Light Mode
                child: const SizedBox.expand(),
              ),
            ),
          // Content layer
          widget.home == null
              ? _buildNoHomeSelected()
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Search and filter section
                    Padding(
                      padding: const EdgeInsets.all(HBotSpacing.space4),
                      child: Column(
                        children: [
                          SmartInputField(
                            controller: _searchController,
                            hintText: 'Search devices...',
                            prefixIcon: Icon(HBotIcons.search, size: 20),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: HBotSpacing.space4),
                          _buildCategoryFilter(),
                        ],
                      ),
                    ),

                    // Devices grid
                    Expanded(
                      child: _filteredDevices.isEmpty
                          ? _buildEmptyState()
                          : GridView.builder(
                              padding: const EdgeInsets.all(
                                HBotSpacing.space4,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: HBotSpacing.space2,
                                    mainAxisSpacing: HBotSpacing.space2,
                                    mainAxisExtent:
                                        130, // Match dashboard exactly
                                  ),
                              itemCount: _filteredDevices.length,
                              itemBuilder: (context, index) {
                                final device = _filteredDevices[index];
                                return _buildDeviceCardWrapper(device);
                              },
                            ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildDeviceCardWrapper(Device device) {
    // Wrapper to handle real-time state with StreamBuilder
    return StreamBuilder<Map<String, dynamic>>(
      stream: _service.watchCombinedDeviceState(device.id),
      builder: (context, snapshot) {
        return _buildDeviceCard(device, snapshot.data);
      },
    );
  }

  Widget _buildDeviceCard(Device device, Map<String, dynamic>? merged) {
    final isControllable =
        device.tasmotaTopicBase != null && device.tasmotaTopicBase!.isNotEmpty;

    // Determine online/health using merged state (MQTT authoritative)
    bool isOnline = false;
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
      // Parse online status
      if (merged.containsKey('online')) {
        final o = merged['online'];
        if (o is bool) isOnline = o;
        if (o is String) {
          isOnline = o.toLowerCase() == 'online' || o.toLowerCase() == 'true';
        }
      }

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

          // Extract direction
          final dir = shutterData['Direction'];
          if (dir is int) {
            shutterDirection = dir;
          }
        }
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
    }

    return Card(
      color: HBotColors.cardLight,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _navigateToDeviceControl(device),
        borderRadius: BorderRadius.circular(HBotRadius.medium),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: _buildGridCardContent(
            device,
            deviceState,
            shutterPosition,
            isOnline,
            isControllable,
            shutterDirection,
            waitingForInitialState,
          ),
        ),
      ),
    );
  }

  Widget _buildGridCardContent(
    Device device,
    bool deviceState,
    int shutterPosition,
    bool isOnline,
    bool isControllable,
    int shutterDirection,
    bool waitingForInitialState,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = HBotColors.textPrimaryLight;

    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Large device icon at the top - compact with online status indicator
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color:
                      // Show blue background only when device is ONLINE AND ON
                      (isOnline &&
                          (deviceState ||
                              (device.deviceType == DeviceType.shutter &&
                                  shutterPosition > 0)))
                      ? HBotColors.primary.withOpacity(0.2)
                      : (isDark
                            ? HBotColors.textTertiaryLight.withOpacity(0.1)
                            : Colors.white),
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
                      : (isDark
                            ? HBotColors.textTertiaryLight
                            : HBotColors.textSecondaryLight),
                  size: 32,
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
                    color: isOnline ? HBotColors.success : HBotColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? HBotColors.surfaceLight : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Device name - centered and allow wrapping to 2 lines
        Flexible(
          child: Text(
            device.deviceName,
            style: TextStyle(
              color: textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
        const SizedBox(height: 2),
        // Controls
        if (device.deviceType == DeviceType.shutter)
          _buildShutterControls(
            device,
            shutterPosition,
            shutterDirection,
            isControllable,
            isOnline,
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

  Widget _buildShutterControls(
    Device device,
    int position,
    int direction,
    bool isControllable,
    bool isOnline,
  ) {
    final textPrimary = HBotColors.textPrimaryLight;
    final textHint = HBotColors.textTertiaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Position indicator above buttons
        Text(
          '$position%',
          style: const TextStyle(
            color: HBotColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        // Shutter control buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Close button (dimmed at 0%)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: Icon(HBotIcons.arrowDown),
                onPressed:
                    isControllable && _mqttConnected && isOnline && position > 0
                    ? () => _controlShutter(device, 'close')
                    : null,
                color: isControllable && _mqttConnected && isOnline
                    ? (position > 0
                          ? textPrimary
                          : textPrimary.withOpacity(0.3))
                    : textHint,
                padding: EdgeInsets.zero,
                tooltip: 'Close',
                iconSize: 16,
              ),
            ),
            SizedBox(width: 2),
            // Stop button (always enabled when online)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: Icon(HBotIcons.stop),
                onPressed: isControllable && _mqttConnected && isOnline
                    ? () => _controlShutter(device, 'stop')
                    : null,
                color: isControllable && _mqttConnected && isOnline
                    ? textPrimary
                    : textHint,
                padding: EdgeInsets.zero,
                tooltip: 'Stop',
                iconSize: 16,
              ),
            ),
            SizedBox(width: 2),
            // Open button (dimmed at 100%)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: Icon(HBotIcons.arrowUp),
                onPressed:
                    isControllable &&
                        _mqttConnected &&
                        isOnline &&
                        position < 100
                    ? () => _controlShutter(device, 'open')
                    : null,
                color: isControllable && _mqttConnected && isOnline
                    ? (position < 100
                          ? textPrimary
                          : textPrimary.withOpacity(0.3))
                    : textHint,
                padding: EdgeInsets.zero,
                tooltip: 'Open',
                iconSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: EdgeInsets.only(
              right: index < _categories.length - 1 ? HBotSpacing.space2 : 0,
            ),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              backgroundColor: HBotColors.cardLight,
              selectedColor: HBotColors.primary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected
                    ? HBotColors.primary
                    : HBotColors.textSecondaryLight,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                color: isSelected
                    ? HBotColors.primary
                    : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.transparent
                          : HBotColors.borderLight),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(HBotSpacing.space6),
        padding: const EdgeInsets.all(HBotSpacing.space6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(HBotRadius.medium),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(HBotIcons.devices, size: 64, color: Colors.white),
            const SizedBox(height: HBotSpacing.space4),
            const Text(
              'No devices found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: HBotSpacing.space2),
            Text(
              'Try adjusting your search or filter',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDeviceControl(Device device) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceControlScreen(
          device: device,
          onDeviceChanged: () {
            // Refresh device list when device is changed (e.g., moved to different room)
            _loadDevices();
            widget.onDeviceChanged?.call();
          },
        ),
      ),
    );

    // If device was deleted, refresh the device list
    if (result == true) {
      _loadDevices();
    }
  }

  /// Control shutter (open/close/stop)
  Future<void> _controlShutter(Device device, String action) async {
    try {
      if (!_mqttConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(HBotIcons.wifiOff, color: Colors.white),
                SizedBox(width: 8),
                Text('Connection lost. Please check your network.'),
              ],
            ),
            backgroundColor: HBotColors.error,
          ),
        );
        return;
      }

      // Normalize action to lowercase for case-insensitive matching
      final normalizedAction = action.toLowerCase();

      switch (normalizedAction) {
        case 'open':
          await _mqttManager.openShutter(device.id, 1);
          debugPrint('Sent OPEN command to shutter ${device.deviceName}');
          break;
        case 'close':
          await _mqttManager.closeShutter(device.id, 1);
          debugPrint('Sent CLOSE command to shutter ${device.deviceName}');
          break;
        case 'stop':
          await _mqttManager.stopShutter(device.id, 1);
          debugPrint('Sent STOP command to shutter ${device.deviceName}');
          break;
      }
    } catch (e) {
      debugPrint('Error controlling shutter ${device.deviceName}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to control shutter: ${e.toString()}'),
            backgroundColor: HBotColors.error,
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
              'Device ${device.deviceName} is not configured for control',
            ),
            backgroundColor: HBotColors.warning,
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
                Icon(HBotIcons.wifiOff, color: Colors.white),
                SizedBox(width: 8),
                Text('Connection lost. Please check your network.'),
              ],
            ),
            backgroundColor: HBotColors.error,
          ),
        );
        return;
      }

      // Send control command via MQTT
      // Use bulk control for all devices (single and multi-channel)
      await _mqttManager.setBulkPower(device.id, value);
      debugPrint(
        'Toggled device ${device.deviceName} to ${value ? 'ON' : 'OFF'}',
      );
    } catch (e) {
      debugPrint('Error toggling device ${device.deviceName}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to control device: ${e.toString()}'),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    }
  }

  Widget _buildNoHomeSelected() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(HBotIcons.home, size: 80, color: HBotColors.textTertiaryLight),
            const SizedBox(height: HBotSpacing.space6),
            Text(
              'No Home Selected',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: HBotColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),
            Text(
              'Please select a home first to view and manage devices',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: HBotColors.textSecondaryLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDeviceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HBotColors.cardLight,
          title: const Text('Add Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(HBotIcons.wifi, color: HBotColors.primary),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDeviceFlowScreen(
          home: widget.home!,
          room: widget.room,
          onDeviceAdded: () {
            // Refresh devices list
            _loadDevices();
            widget.onDeviceChanged?.call();
          },
        ),
      ),
    );
  }

  /// Show delete device confirmation dialog
  void _showDeleteDeviceDialog(Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.cardLight,
        title: Row(
          children: [
            Icon(HBotIcons.error, color: HBotColors.error),
            SizedBox(width: 8),
            Text('Delete Device'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${device.deviceName}"?',
              style: const TextStyle(color: HBotColors.textPrimaryLight, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone. All device data, settings, and channel configurations will be permanently removed.',
              style: TextStyle(color: HBotColors.textSecondaryLight, fontSize: 14),
            ),
          ],
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
              Navigator.pop(context);
              _deleteDevice(device);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Delete a device
  Future<void> _deleteDevice(Device device) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: HBotColors.cardLight,
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: HBotColors.primary),
              SizedBox(width: 16),
              Text(
                'Deleting device...',
                style: TextStyle(color: HBotColors.textPrimaryLight),
              ),
            ],
          ),
        ),
      );

      // Delete the device using the service
      await _service.deleteDevice(device.id);

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Refresh the device list
      await _loadDevices();

      // Notify parent if callback is provided
      widget.onDeviceChanged?.call();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device "${device.deviceName}" deleted successfully'),
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
            title: Row(
              children: [
                Icon(errorIcon, color: HBotColors.error),
                const SizedBox(width: 8),
                const Text('Delete Failed'),
              ],
            ),
            content: Text(
              errorMessage,
              style: const TextStyle(color: HBotColors.textPrimaryLight),
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
}
