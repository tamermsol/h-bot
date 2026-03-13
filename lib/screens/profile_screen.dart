import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_card.dart';
import '../widgets/settings_tile.dart';
import '../widgets/avatar_picker_dialog.dart';
import '../services/auth_service.dart';
import '../services/smart_home_service.dart';
import '../services/current_home_service.dart';
import '../services/avatar_service.dart';
import '../services/theme_service.dart';
import '../models/profile.dart';
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
    final themeService = Provider.of<ThemeService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appearance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light Mode'),
              subtitle: const Text('Bright and clean interface'),
              value: ThemeMode.light,
              groupValue: themeService.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark Mode'),
              subtitle: const Text('Easy on the eyes'),
              value: ThemeMode.dark,
              groupValue: themeService.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeService.setThemeMode(value);
                  Navigator.pop(context);
                }
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
      padding: const EdgeInsets.symmetric(
        horizontal: HBotSpacing.screenPadding,
        vertical: HBotSpacing.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          _buildProfileHeader(),
          const SizedBox(height: HBotSpacing.space6),

          // Home Information
          _buildHomeInfoSection(),
          const SizedBox(height: HBotSpacing.space6),

          // Settings Section
          _buildSettingsSection(),
          const SizedBox(height: HBotSpacing.space6),

          // Account Section
          _buildAccountSection(),
          const SizedBox(height: HBotSpacing.space6),

          // Support Section
          _buildSupportSection(),

          const SizedBox(height: HBotSpacing.space7),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(HBotSpacing.space6),
      decoration: BoxDecoration(
        color: HBotColors.cardLight,
        borderRadius: HBotRadius.xlRadius,
        border: Border.all(color: HBotColors.borderLight, width: 1),
        boxShadow: HBotShadows.small,
      ),
      child: Row(
        children: [
          // Profile Avatar with edit button
          GestureDetector(
            onTap: _showAvatarPicker,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _avatarPath == null
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.secondaryColor,
                            ],
                          )
                        : null,
                  ),
                  child: _avatarPath == null
                      ? const Icon(Icons.person, size: 40, color: Colors.white)
                      : ClipOval(
                          child: _avatarService.isCustomAvatar(_avatarPath)
                              ? Image.file(
                                  File(_avatarPath!),
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                )
                              : Image.asset(
                                  _avatarPath!,
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.paddingMedium),

          // Profile Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName ?? 'Loading...',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail ?? 'Loading...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (_userPhone != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _userPhone!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Home Information',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        Row(
          children: [
            Expanded(
              child: ProfileCard(
                title: 'Devices',
                value: _isLoadingStats ? '...' : '$_totalDevices',
                icon: Icons.devices_outlined,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: AppTheme.paddingMedium),
            Expanded(
              child: ProfileCard(
                title: 'Rooms',
                value: _isLoadingStats ? '...' : '$_totalRooms',
                icon: Icons.home_outlined,
                color: AppTheme.secondaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        Row(
          children: [
            Expanded(
              child: ProfileCard(
                title: 'Homes',
                value: _isLoadingStats ? '...' : '$_totalHomes',
                icon: Icons.home_work_outlined,
                color: AppTheme.accentColor,
              ),
            ),
            const SizedBox(width: AppTheme.paddingMedium),
            Expanded(
              child: ProfileCard(
                title: 'Scenes',
                value: _isLoadingStats ? '...' : '$_totalScenes',
                icon: Icons.auto_awesome_outlined,
                color: AppTheme.warningColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    final cardColor = AppTheme.getCardColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Column(
            children: [
              SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: 'Choose light or dark theme',
                onTap: _showAppearanceDialog,
              ),
              SettingsTile(
                icon: Icons.home_work_outlined,
                title: 'Manage Homes',
                subtitle: 'Add, edit, and manage your homes',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomesScreen(
                        onHomeChanged: () {
                          // Refresh statistics when home changes
                          _loadStatistics();
                        },
                      ),
                    ),
                  );
                  // Also refresh when returning from the screen
                  _loadStatistics();
                },
              ),
              SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Manage your notification preferences',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsSettingsScreen(),
                    ),
                  );
                },
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    // Check if user can change password (email auth only)
    final canChangePassword = _authService.canChangePassword();
    final cardColor = AppTheme.getCardColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Column(
            children: [
              SettingsTile(
                icon: Icons.person_outline,
                title: 'Personal Information',
                subtitle: 'Update your profile details',
                onTap: _openEditProfile,
              ),
              if (canChangePassword)
                SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  onTap: _showChangePasswordDialog,
                ),
              // Device Sharing Section
              SettingsTile(
                icon: Icons.share_outlined,
                title: 'Share My Devices',
                subtitle: 'Share devices with others',
                onTap: () async {
                  // Get current home ID
                  final homes = await supabase
                      .from('homes')
                      .select('id')
                      .limit(1);
                  if (homes.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please create a home first'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  }
                  final homeId = homes.first['id'] as String;

                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MultiDeviceShareScreen(homeId: homeId),
                      ),
                    );
                  }
                },
              ),
              SettingsTile(
                icon: Icons.people_outline,
                title: 'Shared with Me',
                subtitle: 'View devices shared by others',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SharedDevicesScreen(),
                    ),
                  );
                },
              ),
              // HBOT Account section
              SettingsTile(
                icon: Icons.account_circle_outlined,
                title: 'HBOT Account',
                subtitle: 'Manage your account data',
                onTap: _openHBOTAccountScreen,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    final cardColor = AppTheme.getCardColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Support',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Column(
            children: [
              SettingsTile(
                icon: Icons.help_outline,
                title: 'Help Center',
                subtitle: 'Get help and support',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpCenterScreen(),
                    ),
                  );
                },
              ),
              SettingsTile(
                icon: Icons.feedback_outlined,
                title: 'Send Feedback',
                subtitle: 'Share your thoughts with us',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FeedbackScreen(),
                    ),
                  );
                },
              ),
              SettingsTile(
                icon: Icons.logout,
                title: 'Sign Out',
                subtitle: 'Sign out of your account',
                titleColor: AppTheme.errorColor,
                trailing: const SizedBox.shrink(), // No arrow for action items
                onTap: () {
                  _showSignOutDialog();
                },
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

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
              backgroundColor: AppTheme.getCardColor(context),
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
                            AppTheme.radiusSmall,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.paddingMedium),
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
                            AppTheme.radiusSmall,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.paddingMedium),
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
                            AppTheme.radiusSmall,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.paddingSmall),
                    const Text(
                      'Password must be at least 6 characters',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
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
                    foregroundColor: AppTheme.primaryColor,
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
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match'),
          backgroundColor: AppTheme.errorColor,
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
          backgroundColor: AppTheme.primaryColor,
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
            backgroundColor: AppTheme.errorColor,
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
          backgroundColor: AppTheme.getCardColor(context),
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
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
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
            backgroundColor: AppTheme.primaryColor,
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
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
