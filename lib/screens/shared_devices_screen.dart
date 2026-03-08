import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/shared_device.dart';
import '../repos/device_sharing_repo.dart';
import 'scan_device_qr_screen.dart';

class SharedDevicesScreen extends StatefulWidget {
  const SharedDevicesScreen({super.key});

  @override
  State<SharedDevicesScreen> createState() => _SharedDevicesScreenState();
}

class _SharedDevicesScreenState extends State<SharedDevicesScreen> {
  final DeviceSharingRepo _sharingRepo = DeviceSharingRepo();
  List<SharedDevice> _sharedDevices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSharedDevices();
  }

  Future<void> _loadSharedDevices() async {
    setState(() => _isLoading = true);
    try {
      final shared = await _sharingRepo.getSharedWithMe();
      setState(() {
        _sharedDevices = shared;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading shared devices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundColor
          : AppTheme.lightBackgroundColor,
      appBar: AppBar(
        title: const Text('Shared with Me'),
        backgroundColor: isDark
            ? AppTheme.backgroundColor
            : AppTheme.lightBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScanDeviceQRScreen(),
                ),
              ).then((_) => _loadSharedDevices());
            },
            tooltip: 'Scan QR Code',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sharedDevices.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadSharedDevices,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sharedDevices.length,
                itemBuilder: (context, index) {
                  final shared = _sharedDevices[index];
                  return Card(
                    color: AppTheme.getCardColor(context),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getDeviceIcon(shared.deviceType ?? ''),
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      title: Text(
                        shared.deviceName ?? 'Unknown Device',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Type: ${_getDeviceTypeName(shared.deviceType ?? '')}',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Owner: ${shared.ownerEmail ?? 'Unknown'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                shared.canControl
                                    ? Icons.touch_app
                                    : Icons.visibility,
                                size: 14,
                                color: shared.canControl
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                shared.canControl ? 'Can Control' : 'View Only',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: shared.canControl
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.share_outlined,
              size: 80,
              color: AppTheme.getTextHint(context),
            ),
            const SizedBox(height: 16),
            Text(
              'No Shared Devices',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Devices shared with you will appear here.\nControl them from your dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScanDeviceQRScreen(),
                  ),
                ).then((_) => _loadSharedDevices());
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDeviceTypeName(String type) {
    switch (type.toLowerCase()) {
      case 'relay':
        return 'Switch/Relay';
      case 'light':
        return 'Light';
      case 'shutter':
        return 'Shutter/Blind';
      case 'dimmer':
        return 'Dimmer';
      case 'switch':
        return 'Switch';
      default:
        return type.isNotEmpty ? type : 'Device';
    }
  }

  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'light':
        return Icons.lightbulb_outline;
      case 'shutter':
        return Icons.blinds;
      case 'switch':
        return Icons.power_settings_new;
      default:
        return Icons.devices;
    }
  }
}
