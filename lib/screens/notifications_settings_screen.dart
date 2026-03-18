import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_shell.dart';
import '../services/notification_service.dart';
import '../l10n/app_strings.dart';

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
        _showSuccessMessage(AppStrings.get('notif_enabled_success'));
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
      _showSuccessMessage(AppStrings.get('notif_disabled'));
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
        backgroundColor: context.hCard,
        title: Text(AppStrings.get('notifications_settings_permission_denied')),
        content: Text(
          AppStrings.get('notif_permission_denied'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get('notifications_settings_cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleNotifications(true); // Try again
            },
            child: Text(AppStrings.get('notifications_settings_try_again')),
          ),
        ],
      ),
    );
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.hCard,
        title: Text(AppStrings.get('notifications_settings_permission_required')),
        content: Text(
          AppStrings.get('notif_permission_permanent'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get('notifications_settings_cancel_2')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // Open device settings
            },
            child: Text(AppStrings.get('notifications_settings_open_settings')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: context.hBackground,
      appBar: AppBar(
        title: Text(AppStrings.get('notifications_settings_notifications')),
        backgroundColor: context.hBackground,
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
                    AppStrings.get('notifications_settings_notification_preferences'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.hTextPrimary,
                    ),
                  ),
                  const SizedBox(height: HBotSpacing.space2),
                  Text(
                    AppStrings.get('notifications_settings_manage_desc'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.hTextSecondary,
                    ),
                  ),
                  const SizedBox(height: HBotSpacing.space6),

                  // Enable/Disable Notifications
                  Container(
                    decoration: BoxDecoration(
                      color: context.hCard,
                      borderRadius: BorderRadius.circular(
                        HBotRadius.medium,
                      ),
                    ),
                    child: SwitchListTile(
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                      title: Text(
                        AppStrings.get('notifications_settings_enable_notifications'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: context.hTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        _notificationsEnabled
                            ? AppStrings.get('notifications_settings_enable_desc')
                            : AppStrings.get('notif_turn_on'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.hTextSecondary,
                        ),
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(HBotSpacing.space2),
                        decoration: BoxDecoration(
                          color: _notificationsEnabled
                              ? HBotColors.primary.withOpacity(0.1)
                              : context.hTextSecondary.withOpacity(0.1),
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
                              : context.hTextSecondary,
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
                                  AppStrings.get('notif_permission_required'),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: context.hTextPrimary,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppStrings.get('notif_permission_required_desc'),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: context.hTextSecondary,
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
                    AppStrings.get('notifications_settings_notification_types'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.hTextPrimary,
                    ),
                  ),
                  const SizedBox(height: HBotSpacing.space4),
                  Container(
                    decoration: BoxDecoration(
                      color: context.hCard,
                      borderRadius: BorderRadius.circular(HBotRadius.medium),
                    ),
                    child: Column(
                      children: [
                        _buildNotificationToggle(
                          icon: Icons.cloud_off,
                          title: AppStrings.get('notifications_settings_device_offline'),
                          description: AppStrings.get('notifications_settings_device_offline_desc'),
                          value: _deviceOffline,
                          onChanged: _notificationsEnabled ? (v) {
                            setState(() => _deviceOffline = v);
                            _notifService.setDeviceOfflineEnabled(v);
                          } : null,
                        ),
                        const Divider(height: 1, indent: 72),
                        _buildNotificationToggle(
                          icon: Icons.cloud_done,
                          title: AppStrings.get('notifications_settings_device_online'),
                          description: AppStrings.get('notifications_settings_device_online_desc'),
                          value: _deviceOnline,
                          onChanged: _notificationsEnabled ? (v) {
                            setState(() => _deviceOnline = v);
                            _notifService.setDeviceOnlineEnabled(v);
                          } : null,
                        ),
                        const Divider(height: 1, indent: 72),
                        _buildNotificationToggle(
                          icon: Icons.auto_awesome,
                          title: AppStrings.get('notifications_settings_scene_executed'),
                          description: AppStrings.get('notifications_settings_scene_executed_desc'),
                          value: _sceneRun,
                          onChanged: _notificationsEnabled ? (v) {
                            setState(() => _sceneRun = v);
                            _notifService.setSceneRunEnabled(v);
                          } : null,
                        ),
                        const Divider(height: 1, indent: 72),
                        _buildNotificationToggle(
                          icon: Icons.lightbulb_outline,
                          title: AppStrings.get('notifications_settings_state_changes'),
                          description: AppStrings.get('notifications_settings_state_changes_desc'),
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
          color: context.hTextPrimary,
        ),
      ),
      subtitle: Text(
        description,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.hTextSecondary,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
