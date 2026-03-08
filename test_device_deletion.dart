#!/usr/bin/env dart

/// Test runner for device deletion functionality
/// 
/// This script helps run the device deletion tests and provides
/// guidance on setting up the test environment.

import 'dart:io';

void main(List<String> args) async {
  print('🧪 Device Deletion Test Runner');
  print('================================');
  
  if (args.isEmpty) {
    printUsage();
    return;
  }

  final testType = args[0];
  
  switch (testType) {
    case 'unit':
      await runUnitTests();
      break;
    case 'widget':
      await runWidgetTests();
      break;
    case 'integration':
      await runIntegrationTests();
      break;
    case 'all':
      await runAllTests();
      break;
    default:
      print('❌ Unknown test type: $testType');
      printUsage();
  }
}

void printUsage() {
  print('Usage: dart test_device_deletion.dart <test_type>');
  print('');
  print('Test types:');
  print('  unit        - Run unit tests for repository layer');
  print('  widget      - Run widget tests for UI components');
  print('  integration - Run integration tests (requires test environment)');
  print('  all         - Run all tests');
  print('');
  print('Examples:');
  print('  dart test_device_deletion.dart unit');
  print('  dart test_device_deletion.dart widget');
  print('  dart test_device_deletion.dart all');
}

Future<void> runUnitTests() async {
  print('🔧 Running unit tests...');
  print('');
  
  final result = await Process.run(
    'flutter',
    ['test', 'test/devices_repo_test.dart'],
    workingDirectory: '.',
  );
  
  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Errors:');
    print(result.stderr);
  }
  
  if (result.exitCode == 0) {
    print('✅ Unit tests passed!');
  } else {
    print('❌ Unit tests failed!');
  }
}

Future<void> runWidgetTests() async {
  print('🎨 Running widget tests...');
  print('');
  
  final result = await Process.run(
    'flutter',
    ['test', 'test/device_deletion_test.dart'],
    workingDirectory: '.',
  );
  
  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Errors:');
    print(result.stderr);
  }
  
  if (result.exitCode == 0) {
    print('✅ Widget tests passed!');
  } else {
    print('❌ Widget tests failed!');
  }
}

Future<void> runIntegrationTests() async {
  print('🔗 Running integration tests...');
  print('');
  print('⚠️  Integration tests require:');
  print('   - Test Supabase environment');
  print('   - Test authentication setup');
  print('   - Test device data');
  print('');
  
  final result = await Process.run(
    'flutter',
    ['test', 'integration_test/device_deletion_integration_test.dart'],
    workingDirectory: '.',
  );
  
  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Errors:');
    print(result.stderr);
  }
  
  if (result.exitCode == 0) {
    print('✅ Integration tests passed!');
  } else {
    print('❌ Integration tests failed!');
  }
}

Future<void> runAllTests() async {
  print('🚀 Running all device deletion tests...');
  print('');
  
  await runUnitTests();
  print('');
  await runWidgetTests();
  print('');
  await runIntegrationTests();
  
  print('');
  print('📊 Test Summary');
  print('================');
  print('All device deletion tests completed.');
  print('Check individual test results above for details.');
}

/// Print test setup instructions
void printTestSetup() {
  print('📋 Test Environment Setup');
  print('==========================');
  print('');
  print('To run these tests successfully, ensure:');
  print('');
  print('1. Unit Tests:');
  print('   - No special setup required');
  print('   - Tests use mocked dependencies');
  print('');
  print('2. Widget Tests:');
  print('   - No special setup required');
  print('   - Tests use mock services');
  print('');
  print('3. Integration Tests:');
  print('   - Set up test Supabase project');
  print('   - Configure test authentication');
  print('   - Create test device data');
  print('   - Set environment variables for test database');
  print('');
  print('4. Dependencies:');
  print('   - Run: flutter pub get');
  print('   - Run: dart pub global activate mockito');
  print('   - Run: flutter packages pub run build_runner build');
  print('');
}
