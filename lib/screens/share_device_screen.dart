import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import '../theme/app_theme.dart';
import '../models/device.dart';
import '../models/device_share_invitation.dart';
import '../models/device_share_request.dart';
import '../models/shared_device.dart';
import '../repos/device_sharing_repo.dart';

class ShareDeviceScreen extends StatefulWidget {
  final Device device;

  const ShareDeviceScreen({super.key, required this.device});

  @override
  State<ShareDeviceScreen> createState() => _ShareDeviceScreenState();
}

class _ShareDeviceScreenState extends State<ShareDeviceScreen> {
  final DeviceSharingRepo _repo = DeviceSharingRepo();
  final LocalAuthentication _localAuth = LocalAuthentication();
  DeviceShareInvitation? _invitation;
  List<DeviceShareRequest> _pendingRequests = [];
  List<SharedDevice> _sharedWith = [];
  bool _isLoading = true;
  bool _isGeneratingQR = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _repo.getPendingRequests();
      final shared = await _repo.getDevicesIShared();

      setState(() {
        _pendingRequests = requests
            .where((r) => r.deviceId == widget.device.id)
            .toList();
        _sharedWith = shared
            .where((s) => s.deviceId == widget.device.id)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateQRCode() async {
    // Show authentication method choice dialog
    final authChoice = await _showAuthMethodDialog();
    if (authChoice == null) return; // User cancelled

    bool authenticated = false;

    try {
      // Check if device supports authentication
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!isDeviceSupported) {
        // Device doesn't support authentication, proceed without auth
        authenticated = true;
      } else {
        // Authenticate based on user's choice
        if (authChoice == 'biometric') {
          // Try biometric only
          final canCheckBiometrics = await _localAuth.canCheckBiometrics;
          if (canCheckBiometrics) {
            authenticated = await _localAuth.authenticate(
              localizedReason: 'Use biometric to generate QR code',
              options: const AuthenticationOptions(
                stickyAuth: true,
                biometricOnly: true, // Biometric only for this choice
                useErrorDialogs: true,
              ),
            );
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Biometric not available. Please use device password.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
        } else {
          // Use device credentials (PIN/password/pattern)
          authenticated = await _localAuth.authenticate(
            localizedReason: 'Use your device password/PIN to generate QR code',
            options: const AuthenticationOptions(
              stickyAuth: true,
              biometricOnly: false, // Allow all credential types
              useErrorDialogs: true,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Authentication error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication cancelled or failed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required to generate QR code'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Authentication successful, generate QR code
    setState(() => _isGeneratingQR = true);
    try {
      final invitation = await _repo.createInvitation(widget.device.id);
      setState(() {
        _invitation = invitation;
        _isGeneratingQR = false;
      });
    } catch (e) {
      setState(() => _isGeneratingQR = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating QR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showAuthMethodDialog() async {
    final canCheckBiometrics = await _localAuth.canCheckBiometrics;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.cardLight,
        title: const Text('Choose Authentication Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canCheckBiometrics)
              ListTile(
                leading: const Icon(
                  Icons.fingerprint,
                  color: HBotColors.primary,
                  size: 32,
                ),
                title: const Text('Biometric'),
                subtitle: const Text('Fingerprint, face, or iris'),
                onTap: () => Navigator.pop(context, 'biometric'),
              ),
            ListTile(
              leading: const Icon(
                Icons.lock,
                color: HBotColors.primary,
                size: 32,
              ),
              title: const Text('Device Password'),
              subtitle: const Text('PIN, password, or pattern'),
              onTap: () => Navigator.pop(context, 'password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(DeviceShareRequest request) async {
    final permission = await _showPermissionDialog();
    if (permission == null) return;

    try {
      await _repo.approveRequest(request.id, permission);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectRequest(DeviceShareRequest request) async {
    try {
      await _repo.rejectRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<PermissionLevel?> _showPermissionDialog() async {
    return showDialog<PermissionLevel>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HBotColors.cardLight,
        title: const Text('Choose Permission Level'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.visibility,
                color: HBotColors.primary,
              ),
              title: const Text('View Only'),
              subtitle: const Text('Can see device status'),
              onTap: () => Navigator.pop(context, PermissionLevel.view),
            ),
            ListTile(
              leading: const Icon(
                Icons.touch_app,
                color: HBotColors.primary,
              ),
              title: const Text('Control'),
              subtitle: const Text('Can control the device'),
              onTap: () => Navigator.pop(context, PermissionLevel.control),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: HBotColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Share Device'),
        backgroundColor: HBotColors.backgroundLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Device Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: HBotColors.cardLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.devices,
                            color: HBotColors.primary,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.device.deviceName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: HBotColors.textPrimaryLight,
                                  ),
                                ),
                                Text(
                                  widget.device.deviceType
                                      .toString()
                                      .split('.')
                                      .last,
                                  style: TextStyle(
                                    color: HBotColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // QR Code Section
                    Text(
                      'Share via QR Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: HBotColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose biometric or device password for authentication',
                      style: TextStyle(
                        fontSize: 13,
                        color: HBotColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_invitation == null)
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _isGeneratingQR ? null : _generateQRCode,
                          icon: _isGeneratingQR
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.qr_code),
                          label: Text(
                            _isGeneratingQR
                                ? 'Generating...'
                                : 'Generate QR Code',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HBotColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: jsonEncode({
                                'type': 'device_share',
                                'invitation_code': _invitation!.invitationCode,
                                'device_id': widget.device.id,
                                'device_name': widget.device.deviceName,
                              }),
                              version: QrVersions.auto,
                              size: 250,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Expires: ${_invitation!.expiresAt.toLocal().toString().substring(0, 16)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () async {
                                await _repo.deleteInvitation(_invitation!.id);
                                setState(() => _invitation = null);
                              },
                              icon: const Icon(Icons.close),
                              label: const Text('Cancel QR Code'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Pending Requests
                    if (_pendingRequests.isNotEmpty) ...[
                      Text(
                        'Pending Requests (${_pendingRequests.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: HBotColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._pendingRequests.map(
                        (request) => Card(
                          color: HBotColors.cardLight,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: HBotColors.primary,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(
                              request.requesterName ?? request.requesterEmail,
                              style: TextStyle(
                                color: HBotColors.textPrimaryLight,
                              ),
                            ),
                            subtitle: Text(
                              request.requesterEmail,
                              style: TextStyle(
                                color: HBotColors.textSecondaryLight,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _approveRequest(request),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _rejectRequest(request),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Shared With
                    if (_sharedWith.isNotEmpty) ...[
                      Text(
                        'Shared With (${_sharedWith.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: HBotColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._sharedWith.map(
                        (shared) => Card(
                          color: HBotColors.cardLight,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: HBotColors.primary,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(
                              shared.ownerEmail ?? 'User',
                              style: TextStyle(
                                color: HBotColors.textPrimaryLight,
                              ),
                            ),
                            subtitle: Text(
                              'Permission: ${shared.permissionLevel.name}',
                              style: TextStyle(
                                color: HBotColors.textSecondaryLight,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: HBotColors.cardLight,
                                    title: const Text('Revoke Access?'),
                                    content: const Text(
                                      'This user will no longer have access to this device.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text(
                                          'Revoke',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _repo.revokeSharing(shared.id);
                                  _loadData();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
