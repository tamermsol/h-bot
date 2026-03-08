#!/usr/bin/env dart

import 'dart:io';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Comprehensive MQTT connection test script
/// Run with: dart test_mqtt_connection.dart
void main() async {
  print('🚀 Testing MQTT TLS Connection to EMQX Cloud...\n');

  // Test connection parameters
  const brokerHost = 'y3ae1177.ala.eu-central-1.emqxsl.com';
  const brokerPort = 8883;
  const username = 'admin';
  const password = 'P@ssword1';

  print('📋 Connection Details:');
  print('   Host: $brokerHost');
  print('   Port: $brokerPort');
  print('   Username: $username');
  print('   TLS: Enabled');
  print('');

  final clientId = 'test_client_${DateTime.now().millisecondsSinceEpoch}';
  final client = MqttServerClient(brokerHost, clientId);

  try {
    print('⚙️  Configuring MQTT client...');

    // Configure client
    client.port = brokerPort;
    client.secure = true;
    client.keepAlivePeriod = 60;
    client.connectTimeoutPeriod = 30000;
    client.logging(on: true);

    // Set up TLS context with CA certificate
    try {
      final context = SecurityContext.defaultContext;

      // Try to load CA certificate if available
      final caCertFile = File('assets/ca.crt');
      if (await caCertFile.exists()) {
        final caCertData = await caCertFile.readAsBytes();
        context.setTrustedCertificatesBytes(caCertData);
        print('✅ Loaded CA certificate from assets/ca.crt');
      } else {
        print('⚠️  CA certificate file not found, using system defaults');
      }

      client.securityContext = context;
    } catch (e) {
      print('⚠️  TLS setup warning: $e');
    }

    // Allow bad certificates for testing
    client.onBadCertificate = (dynamic certificate) {
      print('⚠️  Accepting bad certificate for testing');
      return true;
    };

    // Set up connection message
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    // Set up event handlers
    client.onConnected = () {
      print('✅ Connected to MQTT broker successfully!');
    };

    client.onDisconnected = () {
      print('❌ Disconnected from MQTT broker');
    };

    client.onSubscribed = (String topic) {
      print('📡 Subscribed to topic: $topic');
    };

    // Connect
    print('🔌 Connecting to y3ae1177.ala.eu-central-1.emqxsl.com:8883...');
    await client.connect();

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('🎉 Connection successful!\n');

      // Test subscription
      const testTopic = 'test/hbot_connection';
      print('📡 Subscribing to test topic: $testTopic');
      client.subscribe(testTopic, MqttQos.atMostOnce);

      // Set up message listener
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        for (final message in messages) {
          final topic = message.topic;
          final payload = MqttPublishPayload.bytesToStringAsString(
            (message.payload as MqttPublishMessage).payload.message,
          );
          print('📨 Received message on $topic: $payload');
        }
      });

      // Test publishing
      print('📤 Publishing test message...');
      final builder = MqttClientPayloadBuilder();
      builder.addString('Hello from Flutter MQTT test!');
      client.publishMessage(testTopic, MqttQos.atLeastOnce, builder.payload!);

      // Test device-like topics
      print('\n🏠 Testing device control topics...');

      // Simulate hbot device topics
      const deviceTopic = 'hbot_50677C';
      final deviceTopics = [
        'stat/$deviceTopic/POWER1',
        'stat/$deviceTopic/POWER2',
        'stat/$deviceTopic/POWER3',
        'stat/$deviceTopic/POWER4',
        'tele/$deviceTopic/STATE',
      ];

      for (final topic in deviceTopics) {
        print('📡 Subscribing to: $topic');
        client.subscribe(topic, MqttQos.atMostOnce);
      }

      // Test power commands
      for (int i = 1; i <= 4; i++) {
        final cmdTopic = 'cmnd/$deviceTopic/POWER$i';
        final payload = i % 2 == 0 ? 'ON' : 'OFF';

        print('📤 Publishing to $cmdTopic: $payload');
        final cmdBuilder = MqttClientPayloadBuilder();
        cmdBuilder.addString(payload);
        client.publishMessage(
          cmdTopic,
          MqttQos.atLeastOnce,
          cmdBuilder.payload!,
        );

        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Wait for messages
      print('\n⏳ Waiting for messages (10 seconds)...');
      await Future.delayed(const Duration(seconds: 10));

      print('\n✅ MQTT TLS connection test completed successfully!');
      print('📊 Connection details:');
      print('   • Host: y3ae1177.ala.eu-central-1.emqxsl.com');
      print('   • Port: 8883 (TLS/SSL)');
      print('   • Username: admin');
      print('   • Client ID: ${client.clientIdentifier}');
      print('   • Protocol: MQTT 3.1.1');
      print('   • TLS: Enabled');
    } else {
      print('❌ Connection failed: ${client.connectionStatus}');
      exit(1);
    }
  } catch (e) {
    print('💥 Error during MQTT test: $e');
    exit(1);
  } finally {
    // Clean up
    client.disconnect();
    print('\n🔌 Disconnected from broker');
  }
}
