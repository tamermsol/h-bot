import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/smart_home_service.dart';
import '../services/current_home_service.dart';
import '../services/avatar_service.dart';
import '../services/theme_service.dart';
import '../models/profile.dart';
import '../utils/error_handler.dart';
import '../widgets/avatar_picker_dialog.dart';
import 'sign_in_screen.dart';
import 'profile_edit_screen.dart';
import 'homes_screen.dart';
import 'help_center_screen.dart';
import 'notifications_settings_screen.dart';
import 'feedback_screen.dart';
import 'hbot_account_screen.dart';
import 'shared_devices_screen.dart';
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
        if (mounted) {
          setState(() {
            _userEmail = user.email;
            _userName = user.email?.split('@').first ?? 'User';
          });
        }

        try {
          final profile = await _authService.getCurrentProfile().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
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
          ErrorHandler.logError(
            profileError,
            context: 'ProfileScreen._loadUserData',
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _userEmail = null;
            _userName = null;
            _userPhone = null;
          });
        }
      }
    } catch (e) {
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

      final homes = await _smartHomeService.getMyHomes();

      int homeCount = homes.length;
      int deviceCount = 0;
      int roomCount = 0;
      int sceneCount = 0;

      for (final home in homes) {
        try {
          final devices = await _smartHomeService.getDevicesByHome(home.id);
          deviceCount += devices.length;

          final rooms = await _smartHomeService.getRooms(home.id);
          roomCount += rooms.length;

          final scenes = await _smartHomeService.getScenes(home.id);
          sceneCount += scenes.length;
        } catch (e) {
          ErrorHandler.logError(
            e,
            context: 'ProfileScreen._loadStatistics.home',
          );
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

    if (result != null) {
      _loadUserData();
      _loadStatistics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- v0: Gradient header: linear-gradient(180deg, #E0F2FE 0%, #FFFFFF 100%) ---
          _buildHeader(),

          // --- v0: Scrollable body px-4 pb-28 ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // v0: Stats grid 4 columns, gap-2, mb-5, mt-1
                const SizedBox(height: 4),
                _buildStatsGrid(),
                const SizedBox(height: 20),

                // v0: Settings section
                _buildSectionTitle('Settings'),
                const SizedBox(height: 8),
                _buildSectionCard([
                  _buildSettingsRow(
                    icon: Icons.palette_outlined,
                    iconBg: const Color(0xFFFFF7ED),
                    iconColor: const Color(0xFFF97316),
                    label: 'Appearance',
                    subtitle: 'Choose light or dark theme',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AppearanceSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsRow(
                    icon: Icons.apartment,
                    iconBg: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'Manage Homes',
                    showDivider: true,
                    onTap: () async {
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
                  _buildSettingsRow(
                    icon: Icons.notifications_outlined,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF3B82F6),
                    label: 'Notifications',
                    showDivider: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ]),

                const SizedBox(height: 16),

                // v0: Account section
                _buildSectionTitle('Account'),
                const SizedBox(height: 8),
                _buildSectionCard([
                  _buildSettingsRow(
                    icon: Icons.person_outline,
                    iconBg: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF10B981),
                    label: 'Personal Information',
                    onTap: _openEditProfile,
                  ),
                  _buildSettingsRow(
                    icon: Icons.lock_outline,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF3B82F6),
                    label: 'Change Password',
                    showDivider: true,
                    onTap: () {
                      // TODO: navigate to change password
                    },
                  ),
                  _buildSettingsRow(
                    icon: Icons.share_outlined,
                    iconBg: const Color(0xFFFFF7ED),
                    iconColor: const Color(0xFFF59E0B),
                    label: 'Share My Devices',
                    showDivider: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SharedDevicesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsRow(
                    icon: Icons.people_outline,
                    iconBg: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'Shared with Me',
                    showDivider: true,
                    onTap: () {
                      // TODO: navigate to shared with me
                    },
                  ),
                  _buildSettingsRow(
                    icon: Icons.smartphone,
                    iconBg: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF22C55E),
                    label: 'HBOT Account',
                    showDivider: true,
                    onTap: _openHBOTAccountScreen,
                  ),
                ]),

                const SizedBox(height: 16),

                // v0: Support section
                _buildSectionTitle('Support'),
                const SizedBox(height: 8),
                _buildSectionCard([
                  _buildSettingsRow(
                    icon: Icons.help_outline,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF3B82F6),
                    label: 'Help Center',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpCenterScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsRow(
                    icon: Icons.chat_bubble_outline,
                    iconBg: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'Send Feedback',
                    showDivider: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FeedbackScreen(),
                        ),
                      );
                    },
                  ),
                ]),

                const SizedBox(height: 16),

                // v0: Sign Out row — red, LogOut icon in #FFF1F2 bg
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showSignOutDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            // v0: 32x32 rounded-xl icon container bg #FFF1F2
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.logout,
                                  size: 15,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Sign Out',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // v0: Version text "H-Bot v2.1.0" 11px #C7C9CF centered
                const Center(
                  child: Text(
                    'H-Bot v2.1.0',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFFC7C9CF),
                    ),
                  ),
                ),

                // Bottom padding to account for bottom nav
                const SizedBox(height: 112),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- v0: Gradient header ---
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0F2FE), Color(0xFFFFFFFF)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: Column(
            children: [
              // v0: Avatar 80x80 circle with gradient bg, edit button
              GestureDetector(
                onTap: _showAvatarPicker,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _avatarPath == null
                          ? const _UserSilhouette()
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
                    // v0: pencil edit button at bottom-right
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
                            color: const Color(0xFFE5E7EB),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.edit,
                            size: 10,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // v0: Name 18px bold
              Text(
                _userName ?? 'Loading...',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 2),

              // v0: Email 13px #6B7280
              Text(
                _userEmail ?? 'Loading...',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),

              // v0: Phone 12px #9CA3AF
              if (_userPhone != null) ...[
                const SizedBox(height: 2),
                Text(
                  _userPhone!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- v0: Stats grid: 4 columns ---
  Widget _buildStatsGrid() {
    final stats = [
      _StatData(
        icon: Icons.memory,
        iconColor: const Color(0xFF3B82F6),
        bg: const Color(0xFFEFF6FF),
        label: 'Devices',
        value: _isLoadingStats ? '...' : '$_totalDevices',
      ),
      _StatData(
        icon: Icons.home_outlined,
        iconColor: const Color(0xFF0EA5E9),
        bg: const Color(0xFFF0F9FF),
        label: 'Rooms',
        value: _isLoadingStats ? '...' : '$_totalRooms',
      ),
      _StatData(
        icon: Icons.apartment,
        iconColor: const Color(0xFF8B5CF6),
        bg: const Color(0xFFF5F3FF),
        label: 'Homes',
        value: _isLoadingStats ? '...' : '$_totalHomes',
      ),
      _StatData(
        icon: Icons.auto_awesome,
        iconColor: const Color(0xFFF59E0B),
        bg: const Color(0xFFFFFBEB),
        label: 'Scenes',
        value: _isLoadingStats ? '...' : '$_totalScenes',
      ),
    ];

    return Row(
      children: stats.map((stat) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  // v0: 32x32 circle icon container
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: stat.bg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(stat.icon, size: 15, color: stat.iconColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // v0: 15px bold value
                  Text(
                    stat.value,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // v0: 10px label
                  Text(
                    stat.label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // v0: Section title: 11px bold uppercase #9CA3AF tracking-wider px-1 mb-2
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // v0: Section card: #F5F7FA bg, rounded-2xl, border #E5E7EB
  Widget _buildSectionCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }

  // v0: Settings row: 32x32 rounded-xl icon, 14px medium label, optional subtitle, ChevronRight
  Widget _buildSettingsRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    String? subtitle,
    bool showDivider = false,
    VoidCallback? onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider)
          Container(
            height: 1,
            color: const Color(0xFFEBEDF0),
          ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // v0: 32x32 rounded-xl icon container
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(icon, size: 15, color: iconColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F2937),
                            height: 1.2,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Color(0xFFC7C9CF),
                  ),
                ],
              ),
            ),
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Sign out?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          content: const Text(
            'You\'ll need to sign back in to access your smart home.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleSignOut();
              },
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
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

      await AuthService().signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignInScreen()),
          (route) => false,
        );
      }
    } catch (e) {
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

/// v0: White user silhouette SVG inside gradient avatar
/// Since we can't use inline SVG in Flutter, approximate with Icon
class _UserSilhouette extends StatelessWidget {
  const _UserSilhouette();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.person,
        size: 42,
        color: Colors.white,
      ),
    );
  }
}

class _StatData {
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final String label;
  final String value;

  const _StatData({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.label,
    required this.value,
  });
}
