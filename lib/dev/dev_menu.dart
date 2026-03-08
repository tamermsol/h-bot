import 'package:flutter/material.dart';
import '../core/supabase_client.dart';
import '../services/smart_home_service.dart';
import '../models/device.dart';

class DevMenu extends StatefulWidget {
  const DevMenu({super.key});

  @override
  State<DevMenu> createState() => _DevMenuState();
}

class _DevMenuState extends State<DevMenu> {
  final _service = SmartHomeService();
  String _status = '';
  bool _isLoading = false;

  void _setStatus(String status) {
    setState(() => _status = status);
  }

  void _setLoading(bool loading) {
    setState(() => _isLoading = loading);
  }

  Future<void> _createDemoData() async {
    _setLoading(true);
    try {
      _setStatus('Creating demo home...');
      final home = await _service.createHome('Demo Home');

      _setStatus('Creating demo rooms...');
      final livingRoom = await _service.createRoom(home.id, 'Living Room');
      final bedroom = await _service.createRoom(home.id, 'Bedroom');
      final kitchen = await _service.createRoom(home.id, 'Kitchen');

      _setStatus('Creating demo devices...');
      await _service.createDevice(
        home.id,
        roomId: livingRoom.id,
        name: 'Living Room Light',
        deviceType: DeviceType.relay,
        channels: 1,
        tasmotaTopicBase: 'tasmota/living_light',
        metaJson: {'type': 'light', 'dimmable': false},
      );

      await _service.createDevice(
        home.id,
        roomId: bedroom.id,
        name: 'Bedroom Dimmer',
        deviceType: DeviceType.dimmer,
        channels: 1,
        tasmotaTopicBase: 'tasmota/bedroom_dimmer',
        metaJson: {'type': 'light', 'dimmable': true, 'max_brightness': 100},
      );

      await _service.createDevice(
        home.id,
        roomId: kitchen.id,
        name: 'Kitchen Temperature',
        deviceType: DeviceType.sensor,
        channels: 1,
        metaJson: {'type': 'temperature', 'unit': 'celsius'},
      );

      _setStatus('Creating demo scene...');
      final scene = await _service.createScene(home.id, 'Good Night');
      await _service.createSceneStep(scene.id, 0, {
        'type': 'device_action',
        'device_id': 'living_room_light',
        'action': 'turn_off',
      });

      _setStatus('Demo data created successfully!');
    } catch (e) {
      _setStatus('Error creating demo data: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _showUserInfo() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _setStatus('No user logged in');
      return;
    }

    final session = supabase.auth.currentSession;
    final expiresAt = session?.expiresAt != null
        ? DateTime.fromMillisecondsSinceEpoch(session!.expiresAt! * 1000)
        : null;

    _setStatus('''
User Info:
ID: ${user.id}
Email: ${user.email ?? 'N/A'}
Created: ${user.createdAt}
JWT Expires: ${expiresAt ?? 'N/A'}
''');
  }

  Future<void> _testDeviceState() async {
    _setLoading(true);
    try {
      _setStatus('Loading homes...');
      final homes = await _service.getMyHomes();
      if (homes.isEmpty) {
        _setStatus('No homes found. Create demo data first.');
        return;
      }

      _setStatus('Loading devices...');
      final devices = await _service.getDevicesByHome(homes.first.id);
      if (devices.isEmpty) {
        _setStatus('No devices found. Create demo data first.');
        return;
      }

      final device = devices.first;
      _setStatus('Updating device state for ${device.name}...');

      await _service.updateDeviceState(
        device.id,
        online: true,
        stateJson: {
          'power': true,
          'brightness': 75,
          'temperature': 22.5,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _setStatus('Device state updated! Check realtime updates.');
    } catch (e) {
      _setStatus('Error testing device state: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _listHomes() async {
    _setLoading(true);
    try {
      final homes = await _service.getMyHomes();
      if (homes.isEmpty) {
        _setStatus('No homes found');
      } else {
        final homesList = homes.map((h) => '- ${h.name} (${h.id})').join('\n');
        _setStatus('Homes:\n$homesList');
      }
    } catch (e) {
      _setStatus('Error listing homes: $e');
    } finally {
      _setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Menu'),
        backgroundColor: Colors.grey[900],
      ),
      backgroundColor: Colors.grey[850],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createDemoData,
                      child: const Text('Create Demo Home/Room/Device'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _listHomes,
                      child: const Text('List My Homes'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _showUserInfo,
                      child: const Text('Show User Info & JWT Expiry'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testDeviceState,
                      child: const Text('Test Device State Update'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isLoading) ...[
                            const SizedBox(width: 16),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _status.isEmpty ? 'Ready' : _status,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
