import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_shell.dart';
import '../services/notification_service.dart';

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

  // Granular notification preferences
  final NotificationService _notifService = NotificationService();
  bool _deviceOffline = true;
  bool _deviceOnline = false;
  bool _sceneRun = true;
  bool _stateChange = false;

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

      // Load granular preferences
      final deviceOffline = await _notifService.deviceOfflineEnabled;
      final deviceOnline = await _notifService.deviceOnlineEnabled;
      final sceneRun = await _notifService.sceneRunEnabled;
      final stateChange = await _notifService.stateChangeEnabled;

      if (mounted) {
        setState(() {
          _notificationsEnabled = enabled;
          _permissionStatus = status;
          _deviceOffline = deviceOffline;
          _deviceOnline = deviceOnline;
          _sceneRun = sceneRun;
          _stateChange = stateChange;
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
          content: Text(message),
          backgroundColor: HBotColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.cardLight,
        title: const Text('Permission Denied'),
        content: const Text(
          'Notification permission was denied. You can enable it later from your device settings or try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleNotifications(true); // Try again
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.cardLight,
        title: const Text('Permission Required'),
        content: const Text(
          'Notification permission is permanently denied. Please enable it from your device settings to receive notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // Open device settings
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: HBotColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: HBotColors.backgroundLight,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(HBotSpacing.space6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Notification Preferences',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: HBotColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: HBotSpacing.space2),
                  Text(
                    'Manage how you receive notifications from HBOT',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HBotColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: HBotSpacing.space6),

                  // Enable/Disable Notifications
                  Container(
                    decoration: BoxDecoration(
                      color: HBotColors.cardLight,
                      borderRadius: BorderRadius.circular(
                        HBotRadius.medium,
                      ),
                    ),
                    child: SwitchListTile(
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                      title: Text(
                        'Enable Notifications',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: HBotColors.textPrimaryLight,
                        ),
                      ),
                      subtitle: Text(
                        _notificationsEnabled
                            ? 'You will receive notifications about device status, automations, and updates'
                            : 'Turn on to receive notifications',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HBotColors.textSecondaryLight,
                        ),
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(HBotSpacing.space2),
                        decoration: BoxDecoration(
                          color: _notificationsEnabled
                              ? HBotColors.primary.withOpacity(0.1)
                              : HBotColors.textSecondaryLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            HBotRadius.small,
                          ),
                        ),
                        child: Icon(
                          _notificationsEnabled
                              ? Icons.notifications_active
                              : Icons.notifications_off_outlined,
                          color: _notificationsEnabled
                              ? HBotColors.primary
                              : HBotColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: HBotSpacing.space6),

                  // Permission Status Info
                  if (_permissionStatus != PermissionStatus.granted)
                    Container(
                      padding: const EdgeInsets.all(HBotSpacing.space4),
                      decoration: BoxDecoration(
                        color: HBotColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          HBotRadius.medium,
                        ),
                        border: Border.all(
                          color: HBotColors.warning.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: HBotColors.warning,
                            size: 24,
                          ),
                          const SizedBox(width: HBotSpacing.space4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Permission Required',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: HBotColors.textPrimaryLight,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Notification permission is required to receive alerts. Enable notifications above to grant permission.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: HBotColors.textSecondaryLight,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: HBotSpacing.space6),

                  // Notification types section
                  Text(
                    'Notification Types',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: HBotColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: HBotSpacing.space4),
                  Container(
                    decoration: BoxDecoration(
                      color: HBotColors.cardLight,
                      borderRadius: BorderRadius.circular(HBotRadius.medium),
                    ),
                    child: Column(
                      children: [
                        _buildNotificationToggle(
                          icon: Icons.cloud_off,
                          title: 'Device Offline',
                          description: 'When a device goes offline',
                          value: _deviceOffline,
                          onChanged: _notificationsEnabled ? (v) {
                            setState(() => _deviceOffline = v);
                            _notifService.setDeviceOfflineEnabled(v);
                          } : null,
                        ),
                        const Divider(height: 1, indent: 72),
                        _buildNotificationToggle(
                          icon: Icons.cloud_done,
                          title: 'Device Online',
                          description: 'When a device comes back online',
                          value: _deviceOnline,
                          onChanged: _notificationsEnabled ? (v) {
                            setState(() => _deviceOnline = v);
                            _notifService.setDeviceOnlineEnabled(v);
                          } : null,
                        ),
                        const Divider(height: 1, indent: 72),
                        _buildNotificationToggle(
                          icon: Icons.auto_awesome,
                          title: 'Scene Executed',
                          description: 'When a scene or automation runs',
                          value: _sceneRun,
                          onChanged: _notificationsEnabled ? (v) {
                            setState(() => _sceneRun = v);
                            _notifService.setSceneRunEnabled(v);
                          } : null,
                        ),
                        const Divider(height: 1, indent: 72),
                        _buildNotificationToggle(
                          icon: Icons.lightbulb_outline,
                          title: 'State Changes',
                          description: 'When a device is turned on/off',
                          value: _stateChange,
                          onChanged: _notificationsEnabled ? (v) {
                            setState(() => _stateChange = v);
                            _notifService.setStateChangeEnabled(v);
                          } : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNotificationToggle({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(HBotSpacing.space2),
        decoration: BoxDecoration(
          color: HBotColors.primary.withOpacity(0.1),
          borderRadius: HBotRadius.smallRadius,
        ),
        child: Icon(icon, color: HBotColors.primary, size: 24),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: HBotColors.textPrimaryLight,
        ),
      ),
      subtitle: Text(
        description,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: HBotColors.textSecondaryLight,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
