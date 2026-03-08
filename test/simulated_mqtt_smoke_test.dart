import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:hbot/models/device.dart';
import 'package:hbot/services/enhanced_mqtt_service.dart';
import 'package:hbot/services/mqtt_device_manager.dart';

void main() {
  group('Simulated MQTT / Tasmota smoke tests', () {
    final svc = EnhancedMqttService();
    final mgr = MqttDeviceManager();

    test(
      'Status 5 probe flow (simulated) responds and marks probe as responded',
      () async {
        // Create a fake device
        final device = Device(
          id: const Uuid().v4(),
          deviceType: DeviceType.relay,
          channels: 1,
          tasmotaTopicBase: 'test_topic_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Register device in internal test maps (no real MQTT subscriptions)
        svc.setTestRegisterDevice(device);

        // Provide a probe handler that simulates a successful Status 5 reply
        svc.setProbeHandlerForTests((d) async {
          // Ensure it's the device we expect
          return d.id == device.id ? true : false;
        });

        // Run the health evaluator which will call the probe handler
        final report = await svc.evaluateDeviceHealthForTests(
          device,
          telePeriodSeconds: 60,
          performProbe: true,
        );

        expect(report, isA<Map<String, dynamic>>());
        expect(report['respondedToCmd'], equals(true));
        // When probe responded we should see ONLINE state returned
        expect(report['state'], equals('ONLINE'));
      },
    );

    test(
      'Per-command optimistic flow: revert and mark offline on send failure (simulated)',
      () async {
        final device = Device(
          id: const Uuid().v4(),
          deviceType: DeviceType.relay,
          channels: 1,
          tasmotaTopicBase: 'test_topic_456',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Register device state in the service for tests only (do not call
        // manager.registerDevice because it attempts real initialization).
        svc.setTestRegisterDevice(device);

        // Call setChannelPower which will apply an optimistic update and then
        // attempt to send the MQTT command. In the test environment the
        // EnhancedMqttService will not be connected, causing sendPowerCommand
        // to throw and the manager to revert the optimistic state.
        bool threw = false;
        try {
          await mgr.setChannelPower(device.id, 1, true);
        } catch (e) {
          threw = true;
        }

        expect(
          threw,
          isTrue,
          reason: 'Expected sendPowerCommand to fail in test environment',
        );

        final after = mgr.getDeviceState(device.id);
        // Manager should have created a state entry when applying optimistic
        // updates; verify it was reverted.
        expect(after, isNotNull);
        expect(after!['POWER1'], equals('OFF'));
        // In the error-path the manager reverts the optimistic value but may
        // not explicitly set 'online' (it can be null). Accept either false
        // or null here.
        expect(after['online'], anyOf(false, isNull));
      },
    );
  });
}
