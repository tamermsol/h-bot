import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/background_container.dart';
import '../models/ha_entity.dart';
import '../models/ha_connection.dart';
import '../repos/ha_repo.dart';
import '../services/ha_websocket_service.dart';
import '../services/ha_entity_state_service.dart';
import 'ha_setup_screen.dart';
import 'ha_entity_control_screen.dart';

/// Screen showing all imported HA entities with real-time state.
/// Grouped by domain, with search and filter capabilities.
class HaEntitiesScreen extends StatefulWidget {
  const HaEntitiesScreen({super.key});

  @override
  State<HaEntitiesScreen> createState() => _HaEntitiesScreenState();
}

class _HaEntitiesScreenState extends State<HaEntitiesScreen> {
  final _repo = HaRepo(Supabase.instance.client);
  final _ws = HaWebSocketService();
  late final HaEntityStateService _stateService;
  final _searchController = TextEditingController();

  List<HaEntity> _entities = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _error;
  String _selectedDomain = 'all';
  HaConnection? _connection;

  @override
  void initState() {
    super.initState();
    _stateService = HaEntityStateService(_ws);
    _stateService.addListener(_onStateChange);
    _loadAndConnect();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAndConnect() async {
    setState(() => _isLoading = true);

    try {
      _connection = await _repo.getActiveConnection();
      if (_connection == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HaSetupScreen()),
          );
        }
        return;
      }

      // Load saved entities
      _entities = await _repo.getEntities();

