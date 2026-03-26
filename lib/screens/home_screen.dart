import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/fcm_service.dart';
import '../services/network_connectivity_service.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/responsive_shell.dart';
import '../l10n/app_strings.dart';
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
  int _consecutiveOfflineChecks = 0;

  @override
  void initState() {
    super.initState();
    _currentHomeName = widget.homeName;
    _currentIndex = widget.initialIndex;
    _startConnectivityMonitoring();
    // Initialize FCM push notifications after auth (non-blocking)
    _initFcm();
  }

  Future<void> _initFcm() async {
    try {
      await FcmService().initialize();
    } catch (e) {
      debugPrint('FCM init failed (non-fatal): $e');
    }
  }

  @override
  void dispose() {
    _connectivityCheckTimer?.cancel();
    super.dispose();
  }

  void _startConnectivityMonitoring() {
    // Delay initial check to avoid flash of "no internet" on app launch
    // while Android's network stack initializes
    // Longer initial delay to avoid flash of "no internet" on app launch
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) _checkConnectivity();
    });
    _connectivityCheckTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkConnectivity(),
    );
  }

  Future<void> _checkConnectivity() async {
    final hasInternet =
        await NetworkConnectivityService.hasInternetConnectivity();
    if (hasInternet) {
      _consecutiveOfflineChecks = 0;
      if (mounted && !_isOnline) setState(() => _isOnline = true);
    } else {
      _consecutiveOfflineChecks++;
      // Only show offline banner after 3 consecutive failures
      if (_consecutiveOfflineChecks >= 3 && mounted && _isOnline) {
        setState(() => _isOnline = false);
      }
    }
  }

  void _updateHomeName(String? name) {
    if (mounted && name != _currentHomeName) {
      setState(() => _currentHomeName = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hBackground,
      body: Column(
        children: [
          ConnectivityBanner(isOnline: _isOnline),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return HomeDashboardScreen(onHomeNameChanged: _updateHomeName);
      case 1:
        return const ScenesScreen();
      case 2:
        return SafeArea(child: const ProfileScreen());
      default:
        return HomeDashboardScreen(onHomeNameChanged: _updateHomeName);
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: context.hSurface,
        border: Border(
          top: BorderSide(color: context.hBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home),
                label: AppStrings.get('nav_home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.auto_awesome_outlined),
                activeIcon: const Icon(Icons.auto_awesome),
                label: AppStrings.get('nav_scenes'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: const Icon(Icons.person),
                label: AppStrings.get('nav_profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
