import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/panel.dart';
import '../models/device.dart';
import '../models/room.dart';
import '../models/scene.dart';
import '../repos/panels_repo.dart';
import '../repos/devices_repo.dart';
import '../repos/rooms_repo.dart';
import '../repos/scenes_repo.dart';
import '../services/enhanced_mqtt_service.dart';

/// Screen to manage what devices and scenes are shown on a paired panel
class ManagePanelScreen extends StatefulWidget {
  final Panel panel;

  const ManagePanelScreen({super.key, required this.panel});

  @override
  State<ManagePanelScreen> createState() => _ManagePanelScreenState();
}

class _ManagePanelScreenState extends State<ManagePanelScreen>
    with SingleTickerProviderStateMixin {
  final PanelsRepo _panelsRepo = PanelsRepo();
  final DevicesRepo _devicesRepo = DevicesRepo();
  final RoomsRepo _roomsRepo = RoomsRepo();
  final ScenesRepo _scenesRepo = ScenesRepo();

  late TabController _tabController;
  late Panel _panel;

  List<Device> _allDevices = [];
  List<Room> _allRooms = [];
  List<Scene> _allScenes = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Selected items
  final Set<String> _selectedDeviceIds = {};
  final Set<String> _selectedSceneIds = {};

  @override
  void initState() {
    super.initState();
    _panel = widget.panel;
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final homeId = _panel.homeId;
      if (homeId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final results = await Future.wait([
        _devicesRepo.listDevicesByHome(homeId).timeout(
              const Duration(seconds: 10),
              onTimeout: () => <Device>[],
            ),
        _roomsRepo.listRooms(homeId).timeout(
              const Duration(seconds: 10),
              onTimeout: () => <Room>[],
            ),
        _scenesRepo.listScenes(homeId).timeout(
              const Duration(seconds: 10),
              onTimeout: () => <Scene>[],
            ),
      ]);

      // Restore previously selected items from panel config (reset first)
      _selectedDeviceIds.clear();
      _selectedSceneIds.clear();
      final config = _panel.displayConfig;
      if (config != null) {
        final configDevices = config['devices'] as List? ?? [];
        for (final d in configDevices) {
          if (d is Map<String, dynamic> && d['id'] is String) {
            _selectedDeviceIds.add(d['id'] as String);
          }
        }
        final configScenes = config['scenes'] as List? ?? [];
        for (final s in configScenes) {
          if (s is Map<String, dynamic> && s['id'] is String) {
            _selectedSceneIds.add(s['id'] as String);
          }
        }
      }

      if (mounted) {
        setState(() {
          _allDevices = results[0] as List<Device>;
          _allRooms = results[1] as List<Room>;
          _allScenes = results[2] as List<Scene>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading panel config data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Build the display_config JSON from selections
  Map<String, dynamic> _buildDisplayConfig() {
    final devices = <Map<String, dynamic>>[];
    for (final device in _allDevices) {
      if (_selectedDeviceIds.contains(device.id)) {
        final room = _allRooms
            .where((r) => r.id == device.roomId)
            .firstOrNull;
        devices.add(PanelDeviceConfig(
          id: device.id,
          name: device.deviceName,
          type: device.deviceType.name,
          topic: device.deviceTopicBase ?? '',
          room: room?.name,
        ).toJson());
      }
    }

    final scenes = <Map<String, dynamic>>[];
    for (final scene in _allScenes) {
      if (_selectedSceneIds.contains(scene.id)) {
        scenes.add(PanelSceneConfig(
          id: scene.id,
          name: scene.name,
          icon: scene.iconCode?.toString(),
        ).toJson());
      }
    }

    return {
      'version': 1,
      'layout': 'grid',
      'devices': devices,
      'scenes': scenes,
    };
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      final config = _buildDisplayConfig();

      // Save to Supabase
      final updated = await _panelsRepo.updateDisplayConfig(_panel.id, config);
      _panel = updated;

      // Publish to MQTT retained topic so panel picks it up
      try {
        final mqtt = EnhancedMqttService();
        if (mqtt.isConnected) {
          mqtt.publishRetained(
            'hbot/panels/${_panel.deviceId}/config',
            jsonEncode(config),
          );
          debugPrint('Published panel config to MQTT');
        }
      } catch (e) {
        debugPrint('MQTT config publish failed (non-fatal): $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Panel display updated — ${_selectedDeviceIds.length} devices, ${_selectedSceneIds.length} scenes'),
          backgroundColor: HBotColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: HBotColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _roomNameForDevice(Device device) {
    if (device.roomId == null) return 'Unassigned';
    return _allRooms
            .where((r) => r.id == device.roomId)
            .firstOrNull
            ?.name ??
        'Unassigned';
  }

  IconData _iconForDeviceType(DeviceType type) {
    switch (type) {
      case DeviceType.relay:
        return Icons.power;
      case DeviceType.dimmer:
        return Icons.lightbulb_outline;
      case DeviceType.shutter:
        return Icons.blinds;
      case DeviceType.sensor:
        return Icons.sensors;
      case DeviceType.other:
        return Icons.devices_other;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hBackground,
      appBar: AppBar(
        title: Text(_panel.displayName),
        backgroundColor: context.hSurface,
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveConfig,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary bar
                _buildSummaryBar(),
                // Tabs
                Container(
                  color: context.hSurface,
                  child: TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(
                        text: 'Devices (${_selectedDeviceIds.length})',
                        icon: const Icon(Icons.devices),
                      ),
                      Tab(
                        text: 'Scenes (${_selectedSceneIds.length})',
                        icon: const Icon(Icons.auto_awesome),
                      ),
                    ],
                  ),
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDevicesTab(),
                      _buildScenesTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HBotSpacing.space5,
        vertical: HBotSpacing.space3,
      ),
      color: context.hSurface,
      child: Row(
        children: [
          Icon(Icons.tv, color: HBotColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_selectedDeviceIds.length} devices and ${_selectedSceneIds.length} scenes will show on this panel',
              style: TextStyle(
                fontSize: 13,
                color: context.hTextSecondary,
              ),
            ),
          ),
          if (_selectedDeviceIds.isNotEmpty || _selectedSceneIds.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDeviceIds.clear();
                  _selectedSceneIds.clear();
                });
              },
              child: Text(
                'Clear all',
                style: TextStyle(fontSize: 12, color: HBotColors.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDevicesTab() {
    if (_allDevices.isEmpty) {
      return Center(
        child: Text(
          'No devices found in this home.',
          style: TextStyle(color: context.hTextSecondary),
        ),
      );
    }

    // Group devices by room
    final Map<String, List<Device>> devicesByRoom = {};
    for (final device in _allDevices) {
      final roomName = _roomNameForDevice(device);
      devicesByRoom.putIfAbsent(roomName, () => []).add(device);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: HBotSpacing.space3),
      children: devicesByRoom.entries.map((entry) {
        final roomName = entry.key;
        final devices = entry.value;
        final allSelected = devices.every((d) => _selectedDeviceIds.contains(d.id));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room header with select all
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HBotSpacing.space5,
                vertical: HBotSpacing.space2,
              ),
              child: Row(
                children: [
                  Text(
                    roomName,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.hTextSecondary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          for (final d in devices) {
                            _selectedDeviceIds.remove(d.id);
                          }
                        } else {
                          for (final d in devices) {
                            _selectedDeviceIds.add(d.id);
                          }
                        }
                      });
                    },
                    child: Text(
                      allSelected ? 'Deselect all' : 'Select all',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            // Device items
            ...devices.map((device) => _buildDeviceItem(device)),
            const Divider(height: 1),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDeviceItem(Device device) {
    final isSelected = _selectedDeviceIds.contains(device.id);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? HBotColors.primary.withOpacity(0.1)
              : context.hBorder.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _iconForDeviceType(device.deviceType),
          color: isSelected ? HBotColors.primary : context.hTextSecondary,
          size: 20,
        ),
      ),
      title: Text(
        device.deviceName,
        style: TextStyle(
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w500,
          color: context.hTextPrimary,
        ),
      ),
      subtitle: Text(
        '${device.deviceType.name} ${device.deviceTopicBase != null ? "• ${device.deviceTopicBase}" : ""}',
        style: TextStyle(fontSize: 12, color: context.hTextSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (val) {
          setState(() {
            if (val == true) {
              _selectedDeviceIds.add(device.id);
            } else {
              _selectedDeviceIds.remove(device.id);
            }
          });
        },
        activeColor: HBotColors.primary,
      ),
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDeviceIds.remove(device.id);
          } else {
            _selectedDeviceIds.add(device.id);
          }
        });
      },
    );
  }

  Widget _buildScenesTab() {
    if (_allScenes.isEmpty) {
      return Center(
        child: Text(
          'No scenes found in this home.',
          style: TextStyle(color: context.hTextSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: HBotSpacing.space3),
      children: [
        // Select all header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HBotSpacing.space5,
            vertical: HBotSpacing.space2,
          ),
          child: Row(
            children: [
              Text(
                'Scenes',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.hTextSecondary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    final allSelected = _allScenes.every(
                        (s) => _selectedSceneIds.contains(s.id));
                    if (allSelected) {
                      _selectedSceneIds.clear();
                    } else {
                      for (final s in _allScenes) {
                        _selectedSceneIds.add(s.id);
                      }
                    }
                  });
                },
                child: Text(
                  _allScenes.every((s) => _selectedSceneIds.contains(s.id))
                      ? 'Deselect all'
                      : 'Select all',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        ..._allScenes.map((scene) => _buildSceneItem(scene)),
      ],
    );
  }

  Widget _buildSceneItem(Scene scene) {
    final isSelected = _selectedSceneIds.contains(scene.id);
    final iconData = scene.iconCode != null
        ? IconData(scene.iconCode!, fontFamily: 'MaterialIcons')
        : Icons.auto_awesome;
    final color = scene.colorValue != null
        ? Color(scene.colorValue!)
        : HBotColors.primary;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : context.hBorder.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(iconData, color: isSelected ? color : context.hTextSecondary, size: 20),
      ),
      title: Text(
        scene.name,
        style: TextStyle(
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w500,
          color: context.hTextPrimary,
        ),
      ),
      subtitle: Text(
        scene.isEnabled ? 'Active' : 'Disabled',
        style: TextStyle(
          fontSize: 12,
          color: scene.isEnabled ? HBotColors.success : context.hTextSecondary,
        ),
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (val) {
          setState(() {
            if (val == true) {
              _selectedSceneIds.add(scene.id);
            } else {
              _selectedSceneIds.remove(scene.id);
            }
          });
        },
        activeColor: color,
      ),
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedSceneIds.remove(scene.id);
          } else {
            _selectedSceneIds.add(scene.id);
          }
        });
      },
    );
  }
}
