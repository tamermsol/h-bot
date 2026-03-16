import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device.dart';
import '../services/home_widget_service.dart';
import '../theme/app_theme.dart';

/// Screen for configuring which devices appear in the home screen widget.
/// Can be launched from:
/// - Widget setup (Android configure activity)
/// - Profile/Settings → "Configure Widget"
class WidgetConfigScreen extends StatefulWidget {
  const WidgetConfigScreen({super.key});

  @override
  State<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends State<WidgetConfigScreen> {
  List<Device> _allDevices = [];
  List<String> _selectedDeviceIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch devices directly from Supabase
      final response = await Supabase.instance.client
          .from('devices')
          .select()
          .eq('owner_user_id', userId)
          .order('device_name');
      final devices = (response as List)
          .map((json) => Device.fromJson(json as Map<String, dynamic>))
          .toList();

      // Load previously selected devices
      final favorites = await HomeWidgetService.loadFavoriteDevices();
      final favoriteIds = favorites.map((f) => f.id).toList();

      setState(() {
        _allDevices = devices;
        _selectedDeviceIds = favoriteIds.where((id) =>
            devices.any((d) => d.id == id)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Error loading devices: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleDevice(String deviceId) {
    setState(() {
      if (_selectedDeviceIds.contains(deviceId)) {
        _selectedDeviceIds.remove(deviceId);
      } else if (_selectedDeviceIds.length < 4) {
        _selectedDeviceIds.add(deviceId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum 4 devices in widget'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _saveAndClose() async {
    final selectedDevices = _selectedDeviceIds
        .map((id) => _allDevices.where((d) => d.id == id).firstOrNull)
        .whereType<Device>()
        .map((d) => WidgetDevice(
              id: d.id,
              name: d.deviceName,
              isOn: false,
              type: d.deviceType.name,
              topicBase: d.deviceTopicBase ?? d.id,
              channels: d.effectiveChannels,
            ))
        .toList();

    await HomeWidgetService.saveFavoriteDevices(selectedDevices);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  IconData _getDeviceIcon(Device device) {
    final type = device.deviceType.name.toLowerCase();
    if (type.contains('shutter') || type.contains('blind')) {
      return Icons.blinds;
    } else if (type.contains('light') || type.contains('dimmer')) {
      return Icons.lightbulb_outline;
    } else {
      return Icons.power_settings_new;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Configure Widget'),
        actions: [
          TextButton(
            onPressed: _selectedDeviceIds.isNotEmpty ? _saveAndClose : null,
            child: Text(
              'Save',
              style: TextStyle(
                color: _selectedDeviceIds.isNotEmpty
                    ? HBotColors.primary
                    : (isDark ? Colors.white38 : Colors.black26),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: HBotColors.primary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Select up to 4 devices for your widget',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),

                // Selected count
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '${_selectedDeviceIds.length}/4 selected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HBotColors.primary,
                    ),
                  ),
                ),

                SizedBox(height: 12),

                // Device list
                Expanded(
                  child: _allDevices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.devices_other, size: 48,
                                  color: isDark ? Colors.white24 : Colors.black26),
                              SizedBox(height: 12),
                              Text('No devices found',
                                  style: TextStyle(
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  )),
                              SizedBox(height: 4),
                              Text('Add devices in the app first',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white24 : Colors.black26,
                                  )),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _allDevices.length,
                          itemBuilder: (context, index) {
                            final device = _allDevices[index];
                            final isSelected =
                                _selectedDeviceIds.contains(device.id);
                            final canSelect =
                                _selectedDeviceIds.length < 4 || isSelected;

                            return Card(
                              margin: EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 4),
                              color: isSelected
                                  ? HBotColors.primary.withOpacity(0.15)
                                  : (isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.white),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isSelected
                                    ? BorderSide(
                                        color: HBotColors.primary, width: 1.5)
                                    : BorderSide.none,
                              ),
                              child: ListTile(
                                onTap: canSelect
                                    ? () => _toggleDevice(device.id)
                                    : null,
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? HBotColors.primary.withOpacity(0.2)
                                        : (isDark
                                            ? Colors.white.withOpacity(0.08)
                                            : Colors.grey.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getDeviceIcon(device),
                                    color: isSelected
                                        ? HBotColors.primary
                                        : (isDark
                                            ? Colors.white54
                                            : Colors.black45),
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  device.deviceName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: !canSelect && !isSelected
                                        ? (isDark
                                            ? Colors.white24
                                            : Colors.black26)
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${device.deviceType.name} • ${device.effectiveChannels} ch',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: HBotColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${_selectedDeviceIds.indexOf(device.id) + 1}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.radio_button_off,
                                        color: canSelect
                                            ? (isDark
                                                ? Colors.white24
                                                : Colors.black26)
                                            : Colors.transparent,
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
