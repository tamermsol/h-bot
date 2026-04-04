import '../models/home.dart';
import '../models/room.dart';
import '../models/device.dart';
import '../models/scene.dart';
import '../models/scene_trigger.dart';
import '../models/scene_step.dart';
import '../models/profile.dart';

/// Demo mode flag — enable with: --dart-define=DEMO_MODE=true
const bool isDemoMode =
    bool.fromEnvironment('DEMO_MODE', defaultValue: false);

/// Demo user ID used across all demo data
const String _demoUserId = 'demo-user-001';

/// Demo home IDs
const String _homeId = 'demo-home-001';

/// Demo room IDs
const String _livingRoomId = 'demo-room-living';
const String _bedroomId = 'demo-room-bedroom';
const String _kitchenId = 'demo-room-kitchen';
const String _officeId = 'demo-room-office';
const String _bathroomId = 'demo-room-bathroom';

/// Demo device IDs
const String _livingLightsId = 'demo-dev-living-lights';
const String _livingShutterId = 'demo-dev-living-shutter';
const String _bedroomLightsId = 'demo-dev-bedroom-lights';
const String _bedroomDimmerId = 'demo-dev-bedroom-dimmer';
const String _kitchenLightsId = 'demo-dev-kitchen-lights';
const String _officeLightsId = 'demo-dev-office-lights';
const String _bathroomLightsId = 'demo-dev-bathroom-lights';
const String _livingSensorId = 'demo-dev-living-sensor';

/// Demo scene IDs
const String _morningSceneId = 'demo-scene-morning';
const String _movieSceneId = 'demo-scene-movie';
const String _goodnightSceneId = 'demo-scene-goodnight';
const String _awaySceneId = 'demo-scene-away';
const String _welcomeSceneId = 'demo-scene-welcome';
const String _readingSceneId = 'demo-scene-reading';

final DateTime _now = DateTime(2026, 3, 24);

class DemoData {
  // ──────────────────── Profile ────────────────────

  static Profile get profile => Profile(
        id: _demoUserId,
        fullName: 'Alex Johnson',
        phoneNumber: '+1 (555) 123-4567',
        createdAt: _now.subtract(const Duration(days: 90)),
        updatedAt: _now,
      );

  static String get userEmail => 'alex@h-bot.tech';

  // ──────────────────── Homes ────────────────────

  static List<Home> get homes => [
        Home(
          id: _homeId,
          ownerId: _demoUserId,
          name: 'My Home',
          backgroundImageUrl: null,
          createdAt: _now.subtract(const Duration(days: 90)),
          updatedAt: _now,
        ),
      ];

  // ──────────────────── Rooms ────────────────────

  static List<Room> getRooms(String homeId) {
    if (homeId != _homeId) return [];
    return [
      Room(
        id: _livingRoomId,
        homeId: _homeId,
        name: 'Living Room',
        sortOrder: 0,
        iconName: 'couch',
        createdAt: _now.subtract(const Duration(days: 90)),
        updatedAt: _now,
      ),
      Room(
        id: _bedroomId,
        homeId: _homeId,
        name: 'Bedroom',
        sortOrder: 1,
        iconName: 'bed',
        createdAt: _now.subtract(const Duration(days: 90)),
        updatedAt: _now,
      ),
      Room(
        id: _kitchenId,
        homeId: _homeId,
        name: 'Kitchen',
        sortOrder: 2,
        iconName: 'cooking_pot',
        createdAt: _now.subtract(const Duration(days: 90)),
        updatedAt: _now,
      ),
      Room(
        id: _officeId,
        homeId: _homeId,
        name: 'Office',
        sortOrder: 3,
        iconName: 'desk',
        createdAt: _now.subtract(const Duration(days: 90)),
        updatedAt: _now,
      ),
      Room(
        id: _bathroomId,
        homeId: _homeId,
        name: 'Bathroom',
        sortOrder: 4,
        iconName: 'bathtub',
        createdAt: _now.subtract(const Duration(days: 90)),
        updatedAt: _now,
      ),
    ];
  }

  // ──────────────────── Devices ────────────────────

