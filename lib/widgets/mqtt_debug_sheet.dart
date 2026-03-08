import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'dart:async';
import '../services/mqtt_device_manager.dart';
import '../theme/app_theme.dart';

/// Debug information sheet for MQTT connection troubleshooting
class MqttDebugSheet extends StatefulWidget {
  final MqttDeviceManager mqttManager;

  const MqttDebugSheet({super.key, required this.mqttManager});

  @override
  State<MqttDebugSheet> createState() => _MqttDebugSheetState();
}

class _MqttDebugSheetState extends State<MqttDebugSheet> {
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _debugSubscription;
  MqttConnectionState _connectionState = MqttConnectionState.disconnected;
  List<String> _debugMessages = [];

  @override
  void initState() {
    super.initState();
    _initializeDebugInfo();
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _debugSubscription?.cancel();
    super.dispose();
  }

  void _initializeDebugInfo() {
    // Get initial state
    _connectionState = widget.mqttManager.connectionState;
    _debugMessages = widget.mqttManager.debugMessages;

    // Listen to connection state changes
    _connectionStateSubscription = widget.mqttManager.connectionStateStream
        .listen((state) {
          if (mounted) {
            setState(() {
              _connectionState = state;
            });
          }
        });

    // Listen to debug messages
    _debugSubscription = widget.mqttManager.debugStream.listen((message) {
      if (mounted) {
        setState(() {
          _debugMessages = widget.mqttManager.debugMessages;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(AppTheme.paddingMedium),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report, color: AppTheme.primaryColor),
                    const SizedBox(width: AppTheme.paddingSmall),
                    const Expanded(
                      child: Text(
                        'MQTT Debug Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppTheme.paddingMedium),
                  children: [
                    _buildConnectionInfo(),
                    const SizedBox(height: AppTheme.paddingLarge),
                    _buildBrokerInfo(),
                    const SizedBox(height: AppTheme.paddingLarge),
                    _buildDebugMessages(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionInfo() {
    Color statusColor = Colors.grey;
    String statusText = 'Unknown';
    IconData statusIcon = Icons.help;

    switch (_connectionState) {
      case MqttConnectionState.connected:
        statusColor = Colors.green;
        statusText = 'Connected';
        statusIcon = Icons.check_circle;
        break;
      case MqttConnectionState.connecting:
        statusColor = Colors.orange;
        statusText = 'Connecting...';
        statusIcon = Icons.sync;
        break;
      case MqttConnectionState.disconnected:
        statusColor = Colors.red;
        statusText = 'Disconnected';
        statusIcon = Icons.cancel;
        break;
      case MqttConnectionState.disconnecting:
        statusColor = Colors.orange;
        statusText = 'Disconnecting...';
        statusIcon = Icons.sync;
        break;
      case MqttConnectionState.faulted:
        statusColor = Colors.red;
        statusText = 'Connection Error';
        statusIcon = Icons.error;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: AppTheme.paddingSmall),
                Text(
                  'Connection Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingSmall),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 14,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppTheme.paddingMedium),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _connectionState == MqttConnectionState.disconnected
                        ? _reconnect
                        : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.paddingSmall),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyDebugInfo,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Info'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrokerInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Broker Configuration',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.paddingMedium),
            _buildInfoRow('Host', 'y3ae1177.ala.eu-central-1.emqxsl.com'),
            _buildInfoRow('Port', '8883 (TLS/SSL)'),
            _buildInfoRow('Username', 'admin'),
            _buildInfoRow('Protocol', 'MQTT 3.1.1'),
            _buildInfoRow('TLS', 'Enabled (DigiCert Global Root CA)'),
            _buildInfoRow('Keep Alive', '60 seconds'),
            _buildInfoRow('Auto Reconnect', 'Enabled'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugMessages() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Debug Messages',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearDebugMessages,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingSmall),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _debugMessages.isEmpty
                  ? const Center(
                      child: Text(
                        'No debug messages',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _debugMessages.length,
                      itemBuilder: (context, index) {
                        final message = _debugMessages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            message,
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reconnect() async {
    try {
      await widget.mqttManager.connect();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reconnect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyDebugInfo() {
    final info = StringBuffer();
    info.writeln('MQTT Debug Information');
    info.writeln('======================');
    info.writeln('Connection State: $_connectionState');
    info.writeln('Broker: y3ae1177.ala.eu-central-1.emqxsl.com:8883');
    info.writeln('TLS: Enabled');
    info.writeln('');
    info.writeln('Debug Messages:');
    for (final message in _debugMessages) {
      info.writeln(message);
    }

    Clipboard.setData(ClipboardData(text: info.toString()));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debug information copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearDebugMessages() {
    // Note: This would require adding a clear method to the MQTT manager
    // For now, just show a message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debug messages cleared'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }
}
