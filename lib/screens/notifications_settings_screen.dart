import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../l10n/app_strings.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_notificationsEnabledKey) ?? false;
      final status = await Permission.notification.status;
      final deviceOffline = await _notifService.deviceOfflineEnabled;
      final deviceOnline = await _notifService.deviceOnlineEnabled;
      final sceneRun = await _notifService.sceneRunEnabled;
      final stateChange = await _notifService.stateChangeEnabled;

      if (mounted) {
        setState(() {
          _notificationsEnabled = enabled && status.isGranted;
          if (status.isGranted && !enabled) {
            prefs.setBool(_notificationsEnabledKey, true);
            _notificationsEnabled = true;
          }
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
      final status = await _requestNotificationPermission();
      if (status.isGranted) {
        await _saveNotificationPreference(true);
        if (mounted) {
          setState(() {
            _notificationsEnabled = true;
            _permissionStatus = status;
          });
        }
        _showSuccessMessage(AppStrings.get('notif_enabled_success'));
      } else if (status.isDenied) {
        _showPermissionDeniedDialog();
      } else if (status.isPermanentlyDenied) {
        _showOpenSettingsDialog();
      }
    } else {
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
        backgroundColor: HBotColors.sheetBackground,
        title: Text(
          AppStrings.get('notifications_settings_permission_denied'),
          style: const TextStyle(color: Colors.white, fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
        ),
        content: Text(
          AppStrings.get('notif_permission_denied'),
          style: const TextStyle(color: HBotColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get('notifications_settings_cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleNotifications(true);
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
        backgroundColor: HBotColors.sheetBackground,
        title: Text(
          AppStrings.get('notifications_settings_permission_required'),
          style: const TextStyle(color: Colors.white, fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
        ),
        content: Text(
          AppStrings.get('notif_permission_permanent'),
          style: const TextStyle(color: HBotColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get('notifications_settings_cancel_2')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          AppStrings.get('notifications_settings_notifications'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'DM Sans',
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: HBotColors.glassBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HBotColors.glassBorder),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HBotColors.darkBgTop, HBotColors.darkBgBottom],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: HBotColors.primary))
            : SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + HBotSpacing.space4,
                  left: HBotSpacing.space5,
                  right: HBotSpacing.space5,
                  bottom: HBotSpacing.space6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      AppStrings.get('notifications_settings_notification_preferences'),
                      style: const TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space2),
                    Text(
                      AppStrings.get('notifications_settings_manage_desc'),
                      style: const TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 14,
                        color: HBotColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space6),

                    // Enable/Disable Notifications — glass card
                    Container(
                      decoration: BoxDecoration(
                        color: HBotColors.glassBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: HBotColors.glassBorder, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: HBotColors.glassBlur, sigmaY: HBotColors.glassBlur),
                          child: SwitchListTile(
                            value: _notificationsEnabled,
                            onChanged: _toggleNotifications,
                            activeColor: HBotColors.primary,
                            title: Text(
                              AppStrings.get('notifications_settings_enable_notifications'),
                              style: const TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              _notificationsEnabled
                                  ? AppStrings.get('notifications_settings_enable_desc')
                                  : AppStrings.get('notif_turn_on'),
                              style: const TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 11,
                                color: HBotColors.textMuted,
                              ),
                            ),
                            secondary: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _notificationsEnabled
                                    ? HBotColors.primary.withOpacity(0.15)
                                    : HBotColors.textMuted.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _notificationsEnabled
                                    ? Icons.notifications_active
                                    : Icons.notifications_off_outlined,
                                color: _notificationsEnabled
                                    ? HBotColors.primary
                                    : HBotColors.textMuted,
                                size: 20,
                              ),
                            ),
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
                          color: HBotColors.warning.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: HBotColors.warning.withOpacity(0.2),
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
                                    style: const TextStyle(
                                      fontFamily: 'DM Sans',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppStrings.get('notif_permission_required_desc'),
                                    style: const TextStyle(
                                      fontFamily: 'DM Sans',
                                      fontSize: 12,
                                      color: HBotColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: HBotSpacing.space6),

                    // Notification types section title
                    Text(
                      AppStrings.get('notifications_settings_notification_types').toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: HBotColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space3),

                    // Notification types — glass card
                    Container(
                      decoration: BoxDecoration(
                        color: HBotColors.glassBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: HBotColors.glassBorder, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: HBotColors.glassBlur, sigmaY: HBotColors.glassBlur),
                          child: Column(
                            children: [
                              _buildNotificationToggle(
                                icon: Icons.cloud_off,
                                title: AppStrings.get('notifications_settings_device_offline'),
                                description: AppStrings.get('notifications_settings_device_offline_desc'),
                                value: _deviceOffline,
                                iconColor: HBotColors.error,
                                onChanged: _notificationsEnabled ? (v) {
                                  setState(() => _deviceOffline = v);
                                  _notifService.setDeviceOfflineEnabled(v);
                                } : null,
                              ),
                              Padding(
                                padding: const EdgeInsetsDirectional.only(start: 60),
                                child: Container(height: 0.5, color: HBotColors.glassBorder),
                              ),
                              _buildNotificationToggle(
                                icon: Icons.cloud_done,
                                title: AppStrings.get('notifications_settings_device_online'),
                                description: AppStrings.get('notifications_settings_device_online_desc'),
                                value: _deviceOnline,
                                iconColor: HBotColors.success,
                                onChanged: _notificationsEnabled ? (v) {
                                  setState(() => _deviceOnline = v);
                                  _notifService.setDeviceOnlineEnabled(v);
                                } : null,
                              ),
                              Padding(
                                padding: const EdgeInsetsDirectional.only(start: 60),
                                child: Container(height: 0.5, color: HBotColors.glassBorder),
                              ),
                              _buildNotificationToggle(
                                icon: Icons.auto_awesome,
                                title: AppStrings.get('notifications_settings_scene_executed'),
                                description: AppStrings.get('notifications_settings_scene_executed_desc'),
                                value: _sceneRun,
                                iconColor: HBotColors.warning,
                                onChanged: _notificationsEnabled ? (v) {
                                  setState(() => _sceneRun = v);
                                  _notifService.setSceneRunEnabled(v);
                                } : null,
                              ),
                              Padding(
                                padding: const EdgeInsetsDirectional.only(start: 60),
                                child: Container(height: 0.5, color: HBotColors.glassBorder),
                              ),
                              _buildNotificationToggle(
                                icon: Icons.lightbulb_outline,
                                title: AppStrings.get('notifications_settings_state_changes'),
                                description: AppStrings.get('notifications_settings_state_changes_desc'),
                                value: _stateChange,
                                iconColor: HBotColors.primary,
                                onChanged: _notificationsEnabled ? (v) {
                                  setState(() => _stateChange = v);
                                  _notifService.setStateChangeEnabled(v);
                                } : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildNotificationToggle({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    Color iconColor = HBotColors.primary,
    ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      activeColor: HBotColors.primary,
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        description,
        style: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 11,
          color: HBotColors.textMuted,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
