/// Service for managing MQTT broker configuration
class MqttConfigService {
  static const String _defaultBrokerHost =
      'y3ae1177.ala.eu-central-1.emqxsl.com';
  static const int _defaultBrokerPort = 8883;
  static const String _defaultUsername = 'admin';
  static const String _defaultPassword = 'P@ssword1';

  /// Get MQTT broker configuration
  /// In a real app, this would come from user settings or environment variables
  static Map<String, dynamic> getBrokerConfig() {
    return {
      'host': _defaultBrokerHost,
      'port': _defaultBrokerPort,
      'username': _defaultUsername,
      'password': _defaultPassword,
    };
  }

  /// Check if MQTT is configured
  static bool isConfigured() {
    final config = getBrokerConfig();
    return config['host'] != null && config['host'].toString().isNotEmpty;
  }

  /// Get broker host
  static String getBrokerHost() {
    return getBrokerConfig()['host'] ?? _defaultBrokerHost;
  }

  /// Get broker port
  static int getBrokerPort() {
    return getBrokerConfig()['port'] ?? _defaultBrokerPort;
  }

  /// Get username
  static String? getUsername() {
    return getBrokerConfig()['username'];
  }

  /// Get password
  static String? getPassword() {
    return getBrokerConfig()['password'];
  }
}
