#!/usr/bin/env dart

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple script to test device topic repair
void main() async {
  print('🔧 Device Topic Repair Test\n');

  // Initialize Supabase (you'll need to add your credentials)
  await Supabase.initialize(
    url: 'https://mvmvqycvorstsftcldzs.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12bXZxeWN2b3JzdHNmdGNsZHpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ5NzE0NzQsImV4cCI6MjA1MDU0NzQ3NH0.Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8',
  );

  final supabase = Supabase.instance.client;

  try {
    // Query devices with invalid topics
    print('📋 Checking for devices with invalid MQTT topics...\n');
    
    final response = await supabase
        .from('devices')
        .select('id, name, tasmota_topic_base, meta_json')
        .order('name');

    final devices = response as List;
    
    print('Found ${devices.length} devices:\n');
    
    for (final device in devices) {
      final name = device['name'] as String;
      final topic = device['tasmota_topic_base'] as String?;
      final metaJson = device['meta_json'] as Map<String, dynamic>?;
      
      print('📱 Device: $name');
      print('   Current Topic: ${topic ?? 'NULL'}');
      
      // Check if topic is invalid
      bool isInvalid = false;
      if (topic == null || 
          topic.contains('NKNOWN') || 
          topic.contains('UNKNOWN') || 
          topic.isEmpty ||
          topic == 'hbot_' ||
          !topic.startsWith('hbot_')) {
        isInvalid = true;
      }
      
      if (isInvalid) {
        print('   ❌ INVALID TOPIC DETECTED');
        
        // Try to extract MAC from metadata
        String? mac;
        if (metaJson != null) {
          mac = metaJson['mac'] as String?;
          if (mac == null) {
            // Try other common field names
            for (final field in ['MAC', 'macAddress', 'mac_address', 'device_mac']) {
              if (metaJson.containsKey(field)) {
                mac = metaJson[field] as String?;
                break;
              }
            }
          }
        }
        
        if (mac != null) {
          // Generate new topic from MAC
          final cleanMac = mac.replaceAll(':', '').toUpperCase();
          final suffix = cleanMac.substring(cleanMac.length - 6);
          final newTopic = 'hbot_$suffix';
          
          print('   📍 Found MAC: $mac');
          print('   🔧 Suggested Topic: $newTopic');
          
          // Ask user if they want to update
          stdout.write('   Update this device? (y/N): ');
          final input = stdin.readLineSync()?.toLowerCase();
          
          if (input == 'y' || input == 'yes') {
            try {
              await supabase
                  .from('devices')
                  .update({'tasmota_topic_base': newTopic})
                  .eq('id', device['id']);
              
              print('   ✅ Updated successfully!');
            } catch (e) {
              print('   ❌ Update failed: $e');
            }
          }
        } else {
          print('   ⚠️  No MAC address found in metadata');
          print('   📋 Metadata: $metaJson');
        }
      } else {
        print('   ✅ Topic is valid');
      }
      
      print('');
    }
    
    print('🎉 Device topic repair check completed!');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
