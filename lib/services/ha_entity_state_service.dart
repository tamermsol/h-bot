import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/ha_entity.dart';
import 'ha_websocket_service.dart';

/// Manages real-time HA entity states in memory.
/// Acts as a local state cache fed by the WebSocket service.
class HaEntityStateService extends ChangeNotifier {
  final HaWebSocketService _ws;
  StreamSubscription<HaEntityState>? _stateSub;
  StreamSubscription<HaConnectionState>? _connSub;

  /// Current states keyed by entity_id
  final Map<String, HaEntityState> _states = {};

  /// Connection state
  HaConnectionState _connectionState = HaConnectionState.disconnected;
  HaConnectionState get connectionState => _connectionState;

  HaEntityStateService(this._ws) {
    _connSub = _ws.connectionState.listen((state) {
      _connectionState = state;
      notifyListeners();

      if (state == HaConnectionState.connected) {
        _subscribeAndFetchStates();
      }
    });
  }

  /// Get the current state for an entity
  HaEntityState? getState(String entityId) => _states[entityId];

  /// Get all states for a specific domain
  Map<String, HaEntityState> getStatesForDomain(String domain) {
    return Map.fromEntries(
      _states.entries.where((e) => e.key.startsWith('$domain.')),
    );
  }

  /// Get a stream of state changes for a specific entity
  Stream<HaEntityState> watchEntity(String entityId) {
    return _ws.stateChanges.where((s) => s.entityId == entityId);
  }

  /// Manually refresh all states
  Future<void> refreshStates() async {
    await _fetchAllStates();
  }

  Future<void> _subscribeAndFetchStates() async {
    try {
      // Subscribe to real-time state changes
      await _ws.subscribeStateChanges();

      // Listen to incoming state changes
      _stateSub?.cancel();
      _stateSub = _ws.stateChanges.listen((state) {
        _states[state.entityId] = state;
        notifyListeners();
      });

      // Fetch initial states
      await _fetchAllStates();
    } catch (e) {
      debugPrint('[HA State] Failed to subscribe: $e');
    }
  }

  Future<void> _fetchAllStates() async {
    try {
      final states = await _ws.getStates();
      for (final state in states) {
        _states[state.entityId] = state;
      }
      notifyListeners();
      debugPrint('[HA State] Loaded ${states.length} entity states');
    } catch (e) {
      debugPrint('[HA State] Failed to fetch states: $e');
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}
