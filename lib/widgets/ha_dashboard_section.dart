import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/ha_entity.dart';
import '../repos/ha_repo.dart';
import '../services/ha_websocket_service.dart';
import '../services/ha_entity_state_service.dart';
import '../screens/ha_entities_screen.dart';
import '../screens/ha_entity_control_screen.dart';
import '../screens/ha_setup_screen.dart';

/// Dashboard section showing HA entities as compact cards.
/// Designed to sit below the native device grid on the main dashboard.
class HaDashboardSection extends StatefulWidget {
  final String? roomId;

  const HaDashboardSection({super.key, this.roomId});

  @override
  State<HaDashboardSection> createState() => _HaDashboardSectionState();
}

class _HaDashboardSectionState extends State<HaDashboardSection> {
  final _repo = HaRepo(Supabase.instance.client);
  HaWebSocketService? _ws;
  HaEntityStateService? _stateService;

  List<HaEntity> _entities = [];
  bool _isLoading = true;
  bool _hasConnection = false;

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  Future<void> _loadEntities() async {
    try {
      final conn = await _repo.getActiveConnection();
      if (conn == null) {
        if (mounted) setState(() { _isLoading = false; _hasConnection = false; });
        return;
      }

      _hasConnection = true;

      // Load entities (optionally filtered by room)
      final entities = await _repo.getEntities(roomId: widget.roomId);

      // Connect WebSocket for real-time
      _ws = HaWebSocketService();
      _stateService = HaEntityStateService(_ws!);
      _stateService!.addListener(_onStateUpdate);
      await _ws!.connect(conn);

      if (mounted) {
        setState(() {
          _entities = entities;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[HA Dashboard] Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onStateUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(HaDashboardSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _loadEntities();
    }
  }

  @override
  void dispose() {
    _stateService?.removeListener(_onStateUpdate);
    _stateService?.dispose();
    _ws?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    if (!_hasConnection) return _buildSetupPrompt(context);
    if (_entities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(Icons.home_outlined, size: 18, color: context.hTextSecondary),
              const SizedBox(width: 6),
              Text(
                'Home Assistant',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.hTextSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HaEntitiesScreen())),
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal scroll of entity cards
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _entities.length,
            itemBuilder: (ctx, i) => _buildEntityCard(_entities[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildSetupPrompt(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.home_outlined),
          title: const Text('Connect Home Assistant'),
          subtitle: const Text('Control 2000+ device types'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HaSetupScreen())),
        ),
      ),
    );
  }

  Widget _buildEntityCard(HaEntity entity) {
    final liveState = _stateService?.getState(entity.entityId);
    final isOn = liveState?.isOn ?? entity.isOn;
    final state = liveState?.state ?? entity.currentState ?? 'unknown';

    final color = isOn ? AppTheme.primaryColor : Colors.grey;

    return GestureDetector(
      onTap: () {
        if (_ws != null && _stateService != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HaEntityControlScreen(
                entity: entity,
                wsService: _ws!,
                stateService: _stateService!,
              ),
            ),
          );
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: context.hSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOn ? color.withOpacity(0.3) : context.hBorder,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(_domainIcon(entity.domainEnum), size: 20, color: color),
                if (entity.domainEnum.isControllable)
                  GestureDetector(
                    onTap: () => _toggle(entity),
                    child: Container(
                      width: 28,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isOn
                            ? AppTheme.primaryColor
                            : Colors.grey.shade400,
                      ),
                      alignment:
                          isOn ? Alignment.centerRight : Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entity.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.hTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatState(entity, liveState, state),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.hTextSecondary,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatState(HaEntity entity, HaEntityState? live, String state) {
    if (entity.domainEnum == HaDomain.sensor ||
        entity.domainEnum == HaDomain.binarySensor) {
      final unit = live?.unitOfMeasurement ?? entity.unitOfMeasurement ?? '';
      return '$state$unit';
    }
    return state;
  }

  IconData _domainIcon(HaDomain domain) {
    switch (domain) {
      case HaDomain.light: return Icons.lightbulb;
      case HaDomain.switchDomain: return Icons.toggle_on;
      case HaDomain.climate: return Icons.thermostat;
      case HaDomain.cover: return Icons.blinds;
      case HaDomain.sensor: return Icons.sensors;
      case HaDomain.binarySensor: return Icons.sensors;
      case HaDomain.fan: return Icons.air;
      case HaDomain.lock: return Icons.lock;
      case HaDomain.mediaPlayer: return Icons.speaker;
      default: return Icons.device_hub;
    }
  }

  Future<void> _toggle(HaEntity entity) async {
    try {
      await _ws?.toggle(entity.entityId);
    } catch (e) {
      debugPrint('[HA Dashboard] Toggle failed: $e');
    }
  }
}
