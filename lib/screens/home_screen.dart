import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/network_connectivity_service.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/responsive_shell.dart';
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
      setState(() => _isOnline = hasInternet);
    }
  }

  void _updateHomeName(String? name) {
    if (mounted && name != _currentHomeName) {
      setState(() => _currentHomeName = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = HBotLayout.isTablet(context);

    return Scaffold(
      backgroundColor: HBotColors.backgroundLight,
      body: isTablet
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: HBotLayout.contentMaxWidth),
                child: Column(
                  children: [
                    ConnectivityBanner(isOnline: _isOnline),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                ConnectivityBanner(isOnline: _isOnline),
                Expanded(child: _buildBody()),
              ],
            ),
      bottomNavigationBar: isTablet
          ? Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: HBotLayout.contentMaxWidth),
                child: _buildBottomNavigation(),
              ),
            )
          : _buildBottomNavigation(),
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
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
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
