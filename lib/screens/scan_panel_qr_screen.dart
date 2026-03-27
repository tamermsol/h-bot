import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_theme.dart';
import '../repos/panels_repo.dart';
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
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String _statusMessage = '';

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

      // Validate required fields from panel QR
      final deviceId = data['device_id'] as String?;
      final broker = data['broker'] as String?;
      final port = data['port'] as int? ?? 1883;
      final token = data['token'] as String?;

      if (deviceId == null || broker == null || token == null) {
        throw 'Invalid panel QR code — missing required fields.';
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

      // TODO: Publish MQTT pair/confirm message and wait for ACK
      // For now, directly save to Supabase (MQTT wiring in next step)

      final panel = await _panelsRepo.pairPanel(
        deviceId: deviceId,
        brokerAddress: broker,
        brokerPort: port,
        pairingToken: token,
        homeId: widget.homeId,
      );

      if (!mounted) return;

      // Show success and navigate to panel management
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Panel paired successfully!'),
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
