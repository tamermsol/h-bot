import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import '../theme/app_theme.dart';
import '../models/device.dart';
import '../models/device_share_invitation.dart';
import '../repos/device_sharing_repo.dart';
import '../repos/devices_repo.dart';
import '../widgets/responsive_shell.dart';
import '../l10n/app_strings.dart';

class MultiDeviceShareScreen extends StatefulWidget {
  final String homeId;

  const MultiDeviceShareScreen({super.key, required this.homeId});

  @override
  State<MultiDeviceShareScreen> createState() => _MultiDeviceShareScreenState();
}

class _MultiDeviceShareScreenState extends State<MultiDeviceShareScreen> {
  final DeviceSharingRepo _sharingRepo = DeviceSharingRepo();
  final DevicesRepo _devicesRepo = DevicesRepo();
  final LocalAuthentication _localAuth = LocalAuthentication();

  List<Device> _allDevices = [];
  Set<String> _selectedDeviceIds = {};
  Map<String, DeviceShareInvitation> _invitations = {};
  bool _isLoading = true;
  bool _isGeneratingQR = false;
  String? _multiDeviceQRData;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final devices = await _devicesRepo.listDevicesByHome(widget.homeId);
      setState(() {
        _allDevices = devices;
        _isLoading = false;
      });
      if (devices.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('no_owned_devices_to_share'))),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('multi_device_share_error_loading_devices_e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateMultiDeviceQR() async {
    if (_selectedDeviceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('multi_device_share_please_select_at_least_one_device')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Authenticate with biometrics
    bool authenticated = false;
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (canCheckBiometrics || isDeviceSupported) {
        authenticated = await _localAuth.authenticate(
          localizedReason:
              'Authenticate to share ${_selectedDeviceIds.length} device(s)',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
          ),
        );
      } else {
        authenticated = true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('multi_device_share_authentication_failed_e')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('multi_device_share_authentication_required')),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Generate invitations for all selected devices
    setState(() => _isGeneratingQR = true);
    try {
      final invitations = <Map<String, dynamic>>[];

      for (final deviceId in _selectedDeviceIds) {
        final device = _allDevices.firstWhere((d) => d.id == deviceId);
        final invitation = await _sharingRepo.createInvitation(deviceId);

        invitations.add({
          'invitation_code': invitation.invitationCode,
          'device_id': device.id,
          'device_name': device.deviceName,
          'device_type': device.deviceType.name,
        });

        _invitations[deviceId] = invitation;
      }

      // Create multi-device QR data
      final qrData = jsonEncode({
        'type': 'multi_device_share',
        'devices': invitations,
        'count': invitations.length,
      });

      setState(() {
        _multiDeviceQRData = qrData;
        _isGeneratingQR = false;
      });
    } catch (e) {
      setState(() => _isGeneratingQR = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('multi_device_share_error_generating_qr_e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelQR() async {
    try {
      // Delete all invitations
      for (final invitation in _invitations.values) {
        await _sharingRepo.deleteInvitation(invitation.id);
      }
      setState(() {
        _multiDeviceQRData = null;
        _invitations.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('multi_device_share_error_canceling_qr_e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: context.hBackground,
      appBar: AppBar(
        title: Text(AppStrings.get('multi_device_share_share_multiple_devices')),
        backgroundColor: context.hBackground,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Selected count banner
                if (_selectedDeviceIds.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: HBotColors.primary.withOpacity(0.1),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_selectedDeviceIds.length} device(s) selected',
                            style: TextStyle(
                              color: context.hTextPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedDeviceIds.clear());
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton.icon(
                          onPressed: _isGeneratingQR
                              ? null
                              : _generateMultiDeviceQR,
                          icon: _isGeneratingQR
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.qr_code, size: 18),
                          label: const Text(
                            'Generate',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HBotColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),

                // QR Code Display
                if (_multiDeviceQRData != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: _multiDeviceQRData!,
                          version: QrVersions.auto,
                          size: 250,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sharing ${_selectedDeviceIds.length} device(s)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _cancelQR,
                          icon: const Icon(Icons.close),
                          label: Text(AppStrings.get('multi_device_share_cancel_qr_code')),
                        ),
                      ],
                    ),
                  ),

                // Device List
                Expanded(
                  child: _allDevices.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.devices_other, size: 64, color: context.hTextTertiary),
                              const SizedBox(height: 16),
                              Text(
                                AppStrings.get('no_owned_devices_to_share'),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: context.hTextSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _allDevices.length,
                    itemBuilder: (context, index) {
                      final device = _allDevices[index];
                      final isSelected = _selectedDeviceIds.contains(device.id);

                      return Card(
                        color: context.hCard,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedDeviceIds.add(device.id);
                              } else {
                                _selectedDeviceIds.remove(device.id);
                              }
                            });
                          },
                          title: Text(
                            device.deviceName,
                            style: TextStyle(
                              color: context.hTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            device.deviceType.toString().split('.').last,
                            style: TextStyle(
                              color: context.hTextSecondary,
                            ),
                          ),
                          secondary: Icon(
                            Icons.devices,
                            color: isSelected
                                ? HBotColors.primary
                                : context.hTextSecondary,
                          ),
                          activeColor: HBotColors.primary,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
