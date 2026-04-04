import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import '../demo/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system.dart';
import '../widgets/settings_tile.dart';
import '../widgets/avatar_picker_dialog.dart';
import '../services/auth_service.dart';
import '../services/smart_home_service.dart';
import '../services/current_home_service.dart';
import '../services/avatar_service.dart';
import '../models/profile.dart';
import '../utils/error_handler.dart';
import '../core/supabase_client.dart';
import '../services/theme_service.dart';
import '../services/locale_service.dart';
import '../l10n/app_strings.dart';
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
// import 'panels_screen.dart';  // Hidden until production-ready
// import 'ha_entities_screen.dart';  // Hidden until production-ready

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
    // Demo mode: inject demo profile
    if (isDemoMode) {
      if (mounted) {
        setState(() {
          _currentProfile = DemoData.profile;
          _userName = DemoData.profile.fullName ?? 'Alex Johnson';
          _userEmail = DemoData.userEmail;
          _userPhone = DemoData.profile.phoneNumber;
        });
      }
      return;
    }

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

  void _openAlexaSkill() {
    // Show instructions for linking with Alexa
    _showAlexaInstructions();
  }

  void _showAlexaInstructions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HBotColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: HBotColors.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.mic, color: HBotColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings.get('alexa_link_title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStep(context, '1', AppStrings.get('alexa_step_1')),
            _buildStep(context, '2', AppStrings.get('alexa_step_2')),
            _buildStep(context, '3', AppStrings.get('alexa_step_3')),
            _buildStep(context, '4', AppStrings.get('alexa_step_4')),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: HBotColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: HBotColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAppearanceDialog() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HBotColors.sheetBackground,
        title: Text(
          AppStrings.get('profile_appearance'),
          style: const TextStyle(color: Colors.white, fontFamily: 'Readex Pro', fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: Text(AppStrings.get('profile_light'), style: const TextStyle(color: Colors.white)),
              value: ThemeMode.light,
              groupValue: themeService.themeMode,
              activeColor: HBotColors.primary,
              onChanged: (v) {
                themeService.setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text(AppStrings.get('profile_dark'), style: const TextStyle(color: Colors.white)),
              value: ThemeMode.dark,
              groupValue: themeService.themeMode,
              activeColor: HBotColors.primary,
              onChanged: (v) {
                themeService.setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text(AppStrings.get('profile_system'), style: const TextStyle(color: Colors.white)),
              value: ThemeMode.system,
              groupValue: themeService.themeMode,
              activeColor: HBotColors.primary,
              onChanged: (v) {
                themeService.setThemeMode(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [HBotColors.darkBgTop, HBotColors.darkBgBottom],
        ),
      ),
      child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Settings header
          Padding(
            padding: const EdgeInsets.fromLTRB(HBotSpacing.space5, HBotSpacing.space4, HBotSpacing.space5, 0),
            child: const Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: HBotSpacing.space4),

          // Profile Header — centered avatar + name + email
          _buildProfileHeader(),

          // Stats cards
          _buildStatsCards(),

          // PREFERENCES section
          SettingsGroup(
            label: 'Preferences',
            children: [
              Consumer<ThemeService>(
                builder: (context, themeService, _) {
                  return SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark Mode',
                    subtitle: themeService.isDarkMode ? 'On' : 'Off',
                    iconColor: HBotColors.primary,
                    showChevron: false,
                    trailing: HBotToggle(
                      value: themeService.isDarkMode,
                      onChanged: (v) => themeService.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                    ),
                  );
                },
              ),
              SettingsTile(
                icon: Icons.notifications_outlined,
                title: AppStrings.get('notifications'),
                subtitle: 'Push & in-app alerts',
                iconColor: HBotColors.primary,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen())),
              ),
              Consumer<LocaleService>(
                builder: (context, localeService, _) => SettingsTile(
                  icon: Icons.language_outlined,
                  title: AppStrings.get('language'),
                  subtitle: localeService.isArabic
                      ? AppStrings.get('language_subtitle_ar')
                      : AppStrings.get('language_subtitle_en'),
                  iconColor: HBotColors.primary,
                  showDivider: false,
                  onTap: () => _showLanguagePicker(localeService),
                ),
              ),
            ],
          ),

          // SMART HOME section
          SettingsGroup(
            label: 'Smart Home',
            children: [
              SettingsTile(
                icon: Icons.home_work_outlined,
                title: AppStrings.get('manage_homes_subtitle'),
                subtitle: 'Add, edit or remove homes',
                iconColor: const Color(0xFF34D399),
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => HomesScreen(onHomeChanged: () => _loadStatistics())));
                  _loadStatistics();
                },
              ),
              SettingsTile(
                icon: Icons.wifi_outlined,
                title: AppStrings.get('profile_wifi_profiles'),
                subtitle: 'Saved network credentials',
                iconColor: const Color(0xFF34D399),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WiFiProfileScreen())),
              ),
              SettingsTile(
                icon: Icons.meeting_room_outlined,
                title: AppStrings.get('profile_rooms'),
                subtitle: 'Organize your spaces',
                iconColor: const Color(0xFF34D399),
                onTap: () async {
                  final homeId = await CurrentHomeService().getCurrentHomeId();
                  if (homeId == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppStrings.get('select_home_first')), backgroundColor: HBotColors.warning),
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
                        SnackBar(content: Text('${AppStrings.get("error_load_home")}: $e'), backgroundColor: HBotColors.error),
                      );
                    }
                  }
                },
              ),
              SettingsTile(
                icon: Icons.share_outlined,
                title: AppStrings.get('profile_share_devices'),
                subtitle: 'Share access with others',
                iconColor: const Color(0xFF34D399),
                onTap: () async {
                  final homes = await supabase.from('homes').select('id').limit(1);
                  if (homes.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppStrings.get('create_home_first')), backgroundColor: HBotColors.warning),
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
                title: AppStrings.get('profile_shared_with_me'),
                subtitle: 'Devices shared with you',
                iconColor: const Color(0xFF34D399),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SharedDevicesScreen())),
              ),
              SettingsTile(
                icon: Icons.record_voice_over_outlined,
                title: AppStrings.get('alexa_integration'),
                subtitle: AppStrings.get('alexa_subtitle'),
                iconColor: const Color(0xFF34D399),
                showDivider: false,
                onTap: _openAlexaSkill,
              ),
              // Wall Panels — hidden until production-ready
              // SettingsTile(
              //   icon: Icons.tv,
              //   title: 'Wall Panels',
              //   subtitle: 'Manage paired H-Bot panels',
              //   onTap: () async {
              //     final homeId = await CurrentHomeService().getCurrentHomeId();
              //     if (mounted) {
              //       Navigator.push(context,
              //           MaterialPageRoute(builder: (_) => PanelsScreen(homeId: homeId)));
              //     }
              //   },
              //   showDivider: false,
              // ),
            ],
          ),

          // ACCOUNT section
          SettingsGroup(
            label: 'Account',
            children: [
              SettingsTile(
                icon: Icons.person_outline,
                title: AppStrings.get('profile_personal_information'),
                subtitle: 'Name, email, phone',
                iconColor: const Color(0xFFF59E0B),
                onTap: _openEditProfile,
              ),
              if (_authService.canChangePassword())
                SettingsTile(
                  icon: Icons.lock_outline,
                  title: AppStrings.get('change_password'),
                  subtitle: 'Update your password',
                  iconColor: const Color(0xFFF59E0B),
                  onTap: _showChangePasswordDialog,
                ),
              SettingsTile(
                icon: Icons.security_outlined,
                title: 'Security',
                subtitle: 'Account & security settings',
                iconColor: const Color(0xFFF59E0B),
                onTap: _openHBOTAccountScreen,
              ),
              SettingsTile(
                icon: Icons.download_outlined,
                title: 'Data Export',
                subtitle: 'Download your data',
                iconColor: const Color(0xFFF59E0B),
                showDivider: false,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data export coming soon'), backgroundColor: HBotColors.primary),
                  );
                },
              ),
            ],
          ),

          // ABOUT section
          SettingsGroup(
            label: 'About',
            children: [
              SettingsTile(
                icon: Icons.help_outline,
                title: 'Help Center',
                subtitle: 'FAQs and support',
                iconColor: HBotColors.primary,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
              ),
              SettingsTile(
                icon: Icons.feedback_outlined,
                title: AppStrings.get('profile_send_feedback'),
                subtitle: 'Report bugs or suggest features',
                iconColor: HBotColors.primary,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FeedbackScreen())),
              ),
              SettingsTile(
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: 'v1.0.3+1',
                iconColor: HBotColors.primary,
                showChevron: false,
              ),
              SettingsTile(
                icon: Icons.star_outline,
                title: 'Rate App',
                subtitle: 'Love H-Bot? Rate us!',
                iconColor: HBotColors.primary,
                showDivider: false,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('App store rating coming soon'), backgroundColor: HBotColors.primary),
                  );
                },
              ),
            ],
          ),

          // Danger zone — red-tinted glass card
          _buildDangerZone(),

          const SizedBox(height: HBotSpacing.space7),
        ],
      ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HBotSpacing.space5,
        vertical: HBotSpacing.space3,
      ),
      child: Row(
        children: [
          _buildStatCard(Icons.devices_outlined, '$_totalDevices', AppStrings.get('profile_devices')),
          const SizedBox(width: HBotSpacing.space3),
          _buildStatCard(Icons.meeting_room_outlined, '$_totalRooms', AppStrings.get('profile_rooms')),
          const SizedBox(width: HBotSpacing.space3),
          _buildStatCard(Icons.auto_awesome_outlined, '$_totalScenes', AppStrings.get('nav_scenes')),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Expanded(
      child: HBotCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(HBotSpacing.space4),
        child: Column(
          children: [
            _isLoadingStats
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: HBotColors.primary,
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Readex Pro',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: HBotColors.primary,
                    ),
                  ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 11,
                color: HBotColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5, vertical: HBotSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 0,
              bottom: HBotSpacing.space2,
            ),
            child: const Text(
              'DANGER ZONE',
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: HBotColors.error,
              ),
            ),
          ),
          // Danger container — spec: bg rgba(239,68,68,0.06), border rgba(239,68,68,0.15), 20px radius
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0x0FEF4444), // rgba(239,68,68,0.06)
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x26EF4444), width: 1), // rgba(239,68,68,0.15)
            ),
            child: Column(
              children: [
                // Sign out button
                GestureDetector(
                  onTap: _showSignOutDialog,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0x1AEF4444), // rgba(239,68,68,0.1)
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        AppStrings.get('sign_out'),
                        style: const TextStyle(
                          fontFamily: 'Readex Pro',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HBotColors.error,
                        ),
                      ),
                    ),
                  ),
                ),
                // Delete account row
                GestureDetector(
                  onTap: _openHBOTAccountScreen,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        'Delete Account',
                        style: TextStyle(
                          fontFamily: 'Readex Pro',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: HBotColors.error.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: HBotSpacing.space5,
        vertical: HBotSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: HBotColors.glassBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HBotColors.glassBorder, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: HBotColors.glassBlur, sigmaY: HBotColors.glassBlur),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: Center(
              child: Column(
                children: [
                  // Avatar — 72x72 circle with gradient
                  GestureDetector(
                    onTap: _showAvatarPicker,
                    child: Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1070AD), Color(0xFF2FB8EC)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x400883FD), // rgba(8,131,253,0.25)
                                blurRadius: 32,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _avatarPath == null
                              ? const Center(child: Icon(Icons.person, size: 36, color: Colors.white))
                              : ClipOval(
                                  child: _avatarService.isCustomAvatar(_avatarPath)
                                      ? Image.file(File(_avatarPath!), fit: BoxFit.cover, width: 72, height: 72)
                                      : Image.asset(_avatarPath!, fit: BoxFit.cover, width: 72, height: 72),
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
                              border: Border.all(color: HBotColors.darkBgTop, width: 2),
                            ),
                            child: const Icon(Icons.edit, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: HBotSpacing.space3),
                  Text(
                    _userName ?? AppStrings.get('profile_loading'),
                    style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: HBotSpacing.space1),
                  Text(
                    _userEmail ?? '',
                    style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 13, fontWeight: FontWeight.w400, color: HBotColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
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

  /// Change password flow: Step 1 → Enter email, Step 2 → Enter OTP, Step 3 → New password
  void _showChangePasswordDialog() {
    final email = _authService.currentUser?.email ?? '';
    final emailController = TextEditingController(text: email);
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    int step = 0; // 0=email, 1=OTP, 2=new password
    bool isLoading = false;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Widget content;
            List<Widget> actions;

            if (step == 0) {
              // Step 1: Email confirmation
              content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.email_outlined, size: 48, color: HBotColors.primary),
                  const SizedBox(height: HBotSpacing.space4),
                  Text(
                    AppStrings.get('profile_change_password_desc'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: HBotColors.textMuted),
                  ),
                  const SizedBox(height: HBotSpacing.space4),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('profile_email_address'),
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(HBotRadius.small)),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: HBotSpacing.space2),
                    Text(errorMessage!, style: const TextStyle(color: HBotColors.error, fontSize: 13)),
                  ],
                ],
              );
              actions = [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(AppStrings.get('profile_cancel'))),
                TextButton(
                  onPressed: isLoading ? null : () async {
                    if (emailController.text.isEmpty) {
                      setState(() => errorMessage = 'Please enter your email');
                      return;
                    }
                    setState(() { isLoading = true; errorMessage = null; });
                    try {
                      await _authService.resetPassword(emailController.text.trim());
                      setState(() { step = 1; isLoading = false; });
                    } catch (e) {
                      setState(() { isLoading = false; errorMessage = 'Failed to send code: $e'; });
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: HBotColors.primary),
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(AppStrings.get('profile_send_code')),
                ),
              ];
            } else if (step == 1) {
              // Step 2: OTP verification
              content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pin_outlined, size: 48, color: HBotColors.primary),
                  const SizedBox(height: HBotSpacing.space4),
                  Text(
                    'Enter the 6-digit code sent to\n${emailController.text.trim()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: HBotColors.textMuted),
                  ),
                  const SizedBox(height: HBotSpacing.space4),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 8, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppStrings.get('profile_verification_code'),
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(HBotRadius.small)),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: HBotSpacing.space2),
                    Text(errorMessage!, style: const TextStyle(color: HBotColors.error, fontSize: 13)),
                  ],
                  const SizedBox(height: HBotSpacing.space2),
                  TextButton(
                    onPressed: isLoading ? null : () async {
                      setState(() => isLoading = true);
                      try {
                        await _authService.resendOtp(emailController.text.trim());
                        setState(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppStrings.get('profile_code_resent')), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        setState(() { isLoading = false; errorMessage = 'Failed to resend: $e'; });
                      }
                    },
                    child: Text(AppStrings.get('profile_resend_code')),
                  ),
                ],
              );
              actions = [
                TextButton(onPressed: () => setState(() { step = 0; errorMessage = null; }), child: Text(AppStrings.get('profile_back'))),
                TextButton(
                  onPressed: isLoading ? null : () async {
                    if (otpController.text.length != 6) {
                      setState(() => errorMessage = 'Please enter the 6-digit code');
                      return;
                    }
                    setState(() { isLoading = true; errorMessage = null; });
                    try {
                      await _authService.verifyOtp(emailController.text.trim(), otpController.text.trim());
                      setState(() { step = 2; isLoading = false; });
                    } catch (e) {
                      setState(() { isLoading = false; errorMessage = 'Invalid code. Please try again.'; });
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: HBotColors.primary),
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(AppStrings.get('profile_verify')),
                ),
              ];
            } else {
              // Step 3: New password
              content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_reset, size: 48, color: HBotColors.primary),
                  const SizedBox(height: HBotSpacing.space4),
                  Text(
                    'Set your new password',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: HBotColors.textMuted),
                  ),
                  const SizedBox(height: HBotSpacing.space4),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('profile_new_password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(HBotRadius.small)),
                    ),
                  ),
                  const SizedBox(height: HBotSpacing.space4),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('profile_confirm_new_password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(HBotRadius.small)),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: HBotSpacing.space2),
                    Text(errorMessage!, style: const TextStyle(color: HBotColors.error, fontSize: 13)),
                  ],
                  const SizedBox(height: HBotSpacing.space2),
                  Text(
                    AppStrings.get('profile_password_min'),
                    style: const TextStyle(fontSize: 12, color: HBotColors.textMuted),
                  ),
                ],
              );
              actions = [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(AppStrings.get('common_cancel'))),
                TextButton(
                  onPressed: isLoading ? null : () async {
                    final newPw = newPasswordController.text;
                    final confirmPw = confirmPasswordController.text;
                    if (newPw.isEmpty || confirmPw.isEmpty) {
                      setState(() => errorMessage = 'Please fill in all fields');
                      return;
                    }
                    if (newPw.length < 6) {
                      setState(() => errorMessage = AppStrings.get('profile_password_min'));
                      return;
                    }
                    if (newPw != confirmPw) {
                      setState(() => errorMessage = 'Passwords do not match');
                      return;
                    }
                    setState(() { isLoading = true; errorMessage = null; });
                    try {
                      await _authService.changePassword(newPw);
                      Navigator.of(dialogContext).pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppStrings.get('profile_password_changed_successfully')), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      setState(() { isLoading = false; errorMessage = 'Failed to change password: $e'; });
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: HBotColors.primary),
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(AppStrings.get('profile_change_password')),
                ),
              ];
            }

            return AlertDialog(
              backgroundColor: HBotColors.sheetBackground,
              title: Text(
                step == 0 ? AppStrings.get('change_password') : step == 1 ? AppStrings.get('profile_verify_email') : AppStrings.get('profile_new_password'),
                style: const TextStyle(fontFamily: 'Readex Pro', fontWeight: FontWeight.w600, color: Colors.white),
              ),
              content: SingleChildScrollView(child: content),
              actions: actions,
            );
          },
        );
      },
    );
  }

  void _showLanguagePicker(LocaleService localeService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: HBotColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: HBotColors.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              AppStrings.get('select_language'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Readex Pro',
              ),
            ),
            const SizedBox(height: 16),
            _buildLanguageOption(ctx, localeService, 'en', AppStrings.get('lang_english')),
            const SizedBox(height: 8),
            _buildLanguageOption(ctx, localeService, 'ar', AppStrings.get('lang_arabic')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext ctx, LocaleService localeService, String code, String label) {
    final isSelected = localeService.locale == code;
    return InkWell(
      onTap: () {
        localeService.setLocale(code);
        Navigator.of(ctx).pop();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? HBotColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? HBotColors.primary : HBotColors.glassBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? HBotColors.primary : Colors.white,
                  fontFamily: 'Readex Pro',
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: HBotColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: HBotColors.sheetBackground,
          title: Text(AppStrings.get('sign_out'), style: const TextStyle(color: Colors.white, fontFamily: 'Readex Pro', fontWeight: FontWeight.w600)),
          content: Text(AppStrings.get('sign_out_confirm'), style: const TextStyle(color: HBotColors.textMuted)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppStrings.get('cancel')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog first
                await _handleSignOut();
              },
              style: TextButton.styleFrom(foregroundColor: HBotColors.error),
              child: Text(AppStrings.get('sign_out')),
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
            content: Row(
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
                Text(AppStrings.get('profile_signing_out')),
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
            content: Text('${AppStrings.get("error_signing_out")}: $e'),
            backgroundColor: HBotColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
