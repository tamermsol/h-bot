import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/scene_trigger.dart';
import '../models/scene.dart';
import 'smart_home_service.dart';

/// Service that monitors user's location and executes scenes based on geofence triggers
class LocationTriggerMonitor {
  static final LocationTriggerMonitor _instance =
      LocationTriggerMonitor._internal();
  factory LocationTriggerMonitor() => _instance;
  LocationTriggerMonitor._internal();

  final _service = SmartHomeService();
  StreamSubscription<Position>? _positionStream;
  Position? _lastPosition;

  /// Track if user is currently inside each geofence
  /// Key: sceneId, Value: true if inside geofence
  final Map<String, bool> _insideGeofence = {};

  /// Track last execution time for each scene to prevent duplicate executions
  /// Key: sceneId, Value: last execution timestamp
  final Map<String, DateTime> _lastExecution = {};

  /// Minimum time between executions of the same scene (5 minutes)
  static const _minExecutionInterval = Duration(minutes: 5);

  bool _isRunning = false;

  /// Start monitoring location changes
  Future<void> start() async {
    if (_isRunning) {
      debugPrint('LocationTriggerMonitor: Already running');
      return;
    }

    debugPrint('LocationTriggerMonitor: Starting location monitoring...');

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint(
          'LocationTriggerMonitor: Location services are disabled',
        );
        return;
      }

      // Check location permissions (don't request — permissions should only be
      // requested from a UI context, not from a background service)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('LocationTriggerMonitor: Location permissions not granted, skipping');
        return;
      }

      // Start listening to position changes
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 50, // Update every 50 meters
        ),
      ).listen(
        _onPositionChanged,
        onError: (error) {
          debugPrint('LocationTriggerMonitor: Error: $error');
        },
      );

      _isRunning = true;
      debugPrint('LocationTriggerMonitor: Started successfully');
    } catch (e) {
      debugPrint('LocationTriggerMonitor: Failed to start: $e');
    }
  }

  /// Stop monitoring location changes
  void stop() {
    if (!_isRunning) {
      return;
    }

    debugPrint('LocationTriggerMonitor: Stopping location monitoring...');
    _positionStream?.cancel();
    _positionStream = null;
    _isRunning = false;
    _insideGeofence.clear();
    _lastExecution.clear();
    debugPrint('LocationTriggerMonitor: Stopped');
  }

  /// Called when position changes
  Future<void> _onPositionChanged(Position position) async {
    _lastPosition = position;
    debugPrint(
      'LocationTriggerMonitor: Position updated: ${position.latitude}, ${position.longitude}',
    );
    await _checkGeofences(position);
  }

  /// Check all geofences and execute scenes if conditions are met
  Future<void> _checkGeofences(Position currentPosition) async {
    try {
      // Get all enabled scenes with geo triggers
      final scenes = await _getAllEnabledScenes();

      for (final scene in scenes) {
        await _checkSceneGeofence(scene, currentPosition);
      }
    } catch (e) {
      debugPrint('LocationTriggerMonitor: Error checking geofences: $e');
    }
  }

  /// Check a single scene's geofence
  Future<void> _checkSceneGeofence(
    Scene scene,
    Position currentPosition,
  ) async {
    try {
      // Get scene triggers
      final triggers = await _service.getSceneTriggers(scene.id);

      // Find geo trigger
      final geoTrigger = triggers.firstWhere(
        (t) => t.kind == TriggerKind.geo && t.isEnabled,
        orElse: () => throw Exception('No geo trigger found'),
      );

      final config = geoTrigger.configJson;
      final triggerType = config['trigger_type'] as String?; // 'arrive' or 'leave'
      final latitude = (config['latitude'] as num?)?.toDouble();
      final longitude = (config['longitude'] as num?)?.toDouble();
      final radius = (config['radius'] as num?)?.toDouble() ?? 200;

      if (triggerType == null || latitude == null || longitude == null) {
        debugPrint(
          'LocationTriggerMonitor: Invalid geo trigger config for scene ${scene.name}',
        );
        return;
      }

      // Calculate distance from geofence center
      final distance = _calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        latitude,
        longitude,
      );

      final isInside = distance <= radius;
      final wasInside = _insideGeofence[scene.id] ?? false;

      debugPrint(
        'LocationTriggerMonitor: Scene "${scene.name}" - Distance: ${distance.toStringAsFixed(1)}m, '
        'Radius: ${radius.toStringAsFixed(0)}m, Inside: $isInside, Was Inside: $wasInside',
      );

      // Check if we should execute the scene
      bool shouldExecute = false;

      if (triggerType == 'arrive' && isInside && !wasInside) {
        // User just entered the geofence
        shouldExecute = true;
        debugPrint(
          'LocationTriggerMonitor: User ARRIVED at "${scene.name}" location',
        );
      } else if (triggerType == 'leave' && !isInside && wasInside) {
        // User just left the geofence
        shouldExecute = true;
        debugPrint(
          'LocationTriggerMonitor: User LEFT "${scene.name}" location',
        );
      }

      // Update geofence state
      _insideGeofence[scene.id] = isInside;

      // Execute scene if conditions are met
      if (shouldExecute) {
        await _executeScene(scene);
      }
    } catch (e) {
      // Scene doesn't have a geo trigger, skip it
      if (!e.toString().contains('No geo trigger found')) {
        debugPrint(
          'LocationTriggerMonitor: Error checking scene ${scene.name}: $e',
        );
      }
    }
  }

  /// Get all enabled scenes from all user's homes
  Future<List<Scene>> _getAllEnabledScenes() async {
    final allScenes = <Scene>[];

    try {
      // Get all homes
      final homes = await _service.getMyHomes();

      // Get scenes from each home
      for (final home in homes) {
        final scenes = await _service.getScenes(home.id);
        // Only include enabled scenes
        allScenes.addAll(scenes.where((s) => s.isEnabled));
      }
    } catch (e) {
      debugPrint('LocationTriggerMonitor: Error fetching scenes: $e');
    }

    return allScenes;
  }

  /// Execute a scene
  Future<void> _executeScene(Scene scene) async {
    try {
      // Check if we executed this scene recently
      final lastExec = _lastExecution[scene.id];
      if (lastExec != null) {
        final timeSinceLastExec = DateTime.now().difference(lastExec);
        if (timeSinceLastExec < _minExecutionInterval) {
          debugPrint(
            'LocationTriggerMonitor: Skipping scene "${scene.name}" - '
            'executed ${timeSinceLastExec.inMinutes} minutes ago',
          );
          return;
        }
      }

      debugPrint(
        'LocationTriggerMonitor: Executing scene "${scene.name}" (${scene.id})',
      );

      await _service.runScene(scene.id);

      // Update last execution time
      _lastExecution[scene.id] = DateTime.now();

      debugPrint(
        'LocationTriggerMonitor: Successfully executed scene "${scene.name}"',
      );
    } catch (e) {
      debugPrint(
        'LocationTriggerMonitor: Failed to execute scene "${scene.name}": $e',
      );
    }
  }

  /// Calculate distance between two coordinates in meters using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Get current monitoring status
  bool get isRunning => _isRunning;

  /// Get last known position
  Position? get lastPosition => _lastPosition;
}