  static List<Device> getDevices(String homeId) {
    if (homeId != _homeId) return [];
    return [
      Device(
        id: _livingLightsId,
        homeId: _homeId,
        roomId: _livingRoomId,
        name: 'Ceiling Lights',
        displayName: 'Ceiling Lights',
        nameIsCustom: true,
        deviceType: DeviceType.relay,
        channels: 4,
        channelCount: 4,
        online: true,
        lastSeenAt: _now,
        topicBase: 'tasmota_demo_living',
        createdAt: _now.subtract(const Duration(days: 60)),
        updatedAt: _now,
      ),
      Device(
        id: _livingShutterId,
        homeId: _homeId,
        roomId: _livingRoomId,
        name: 'Window Blinds',
        displayName: 'Window Blinds',
        nameIsCustom: true,
        deviceType: DeviceType.shutter,
        channels: 1,
        channelCount: 1,
        online: true,
        lastSeenAt: _now,
        topicBase: 'tasmota_demo_shutter',
        createdAt: _now.subtract(const Duration(days: 60)),
        updatedAt: _now,
      ),
      Device(
        id: _bedroomLightsId,
        homeId: _homeId,
        roomId: _bedroomId,
        name: 'Bedroom Lights',
        displayName: 'Bedroom Lights',
        nameIsCustom: true,
        deviceType: DeviceType.relay,
        channels: 2,
        channelCount: 2,
        online: true,
        lastSeenAt: _now,
        topicBase: 'tasmota_demo_bedroom',
        createdAt: _now.subtract(const Duration(days: 55)),
        updatedAt: _now,
      ),
      Device(
        id: _bedroomDimmerId,
        homeId: _homeId,
        roomId: _bedroomId,
        name: 'Bedside Lamp',
        displayName: 'Bedside Lamp',
        nameIsCustom: true,
        deviceType: DeviceType.dimmer,
        channels: 1,
        channelCount: 1,
        online: true,
        lastSeenAt: _now,
        topicBase: 'tasmota_demo_dimmer',
        createdAt: _now.subtract(const Duration(days: 55)),
        updatedAt: _now,
      ),
      Device(
        id: _kitchenLightsId,
        homeId: _homeId,
        roomId: _kitchenId,
        name: 'Kitchen Lights',
        displayName: 'Kitchen Lights',
        nameIsCustom: true,
        deviceType: DeviceType.relay,
        channels: 4,
        channelCount: 4,
        online: true,
        lastSeenAt: _now,
        topicBase: 'tasmota_demo_kitchen',
        createdAt: _now.subtract(const Duration(days: 50)),
        updatedAt: _now,
      ),
      Device(
        id: _officeLightsId,
        homeId: _homeId,
        roomId: _officeId,
        name: 'Desk Lamp',
        displayName: 'Desk Lamp',
        nameIsCustom: true,
        deviceType: DeviceType.relay,
        channels: 2,
        channelCount: 2,
        online: true,
        lastSeenAt: _now,
        topicBase: 'tasmota_demo_office',
        createdAt: _now.subtract(const Duration(days: 45)),
        updatedAt: _now,
      ),
      Device(
        id: _bathroomLightsId,
        homeId: _homeId,
        roomId: _bathroomId,
        name: 'Bathroom Light',
        displayName: 'Bathroom Light',
        nameIsCustom: true,
        deviceType: DeviceType.relay,
        channels: 2,
        channelCount: 2,
        online: true,
        lastSeenAt: _now,
        topicBase: 'tasmota_demo_bathroom',
        createdAt: _now.subtract(const Duration(days: 40)),
        updatedAt: _now,
      ),
      Device(
        id: _livingSensorId,
        homeId: _homeId,
        roomId: _livingRoomId,
        name: 'Climate Sensor',
        displayName: 'Climate Sensor',
        nameIsCustom: true,
        deviceType: DeviceType.sensor,
        channels: 0,
        channelCount: 1,
        online: true,
        lastSeenAt: _now,
        topicBase: 'tasmota_demo_sensor',
        createdAt: _now.subtract(const Duration(days: 30)),
        updatedAt: _now,
      ),
    ];
  }

  static List<Device> get sharedDevices => [];

  // ──────────────────── Scenes ────────────────────

  static List<Scene> getScenes(String homeId) {
    if (homeId != _homeId) return [];
    return [
      Scene(
        id: _morningSceneId,
        homeId: _homeId,
        name: 'Morning Routine',
        isEnabled: true,
        iconCode: 0xe518, // wb_sunny
        colorValue: 0xFFFFA726, // orange
        createdAt: _now.subtract(const Duration(days: 30)),
        updatedAt: _now,
      ),
      Scene(
        id: _movieSceneId,
        homeId: _homeId,
        name: 'Movie Night',
        isEnabled: true,
        iconCode: 0xe02C, // movie
        colorValue: 0xFF7C4DFF, // deep purple
        createdAt: _now.subtract(const Duration(days: 28)),
        updatedAt: _now,
      ),
      Scene(
        id: _goodnightSceneId,
        homeId: _homeId,
        name: 'Good Night',
        isEnabled: true,
        iconCode: 0xe51C, // nightlight
        colorValue: 0xFF42A5F5, // blue
        createdAt: _now.subtract(const Duration(days: 25)),
        updatedAt: _now,
      ),
      Scene(
        id: _awaySceneId,
        homeId: _homeId,
        name: 'Away Mode',
        isEnabled: true,
        iconCode: 0xe8B8, // security
        colorValue: 0xFFEF5350, // red
        createdAt: _now.subtract(const Duration(days: 20)),
        updatedAt: _now,
      ),
      Scene(
        id: _welcomeSceneId,
        homeId: _homeId,
        name: 'Welcome Home',
        isEnabled: true,
        iconCode: 0xe88A, // home
        colorValue: 0xFF66BB6A, // green
        createdAt: _now.subtract(const Duration(days: 15)),
        updatedAt: _now,
      ),
      Scene(
        id: _readingSceneId,
        homeId: _homeId,
        name: 'Reading Time',
        isEnabled: false,
        iconCode: 0xe865, // menu_book
        colorValue: 0xFF8D6E63, // brown
        createdAt: _now.subtract(const Duration(days: 10)),
        updatedAt: _now,
      ),
    ];
  }

