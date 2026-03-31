import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_theme.dart';
import '../models/device.dart';
import '../models/panel.dart';
import '../repos/panels_repo.dart';
import '../repos/devices_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/enhanced_mqtt_service.dart';
import '../services/current_home_service.dart';
import 'manage_panel_screen.dart';

/// Screen to scan a panel's QR code and initiate pairing
class ScanPanelQRScreen extends StatefulWidget {
  final String? homeId;

  const ScanPanelQRScreen({super.key, this.homeId});

  @override
  State<ScanPanelQRScreen> createState() => _ScanPanelQRScreenState();
}

class _ScanPanelQRScreenState extends State<ScanPanelQRScreen> {
  final PanelsRepo _panelsRepo = PanelsRepo();
  final DevicesRepo _devicesRepo = DevicesRepo();
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String _statusMessage = '';

  static const int _defaultRelayCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Reading QR code...';
    });

    try {
      final data = jsonDecode(code) as Map<String, dynamic>;

      // Support both current QR format and future format:
      // Current: {"device_id":"panel-xxxx","token":"hex16","fw":"2.1.0"}
      // Future:  {"id":"panel_MAC","broker":{"host":"...","port":8883},"relay_count":3,"fw":"1.0.0","token":"..."}
      final deviceId = (data['device_id'] ?? data['id']) as String?;
      final token = data['token'] as String?;
      final relayCount = data['relay_count'] as int? ?? _defaultRelayCount;

      // Broker: try QR first, fallback to known EMQX broker
      String broker;
      int port;
      if (data['broker'] is Map) {
        broker = data['broker']['host'] as String? ?? 'y3ae1177.ala.eu-central-1.emqxsl.com';
        port = data['broker']['port'] as int? ?? 8883;
      } else {
        broker = 'y3ae1177.ala.eu-central-1.emqxsl.com';
        port = 8883;
      }

      if (deviceId == null || token == null) {
        throw 'Invalid panel QR code — missing device_id or token.';
      }

      // Check if already paired
      final existing = await _panelsRepo.getPanelByDeviceId(deviceId);
      if (existing != null) {
        if (!mounted) return;
        final repairConfirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ctx.hCard,
            title: const Text('Panel Already Paired'),
            content: Text(
              'This panel "${existing.displayName}" is already paired. Do you want to re-pair it? This will reset its display configuration.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Re-pair', style: TextStyle(color: HBotColors.error)),
              ),
            ],
          ),
        );

        if (repairConfirmed != true) {
          setState(() => _isProcessing = false);
          return;
        }

        // Delete old record before re-pairing
        await _panelsRepo.deletePanel(existing.id);
      }

      setState(() => _statusMessage = 'Pairing with panel...');

      // Resolve homeId: use passed value, or fetch from CurrentHomeService
      String? homeId = widget.homeId;
      if (homeId == null) {
        homeId = await CurrentHomeService().getCurrentHomeId();
        debugPrint('Resolved homeId from CurrentHomeService: $homeId');
      }

      final panel = await _panelsRepo.pairPanel(
        deviceId: deviceId,
        brokerAddress: broker,
        brokerPort: port,
        pairingToken: token,
        homeId: homeId,
      );

      // Auto-create relay devices for the panel's built-in channels
      int createdCount = 0;
      if (homeId != null) {
        setState(() => _statusMessage = 'Adding $relayCount panel relays...');
        final createdDevices = await _createPanelRelays(
          deviceId, homeId, panel, relayCount,
        );
        createdCount = createdDevices.length;

        // Auto-build display config with the new relay devices
        if (createdDevices.isNotEmpty) {
          setState(() => _statusMessage = 'Pushing config to panel...');
          await _pushInitialConfig(panel, createdDevices);
        }
      } else {
        debugPrint('WARNING: No homeId available — skipping relay creation');
      }

      // Publish MQTT pair/confirm so the panel knows it's paired
      setState(() => _statusMessage = 'Confirming with panel...');
      await _publishPairConfirm(deviceId, token);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            homeId != null
                ? 'Panel paired with $createdCount relays!'
                : 'Panel paired! Set a home to add relay devices.',
          ),
          backgroundColor: HBotColors.success,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ManagePanelScreen(panel: panel),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pair: $e'),
          backgroundColor: HBotColors.error,
        ),
      );
      setState(() {
        _isProcessing = false;
        _statusMessage = '';
      });
    }
  }

  /// Create relay devices in Supabase for the panel's built-in channels.
  /// Each relay gets a unique topic_base so there's no conflict.
  /// Throws on first failure so the error surfaces to the user.
  Future<List<Device>> _createPanelRelays(
    String panelDeviceId, String homeId, Panel panel, int relayCount,
  ) async {
    final devices = <Device>[];
    for (int i = 0; i < relayCount; i++) {
      final device = await _devicesRepo.createDevice(
        homeId,
        name: '${panel.displayName} Relay ${i + 1}',
        deviceType: DeviceType.relay,
        channels: 1,
        // Each relay gets a unique topic_base to avoid unique constraint conflicts
        tasmotaTopicBase: 'hbot/panels/$panelDeviceId/relay/${i + 1}',
        metaJson: {
          'panel_device_id': panelDeviceId,
          'panel_relay_index': i + 1,
          'source': 'panel_pairing',
        },
      );
      devices.add(device);
      debugPrint('Created panel relay ${i + 1}: ${device.id}');
    }
    return devices;
  }

  /// Push initial display config with relays to Supabase + MQTT
  /// Uses agreed format: {version, display: {devices: [{id,label,icon,visible}], scenes: []}}
  Future<void> _pushInitialConfig(Panel panel, List<Device> relays) async {
    try {
      final deviceConfigs = <Map<String, dynamic>>[];
      for (int i = 0; i < relays.length; i++) {
        final d = relays[i];
        deviceConfigs.add(PanelDeviceConfig(
          id: d.id,
          label: d.deviceName,
          icon: deviceTypeToIcon(d.deviceType.name),
          type: d.deviceType.name,
          topic: d.deviceTopicBase ?? '',
          visible: true,
          relayIndex: i + 1,
        ).toJson());
      }

      final config = {
        'version': 1,
        'display': {
          'devices': deviceConfigs,
          'scenes': <Map<String, dynamic>>[],
        },
      };

      // Save to Supabase
      await _panelsRepo.updateDisplayConfig(panel.id, config);

      // Push to MQTT retained topic
      try {
        final mqtt = EnhancedMqttService();
        if (mqtt.isConnected) {
          mqtt.publishRetained(
            'hbot/panels/${panel.deviceId}/config',
            jsonEncode(config),
          );
          debugPrint('Pushed initial panel config via MQTT');
        }
      } catch (e) {
        debugPrint('MQTT config push failed (non-fatal): $e');
      }
    } catch (e) {
      debugPrint('Failed to push initial config: $e');
    }
  }

  /// Publish pair/confirm MQTT message so panel knows it's been claimed.
  /// Retries up to 3 times if MQTT isn't connected yet.
  Future<void> _publishPairConfirm(String panelDeviceId, String token) async {
    final mqtt = EnhancedMqttService();
    final user = Supabase.instance.client.auth.currentUser;
    final payload = jsonEncode({
      'device_id': panelDeviceId,
      'token': token,
      'user_id': user?.id ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    });
    final topic = 'hbot/panels/$panelDeviceId/pair/confirm';

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        if (mqtt.isConnected) {
          await mqtt.publishRetained(topic, payload);
          debugPrint('Published pair/confirm for $panelDeviceId (attempt ${attempt + 1})');
          return;
        }
        debugPrint('MQTT not connected, waiting 2s before retry (attempt ${attempt + 1})');
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('MQTT pair/confirm attempt ${attempt + 1} failed: $e');
      }
    }
    debugPrint('WARNING: Could not publish pair/confirm after 3 attempts');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan Panel QR'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Scan overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: HBotColors.primary, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  _isProcessing
                      ? _statusMessage
                      : 'Point your camera at the QR code on your H-Bot panel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_isProcessing) ...[
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
