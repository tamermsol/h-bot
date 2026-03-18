import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/smart_home_service.dart';
import '../models/device.dart';
import '../repos/devices_repo.dart';
import '../l10n/app_strings.dart';

class DeviceSelector extends StatefulWidget {
  final List<Map<String, dynamic>> selectedDevices;
  final Function(List<Map<String, dynamic>>) onDevicesChanged;
  final Color accentColor;
  final String? homeId;

  const DeviceSelector({
    super.key,
    required this.selectedDevices,
    required this.onDevicesChanged,
    required this.accentColor,
    this.homeId,
  });

  @override
  State<DeviceSelector> createState() => _DeviceSelectorState();
}

class _DeviceSelectorState extends State<DeviceSelector> {
  final SmartHomeService _service = SmartHomeService();

  // Will either hold real devices (when a home is configured) or fallback mock data
  List<Map<String, dynamic>> _availableDevices = [];
  final Map<String, StreamSubscription> _stateSubscriptions = {};
  bool _isLoading = true;
  String? _errorMessage;

  final List<String> _categories = [
    'All',
    'Light',
    'Climate',
    'Security',
    'Entertainment',
    'Automation',
  ];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load devices for the specific home if homeId is provided
      List<Device> devices;
      if (widget.homeId != null) {
        debugPrint(
          'DeviceSelector: Loading devices for homeId: ${widget.homeId}',
        );
        devices = await _service.getDevicesByHome(widget.homeId!);
        debugPrint('DeviceSelector: Loaded ${devices.length} devices');
      } else {
        // Fallback to current home if no homeId provided
        debugPrint(
          'DeviceSelector: No homeId provided, loading for current home',
        );
        devices = await _service.getDevicesForCurrentHome();
        debugPrint(
          'DeviceSelector: Loaded ${devices.length} devices for current home',
        );
      }

      // Get room names for better display
      final Map<String, String> roomNames = {};
      if (widget.homeId != null) {
        try {
          final rooms = await _service.getRooms(widget.homeId!);
          debugPrint('DeviceSelector: Loaded ${rooms.length} rooms');
          for (final room in rooms) {
            roomNames[room.id] = room.name;
          }
        } catch (e) {
          // Ignore room name fetch errors
          debugPrint('DeviceSelector: Failed to load rooms: $e');
        }
      }

      final List<Map<String, dynamic>> allDevices = devices.map((Device d) {
        final roomName = d.roomId != null
            ? roomNames[d.roomId] ?? 'Unknown Room'
            : 'No Room';
        return {
          'id': d.id,
          'name': d.deviceName,
          'deviceName': d.deviceName,
          'type': _mapDeviceTypeToCategory(d.deviceType),
          'icon': _getIconForDeviceType(d.deviceType),
          'room': roomName,
          'isOnline': d.online ?? false,
          'device': d,
          'isShared': false,
        };
      }).toList();

      // Load shared devices using the same approach as the dashboard
      // (queries through shared_devices table join, which respects RLS properly)
      try {
        final devicesRepo = DevicesRepo();
        final sharedDevicesList = await devicesRepo.listSharedDevices();
        debugPrint('DeviceSelector: Loaded ${sharedDevicesList.length} shared devices');

        // Track existing device IDs to avoid duplicates
        final existingIds = allDevices.map((d) => d['id'] as String).toSet();

        for (final device in sharedDevicesList) {
          if (existingIds.contains(device.id)) continue;

          allDevices.add({
            'id': device.id,
            'name': device.deviceName,
            'deviceName': device.deviceName,
            'type': _mapDeviceTypeToCategory(device.deviceType),
            'icon': _getIconForDeviceType(device.deviceType),
            'room': 'Shared',
            'isOnline': device.online ?? false,
            'device': device,
            'isShared': true,
          });
          existingIds.add(device.id);
        }
      } catch (e) {
        debugPrint('DeviceSelector: Failed to load shared devices: $e');
        // Non-fatal — continue with home devices only
      }

      if (allDevices.isEmpty) {
        debugPrint('DeviceSelector: No devices found');
        setState(() {
          _isLoading = false;
          _errorMessage = 'No devices found in this home. Add devices first.';
          _availableDevices = [];
        });
        return;
      }

      _availableDevices = allDevices;