      // Connect to HA for real-time state
      await _ws.connect(_connection!);
    } catch (e) {
      _error = 'Failed to load: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    // Auto-sync if no entities yet (first-time setup)
    // Run after the frame renders so user sees the UI first
    if (_entities.isEmpty && _connection != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncEntities();
      });
    }
  }

  /// Sync entities from Home Assistant (discovery)
  Future<void> _syncEntities() async {
    if (_connection == null) return;

    setState(() {
      _isSyncing = true;
      _error = null;
    });

    try {
      // Ensure connected
      if (!_ws.isConnected) {
        await _ws.connect(_connection!);
        // Wait for auth
        await _ws.connectionState
            .firstWhere((s) =>
                s == HaConnectionState.connected ||
                s == HaConnectionState.authFailed)
            .timeout(const Duration(seconds: 10));

        if (!_ws.isConnected) {
          setState(() => _error = 'Could not connect to HA');
          return;
        }
      }

      // Fetch registries
      final entityRegistry = await _ws.getEntityRegistry();
      final deviceRegistry = await _ws.getDeviceRegistry();
      final areaRegistry = await _ws.getAreaRegistry();
      final states = await _ws.getStates();

      // Build lookup maps
      final deviceMap = <String, Map<String, dynamic>>{};
      for (final d in deviceRegistry) {
        deviceMap[d['id'] as String] = d;
      }

      final areaMap = <String, Map<String, dynamic>>{};
      for (final a in areaRegistry) {
        areaMap[a['area_id'] as String] = a;
      }

      final stateMap = <String, Map<String, dynamic>>{};
      for (final s in states) {
        stateMap[s.entityId] = {
          'state': s.state,
          'attributes': s.attributes,
        };
      }

      // Build entity records for upsert
      final entityRecords = <Map<String, dynamic>>[];

      for (final entry in entityRegistry) {
        final entityId = entry['entity_id'] as String? ?? '';
        final domain = entityId.split('.').first;

        // Skip internal/system entities
        if (entry['hidden_by'] != null || entry['disabled_by'] != null) {
          continue;
        }
        if (domain == 'automation' ||
            domain == 'script' ||
            domain == 'update' ||
            domain == 'person' ||
            domain == 'zone' ||
            domain == 'weather' ||
            domain == 'sun' ||
            domain == 'persistent_notification') {
          continue;
        }

        // Resolve area from device or entity
        String? areaId = entry['area_id'] as String?;
        String? areaName;
        final deviceId = entry['device_id'] as String?;

        if (areaId == null && deviceId != null) {
          areaId = deviceMap[deviceId]?['area_id'] as String?;
        }
        if (areaId != null) {
          areaName = areaMap[areaId]?['name'] as String?;
        }

        // Get state
        final state = stateMap[entityId];
        final attrs = state?['attributes'] as Map<String, dynamic>? ?? {};

        entityRecords.add({
          'entity_id': entityId,
          'domain': domain,
          'friendly_name': attrs['friendly_name'] as String? ??
              entry['original_name'] as String? ??
              entityId.split('.').last.replaceAll('_', ' '),
          'ha_device_id': deviceId,
          'ha_area_id': areaId,
          'ha_area_name': areaName,
          'icon': attrs['icon'] as String?,
          'device_class':
              entry['device_class'] as String? ??
              entry['original_device_class'] as String?,
          'supported_features': attrs['supported_features'] ?? 0,
          'state_json': state,
          'last_state_at': DateTime.now().toIso8601String(),
          'is_visible': true,
        });
      }

      // Sync to Supabase
      await _repo.syncEntities(_connection!.id, entityRecords);
      await _repo.updateLastSync(_connection!.id);

      // Auto-map HA areas to H-Bot rooms
      // Uses the user's current home for matching
      try {
        final currentHomeId = await Supabase.instance.client
            .from('homes')
            .select('id')
            .eq('owner_user_id', Supabase.instance.client.auth.currentUser!.id)
            .limit(1)
            .maybeSingle();

        if (currentHomeId != null) {
          final mapped = await _repo.autoMapAreasToRooms(
            _connection!.id,
            currentHomeId['id'] as String,
          );
          if (mapped > 0) {
            debugPrint('[HA Sync] Auto-mapped $mapped entities to rooms');
          }
        }
      } catch (e) {
        debugPrint('[HA Sync] Area-to-room mapping failed (non-fatal): $e');
      }

      // Reload
      _entities = await _repo.getEntities();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Synced ${entityRecords.length} entities from HA')),
        );
      }
    } catch (e) {
      _error = 'Sync failed: $e';
      if (_connection != null) {
        await _repo.updateConnectionError(_connection!.id, '$e');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  List<HaEntity> get _filteredEntities {
    var list = _entities;

    // Domain filter
    if (_selectedDomain != 'all') {
      list = list.where((e) => e.domain == _selectedDomain).toList();
    }

    // Search filter
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where((e) =>
              e.displayName.toLowerCase().contains(query) ||
              e.entityId.toLowerCase().contains(query))
          .toList();
    }

    return list;
  }

  Set<String> get _availableDomains {
    return _entities.map((e) => e.domain).toSet();
  }

  @override
  void dispose() {
    _stateService.removeListener(_onStateChange);
    _stateService.dispose();
    _ws.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Assistant'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync from HA',
            onPressed: _isSyncing ? null : _syncEntities,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HaSetupScreen()),
            ),
          ),
        ],
      ),
      body: BackgroundContainer(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Connection status bar
                  _buildConnectionBar(),

                  // Search
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search entities...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),

                  // Domain filter chips
                  _buildDomainChips(),

                  // Error
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ),

                  // Entity list
                  Expanded(
                    child: _filteredEntities.isEmpty
                        ? _buildEmptyState()
                        : _buildEntityList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildConnectionBar() {
    final state = _stateService.connectionState;
    Color color;
    String label;

    switch (state) {
      case HaConnectionState.connected:
        color = Colors.green;
        label = 'Connected';
        break;
      case HaConnectionState.connecting:
        color = Colors.orange;
        label = 'Connecting...';
        break;
      case HaConnectionState.authFailed:
        color = Colors.red;
        label = 'Auth failed';
        break;
      case HaConnectionState.error:
        color = Colors.red;
        label = 'Error';
        break;
      case HaConnectionState.disconnected:
        color = Colors.grey;
        label = 'Disconnected';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: color.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text('${_entities.length} entities',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDomainChips() {
    final domains = ['all', ..._availableDomains.toList()..sort()];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: domains.length,
        itemBuilder: (ctx, i) {
          final domain = domains[i];
          final selected = domain == _selectedDomain;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: selected,
              label: Text(domain == 'all'
                  ? 'All'
                  : HaDomain.fromString(domain).displayName),
              onSelected: (_) =>
                  setState(() => _selectedDomain = domain),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices_other, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No entities found'),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.sync),
            label: const Text('Sync from Home Assistant'),
            onPressed: _syncEntities,
          ),
        ],
      ),
    );
  }

  Widget _buildEntityList() {
    final entities = _filteredEntities;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: entities.length,
      itemBuilder: (ctx, i) => _buildEntityTile(entities[i]),
    );
  }

  Widget _buildEntityTile(HaEntity entity) {
    // Use real-time state if available, otherwise saved state
    final liveState = _stateService.getState(entity.entityId);
    final state = liveState?.state ?? entity.currentState ?? 'unknown';
    final isOn = liveState?.isOn ?? entity.isOn;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _entityIcon(entity, isOn),
        title: Text(entity.displayName),
        subtitle: Text(
          '${entity.entityId} — $state',
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: entity.domainEnum.isControllable
            ? Switch(
                value: isOn,
                onChanged: (_) => _toggleEntity(entity),
                activeColor: AppTheme.primaryColor,
              )
            : Text(
                _formatSensorValue(entity, liveState),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HaEntityControlScreen(
              entity: entity,
              wsService: _ws,
              stateService: _stateService,
            ),
          ),
        ),
      ),
    );
  }

  Widget _entityIcon(HaEntity entity, bool isOn) {
    IconData icon;
    Color color = isOn ? AppTheme.primaryColor : Colors.grey;

    switch (entity.domainEnum) {
      case HaDomain.light:
        icon = Icons.lightbulb;
        break;
      case HaDomain.switchDomain:
        icon = Icons.toggle_on;
        break;
      case HaDomain.climate:
        icon = Icons.thermostat;
        color = isOn ? Colors.orange : Colors.grey;
        break;
      case HaDomain.cover:
        icon = Icons.blinds;
        break;
      case HaDomain.sensor:
        icon = _sensorIcon(entity.deviceClass);
        color = Colors.blue;
        break;
      case HaDomain.binarySensor:
        icon = Icons.sensors;
        color = isOn ? Colors.orange : Colors.grey;
        break;
      case HaDomain.fan:
        icon = Icons.air;
        break;
      case HaDomain.lock:
        icon = isOn ? Icons.lock_open : Icons.lock;
        break;
      case HaDomain.mediaPlayer:
        icon = Icons.speaker;
        break;
      case HaDomain.camera:
        icon = Icons.videocam;
        break;
      case HaDomain.scene:
        icon = Icons.palette;
        break;
      case HaDomain.button:
        icon = Icons.radio_button_checked;
        break;
      default:
        icon = Icons.device_hub;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.15),
      child: Icon(icon, color: color, size: 20),
    );
  }

  IconData _sensorIcon(String? deviceClass) {
    switch (deviceClass) {
      case 'temperature':
        return Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      case 'power':
      case 'energy':
        return Icons.bolt;
      case 'battery':
        return Icons.battery_std;
      case 'illuminance':
        return Icons.light_mode;
      case 'motion':
        return Icons.directions_walk;
      default:
        return Icons.sensors;
    }
  }

  String _formatSensorValue(HaEntity entity, HaEntityState? liveState) {
    final state = liveState?.state ?? entity.currentState ?? '';
    final unit = liveState?.unitOfMeasurement ?? entity.unitOfMeasurement ?? '';
    if (state == 'unknown' || state == 'unavailable') return state;
    return '$state$unit';
  }

  Future<void> _toggleEntity(HaEntity entity) async {
    try {
      await _ws.toggle(entity.entityId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}
