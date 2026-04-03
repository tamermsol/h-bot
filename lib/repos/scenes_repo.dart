import '../core/supabase_client.dart';
import '../demo/demo_data.dart';
import '../models/scene.dart';
import '../models/scene_step.dart';
import '../models/scene_trigger.dart';
import '../models/scene_run.dart';
import '../services/mqtt_device_manager.dart';
import '../services/enhanced_mqtt_service.dart';

class ScenesRepo {
  /// List all scenes in a home
  Future<List<Scene>> listScenes(String homeId) async {
    if (isDemoMode) return DemoData.getScenes(homeId);
    try {
      final response = await supabase
          .from('scenes')
          .select('*')
          .eq('home_id', homeId)
          .order('name');

      return (response as List).map((json) => Scene.fromJson(json)).toList();
    } catch (e) {
      throw 'Failed to load scenes: $e';
    }
  }

  /// Get a single scene by ID
  Future<Scene> getScene(String sceneId) async {
    try {
      final response = await supabase
          .from('scenes')
          .select('*')
          .eq('id', sceneId)
          .single();

      return Scene.fromJson(response);
    } catch (e) {
      throw 'Failed to load scene: $e';
    }
  }

  /// Create a new scene
  Future<Scene> createScene(
    String homeId,
    String name, {
    bool isEnabled = true,
    int? iconCode,
    int? colorValue,
  }) async {
    try {
      final data = {
        'home_id': homeId,
        'name': name,
        'is_enabled': isEnabled,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Add optional fields if provided
      if (iconCode != null) data['icon_code'] = iconCode;
      if (colorValue != null) data['color_value'] = colorValue;

      final response = await supabase
          .from('scenes')
          .insert(data)
          .select()
          .single();

      return Scene.fromJson(response);
    } catch (e) {
      throw 'Failed to create scene: $e';
    }
  }

  /// Update a scene
  Future<Scene> updateScene(
    String sceneId, {
    String? name,
    bool? isEnabled,
    int? iconCode,
    int? colorValue,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (isEnabled != null) updates['is_enabled'] = isEnabled;
      if (iconCode != null) updates['icon_code'] = iconCode;
      if (colorValue != null) updates['color_value'] = colorValue;

      final response = await supabase
          .from('scenes')
          .update(updates)
          .eq('id', sceneId)
          .select()
          .single();

      return Scene.fromJson(response);
    } catch (e) {
      throw 'Failed to update scene: $e';
    }
  }

  /// Delete a scene
  Future<void> deleteScene(String sceneId) async {
    try {
      // Delete related records first
      await Future.wait([
        supabase.from('scene_steps').delete().eq('scene_id', sceneId),
        supabase.from('scene_triggers').delete().eq('scene_id', sceneId),
        supabase.from('scene_runs').delete().eq('scene_id', sceneId),
      ]);

      // Delete the scene
      await supabase.from('scenes').delete().eq('id', sceneId);
    } catch (e) {
      throw 'Failed to delete scene: $e';
    }
  }

  /// List scene steps
  Future<List<SceneStep>> listSceneSteps(String sceneId) async {
    if (isDemoMode) return DemoData.getSceneSteps(sceneId);
    try {
      final response = await supabase
          .from('scene_steps')
          .select('*')
          .eq('scene_id', sceneId)
          .order('step_order');

      return (response as List)
          .map((json) => SceneStep.fromJson(json))
          .toList();
    } catch (e) {
      throw 'Failed to load scene steps: $e';
    }
  }

  /// Create a scene step
  Future<SceneStep> createSceneStep(
    String sceneId,
    int stepOrder,
    Map<String, dynamic> actionJson,
  ) async {
    try {
      final response = await supabase
          .from('scene_steps')
          .insert({
            'scene_id': sceneId,
            'step_order': stepOrder,
            'action_json': actionJson,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return SceneStep.fromJson(response);
    } catch (e) {
      throw 'Failed to create scene step: $e';
    }
  }

  /// Update a scene step
  Future<SceneStep> updateSceneStep(
    String stepId, {
    int? stepOrder,
    Map<String, dynamic>? actionJson,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (stepOrder != null) updates['step_order'] = stepOrder;
      if (actionJson != null) updates['action_json'] = actionJson;

      final response = await supabase
          .from('scene_steps')
          .update(updates)
          .eq('id', stepId)
          .select()
          .single();

      return SceneStep.fromJson(response);
    } catch (e) {
      throw 'Failed to update scene step: $e';
    }
  }

  /// Delete a scene step
  Future<void> deleteSceneStep(String stepId) async {
    try {
      await supabase.from('scene_steps').delete().eq('id', stepId);
    } catch (e) {
      throw 'Failed to delete scene step: $e';
    }
  }

  /// Delete all scene steps for a scene
  Future<void> deleteSceneSteps(String sceneId) async {
    try {
      await supabase.from('scene_steps').delete().eq('scene_id', sceneId);
    } catch (e) {
      throw 'Failed to delete scene steps: $e';
    }
  }

  /// List scene triggers
  Future<List<SceneTrigger>> listSceneTriggers(String sceneId) async {
    if (isDemoMode) return DemoData.getSceneTriggers(sceneId);
    try {
      final response = await supabase
          .from('scene_triggers')
          .select('*')
          .eq('scene_id', sceneId)
          .order('created_at');

      return (response as List)
          .map((json) => SceneTrigger.fromJson(json))
          .toList();
    } catch (e) {
      throw 'Failed to load scene triggers: $e';
    }
  }

  /// Create a scene trigger
  Future<SceneTrigger> createSceneTrigger(
    String sceneId,
    TriggerKind kind,
    Map<String, dynamic> configJson, {
    bool isEnabled = true,
  }) async {
    try {
      final response = await supabase
          .from('scene_triggers')
          .insert({
            'scene_id': sceneId,
            'kind': kind.name,
            'config_json': configJson,
            'is_enabled': isEnabled,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return SceneTrigger.fromJson(response);
    } catch (e) {
      throw 'Failed to create scene trigger: $e';
    }
  }

  /// Update a scene trigger
  Future<SceneTrigger> updateSceneTrigger(
    String triggerId, {
    TriggerKind? kind,
    Map<String, dynamic>? configJson,
    bool? isEnabled,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (kind != null) updates['kind'] = kind.name;
      if (configJson != null) updates['config_json'] = configJson;
      if (isEnabled != null) updates['is_enabled'] = isEnabled;

      final response = await supabase
          .from('scene_triggers')
          .update(updates)
          .eq('id', triggerId)
          .select()
          .single();

      return SceneTrigger.fromJson(response);
    } catch (e) {
      throw 'Failed to update scene trigger: $e';
    }
  }

  /// Delete a scene trigger
  Future<void> deleteSceneTrigger(String triggerId) async {
    try {
      await supabase.from('scene_triggers').delete().eq('id', triggerId);
    } catch (e) {
      throw 'Failed to delete scene trigger: $e';
    }
  }

  /// Run a scene (creates a scene_run record and executes device actions)
  Future<SceneRun> runScene(String sceneId) async {
    final mqttDeviceManager = MqttDeviceManager();
    final enhancedMqttService = EnhancedMqttService();
    final logs = <String>[];

    try {
      // Get current user ID for RLS policy
      final user = supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Create initial run record with 'running' status
      final response = await supabase
          .from('scene_runs')
          .insert({
            'scene_id': sceneId,
            'user_id': user.id,
            'started_at': DateTime.now().toIso8601String(),
            'status': 'running',
            'logs_json': {'message': 'Scene execution started'},
          })
          .select()
          .single();

      final runId = response['id'];
      logs.add('Scene execution started');

      // Fetch scene steps
      final steps = await listSceneSteps(sceneId);
      logs.add('Found ${steps.length} scene step(s)');

      if (steps.isEmpty) {
        logs.add('No device actions configured for this scene');
        await supabase
            .from('scene_runs')
            .update({
              'finished_at': DateTime.now().toIso8601String(),
              'status': 'success',
              'logs_json': {'logs': logs},
            })
            .eq('id', runId);

        final updatedResponse = await supabase
            .from('scene_runs')
            .select('*')
            .eq('id', runId)
            .single();

        return SceneRun.fromJson(updatedResponse);
      }

      // Execute each step in order
      for (final step in steps) {
        try {
          final actionJson = step.actionJson;
          final deviceId = actionJson['device_id'] as String?;
          final actionType = actionJson['action_type'] as String?;

          if (deviceId == null || actionType == null) {
            logs.add('Step ${step.stepOrder}: Invalid action data');
            continue;
          }

          // Execute based on action type
          if (actionType == 'power') {
            // Relay/Dimmer device action
            final channels = List<int>.from(actionJson['channels'] ?? [1]);
            final state = actionJson['state'] as bool? ?? true;

            logs.add(
              'Step ${step.stepOrder}: Turning ${state ? "ON" : "OFF"} channels ${channels.join(", ")} for device $deviceId',
            );

            // Fetch device to check total channels
            final deviceResponse = await supabase
                .from('devices')
                .select('channels')
                .eq('id', deviceId)
                .single();

            final totalChannels = deviceResponse['channels'] as int? ?? 1;

            // Optimize: If controlling all channels, use POWER0 command (Tasmota)
            if (channels.length == totalChannels && channels.length > 1) {
              // Use POWER0 to control all channels at once - much faster!
              logs.add('Using POWER0 command for all $totalChannels channels');
              await mqttDeviceManager.setBulkPower(deviceId, state);
            } else {
              // Send power command for each channel individually
              for (final channel in channels) {
                await mqttDeviceManager.setChannelPower(
                  deviceId,
                  channel,
                  state,
                );
                // Small delay between commands
                await Future.delayed(const Duration(milliseconds: 50));
              }
            }
          } else if (actionType == 'shutter') {
            // Shutter device action
            final position = actionJson['position'] as int? ?? 50;

            logs.add(
              'Step ${step.stepOrder}: Setting shutter position to $position% for device $deviceId',
            );

            // Assuming shutter index 1 (most common case)
            // You may need to adjust this based on your device configuration
            await enhancedMqttService.setShutterPosition(deviceId, 1, position);
          } else {
            logs.add(
              'Step ${step.stepOrder}: Unknown action type: $actionType',
            );
          }

          // Small delay between steps
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          logs.add('Step ${step.stepOrder}: Error - $e');
          // Continue with next step even if one fails
        }
      }

      logs.add('Scene execution completed');

      // Mark as success
      await supabase
          .from('scene_runs')
          .update({
            'finished_at': DateTime.now().toIso8601String(),
            'status': 'success',
            'logs_json': {'logs': logs},
          })
          .eq('id', runId);

      // Return the updated run
      final updatedResponse = await supabase
          .from('scene_runs')
          .select('*')
          .eq('id', runId)
          .single();

      return SceneRun.fromJson(updatedResponse);
    } catch (e) {
      logs.add('Fatal error: $e');
      throw 'Failed to run scene: $e';
    }
  }

  /// List scene runs
  Future<List<SceneRun>> listSceneRuns(String sceneId, {int limit = 50}) async {
    try {
      final response = await supabase
          .from('scene_runs')
          .select('*')
          .eq('scene_id', sceneId)
          .order('started_at', ascending: false)
          .limit(limit);

      return (response as List).map((json) => SceneRun.fromJson(json)).toList();
    } catch (e) {
      throw 'Failed to load scene runs: $e';
    }
  }
}