      debugPrint(
        'DeviceSelector: Prepared ${_availableDevices.length} devices for display',
      );
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('DeviceSelector: Error loading devices: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load devices: $e';
        _availableDevices = [];
      });
    }
  }

  String _mapDeviceTypeToCategory(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.relay:
      case DeviceType.dimmer:
        return 'Light';
      case DeviceType.sensor:
      case DeviceType.shutter:
        return 'Climate';
      case DeviceType.other:
        return 'Automation';
    }
  }

  IconData _getIconForDeviceType(dynamic deviceType) {
    try {
      if (deviceType is DeviceType) return _mapDeviceTypeToIcon(deviceType);
      if (deviceType is String) {
        return _mapDeviceTypeToIcon(DeviceType.values.byName(deviceType));
      }
    } catch (_) {}
    return Icons.device_unknown;
  }

  IconData _mapDeviceTypeToIcon(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.relay:
      case DeviceType.dimmer:
        return Icons.lightbulb_outline;
      case DeviceType.sensor:
        return Icons.thermostat;
      case DeviceType.shutter:
        return Icons.window;
      case DeviceType.other:
        return Icons.device_unknown;
    }
  }

  @override
  void dispose() {
    for (final sub in _stateSubscriptions.values) {
      try {
        sub.cancel();
      } catch (_) {}
    }
    _stateSubscriptions.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(HBotSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: HBotSpacing.space4),
              Text(AppStrings.get('device_selector_loading_devices')),
            ],
          ),
        ),
      );
    }

    // Show error state
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HBotSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: context.hTextTertiary),
              const SizedBox(height: HBotSpacing.space4),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.hTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HBotSpacing.space4),
              ElevatedButton.icon(
                onPressed: _loadDevices,
                icon: const Icon(Icons.refresh),
                label: Text(AppStrings.get('device_selector_retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filteredDevices = _selectedCategory == 'All'
        ? _availableDevices
        : _availableDevices
              .where((device) => device['type'] == _selectedCategory)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((category) {
              final isSelected = category == _selectedCategory;
              return Container(
                margin: const EdgeInsets.only(right: HBotSpacing.space2),
                child: FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  selectedColor: widget.accentColor.withOpacity(0.2),
                  checkmarkColor: widget.accentColor,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? widget.accentColor
                        : context.hTextSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  backgroundColor: context.hCard,
                  side: BorderSide(
                    color: isSelected
                        ? widget.accentColor.withOpacity(0.5)
                        : context.hTextTertiary.withOpacity(0.3),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: HBotSpacing.space4),

        // Selected devices count
        if (widget.selectedDevices.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(HBotSpacing.space4),
            decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(HBotRadius.medium),
              border: Border.all(
                color: widget.accentColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: widget.accentColor, size: 20),
                const SizedBox(width: HBotSpacing.space2),
                Text(
                  '${widget.selectedDevices.length} devices selected',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: widget.accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: HBotSpacing.space4),
        ],

        // Device list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredDevices.length,
          itemBuilder: (context, index) {
            final device = filteredDevices[index];
            final isShared = device['isShared'] as bool? ?? false;
            final isSelected = widget.selectedDevices.any(
              (selected) => selected['id'] == device['id'],
            );

            return Container(
              margin: const EdgeInsets.only(bottom: HBotSpacing.space2),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.accentColor.withOpacity(0.2)
                        : context.hCard,
                    borderRadius: BorderRadius.circular(HBotRadius.small),
                  ),
                  child: Icon(
                    device['icon'],
                    color: isSelected
                        ? widget.accentColor
                        : context.hTextSecondary,
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        device['name'],
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.hTextPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (isShared)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.withOpacity(0.4)),
                        ),
                        child: const Text(
                          'Shared',
                          style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  device['room'],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.hTextTertiary,
                  ),
                ),
                trailing: Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    _toggleDevice(device);
                  },
                  activeColor: widget.accentColor,
                ),
                onTap: () {
                  _toggleDevice(device);
                },
                tileColor: isSelected
                    ? widget.accentColor.withOpacity(0.1)
                    : context.hCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HBotRadius.medium),
                  side: BorderSide(
                    color: isSelected
                        ? widget.accentColor.withOpacity(0.5)
                        : Colors.transparent,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _toggleDevice(Map<String, dynamic> device) {
    final List<Map<String, dynamic>> updatedDevices = List.from(
      widget.selectedDevices,
    );
    final existingIndex = updatedDevices.indexWhere(
      (selected) => selected['id'] == device['id'],
    );

    if (existingIndex >= 0) {
      updatedDevices.removeAt(existingIndex);
    } else {
      updatedDevices.add(device);
    }

    widget.onDevicesChanged(updatedDevices);
  }
}
