import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/fcm_service.dart';
import '../services/network_connectivity_service.dart';
import '../widgets/connectivity_banner.dart';
import '../l10n/app_strings.dart';
import 'home_dashboard_screen.dart';
import 'rooms_screen.dart';
import 'profile_screen.dart';
import 'scenes_screen.dart';
import '../models/home.dart';
import '../repos/homes_repo.dart';
import '../services/current_home_service.dart';

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
  Home? _currentHome;

  @override
  void initState() {
    super.initState();
    _currentHomeName = widget.homeName;
    _currentIndex = widget.initialIndex;
    _startConnectivityMonitoring();
    // Initialize FCM push notifications after auth (non-blocking)
    _initFcm();
    _loadCurrentHome();
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

  Future<void> _loadCurrentHome() async {
    try {
      final homes = await HomesRepo().listMyHomes();
      if (homes.isEmpty || !mounted) return;
      final savedId = await CurrentHomeService().getCurrentHomeId();
      final match = savedId != null
          ? homes.where((h) => h.id == savedId).firstOrNull
          : null;
      setState(() => _currentHome = match ?? homes.first);
    } catch (e) {
      debugPrint('HomeScreen: failed to load current home: $e');
    }
  }

  void _updateHomeName(String? name) {
    if (mounted && name != _currentHomeName) {
      setState(() => _currentHomeName = name);
    }
    // Refresh home object when dashboard reports a home change
    _loadCurrentHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HBotColors.darkBgTop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HBotColors.darkBgTop, HBotColors.darkBgBottom],
          ),
        ),
        child: Column(
          children: [
            ConnectivityBanner(isOnline: _isOnline),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return HomeDashboardScreen(onHomeNameChanged: _updateHomeName);
      case 1:
        if (_currentHome != null) {
          return RoomsScreen(
            home: _currentHome!,
            onRoomChanged: () => _loadCurrentHome(),
          );
        }
        return const Center(
          child: CircularProgressIndicator(color: HBotColors.primary),
        );
      case 2:
        return const ScenesScreen();
      case 3:
        return SafeArea(child: const ProfileScreen());
      default:
        return HomeDashboardScreen(onHomeNameChanged: _updateHomeName);
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: HBotColors.sheetBackground,
        border: Border(
          top: BorderSide(color: HBotColors.glassBorder, width: 0.5),
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
            unselectedItemColor: HBotColors.textMuted,
            selectedLabelStyle: const TextStyle(fontFamily: 'Readex Pro', fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Readex Pro', fontSize: 11, fontWeight: FontWeight.w400),
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home),
                label: AppStrings.get('nav_home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.meeting_room_outlined),
                activeIcon: const Icon(Icons.meeting_room),
                label: AppStrings.get('nav_rooms'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.auto_awesome_outlined),
                activeIcon: const Icon(Icons.auto_awesome),
                label: AppStrings.get('nav_scenes'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings_outlined),
                activeIcon: const Icon(Icons.settings),
                label: AppStrings.get('nav_settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
