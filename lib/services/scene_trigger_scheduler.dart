import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/scene_trigger.dart';
import '../models/scene.dart';
import 'smart_home_service.dart';

/// Service that monitors and executes time-based scene triggers
///
/// This service runs a periodic timer that checks every minute for scene triggers
/// that should fire based on the current time. When a matching trigger is found,
/// it automatically executes the associated scene.
///
/// Features:
/// - Singleton pattern for app-wide access
/// - Periodic checking every minute
/// - Duplicate execution prevention
/// - Error handling and logging
/// - Lifecycle management (start/stop)
class SceneTriggerScheduler {
  static final SceneTriggerScheduler _instance =
      SceneTriggerScheduler._internal();

  factory SceneTriggerScheduler() {
    return _instance;
  }

  SceneTriggerScheduler._internal();

  final SmartHomeService _service = SmartHomeService();
  Timer? _timer;
  bool _isRunning = false;

  // Track last execution to prevent duplicates within the same minute
  final Map<String, DateTime> _lastExecutionTimes = {};

  /// Start the scheduler
  ///
  /// Begins periodic checking for scene triggers every minute.
  /// Safe to call multiple times - will not create duplicate timers.
  void start() {
    if (_isRunning) {
      debugPrint('⏰ SceneTriggerScheduler: Already running');
      return;
    }

    debugPrint('⏰ SceneTriggerScheduler: Starting...');
    _isRunning = true;

    // Check immediately on start
    _checkAndExecuteTriggers();

    // Then check every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndExecuteTriggers();
    });

    debugPrint('⏰ SceneTriggerScheduler: Started successfully');
  }

  /// Stop the scheduler
  ///
  /// Cancels the periodic timer and stops checking for triggers.
  void stop() {
    if (!_isRunning) {
      debugPrint('⏰ SceneTriggerScheduler: Already stopped');
      return;
    }

    debugPrint('⏰ SceneTriggerScheduler: Stopping...');
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _lastExecutionTimes.clear();
    debugPrint('⏰ SceneTriggerScheduler: Stopped successfully');
  }

  /// Check if the scheduler is currently running
  bool get isRunning => _isRunning;

  /// Main logic to check and execute triggers
  Future<void> _checkAndExecuteTriggers() async {
    try {
      final now = DateTime.now();
      final currentHour = now.hour;
      final currentMinute = now.minute;
      final currentDay = now.weekday; // Monday=1, Sunday=7

      debugPrint(
        '⏰ SceneTriggerScheduler: Checking triggers at ${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}',
      );

      // Get all enabled scenes
      final scenes = await _getAllEnabledScenes();

      if (scenes.isEmpty) {
        debugPrint('⏰ SceneTriggerScheduler: No enabled scenes found');
        return;
      }

      debugPrint(
        '⏰ SceneTriggerScheduler: Found ${scenes.length} enabled scene(s)',
      );

      // Check each scene's triggers
      for (final scene in scenes) {
        try {
          final triggers = await _service.getSceneTriggers(scene.id);

          for (final trigger in triggers) {
            // Only process enabled schedule triggers
            if (!trigger.isEnabled || trigger.kind != TriggerKind.schedule) {
              continue;
            }

            // Check if this trigger should fire now
            if (_shouldTriggerFire(
              trigger,
              currentHour,
              currentMinute,
              currentDay,
            )) {
              // Check if we already executed this trigger in the current minute
              final lastExecution = _lastExecutionTimes[trigger.id];
              if (lastExecution != null &&
                  lastExecution.year == now.year &&
                  lastExecution.month == now.month &&
                  lastExecution.day == now.day &&
                  lastExecution.hour == now.hour &&
                  lastExecution.minute == now.minute) {
                debugPrint(
                  '⏰ SceneTriggerScheduler: Skipping duplicate execution for scene "${scene.name}" (trigger ${trigger.id})',
                );
                continue;
              }

              // Execute the scene
              debugPrint(
                '⏰ SceneTriggerScheduler: Executing scene "${scene.name}" (trigger ${trigger.id})',
              );
              await _executeScene(scene, trigger);

              // Record execution time
              _lastExecutionTimes[trigger.id] = now;
            }
          }
        } catch (e) {
          debugPrint(
            '⏰ SceneTriggerScheduler: Error processing scene "${scene.name}": $e',
          );
        }
      }

      // Clean up old execution records (keep only last 24 hours)
      _cleanupExecutionHistory(now);
    } catch (e) {
      debugPrint(
        '⏰ SceneTriggerScheduler: Error in _checkAndExecuteTriggers: $e',
      );
    }
  }

  /// Check if a trigger should fire based on current time
  bool _shouldTriggerFire(
    SceneTrigger trigger,
    int currentHour,
    int currentMinute,
    int currentDay,
  ) {
    final config = trigger.configJson;
    final triggerHour = config['hour'] as int?;
    final triggerMinute = config['minute'] as int?;
    final triggerDays = config['days'] as List<dynamic>?;

    // Validate configuration
    if (triggerHour == null || triggerMinute == null) {
      debugPrint(
        '⏰ SceneTriggerScheduler: Invalid trigger config (missing hour/minute): ${trigger.id}',
      );
      return false;
    }

    // Check if time matches
    if (triggerHour != currentHour || triggerMinute != currentMinute) {
      return false;
    }

    // Check if day matches (if days are specified)
    if (triggerDays != null && triggerDays.isNotEmpty) {
      final daysAsInts = triggerDays.map((d) => d as int).toList();
      if (!daysAsInts.contains(currentDay)) {
        return false;
      }
    }

    return true;
  }

  /// Execute a scene
  Future<void> _executeScene(Scene scene, SceneTrigger trigger) async {
    try {
      debugPrint('⏰ SceneTriggerScheduler: Running scene "${scene.name}"...');
      await _service.runScene(scene.id);
      debugPrint(
        '⏰ SceneTriggerScheduler: Scene "${scene.name}" executed successfully',
      );
    } catch (e) {
      debugPrint(
        '⏰ SceneTriggerScheduler: Failed to execute scene "${scene.name}": $e',
      );
    }
  }

  /// Get all enabled scenes from all user's homes
  Future<List<Scene>> _getAllEnabledScenes() async {
    try {
      // Get all homes for the current user
      final homes = await _service.getMyHomes();

      final List<Scene> allScenes = [];

      // Get scenes from each home
      for (final home in homes) {
        try {
          final scenes = await _service.getScenes(home.id);
          // Filter for enabled scenes only
          final enabledScenes = scenes.where((s) => s.isEnabled).toList();
          allScenes.addAll(enabledScenes);
        } catch (e) {
          debugPrint(
            '⏰ SceneTriggerScheduler: Error loading scenes for home ${home.id}: $e',
          );
        }
      }

      return allScenes;
    } catch (e) {
      debugPrint('⏰ SceneTriggerScheduler: Error loading scenes: $e');
      return [];
    }
  }

  /// Clean up old execution records to prevent memory leaks
  void _cleanupExecutionHistory(DateTime now) {
    final cutoff = now.subtract(const Duration(hours: 24));
    _lastExecutionTimes.removeWhere((key, value) => value.isBefore(cutoff));
  }

  /// Force an immediate check (useful for testing)
  Future<void> checkNow() async {
    debugPrint('⏰ SceneTriggerScheduler: Manual check triggered');
    await _checkAndExecuteTriggers();
  }
}
