import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
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
import 'rooms_screen.dart';
import 'wifi_profile_screen.dart';
import 'appearance_settings_screen.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildStatsRow()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSettingsSection('Home', _buildHomeGroup())),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildSettingsSection('App', _buildAppGroup())),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildSettingsSection('Account', _buildAccountGroup())),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profile',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Avatar
              GestureDetector(
                onTap: _showAvatarPicker,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
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
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE8ECF1),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Color(0xFF0883FD),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Name
              Text(
                _userName ?? 'Loading...',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              // Email
              Text(
                _userEmail ?? 'Loading...',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              _isLoadingStats ? '...' : '$_totalDevices',
              'Devices',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              _isLoadingStats ? '...' : '$_totalRooms',
              'Rooms',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              _isLoadingStats ? '...' : '$_totalScenes',
              'Scenes',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String count, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF1)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0883FD),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color(0xFF5A6577),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> tiles) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: Color(0xFF5A6577),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8ECF1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: tiles),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHomeGroup() {
    return [
      SettingsTile(
        icon: Icons.room_outlined,
        title: 'Rooms',
        subtitle: '',
        onTap: () async {
          // Navigate to homes screen to pick a home, then rooms
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomesScreen(
                onHomeChanged: () {
                  _loadStatistics();
                },
              ),
            ),
          );
          _loadStatistics();
        },
      ),
      SettingsTile(
        icon: Icons.wifi_outlined,
        title: 'WiFi Profiles',
        subtitle: '',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WiFiProfileScreen(),
            ),
          );
        },
      ),
      SettingsTile(
        icon: Icons.share_outlined,
        title: 'Device Sharing',
        subtitle: '',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SharedDevicesScreen(),
            ),
          );
        },
        showDivider: false,
      ),
    ];
  }

  List<Widget> _buildAppGroup() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final currentTheme = themeService.themeMode == ThemeMode.dark ? 'Dark' : 'Light';

    return [
      SettingsTile(
        icon: Icons.notifications_outlined,
        title: 'Notifications',
        subtitle: '',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsSettingsScreen(),
            ),
          );
        },
      ),
      SettingsTile(
        icon: Icons.palette_outlined,
        title: 'Appearance',
        subtitle: currentTheme,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AppearanceSettingsScreen(),
            ),
          );
        },
      ),
      SettingsTile(
        icon: Icons.help_outline,
        title: 'Help',
        subtitle: '',
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
        title: 'Feedback',
        subtitle: '',
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
        icon: Icons.info_outline,
        title: 'About',
        subtitle: '',
        onTap: _showAboutDialog,
        showDivider: false,
      ),
    ];
  }

  List<Widget> _buildAccountGroup() {
    return [
      SettingsTile(
        icon: Icons.account_circle_outlined,
        title: 'H-Bot Account',
        subtitle: '',
        onTap: _openHBOTAccountScreen,
      ),
      SettingsTile(
        icon: Icons.logout,
        title: 'Sign Out',
        subtitle: '',
        titleColor: HBotColors.error,
        trailing: const SizedBox.shrink(),
        onTap: _showSignOutDialog,
        showDivider: false,
      ),
    ];
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'About H-Bot',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0A1628),
          ),
        ),
        content: const Text(
          'H-Bot Smart Home\nVersion 1.0.0',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF5A6577),
          ),
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

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: HBotColors.cardLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Sign out?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A1628),
            ),
          ),
          content: const Text(
            'You\'ll need to sign back in to access your smart home.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF5A6577),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: HBotTheme.textSecondary(context),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog first
                await _handleSignOut();
              },
              style: TextButton.styleFrom(foregroundColor: HBotColors.error),
              child: const Text(
                'Sign Out',
                style: TextStyle(fontFamily: 'Inter'),
              ),
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
