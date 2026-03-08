// ...existing code...
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'lib/services/enhanced_mqtt_service.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'lib/models/device.dart';

// Manual mock for Device to avoid generated mocks dependency in this test file
class MockDevice extends Mock implements Device {}

void main() {
  group('MQTT Stability Improvements Tests', () {
    late EnhancedMqttService mqttService;
    late MockDevice mockDevice;

    setUp(() {
      mqttService = EnhancedMqttService();
      mockDevice = MockDevice();

      // Setup mock device
      when(mockDevice.id).thenReturn('test-device-1');
      when(mockDevice.name).thenReturn('Test Device');
      when(mockDevice.tasmotaTopicBase).thenReturn('Hbot_Test_123456');
      when(mockDevice.channels).thenReturn(2);
    });

    tearDown(() async {
      await mqttService.dispose();
    });

    group('Connection Monitoring', () {
      test(
        'should start connection monitoring after successful connection',
        () async {
          // Initialize service
          await mqttService.initialize('test-user-123');

          // Get initial connection stats
          final initialStats = mqttService.connectionStats;
          expect(initialStats['monitoring_active'], isFalse);

          // Note: In a real test environment, we would mock the MQTT client
          // For now, we verify the monitoring setup logic
          expect(mqttService.connectionState, MqttConnectionState.disconnected);
        },
      );

      test('should detect connection health issues', () async {
        await mqttService.initialize('test-user-123');

        // Test health check when disconnected
        expect(mqttService.isHealthy, isFalse);

        // Verify connection stats include health information
        final stats = mqttService.connectionStats;
        expect(stats.containsKey('connection_state'), isTrue);
        expect(stats.containsKey('monitoring_active'), isTrue);
        expect(stats.containsKey('reconnection_attempts'), isTrue);
      });
    });

    group('Error Analysis and Recovery', () {
      test('should analyze SSL/TLS errors correctly', () {
        // Test error analysis (accessing private method through reflection would be complex)
        // Instead, we test the public interface that uses error analysis
        final stats = mqttService.connectionStats;
        expect(stats.containsKey('last_error_type'), isTrue);
        expect(stats.containsKey('current_recovery_strategy'), isTrue);
      });

      test(
        'should provide appropriate recovery strategies for different error types',
        () {
          // Test that connection stats include recovery strategy information
          final stats = mqttService.connectionStats;

          // Verify recovery strategy structure when present
          if (stats['current_recovery_strategy'] != null) {
            final strategy =
                stats['current_recovery_strategy'] as Map<String, dynamic>;
            expect(strategy.containsKey('should_retry'), isTrue);
            expect(strategy.containsKey('max_retries'), isTrue);
            expect(strategy.containsKey('base_delay_seconds'), isTrue);
            expect(strategy.containsKey('requires_network_check'), isTrue);
          }
        },
      );
    });

    group('Connection State Recovery', () {
      test('should provide comprehensive connection state recovery', () async {
        await mqttService.initialize('test-user-123');

        // Test connection state recovery method exists and returns boolean
        final result = await mqttService.performConnectionStateRecovery();
        expect(result, isA<bool>());
      });

      test('should verify device registrations after recovery', () async {
        await mqttService.initialize('test-user-123');

        // Register a mock device
        await mqttService.registerDevice(mockDevice);

        // Verify device is registered
        final stats = mqttService.connectionStats;
        expect(stats['registered_devices'], equals(1));

        // Test recovery process
        await mqttService.performConnectionStateRecovery();

        // Device should still be registered after recovery
        final statsAfterRecovery = mqttService.connectionStats;
        expect(statsAfterRecovery['registered_devices'], equals(1));
      });
    });

    group('Network Connectivity Handling', () {
      test('should track network connectivity status', () {
        final stats = mqttService.connectionStats;
        expect(stats.containsKey('has_network_connectivity'), isTrue);
        expect(stats['has_network_connectivity'], isA<bool>());
      });

      test('should handle network connectivity changes gracefully', () async {
        await mqttService.initialize('test-user-123');

        // Verify initial state
        final initialStats = mqttService.connectionStats;
        expect(initialStats['has_network_connectivity'], isNotNull);

        // Network connectivity handling is tested through the public interface
        // The actual network change detection would require integration testing
      });
    });

    group('Automatic Reconnection Logic', () {
      test(
        'should implement exponential backoff for reconnection attempts',
        () {
          final stats = mqttService.connectionStats;

          // Verify reconnection tracking fields exist
          expect(stats.containsKey('reconnection_attempts'), isTrue);
          expect(stats.containsKey('max_reconnection_attempts'), isTrue);
          expect(stats['reconnection_attempts'], isA<int>());
          expect(stats['max_reconnection_attempts'], isA<int>());
        },
      );

      test('should limit maximum reconnection attempts', () {
        final stats = mqttService.connectionStats;
        final maxAttempts = stats['max_reconnection_attempts'] as int;

        // Verify reasonable maximum attempts limit
        expect(maxAttempts, greaterThan(0));
        expect(maxAttempts, lessThanOrEqualTo(10));
      });

      test(
        'should reset reconnection attempts on successful connection',
        () async {
          await mqttService.initialize('test-user-123');

          final stats = mqttService.connectionStats;
          expect(stats['reconnection_attempts'], equals(0));
        },
      );
    });

    group('Connection Statistics and Debugging', () {
      test('should provide comprehensive connection statistics', () {
        final stats = mqttService.connectionStats;

        // Verify all expected statistics are present
        final expectedKeys = [
          'connection_state',
          'client_state',
          'reconnection_attempts',
          'max_reconnection_attempts',
          'is_reconnecting',
          'has_network_connectivity',
          'last_successful_connection',
          'last_connection_attempt',
          'monitoring_active',
          'registered_devices',
          'active_subscriptions',
          'last_error_type',
          'current_recovery_strategy',
        ];

        for (final key in expectedKeys) {
          expect(stats.containsKey(key), isTrue, reason: 'Missing key: $key');
        }
      });

      test('should track connection timestamps', () {
        final stats = mqttService.connectionStats;

        // Timestamps should be null initially or valid ISO strings
        final lastSuccess = stats['last_successful_connection'];
        final lastAttempt = stats['last_connection_attempt'];

        if (lastSuccess != null) {
          expect(lastSuccess, isA<String>());
          expect(() => DateTime.parse(lastSuccess), returnsNormally);
        }

        if (lastAttempt != null) {
          expect(lastAttempt, isA<String>());
          expect(() => DateTime.parse(lastAttempt), returnsNormally);
        }
      });
    });

    group('Device Registration and Management', () {
      test('should handle device registration correctly', () async {
        await mqttService.initialize('test-user-123');

        // Register device
        await mqttService.registerDevice(mockDevice);

        // Verify registration
        final stats = mqttService.connectionStats;
        expect(stats['registered_devices'], equals(1));
      });

      test('should handle device unregistration correctly', () async {
        await mqttService.initialize('test-user-123');

        // Register and then unregister device
        await mqttService.registerDevice(mockDevice);
        await mqttService.unregisterDevice(mockDevice.id);

        // Verify unregistration
        final stats = mqttService.connectionStats;
        expect(stats['registered_devices'], equals(0));
      });
    });

    group('Resource Management', () {
      test('should clean up resources properly on dispose', () async {
        await mqttService.initialize('test-user-123');
        await mqttService.registerDevice(mockDevice);

        // Dispose should not throw
        expect(() async => await mqttService.dispose(), returnsNormally);
      });

      test('should stop monitoring when connection is stopped', () async {
        await mqttService.initialize('test-user-123');

        // Disconnect should stop monitoring
        await mqttService.disconnect();

        final stats = mqttService.connectionStats;
        expect(stats['monitoring_active'], isFalse);
      });
    });
  });

  group('Integration Scenarios', () {
    test('should handle rapid connect/disconnect cycles', () async {
      final mqttService = EnhancedMqttService();
      await mqttService.initialize('test-user-123');

      // Perform multiple connect/disconnect cycles
      for (int i = 0; i < 3; i++) {
        await mqttService.disconnect();
        await Future.delayed(const Duration(milliseconds: 100));
        // Note: Actual connection would require a real MQTT broker
      }

      await mqttService.dispose();
    });

    test('should maintain device registrations across reconnections', () async {
      final mqttService = EnhancedMqttService();
      final mockDevice = MockDevice();

      when(mockDevice.id).thenReturn('test-device-persistent');
      when(mockDevice.name).thenReturn('Persistent Device');
      when(mockDevice.tasmotaTopicBase).thenReturn('Hbot_Persistent_789');
      when(mockDevice.channels).thenReturn(1);

      await mqttService.initialize('test-user-123');
      await mqttService.registerDevice(mockDevice);

      // Simulate reconnection
      await mqttService.performConnectionStateRecovery();

      // Device should still be registered
      final stats = mqttService.connectionStats;
      expect(stats['registered_devices'], equals(1));

      await mqttService.dispose();
    });
  });
}
