import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'panels_screen.dart';
import 'ha_setup_screen.dart';
import 'ha_entities_screen.dart';
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

  void _openAlexaSkill() {
    // Show instructions for linking with Alexa
    _showAlexaInstructions();
  }

  void _showAlexaInstructions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.hCard,
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
                  color: context.hTextSecondary.withOpacity(0.3),
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.hTextPrimary,
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
              color: HBotColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
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
                style: TextStyle(
                  fontSize: 15,
                  color: context.hTextPrimary,
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
        backgroundColor: AppTheme.getCardColor(context),
        title: Text(AppStrings.get('profile_appearance')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: Text(AppStrings.get('profile_light')),
              value: ThemeMode.light,
              groupValue: themeService.themeMode,
              onChanged: (v) {
                themeService.setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text(AppStrings.get('profile_dark')),
              value: ThemeMode.dark,
              groupValue: themeService.themeMode,
              onChanged: (v) {
                themeService.setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text(AppStrings.get('profile_system')),
              value: ThemeMode.system,
              groupValue: themeService.themeMode,
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: HBotSpacing.space4),

          // Profile Header — centered avatar + name + email
          _buildProfileHeader(),

          // Home section
          SettingsGroup(
            label: AppStrings.get('profile_smart_home'),
            children: [
              SettingsTile(
                icon: Icons.home_work_outlined,
                title: AppStrings.get('manage_homes_subtitle'),
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => HomesScreen(onHomeChanged: () => _loadStatistics())));
                  _loadStatistics();
                },
              ),
              SettingsTile(
                icon: Icons.meeting_room_outlined,
                title: AppStrings.get('profile_rooms'),
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
                icon: Icons.wifi_outlined,
                title: AppStrings.get('profile_wifi_profiles'),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WiFiProfileScreen())),
              ),
              SettingsTile(
                icon: Icons.tv,
                title: 'Wall Panels',
                subtitle: 'Manage paired H-Bot panels',
                onTap: () async {
                  final homeId = await CurrentHomeService().getCurrentHomeId();
                  if (mounted) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => PanelsScreen(homeId: homeId)));
                  }
                },
                showDivider: false,
              ),
            ],
          ),

          // Integrations section
          SettingsGroup(
            label: AppStrings.get('profile_integrations'),
            children: [
              SettingsTile(
                icon: Icons.home_outlined,
                title: 'Home Assistant',
                subtitle: 'Control devices from any vendor',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HaEntitiesScreen())),
              ),
              SettingsTile(
                icon: Icons.record_voice_over_outlined,
                title: AppStrings.get('alexa_integration'),
                subtitle: AppStrings.get('alexa_subtitle'),
                onTap: _openAlexaSkill,
                showDivider: false,
              ),
            ],
          ),

          // App section
          SettingsGroup(
            label: AppStrings.get('profile_settings'),
            children: [
              SettingsTile(
                icon: Icons.notifications_outlined,
                title: AppStrings.get('notifications'),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen())),
              ),
              Consumer<ThemeService>(
                builder: (context, themeService, _) => SettingsTile(
                  icon: Icons.palette_outlined,
                  title: AppStrings.get('theme'),
                  value: themeService.isDarkMode
                      ? AppStrings.get('theme_subtitle_dark')
                      : AppStrings.get('theme_subtitle_light'),
                  onTap: _showAppearanceDialog,
                ),
              ),
              Consumer<LocaleService>(
                builder: (context, localeService, _) => SettingsTile(
                  icon: Icons.language_outlined,
                  title: AppStrings.get('language'),
                  value: localeService.isArabic
                      ? AppStrings.get('language_subtitle_ar')
                      : AppStrings.get('language_subtitle_en'),
                  onTap: () => _showLanguagePicker(localeService),
                ),
              ),
              SettingsTile(
                icon: Icons.info_outline,
                title: AppStrings.get('profile_about'),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
                showDivider: false,
              ),
            ],
          ),

          // Account section
          SettingsGroup(
            label: AppStrings.get('profile_account'),
            children: [
              SettingsTile(
                icon: Icons.person_outline,
                title: AppStrings.get('profile_personal_information'),
                onTap: _openEditProfile,
              ),
              if (_authService.canChangePassword())
                SettingsTile(
                  icon: Icons.lock_outline,
                  title: AppStrings.get('change_password'),
                  onTap: _showChangePasswordDialog,
                ),
              SettingsTile(
                icon: Icons.share_outlined,
                title: AppStrings.get('profile_share_devices'),
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
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SharedDevicesScreen())),
              ),
              SettingsTile(
                icon: Icons.feedback_outlined,
                title: AppStrings.get('profile_send_feedback'),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FeedbackScreen())),
              ),
              SettingsTile(
                icon: Icons.account_circle_outlined,
                title: AppStrings.get('hbot_account'),
                onTap: _openHBOTAccountScreen,
              ),
              SettingsTile(
                icon: Icons.logout,
                title: AppStrings.get('sign_out'),
                titleColor: HBotColors.error,
                iconColor: HBotColors.error,
                showChevron: false,
                showDivider: false,
                onTap: _showSignOutDialog,
              ),
            ],
          ),

          const SizedBox(height: HBotSpacing.space7),
          Center(
            child: Text(
              'v1.0.0 (143)',
              style: TextStyle(
                fontSize: 11,
                color: context.hTextTertiary,
                fontFamily: 'DM Sans',
              ),
            ),
          ),
          const SizedBox(height: HBotSpacing.space5),
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
                        ? const Center(child: Icon(Icons.person, size: 44, color: HBotColors.primary))
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
              _userName ?? AppStrings.get('profile_loading'),
              style: TextStyle(fontFamily: 'DM Sans', fontSize: 18, fontWeight: FontWeight.w600, color: context.hTextPrimary),
            ),
            const SizedBox(height: HBotSpacing.space1),
            Text(
              _userEmail ?? '',
              style: TextStyle(fontFamily: 'DM Sans', fontSize: 14, fontWeight: FontWeight.w400, color: context.hTextSecondary),
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
                    style: TextStyle(fontSize: 14, color: context.hTextSecondary),
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
                    style: TextStyle(fontSize: 14, color: context.hTextSecondary),
                  ),
                  const SizedBox(height: HBotSpacing.space4),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 8),
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
                    style: TextStyle(fontSize: 14, color: context.hTextSecondary),
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
                    style: TextStyle(fontSize: 12, color: context.hTextSecondary),
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
              backgroundColor: context.hCard,
              title: Text(
                step == 0 ? AppStrings.get('change_password') : step == 1 ? AppStrings.get('profile_verify_email') : AppStrings.get('profile_new_password'),
                style: const TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
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
      backgroundColor: context.hCard,
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
                  color: context.hTextSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              AppStrings.get('select_language'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.hTextPrimary,
                fontFamily: 'DM Sans',
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
          color: isSelected ? HBotColors.primarySurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? HBotColors.primary : context.hBorder,
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
                  color: isSelected ? HBotColors.primary : context.hTextPrimary,
                  fontFamily: 'DM Sans',
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
          backgroundColor: context.hCard,
          title: Text(AppStrings.get('sign_out')),
          content: Text(AppStrings.get('sign_out_confirm')),
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
