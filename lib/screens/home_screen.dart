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
        title: _currentIndex == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/branding/hbot_logo.png',
                    height: 26,
                    errorBuilder: (_, __, ___) => const Text(
                      'H-Bot',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: HBotColors.primary,
                      ),
                    ),
                  ),
                  if (_currentHomeName != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 18,
                      color: HBotColors.borderLight,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _currentHomeName!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: HBotColors.textSecondaryLight,
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              )
            : Text(
                _getAppBarTitle(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: HBotColors.textPrimaryLight,
                  letterSpacing: -0.2,
                ),
              ),
        backgroundColor: HBotColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: ConnectivityBanner(isOnline: _isOnline),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return _currentHomeName ?? 'Smart Home';
      case 1:
        return 'Scenes';
      case 2:
        return 'Profile';
      default:
        return 'Smart Home';
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return HomeDashboardScreen(onHomeNameChanged: _updateHomeName);
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
        color: HBotColors.surfaceLight,
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
