# Integration Example - Wiring UI to SmartHomeService

This document shows how to integrate the existing UI screens with the new Supabase backend.

## Example: Updating Home Screen to Use Real Data

Here's how to modify the existing home screen to use real data from Supabase:

```dart
// lib/screens/home_screen.dart - Updated version
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/device_card.dart';
import '../services/smart_home_service.dart';
import '../services/auth_service.dart';
import '../models/home.dart';
import '../models/device_state.dart';
import 'devices_screen.dart';
import 'profile_screen.dart';
import 'scenes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _smartHomeService = SmartHomeService();
  final _authService = AuthService();
  
  List<Home> _homes = [];
  Home? _currentHome;
  List<DeviceWithState> _devices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load user's homes
      final homes = await _smartHomeService.getMyHomes();
      
      if (homes.isNotEmpty) {
        final currentHome = homes.first; // Use first home or let user select
        final devices = await _smartHomeService.getDevicesWithState(currentHome.id);
        
        setState(() {
          _homes = homes;
          _currentHome = currentHome;
          _devices = devices;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _currentHome?.name ?? 'My Home',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Handle notifications
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'logout') {
                try {
                  await _authService.signOut();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error signing out: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else if (value == 'dev_menu') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DevMenu(),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'dev_menu',
                child: Row(
                  children: [
                    Icon(Icons.developer_mode),
                    SizedBox(width: 8),
                    Text('Dev Menu'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading data',
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_outlined,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No devices found',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add some devices to get started',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate to add device screen
              },
              child: const Text('Add Device'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Actions
            _buildQuickActions(),
            
            const SizedBox(height: AppTheme.paddingLarge),
            
            // Devices
            _buildDevicesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                'All Lights Off',
                Icons.lightbulb_outline,
                () async {
                  // Implement turn off all lights
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All lights turned off')),
                  );
                },
              ),
            ),
            const SizedBox(width: AppTheme.paddingMedium),
            Expanded(
              child: _buildQuickActionCard(
                'Good Night',
                Icons.bedtime_outlined,
                () async {
                  // Run good night scene
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Good night scene activated')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Devices',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DevicesScreen(),
                  ),
                );
              },
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppTheme.paddingMedium,
            mainAxisSpacing: AppTheme.paddingMedium,
            childAspectRatio: 1.2,
          ),
          itemCount: _devices.length,
          itemBuilder: (context, index) {
            final device = _devices[index];
            return StreamBuilder<DeviceState>(
              stream: _smartHomeService.watchDeviceState(device.id),
              initialData: device.stateJson != null
                  ? DeviceState(
                      deviceId: device.id,
                      reportedAt: device.reportedAt ?? DateTime.now(),
                      online: device.online ?? false,
                      stateJson: device.stateJson ?? {},
                    )
                  : null,
              builder: (context, snapshot) {
                final state = snapshot.data;
                return DeviceCard(
                  name: device.name,
                  type: device.deviceType,
                  isOnline: state?.online ?? false,
                  value: _getDeviceValue(state),
                  onTap: () {
                    // Handle device tap
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _getDeviceValue(DeviceState? state) {
    if (state == null) return 'Unknown';
    
    final stateJson = state.stateJson;
    if (stateJson.containsKey('power')) {
      return stateJson['power'] ? 'On' : 'Off';
    }
    if (stateJson.containsKey('brightness')) {
      return '${stateJson['brightness']}%';
    }
    if (stateJson.containsKey('temperature')) {
      return '${stateJson['temperature']}°C';
    }
    
    return 'Unknown';
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      backgroundColor: AppTheme.cardColor,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: AppTheme.textSecondary,
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.devices_outlined),
          activeIcon: Icon(Icons.devices),
          label: 'Devices',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.scene_outlined),
          activeIcon: Icon(Icons.scene),
          label: 'Scenes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 1:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const DevicesScreen()),
            );
            break;
          case 2:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ScenesScreen()),
            );
            break;
          case 3:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
            break;
        }
      },
    );
  }

  @override
  void dispose() {
    _smartHomeService.dispose();
    super.dispose();
  }
}
```

## Key Integration Points

1. **Data Loading**: Replace mock data with `SmartHomeService` calls
2. **Realtime Updates**: Use `StreamBuilder` with `watchDeviceState()`
3. **Error Handling**: Show loading states and error messages
4. **Authentication**: Integrate sign-out functionality
5. **Navigation**: Add developer menu for testing

## Next Steps

1. Update other screens (DevicesScreen, ScenesScreen, etc.) similarly
2. Add device control functionality
3. Implement scene execution
4. Add proper error handling and retry logic
5. Test with real Supabase data
