import 'package:flutter/foundation.dart';

/// Helper class for debugging MQTT topic issues
class MqttDebugHelper {
  /// Generate expected MQTT topics for a device
  static Map<String, List<String>> generateExpectedTopics(
    String topicBase,
    int channels,
  ) {
    final topics = <String, List<String>>{};

    // Command topics (what we send TO the device)
    final commandTopics = <String>[];
    for (int i = 1; i <= channels; i++) {
      commandTopics.add('cmnd/$topicBase/POWER$i');
    }
    commandTopics.addAll([
      'cmnd/$topicBase/STATUS',
      'cmnd/$topicBase/STATE',
      'cmnd/$topicBase/RESTART',
    ]);
    topics['command'] = commandTopics;

    // Status topics (what we expect FROM the device)
    final statusTopics = <String>[];
    for (int i = 1; i <= channels; i++) {
      statusTopics.add('stat/$topicBase/POWER$i');
    }
    statusTopics.addAll([
      'stat/$topicBase/STATUS',
      'stat/$topicBase/STATE',
      'stat/$topicBase/RESULT',
    ]);
    topics['status'] = statusTopics;

    // Telemetry topics (periodic updates from device)
    final telemetryTopics = <String>[];
    telemetryTopics.addAll([
      'tele/$topicBase/STATE',
      'tele/$topicBase/SENSOR',
      'tele/$topicBase/LWT',
      'tele/$topicBase/RESULT',
    ]);
    topics['telemetry'] = telemetryTopics;

    // Subscription patterns (what we actually subscribe to)
    final subscriptionPatterns = <String>[
      'stat/$topicBase/+',
      'tele/$topicBase/+',
      'cmnd/$topicBase/+',
      'tele/$topicBase/LWT',
    ];
    topics['subscriptions'] = subscriptionPatterns;

    return topics;
  }

