import 'package:flutter_test/flutter_test.dart';

import 'package:hbot/services/enhanced_mqtt_service.dart';
import 'package:hbot/models/device.dart';

Device makeFakeDevice({
  required String id,
  String? tasmotaTopicBase,
  required int channels,
}) {
  return Device(
    id: id,
    homeId: null,
    roomId: null,
    name: 'Fake',
    displayName: null,
    nameIsCustom: false,
    deviceType: DeviceType.relay,
    channels: channels,
    tasmotaTopicBase: tasmotaTopicBase,
    topicBase: null,
    macAddress: null,
    ownerUserId: null,
    matterType: null,
    metaJson: null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('Health evaluation and probe behavior', () {
    final service = EnhancedMqttService();
    final device = makeFakeDevice(
      id: 'dev-test-1',
      tasmotaTopicBase: 'hbot_test_1',
      channels: 1,
    );

    setUp(() async {
      await service.initialize('test-user');
      // ensure clean test hooks
      service.setProbeHandlerForTests(null);
      service.setTestDeviceLastSeen(device.id, null);
      service.setTestDeviceLWT(device.id, null);
      // Register device in service for tests
      service.setTestRegisterDevice(device);
    });

    test('fresh telemetry within window => ONLINE', () async {
      // set last seen to now
      service.setTestDeviceLastSeen(device.id, DateTime.now());
      final report = await service.evaluateDeviceHealthForTests(
        device,
        telePeriodSeconds: 10,
        performProbe: false,
      );
      expect(report['state'], equals('ONLINE'));
    });

    test('LWT offline and no probe => OFFLINE', () async {
      service.setTestDeviceLWT(device.id, 'offline');
      service.setTestDeviceLastSeen(
        device.id,
        DateTime.now().subtract(Duration(minutes: 10)),
      );
      final report = await service.evaluateDeviceHealthForTests(
        device,
        telePeriodSeconds: 10,
        performProbe: false,
      );
      expect(report['state'], equals('OFFLINE'));
    });

    test('LWT online but stale telemetry => STALE', () async {
      service.setTestDeviceLWT(device.id, 'online');
      service.setTestDeviceLastSeen(
        device.id,
        DateTime.now().subtract(Duration(minutes: 10)),
      );
      final report = await service.evaluateDeviceHealthForTests(
        device,
        telePeriodSeconds: 10,
        performProbe: false,
      );
      expect(report['state'], equals('STALE'));
    });

    test('probe handler override returning true => ONLINE', () async {
      // Ensure no recent telemetry and no LWT
      service.setTestDeviceLastSeen(
        device.id,
        DateTime.now().subtract(Duration(minutes: 10)),
      );
      service.setTestDeviceLWT(device.id, null);

      // Inject probe handler that returns true
      service.setProbeHandlerForTests((d) async {
        return true;
      });

      final report = await service.evaluateDeviceHealthForTests(
        device,
        telePeriodSeconds: 10,
        performProbe: true,
      );
      expect(report['state'], equals('ONLINE'));
    });
  });
}
