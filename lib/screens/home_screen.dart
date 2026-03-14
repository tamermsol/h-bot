import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/network_connectivity_service.dart';
import '../widgets/connectivity_banner.dart';
import 'home_dashboard_screen.dart';
import 'profile_screen.dart';
import 'scenes_screen.dart';
class HomeScreen extends StatefulWidget {
  final String? homeName;
  final int initialIndex;

  const HomeScreen({super.key, this.homeName, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _currentHomeName;
  late int _currentIndex;
  bool _isOnline = true;
  Timer? _connectivityCheckTimer;

  @override
  void initState() {
    super.initState();
    _currentHomeName = widget.homeName;
    _currentIndex = widget.initialIndex;
    _startConnectivityMonitoring();
  }

  @override
  void dispose() {
    _connectivityCheckTimer?.cancel();
    super.dispose();
  }

  void _startConnectivityMonitoring() {
    _checkConnectivity();
    _connectivityCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );
  }

  Future<void> _checkConnectivity() async {
    final hasInternet =
        await NetworkConnectivityService.hasInternetConnectivity();
    if (mounted && hasInternet != _isOnline) {
      setState(() {
        _isOnline = hasInternet;
      });
    }
  }

  void _updateHomeName(String? name) {
    if (mounted && name != _currentHomeName) {
      setState(() {
        _currentHomeName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HBotColors.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/branding/hbot_app_icon.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: HBotColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.smart_toy, color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _currentIndex == 0 ? 'H-Bot' : _getAppBarTitle(),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: HBotColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        backgroundColor: HBotColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: _buildAppBarActions(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: ConnectivityBanner(isOnline: _isOnline),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  List<Widget>? _buildAppBarActions() {
    if (_currentIndex == 0) {
      return [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, size: 22),
          color: HBotColors.iconDefault,
          onPressed: () {
            // Notifications placeholder
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 22),
          color: HBotColors.iconDefault,
          onPressed: () {
            setState(() => _currentIndex = 2);
          },
        ),
        const SizedBox(width: 4),
      ];
    } else if (_currentIndex == 1) {
      return [
        IconButton(
          icon: const Icon(Icons.add, size: 22),
          color: HBotColors.iconDefault,
          onPressed: () {
            // Scene creation is handled by ScenesScreen internally
          },
        ),
        const SizedBox(width: 4),
      ];
    }
    return null;
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Home';
      case 1:
        return 'Scenes';
      case 2:
        return 'Profile';
      default:
        return 'Home';
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return SafeArea(child: HomeDashboardScreen(onHomeNameChanged: _updateHomeName));
      case 1:
        return SafeArea(child: const ScenesScreen());
      case 2:
        return SafeArea(child: const ProfileScreen());
      default:
        return HomeDashboardScreen(onHomeNameChanged: _updateHomeName);
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        color: HBotColors.cardLight,
        border: Border(
          top: BorderSide(color: HBotColors.borderLight, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: HBotColors.primary,
            unselectedItemColor: HBotColors.neutral400,
            selectedLabelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
            selectedFontSize: 12,
            unselectedFontSize: 12,
            iconSize: 24,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome_outlined),
                activeIcon: Icon(Icons.auto_awesome),
                label: 'Scenes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