  // ──────────────────── Scene Triggers ────────────────────

  static List<SceneTrigger> getSceneTriggers(String sceneId) {
    switch (sceneId) {
      case _morningSceneId:
        return [
          SceneTrigger(
            id: 'demo-trigger-morning',
            sceneId: _morningSceneId,
            kind: TriggerKind.schedule,
            configJson: {'time': '07:00', 'days': [1, 2, 3, 4, 5]},
            isEnabled: true,
            createdAt: _now,
          ),
        ];
      case _goodnightSceneId:
        return [
          SceneTrigger(
            id: 'demo-trigger-goodnight',
            sceneId: _goodnightSceneId,
            kind: TriggerKind.schedule,
            configJson: {'time': '23:00', 'days': [0, 1, 2, 3, 4, 5, 6]},
            isEnabled: true,
            createdAt: _now,
          ),
        ];
      case _welcomeSceneId:
        return [
          SceneTrigger(
            id: 'demo-trigger-welcome',
            sceneId: _welcomeSceneId,
            kind: TriggerKind.geo,
            configJson: {'radius': 200, 'action': 'enter'},
            isEnabled: true,
            createdAt: _now,
          ),
        ];
      default:
        return [
          SceneTrigger(
            id: 'demo-trigger-$sceneId',
            sceneId: sceneId,
            kind: TriggerKind.manual,
            configJson: {},
            isEnabled: true,
            createdAt: _now,
          ),
        ];
    }
  }

  // ──────────────────── Scene Steps ────────────────────

  static List<SceneStep> getSceneSteps(String sceneId) {
    switch (sceneId) {
      case _morningSceneId:
        return [
          SceneStep(
            id: 'demo-step-m1',
            sceneId: _morningSceneId,
            stepOrder: 0,
            actionJson: {
              'device_id': _livingLightsId,
              'action_type': 'power',
              'channels': [1, 2, 3, 4],
              'state': true,
            },
            createdAt: _now,
          ),
          SceneStep(
            id: 'demo-step-m2',
            sceneId: _morningSceneId,
            stepOrder: 1,
            actionJson: {
              'device_id': _livingShutterId,
              'action_type': 'shutter',
              'position': 100,
            },
            createdAt: _now,
          ),
          SceneStep(
            id: 'demo-step-m3',
            sceneId: _morningSceneId,
            stepOrder: 2,
            actionJson: {
              'device_id': _kitchenLightsId,
              'action_type': 'power',
              'channels': [1, 2],
              'state': true,
            },
            createdAt: _now,
          ),
        ];
      case _goodnightSceneId:
        return [
          SceneStep(
            id: 'demo-step-g1',
            sceneId: _goodnightSceneId,
            stepOrder: 0,
            actionJson: {
              'device_id': _livingLightsId,
              'action_type': 'power',
              'channels': [1, 2, 3, 4],
              'state': false,
            },
            createdAt: _now,
          ),
          SceneStep(
            id: 'demo-step-g2',
            sceneId: _goodnightSceneId,
            stepOrder: 1,
            actionJson: {
              'device_id': _kitchenLightsId,
              'action_type': 'power',
              'channels': [1, 2, 3, 4],
              'state': false,
            },
            createdAt: _now,
          ),
        ];
      default:
        return [
          SceneStep(
            id: 'demo-step-$sceneId-1',
            sceneId: sceneId,
            stepOrder: 0,
            actionJson: {
              'device_id': _livingLightsId,
              'action_type': 'power',
              'channels': [1, 2],
              'state': true,
            },
            createdAt: _now,
          ),
        ];
    }
  }

  // ──────────────────── Device State (MQTT mock) ────────────────────

  /// Returns mock MQTT state for demo devices
  static Map<String, dynamic> getDeviceState(String deviceId) {
    switch (deviceId) {
      case _livingLightsId:
        return {
          'POWER1': 'ON',
          'POWER2': 'ON',
          'POWER3': 'OFF',
          'POWER4': 'ON',
        };
      case _livingShutterId:
        return {'Shutter1': {'Position': 75, 'Direction': 0}};
      case _bedroomLightsId:
        return {'POWER1': 'ON', 'POWER2': 'OFF'};
      case _bedroomDimmerId:
        return {'POWER1': 'ON', 'Dimmer': 60};
      case _kitchenLightsId:
        return {
          'POWER1': 'ON',
          'POWER2': 'ON',
          'POWER3': 'ON',
          'POWER4': 'OFF',
        };
      case _officeLightsId:
        return {'POWER1': 'ON', 'POWER2': 'OFF'};
      case _bathroomLightsId:
        return {'POWER1': 'OFF', 'POWER2': 'OFF'};
      case _livingSensorId:
        return {
          'StatusSNS': {
            'Temperature': 23.5,
            'Humidity': 45,
          },
        };
      default:
        return {};
    }
  }

  // ──────────────────── Statistics ────────────────────

  static int get totalHomes => 1;
  static int get totalDevices => 8;
  static int get totalRooms => 5;
  static int get totalScenes => 6;
}
