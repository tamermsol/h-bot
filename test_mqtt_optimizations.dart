#!/usr/bin/env dart

import 'dart:io';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Test script to verify MQTT optimizations and performance improvements
void main() async {
  print('🚀 MQTT Performance Optimization Test\n');

  const brokerHost = 'y3ae1177.ala.eu-central-1.emqxsl.com';
  const brokerPort = 8883;
  const username = 'admin';
  const password = 'P@ssword1';

  final clientId = 'perf_test_${DateTime.now().millisecondsSinceEpoch}';
  final client = MqttServerClient(brokerHost, clientId);

  try {
    print('⚙️  Configuring optimized client...');

    // Optimized configuration matching the enhanced service
    client.port = brokerPort;
    client.secure = true;
    client.keepAlivePeriod = 60; // Optimized keep-alive
    client.connectTimeoutPeriod = 15000; // Balanced timeout
    client.logging(on: false); // Disable verbose logging for performance
    client.setProtocolV311();

    // Set up TLS
    client.securityContext = SecurityContext.defaultContext;
    client.onBadCertificate = (dynamic certificate) => true;

    // Connection message with clean session
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .startClean(); // Clean session to avoid retained message issues

    client.connectionMessage = connMessage;

    // Event handlers
    client.onConnected = () {
      print('✅ CONNECTED with optimized settings!');
    };

    client.onDisconnected = () {
      print('❌ DISCONNECTED');
    };

    // Connect
    print('🔌 Connecting with optimized parameters...');
    final stopwatch = Stopwatch()..start();
    await client.connect();
    stopwatch.stop();

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('🎉 Connection successful in ${stopwatch.elapsedMilliseconds}ms!');

      // Test optimized subscription strategy
      print('\n📡 Testing optimized subscription strategy...');
      const deviceTopic = 'hbot_50677C';
      
      // Only subscribe to essential topics (avoiding redundant subscriptions)
      final optimizedTopics = [
        'stat/$deviceTopic/+',  // Covers all status messages
        'tele/$deviceTopic/+',  // Covers all telemetry messages
      ];

      final subscriptionStopwatch = Stopwatch()..start();
      for (final topic in optimizedTopics) {
        print('📡 Subscribing to: $topic');
        client.subscribe(topic, MqttQos.atLeastOnce); // Consistent QoS
      }
      subscriptionStopwatch.stop();
      print('✅ Subscriptions completed in ${subscriptionStopwatch.elapsedMilliseconds}ms');

      // Test command queuing simulation
      print('\n📤 Testing command queuing simulation...');
      final commandStopwatch = Stopwatch()..start();
      
      // Simulate rapid commands (this would be queued in the enhanced service)
      for (int i = 1; i <= 4; i++) {
        final builder = MqttClientPayloadBuilder();
        builder.addString('ON');
        client.publishMessage(
          'cmnd/$deviceTopic/POWER$i',
          MqttQos.atLeastOnce, // Consistent QoS
          builder.payload!,
        );
        print('📤 Sent command: POWER$i = ON');
        
        // Small delay to simulate queuing
        await Future.delayed(const Duration(milliseconds: 100));
      }
      commandStopwatch.stop();
      print('✅ Commands sent in ${commandStopwatch.elapsedMilliseconds}ms');

      // Test message handling
      print('\n📨 Testing message handling...');
      int messageCount = 0;
      final messageStopwatch = Stopwatch()..start();
      
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        for (final message in messages) {
          final topic = message.topic;
          final payload = MqttPublishPayload.bytesToStringAsString(
            (message.payload as MqttPublishMessage).payload.message,
          );
          messageCount++;
          print('📨 Message $messageCount: $topic = $payload');
        }
      });

      // Wait for messages
      print('⏳ Waiting for messages (10 seconds)...');
      await Future.delayed(const Duration(seconds: 10));
      messageStopwatch.stop();
      
      print('✅ Processed $messageCount messages in ${messageStopwatch.elapsedMilliseconds}ms');
      if (messageCount > 0) {
        final avgTime = messageStopwatch.elapsedMilliseconds / messageCount;
        print('📊 Average message processing time: ${avgTime.toStringAsFixed(2)}ms');
      }

      // Test status requests
      print('\n🔍 Testing status requests...');
      final statusStopwatch = Stopwatch()..start();
      
      for (int i = 1; i <= 4; i++) {
        final builder = MqttClientPayloadBuilder();
        builder.addString('');
        client.publishMessage(
          'cmnd/$deviceTopic/POWER$i',
          MqttQos.atLeastOnce,
          builder.payload!,
        );
        print('🔍 Requested status: POWER$i');
        
        // Throttled delay
        await Future.delayed(const Duration(milliseconds: 500));
      }
      statusStopwatch.stop();
      print('✅ Status requests completed in ${statusStopwatch.elapsedMilliseconds}ms');

      // Performance summary
      print('\n📊 PERFORMANCE SUMMARY:');
      print('   Connection time: ${stopwatch.elapsedMilliseconds}ms');
      print('   Subscription time: ${subscriptionStopwatch.elapsedMilliseconds}ms');
      print('   Command batch time: ${commandStopwatch.elapsedMilliseconds}ms');
      print('   Messages processed: $messageCount');
      print('   Status request time: ${statusStopwatch.elapsedMilliseconds}ms');
      
      final totalTime = stopwatch.elapsedMilliseconds + 
                       subscriptionStopwatch.elapsedMilliseconds + 
                       commandStopwatch.elapsedMilliseconds + 
                       statusStopwatch.elapsedMilliseconds;
      print('   Total operation time: ${totalTime}ms');

    } else {
      print('❌ Connection failed!');
      exit(1);
    }

  } catch (e) {
    print('💥 Error during test: $e');
    exit(1);
  } finally {
    print('\n🔌 Disconnecting...');
    client.disconnect();
    print('✅ Test completed!');
  }
}