  /// Check if a received topic matches expected patterns
  static bool isTopicExpected(
    String receivedTopic,
    String expectedTopicBase,
    int channels,
  ) {
    final expectedTopics = generateExpectedTopics(expectedTopicBase, channels);

    // First check exact matches (non-wildcard topics)
    for (final topicList in expectedTopics.values) {
      for (final expectedTopic in topicList) {
        if (!expectedTopic.contains('+')) {
          // Exact match
          if (receivedTopic == expectedTopic) {
            return true;
          }
        }
      }
    }

    // For wildcard patterns, we need to be more specific about POWER channels
    final topicParts = receivedTopic.split('/');
    if (topicParts.length >= 3) {
      final prefix = topicParts[0]; // stat, tele, cmnd
      final topicBase = topicParts[1]; // device topic base
      final command = topicParts[2]; // POWER1, STATUS, etc.

      // Check if topic base matches
      if (topicBase != expectedTopicBase) {
        return false;
      }

      // Check if prefix is valid
      if (!['stat', 'tele', 'cmnd'].contains(prefix)) {
        return false;
      }

      // Special handling for POWER commands - check channel validity
      if (command.startsWith('POWER')) {
        final channelMatch = RegExp(r'POWER(\d+)').firstMatch(command);
        if (channelMatch != null) {
          final channel = int.tryParse(channelMatch.group(1)!);
          if (channel == null || channel < 1 || channel > channels) {
            return false; // Invalid channel for this device
          }
        } else if (command == 'POWER') {
          // Single POWER is valid for any device
          return true;
        } else {
          return false; // Invalid POWER format
        }
        return true;
      }

      // For non-POWER commands, check against wildcard patterns
      for (final topicList in expectedTopics.values) {
        for (final expectedTopic in topicList) {
          if (expectedTopic.contains('+')) {
            final pattern = expectedTopic.replaceAll('+', r'[^/]+');
            final regex = RegExp('^$pattern\$');
            if (regex.hasMatch(receivedTopic)) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  /// Extract channel number from a POWER topic
  static int? extractChannelFromTopic(String topic) {
    final powerMatch = RegExp(r'POWER(\d+)').firstMatch(topic);
    if (powerMatch != null) {
      return int.tryParse(powerMatch.group(1)!);
    }

    // Check for single POWER (channel 1)
    if (topic.endsWith('/POWER')) {
      return 1;
    }

    return null;
  }

  /// Validate topic format and case sensitivity
  static Map<String, dynamic> validateTopic(
    String topic,
    String expectedTopicBase,
  ) {
    final parts = topic.split('/');
    final validation = <String, dynamic>{
      'isValid': false,
      'issues': <String>[],
      'suggestions': <String>[],
    };

    if (parts.length < 3) {
      validation['issues'].add(
        'Topic has insufficient parts (expected: prefix/topic/command)',
      );
      return validation;
    }

    final prefix = parts[0]; // stat, tele, cmnd
    final topicBase = parts[1]; // Hbot_2CH_BC8397
    final command = parts[2]; // POWER1, STATUS, etc.

    // Check prefix
    if (!['stat', 'tele', 'cmnd'].contains(prefix)) {
      validation['issues'].add(
        'Invalid prefix: $prefix (expected: stat, tele, or cmnd)',
      );
    }

    // Check topic base case sensitivity
    if (topicBase != expectedTopicBase) {
      if (topicBase.toLowerCase() == expectedTopicBase.toLowerCase()) {
        validation['issues'].add(
          'Topic base case mismatch: $topicBase vs $expectedTopicBase',
        );
        validation['suggestions'].add(
          'Check device configuration for correct topic case',
        );
      } else {
        validation['issues'].add(
          'Topic base mismatch: $topicBase vs $expectedTopicBase',
        );
        validation['suggestions'].add('Verify device topic configuration');
      }
    }

    // Check command format
    if (command.startsWith('POWER')) {
      final channelMatch = RegExp(r'POWER(\d+)').firstMatch(command);
      if (channelMatch == null && command != 'POWER') {
        validation['issues'].add('Invalid POWER command format: $command');
        validation['suggestions'].add(
          'Expected POWER1, POWER2, etc. or just POWER',
        );
      }
    }

    validation['isValid'] = (validation['issues'] as List).isEmpty;
    return validation;
  }

  /// Generate debug information for MQTT troubleshooting
  static String generateDebugInfo(
    String deviceName,
    String topicBase,
    int channels,
    List<String> receivedTopics,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('=== MQTT Debug Information ===');
    buffer.writeln('Device: $deviceName');
    buffer.writeln('Topic Base: $topicBase');
    buffer.writeln('Channels: $channels');
    buffer.writeln('');

    final expectedTopics = generateExpectedTopics(topicBase, channels);

    buffer.writeln('Expected Topics:');
    for (final entry in expectedTopics.entries) {
      buffer.writeln('  ${entry.key.toUpperCase()}:');
      for (final topic in entry.value) {
        buffer.writeln('    $topic');
      }
    }
    buffer.writeln('');

    buffer.writeln('Received Topics:');
    if (receivedTopics.isEmpty) {
      buffer.writeln('  No topics received yet');
    } else {
      for (final topic in receivedTopics) {
        final isExpected = isTopicExpected(topic, topicBase, channels);
        final status = isExpected ? '✅' : '❌';
        buffer.writeln('  $status $topic');

        if (!isExpected) {
          final validation = validateTopic(topic, topicBase);
          for (final issue in validation['issues'] as List<String>) {
            buffer.writeln('      Issue: $issue');
          }
          for (final suggestion in validation['suggestions'] as List<String>) {
            buffer.writeln('      Suggestion: $suggestion');
          }
        }
      }
    }

    return buffer.toString();
  }

  /// Log debug information
  static void logDebugInfo(
    String deviceName,
    String topicBase,
    int channels,
    List<String> receivedTopics,
  ) {
    final debugInfo = generateDebugInfo(
      deviceName,
      topicBase,
      channels,
      receivedTopics,
    );
    debugPrint(debugInfo);
  }
}
