import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../theme/app_theme.dart';
import '../widgets/settings_tile.dart';
import '../widgets/avatar_picker_dialog.dart';
import '../services/auth_service.dart';
import '../services/smart_home_service.dart';
import '../services/current_home_service.dart';
import '../services/avatar_service.dart';
import '../models/profile.dart';
import '../models/home.dart';
import '../utils/error_handler.dart';
import '../core/supabase_client.dart';
import 'sign_in_screen.dart';
import 'profile_edit_screen.dart';
import 'homes_screen.dart';
import 'help_center_screen.dart';
import 'notifications_settings_screen.dart';
import 'feedback_screen.dart';
import 'hbot_account_screen.dart';
import 'shared_devices_screen.dart';
import 'multi_device_share_screen.dart';
import 'rooms_screen.dart';
import 'wifi_profile_screen.dart';
import '../widgets/responsive_shell.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final SmartHomeService _smartHomeService = SmartHomeService();
  final CurrentHomeService _currentHomeService = CurrentHomeService();
  final AvatarService _avatarService = AvatarService();
  String? _userEmail;
  String? _userName;
  String? _userPhone;
  Profile? _currentProfile;
  String? _avatarPath;

  // Statistics
  int _totalHomes = 0;
  int _totalDevices = 0;
  int _totalRooms = 0;
  int _totalScenes = 0;
  bool _isLoadingStats = true;

  // Home change subscription
  StreamSubscription<String?>? _homeChangeSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStatistics();
    _loadAvatar();

    // Listen for home changes
    _homeChangeSubscription = _currentHomeService.homeChanges.listen((_) {
      debugPrint('Profile screen detected home change, refreshing statistics');
      _loadStatistics();
    });
  }

  @override
  void dispose() {
    _homeChangeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Get basic user info from auth
        if (mounted) {
          setState(() {
            _userEmail = user.email;
            _userName = user.email?.split('@').first ?? 'User';
          });
        }

        // Try to get full profile from database with timeout
        try {
          final profile = await _authService.getCurrentProfile().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              // Return null on timeout, use basic auth data
              return null;
            },
          );

          if (profile != null && mounted) {
            setState(() {
              _currentProfile = profile;
              _userName = profile.fullName ?? _userName;
              _userPhone = profile.phoneNumber;
            });
          }
        } catch (profileError) {
          // Profile loading failed, but we still have basic auth info
          // Silently continue with auth data only
          ErrorHandler.logError(
            profileError,
            context: 'ProfileScreen._loadUserData',
          );
        }
      } else {
        // No user signed in
        if (mounted) {
          setState(() {
            _userEmail = null;
            _userName = null;
            _userPhone = null;
          });
        }
      }
    } catch (e) {
      // Handle error - show fallback data
      ErrorHandler.logError(e, context: 'ProfileScreen._loadUserData');
      if (mounted) {
        setState(() {
          _userEmail = 'Unable to load';
          _userName = 'User';
          _userPhone = null;
        });
      }
    }
  }

  Future<void> _loadAvatar() async {
    final avatarPath = await _avatarService.getCurrentAvatarPath();
    if (mounted) {
      setState(() {
        _avatarPath = avatarPath;
      });
    }
  }

  Future<void> _showAvatarPicker() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AvatarPickerDialog(currentAvatarPath: _avatarPath),
    );

    if (result != null) {
      if (result == 'gallery') {
        final path = await _avatarService.pickFromGallery();
        if (path != null && mounted) {
          setState(() {
            _avatarPath = path;
          });
        }
      } else if (result == 'camera') {
        final path = await _avatarService.pickFromCamera();
        if (path != null && mounted) {
          setState(() {
            _avatarPath = path;
          });
        }
      } else {
        // Default avatar selected
        await _avatarService.setDefaultAvatar(result);
        if (mounted) {
          setState(() {
            _avatarPath = result;
          });
        }
      }
    }
  }

  void _showAppearanceDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dark mode coming in a future update'),
        backgroundColor: HBotColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadStatistics() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingStats = true;
        });
      }

      // Get all homes for the current user
      final homes = await _smartHomeService.getMyHomes();

      int homeCount = homes.length;
      int deviceCount = 0;
      int roomCount = 0;
      int sceneCount = 0;

      // Aggregate statistics across all homes
      for (final home in homes) {
        try {
          // Count devices in this home
          final devices = await _smartHomeService.getDevicesByHome(home.id);
          deviceCount += devices.length;

          // Count rooms in this home
          final rooms = await _smartHomeService.getRooms(home.id);
          roomCount += rooms.length;

          // Count scenes in this home
          final scenes = await _smartHomeService.getScenes(home.id);
          sceneCount += scenes.length;
        } catch (e) {
          ErrorHandler.logError(
            e,
            context: 'ProfileScreen._loadStatistics.home',
          );
          // Continue with other homes even if one fails
        }
      }

      if (mounted) {
        setState(() {
          _totalHomes = homeCount;
          _totalDevices = deviceCount;
          _totalRooms = roomCount;
          _totalScenes = sceneCount;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProfileScreen._loadStatistics');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          // Keep default values (0) on error
        });
      }
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.of(context).push<Profile>(
      MaterialPageRoute(
        builder: (context) =>
            ProfileEditScreen(initialProfile: _currentProfile),
      ),
    );

    // Refresh profile data if updated
    if (result != null) {
      _loadUserData();
      _loadStatistics(); // Also refresh statistics
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: HBotSpacing.space4),

          // Profile Header — centered avatar + name + email
          _buildProfileHeader(),

          // Home section
          SettingsGroup(
            label: 'Home',
            children: [
              SettingsTile(
                icon: Icons.meeting_room_outlined,
                title: 'Rooms',
                onTap: () async {
                  final homeId = await CurrentHomeService().getCurrentHomeId();
                  if (homeId == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a home first'), backgroundColor: HBotColors.warning),
                      );
                    }
                    return;
                  }
                  try {
                    final homes = await SmartHomeService().getMyHomes();
                    final home = homes.firstWhere((h) => h.id == homeId);
                    if (mounted) {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => RoomsScreen(home: home)));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not load home: $e'), backgroundColor: HBotColors.error),
                      );
                    }
                  }
                },
              ),
              SettingsTile(
                icon: Icons.wifi_outlined,
                title: 'WiFi Profiles',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WiFiProfileScreen())),
                showDivider: false,
              ),
            ],
          ),

          // App section
          SettingsGroup(
            label: 'App',
            children: [
              SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen())),
              ),
              SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                value: 'Light Mode',
                onTap: _showAppearanceDialog,
              ),
              SettingsTile(
                icon: Icons.info_outline,
                title: 'About',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
                showDivider: false,
              ),
            ],
          ),

          // Account section
          SettingsGroup(
            label: 'Account',
            children: [
              SettingsTile(
                icon: Icons.person_outline,
                title: 'Personal Information',
                onTap: _openEditProfile,
              ),
              if (_authService.canChangePassword())
                SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: _showChangePasswordDialog,
                ),
              SettingsTile(
                icon: Icons.home_work_outlined,
                title: 'Manage Homes',
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => HomesScreen(onHomeChanged: () => _loadStatistics())));
                  _loadStatistics();
                },
              ),
              SettingsTile(
                icon: Icons.share_outlined,
                title: 'Share Devices',
                onTap: () async {
                  final homes = await supabase.from('homes').select('id').limit(1);
                  if (homes.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please create a home first'), backgroundColor: HBotColors.warning),
                      );
                    }
                    return;
                  }
                  if (mounted) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => MultiDeviceShareScreen(homeId: homes.first['id'])));
                  }
                },
              ),
              SettingsTile(
                icon: Icons.people_outline,
                title: 'Shared with Me',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SharedDevicesScreen())),
              ),
              SettingsTile(
                icon: Icons.feedback_outlined,
                title: 'Send Feedback',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FeedbackScreen())),
              ),
              SettingsTile(
                icon: Icons.account_circle_outlined,
                title: 'HBOT Account',
                onTap: _openHBOTAccountScreen,
              ),
              SettingsTile(
                icon: Icons.logout,
                title: 'Sign Out',
                titleColor: HBotColors.error,
                iconColor: HBotColors.error,
                showChevron: false,
                onTap: _showSignOutDialog,
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: HBotSpacing.space7),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(
          top: HBotSpacing.space6,
          bottom: HBotSpacing.space2,
        ),
        child: Column(
          children: [
            // Avatar — 80px circle
            GestureDetector(
              onTap: _showAvatarPicker,
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: HBotColors.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: _avatarPath == null
                        ? const Center(child: Text('😀', style: TextStyle(fontSize: 40)))
                        : ClipOval(
                            child: _avatarService.isCustomAvatar(_avatarPath)
                                ? Image.file(File(_avatarPath!), fit: BoxFit.cover, width: 80, height: 80)
                                : Image.asset(_avatarPath!, fit: BoxFit.cover, width: 80, height: 80),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: HBotColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.edit, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HBotSpacing.space3),
            Text(
              _userName ?? 'Loading...',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: HBotColors.textPrimaryLight),
            ),
            const SizedBox(height: HBotSpacing.space1),
            Text(
              _userEmail ?? '',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400, color: HBotColors.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }

  // Legacy section builders removed — now using SettingsGroup pattern above

  void _openHBOTAccountScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HBOTAccountScreen(
          userEmail: _userEmail,
          userName: _userName,
          userPhone: _userPhone,
          onAccountDeleted: () {
            // Navigate to sign-in screen after account deletion
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const SignInScreen()),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: HBotColors.cardLight,
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrentPassword,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrentPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureCurrentPassword = !obscureCurrentPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            HBotRadius.small,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            HBotRadius.small,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            HBotRadius.small,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space2),
                    const Text(
                      'Password must be at least 6 characters',
                      style: TextStyle(
                        fontSize: 12,
                        color: HBotColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    await _handlePasswordChange(
                      dialogContext,
                      currentPasswordController.text,
                      newPasswordController.text,
                      confirmPasswordController.text,
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: HBotColors.primary,
                  ),
                  child: const Text('Change Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handlePasswordChange(
    BuildContext dialogContext,
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    // Validate inputs
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match'),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    try {
      // Close dialog first
      Navigator.of(dialogContext).pop();

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Changing password...'),
            ],
          ),
          backgroundColor: HBotColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );

      // Verify current password by attempting to sign in
      final email = _authService.currentUser?.email;
      if (email == null) {
        throw Exception('User email not found');
      }

      try {
        await _authService.signInWithEmailAndPassword(email, currentPassword);
      } catch (e) {
        throw Exception('Current password is incorrect');
      }

      // Change password
      await _authService.changePassword(newPassword);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change password: $e'),
            backgroundColor: HBotColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: HBotColors.cardLight,
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog first
                await _handleSignOut();
              },
              style: TextButton.styleFrom(foregroundColor: HBotColors.error),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSignOut() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Signing out...'),
              ],
            ),
            backgroundColor: HBotColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Perform sign out
      await AuthService().signOut();

      // Navigate to sign-in screen and clear navigation stack
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignInScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Handle sign out error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: HBotColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
