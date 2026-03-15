import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../repos/device_sharing_repo.dart';
import '../models/shared_device.dart';
import '../core/supabase_client.dart';

class ScanDeviceQRScreen extends StatefulWidget {
  const ScanDeviceQRScreen({super.key});

  @override
  State<ScanDeviceQRScreen> createState() => _ScanDeviceQRScreenState();
}

class _ScanDeviceQRScreenState extends State<ScanDeviceQRScreen> {
  final DeviceSharingRepo _repo = DeviceSharingRepo();
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

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

    setState(() => _isProcessing = true);

    try {
      // Parse QR code data
      final data = jsonDecode(code) as Map<String, dynamic>;

      if (data['type'] == 'multi_device_share') {
        await _handleMultiDeviceShare(data);
      } else if (data['type'] == 'device_share') {
        await _handleSingleDeviceShare(data);
      } else {
        throw 'Invalid QR code type';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSingleDeviceShare(Map<String, dynamic> data) async {
    final invitationCode = data['invitation_code'] as String;
    final deviceName = data['device_name'] as String;

    // Get invitation details
    final invitation = await _repo.getInvitationByCode(invitationCode);
    if (invitation == null) {
      throw 'Invalid or expired invitation';
    }

    // Show confirmation dialog
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.cardLight,
        title: const Text('Add Shared Device?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device: $deviceName'),
            const SizedBox(height: 8),
            const Text(
              'This device will be added to your dashboard immediately.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: HBotColors.primary,
            ),
            child: const Text('Add Device'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() => _isProcessing = false);
      return;
    }

    // Ensure user has a home and room
    await _ensureUserHasHomeAndRoom();

    // Instantly share device
    await _repo.instantShareDevice(
      deviceId: invitation.deviceId,
      ownerId: invitation.ownerId,
      permissionLevel: PermissionLevel.control,
    );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Device added successfully! Check your dashboard.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _handleMultiDeviceShare(Map<String, dynamic> data) async {
    final devices = data['devices'] as List<dynamic>;
    final deviceCount = data['count'] as int;

    // Show confirmation dialog
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.cardLight,
        title: const Text('Add Shared Devices?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$deviceCount device(s) will be added:'),
            const SizedBox(height: 12),
            ...devices
                .take(5)
                .map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${d['device_name']}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
            if (devices.length > 5)
              Text(
                '... and ${devices.length - 5} more',
                style: const TextStyle(fontSize: 13),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: HBotColors.primary,
            ),
            child: const Text('Add All'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() => _isProcessing = false);
      return;
    }

    // Ensure user has a home and room
    await _ensureUserHasHomeAndRoom();

    // Share all devices
    int successCount = 0;
    for (final deviceData in devices) {
      try {
        final invitationCode = deviceData['invitation_code'] as String;
        final invitation = await _repo.getInvitationByCode(invitationCode);

        if (invitation != null) {
          await _repo.instantShareDevice(
            deviceId: invitation.deviceId,
            ownerId: invitation.ownerId,
            permissionLevel: PermissionLevel.control,
          );
          successCount++;
        }
      } catch (e) {
        debugPrint('Error sharing device: $e');
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$successCount of $deviceCount device(s) added successfully!',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _ensureUserHasHomeAndRoom() async {
    try {
      // Check if user has any homes
      final homes = await supabase.from('homes').select('id').limit(1);

      if (homes.isEmpty) {
        // Create "Shared Devices" home
        final homeResponse = await supabase
            .from('homes')
            .insert({'name': 'Shared Devices'})
            .select()
            .single();

        final homeId = homeResponse['id'] as String;

        // Create "Shared Devices" room
        await supabase.from('rooms').insert({
          'home_id': homeId,
          'name': 'Shared Devices',
          'sort_order': 0,
        });

        debugPrint('Created "Shared Devices" home and room for new user');
      }
    } catch (e) {
      debugPrint('Error ensuring home/room: $e');
      // Don't throw - user might already have homes
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Device QR Code'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(
              _controller.torchEnabled ? Icons.flash_on : Icons.flash_off,
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Scanning overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: HBotColors.primary, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Point your camera at the QR code\nshared by the device owner',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
