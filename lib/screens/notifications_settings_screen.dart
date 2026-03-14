import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/phosphor_icons.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  static const String _notificationsEnabledKey = 'notifications_enabled';
  bool _notificationsEnabled = false;
  bool _isLoading = true;
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // Load saved preference
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_notificationsEnabledKey) ?? false;

      // Check current permission status
      final status = await Permission.notification.status;

      if (mounted) {
        setState(() {
          _notificationsEnabled = enabled;
          _permissionStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // User wants to enable notifications - request permission
      final status = await _requestNotificationPermission();

      if (status.isGranted) {
        // Permission granted, save the preference
        await _saveNotificationPreference(true);
        if (mounted) {
          setState(() {
            _notificationsEnabled = true;
            _permissionStatus = status;
          });
        }
        _showSuccessMessage('Notifications enabled successfully');
      } else if (status.isDenied) {
        // Permission denied
        _showPermissionDeniedDialog();
      } else if (status.isPermanentlyDenied) {
        // Permission permanently denied - guide user to settings
        _showOpenSettingsDialog();
      }
    } else {
      // User wants to disable notifications
      await _saveNotificationPreference(false);
      if (mounted) {
        setState(() {
          _notificationsEnabled = false;
        });
      }
      _showSuccessMessage('Notifications disabled');
    }
  }

  Future<PermissionStatus> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return PermissionStatus.denied;
    }
  }

  Future<void> _saveNotificationPreference(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsEnabledKey, enabled);
    } catch (e) {
      debugPrint('Error saving notification preference: $e');
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: const Color(0xFF8CD1FB),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F7FA),
        title: const Text(
          'Permission Denied',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        content: const Text(
          'Notification permission was denied. You can enable it later from your device settings or try again.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Inter'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleNotifications(true); // Try again
            },
            child: const Text(
              'Try Again',
              style: TextStyle(fontFamily: 'Inter'),
            ),
          ),
        ],
      ),
    );
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F7FA),
        title: const Text(
          'Permission Required',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        content: const Text(
          'Notification permission is permanently denied. Please enable it from your device settings to receive notifications.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Inter'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // Open device settings
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(fontFamily: 'Inter'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                HBotIcons.back,
                size: 16,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
            color: Color(0xFF1F2937),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Notification Preferences',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage how you receive notifications from HBOT',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Enable/Disable Notifications
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                      title: const Text(
                        'Enable Notifications',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: Color(0xFF1F2937),
                          fontFamily: 'Inter',
                        ),
                      ),
                      subtitle: Text(
                        _notificationsEnabled
                            ? 'You will receive notifications about device status, automations, and updates'
                            : 'Turn on to receive notifications',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontFamily: 'Inter',
                        ),
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _notificationsEnabled
                              ? const Color(0xFF0883FD).withOpacity(0.1)
                              : const Color(0xFF6B7280).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _notificationsEnabled
                              ? HBotIcons.notificationsFilled
                              : HBotIcons.notifications,
                          color: _notificationsEnabled
                              ? const Color(0xFF0883FD)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Permission Status Info
                  if (_permissionStatus != PermissionStatus.granted)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            HBotIcons.info,
                            color: Color(0xFFF59E0B),
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Permission Required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF1F2937),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Notification permission is required to receive alerts. Enable notifications above to grant permission.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // What you'll receive section
                  const Text(
                    'What you\'ll receive',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildNotificationTypeItem(
                          icon: HBotIcons.power,
                          title: 'Device Status',
                          description:
                              'Get notified when devices go online or offline',
                        ),
                        const Divider(height: 1, indent: 72),
                        _buildNotificationTypeItem(
                          icon: HBotIcons.scenes,
                          title: 'Automation Alerts',
                          description:
                              'Notifications when scenes and automations run',
                        ),
                        const Divider(height: 1, indent: 72),
                        _buildNotificationTypeItem(
                          icon: HBotIcons.refresh,
                          title: 'System Updates',
                          description: 'Important updates and announcements',
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNotificationTypeItem({
    required IconData icon,
    required String title,
    required String description,
    bool showDivider = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0883FD).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF0883FD), size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: Color(0xFF1F2937),
          fontFamily: 'Inter',
        ),
      ),
      subtitle: Text(
        description,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF6B7280),
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
