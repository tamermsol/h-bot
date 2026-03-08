#!/usr/bin/env dart

import 'dart:io';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Simple MQTT connection test with correct protocol version
void main() async {
  print('🚀 Simple MQTT Connection Test\n');

  const brokerHost = 'y3ae1177.ala.eu-central-1.emqxsl.com';
  const brokerPort = 8883;
  const username = 'admin';
  const password = 'P@ssword1';

  final clientId = 'flutter_test_${DateTime.now().millisecondsSinceEpoch}';
  final client = MqttServerClient(brokerHost, clientId);

  try {
    print('⚙️  Configuring client...');

    // Basic configuration
    client.port = brokerPort;
    client.secure = true;
    client.keepAlivePeriod = 60;
    client.connectTimeoutPeriod = 30000;
    client.logging(on: false); // Disable verbose logging

    // Use MQTT 3.1.1 (this is important!)
    client.setProtocolV311();

    // Set up TLS
    client.securityContext = SecurityContext.defaultContext;
    client.onBadCertificate = (dynamic certificate) =>
        true; // Accept all certificates for testing

    // Connection message
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .startClean();

    client.connectionMessage = connMessage;

    // Event handlers
    client.onConnected = () {
      print('✅ CONNECTED to MQTT broker!');
    };

    client.onDisconnected = () {
      print('❌ DISCONNECTED from MQTT broker');
    };

    print('🔌 Connecting to $brokerHost:$brokerPort...');

    // Connect
    await client.connect();

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('🎉 Connection successful!');

      // Test subscription
      const testTopic = 'test/flutter_app';
      print('📡 Subscribing to: $testTopic');
      client.subscribe(testTopic, MqttQos.atMostOnce);

      // Test publishing
      print('📤 Publishing test message...');
      final builder = MqttClientPayloadBuilder();
      builder.addString('Hello from Flutter!');
      client.publishMessage(testTopic, MqttQos.atMostOnce, builder.payload!);

      // Test device topics
      print('\n🏠 Testing device topics...');
      const deviceTopic = 'hbot_50677C';

      final deviceTopics = [
        'stat/$deviceTopic/POWER1',
        'stat/$deviceTopic/POWER2',
        'cmnd/$deviceTopic/POWER1',
        'tele/$deviceTopic/STATE',
      ];

      for (final topic in deviceTopics) {
        print('📡 Subscribing to: $topic');
        client.subscribe(topic, MqttQos.atMostOnce);
      }

      // Send a test command
      print('📤 Sending test command...');
      final cmdBuilder = MqttClientPayloadBuilder();
      cmdBuilder.addString('');
      client.publishMessage(
        'cmnd/$deviceTopic/POWER1',
        MqttQos.atMostOnce,
        cmdBuilder.payload!,
      );

      // Wait for messages
      print('\n⏳ Waiting for messages (10 seconds)...');

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        for (final message in messages) {
          final topic = message.topic;
          final payload = MqttPublishPayload.bytesToStringAsString(
            (message.payload as MqttPublishMessage).payload.message,
          );
          print('📨 Received: $topic = $payload');
        }
      });

      await Future.delayed(const Duration(seconds: 10));

      print('\n🔌 Disconnecting...');
      client.disconnect();
    } else {
      print('❌ Connection failed: ${client.connectionStatus}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  print('\n✅ Test completed');
}
