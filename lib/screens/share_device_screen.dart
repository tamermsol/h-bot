import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import '../models/device.dart';
import '../models/device_share_invitation.dart';
import '../models/device_share_request.dart';
import '../models/shared_device.dart';
import '../repos/device_sharing_repo.dart';
import '../utils/phosphor_icons.dart';

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
            content: Text('Error loading data: $e', style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: const Color(0xFFEF4444),
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
                    style: TextStyle(fontFamily: 'Inter'),
                  ),
                  backgroundColor: Color(0xFFF59E0B),
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
            content: Text(
              'Authentication cancelled or failed',
              style: TextStyle(fontFamily: 'Inter'),
            ),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
      }
      return;
    }

    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Authentication required to generate QR code',
              style: TextStyle(fontFamily: 'Inter'),
            ),
            backgroundColor: Color(0xFFF59E0B),
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
            content: Text('Error generating QR: $e', style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: const Color(0xFFEF4444),
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
        backgroundColor: const Color(0xFFF5F7FA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Choose Authentication Method',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canCheckBiometrics)
              ListTile(
                leading: Icon(
                  HBotIcons.lock,
                  color: Color(0xFF0883FD),
                  size: 32,
                ),
                title: const Text(
                  'Biometric',
                  style: TextStyle(fontFamily: 'Inter', color: Color(0xFF1F2937)),
                ),
                subtitle: const Text(
                  'Fingerprint, face, or iris',
                  style: TextStyle(fontFamily: 'Inter', color: Color(0xFF6B7280)),
                ),
                onTap: () => Navigator.pop(context, 'biometric'),
              ),
            ListTile(
              leading: Icon(
                HBotIcons.lock,
                color: const Color(0xFF0883FD),
                size: 32,
              ),
              title: const Text(
                'Device Password',
                style: TextStyle(fontFamily: 'Inter', color: Color(0xFF1F2937)),
              ),
              subtitle: const Text(
                'PIN, password, or pattern',
                style: TextStyle(fontFamily: 'Inter', color: Color(0xFF6B7280)),
              ),
              onTap: () => Navigator.pop(context, 'password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Inter', color: Color(0xFF6B7280)),
            ),
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
            content: Text(
              'Request approved!',
              style: TextStyle(fontFamily: 'Inter'),
            ),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: const Color(0xFFEF4444),
          ),
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
            content: Text(
              'Request rejected',
              style: TextStyle(fontFamily: 'Inter'),
            ),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<PermissionLevel?> _showPermissionDialog() async {
    return showDialog<PermissionLevel>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F7FA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Choose Permission Level',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                HBotIcons.visibility,
                color: const Color(0xFF0883FD),
              ),
              title: const Text(
                'View Only',
                style: TextStyle(fontFamily: 'Inter', color: Color(0xFF1F2937)),
              ),
              subtitle: const Text(
                'Can see device status',
                style: TextStyle(fontFamily: 'Inter', color: Color(0xFF6B7280)),
              ),
              onTap: () => Navigator.pop(context, PermissionLevel.view),
            ),
            ListTile(
              leading: Icon(
                HBotIcons.power,
                color: const Color(0xFF0883FD),
              ),
              title: const Text(
                'Control',
                style: TextStyle(fontFamily: 'Inter', color: Color(0xFF1F2937)),
              ),
              subtitle: const Text(
                'Can control the device',
                style: TextStyle(fontFamily: 'Inter', color: Color(0xFF6B7280)),
              ),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                HBotIcons.back,
                color: Color(0xFF1F2937),
                size: 18,
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Share Device',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(HBotIcons.refresh, color: const Color(0xFF1F2937)),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0883FD)))
          : RefreshIndicator(
              color: const Color(0xFF0883FD),
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
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            HBotIcons.devices,
                            color: const Color(0xFF0883FD),
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.device.deviceName,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  widget.device.deviceType
                                      .toString()
                                      .split('.')
                                      .last,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF6B7280),
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
                    const Text(
                      'Share via QR Code',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose biometric or device password for authentication',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_invitation == null)
                      Center(
                        child: SizedBox(
                          height: 50,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x590883FD),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _isGeneratingQR ? null : _generateQRCode,
                              icon: _isGeneratingQR
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(HBotIcons.devices),
                              label: Text(
                                _isGeneratingQR
                                    ? 'Generating...'
                                    : 'Generate QR Code',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
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
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () async {
                                await _repo.deleteInvitation(_invitation!.id);
                                setState(() => _invitation = null);
                              },
                              icon: Icon(HBotIcons.close, color: const Color(0xFFEF4444)),
                              label: const Text(
                                'Cancel QR Code',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Pending Requests
                    if (_pendingRequests.isNotEmpty) ...[
                      Text(
                        'Pending Requests (${_pendingRequests.length})',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._pendingRequests.map(
                        (request) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF0883FD),
                              child: Icon(HBotIcons.person, color: Colors.white),
                            ),
                            title: Text(
                              request.requesterName ?? request.requesterEmail,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            subtitle: Text(
                              request.requesterEmail,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    HBotIcons.check,
                                    color: const Color(0xFF22C55E),
                                  ),
                                  onPressed: () => _approveRequest(request),
                                ),
                                IconButton(
                                  icon: Icon(
                                    HBotIcons.close,
                                    color: const Color(0xFFEF4444),
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
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._sharedWith.map(
                        (shared) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF0883FD),
                              child: Icon(HBotIcons.person, color: Colors.white),
                            ),
                            title: Text(
                              shared.ownerEmail ?? 'User',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            subtitle: Text(
                              'Permission: ${shared.permissionLevel.name}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(HBotIcons.delete, color: const Color(0xFFEF4444)),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFFF5F7FA),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Text(
                                      'Revoke Access?',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    content: const Text(
                                      'This user will no longer have access to this device.',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text(
                                          'Revoke',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            color: Color(0xFFEF4444),
                                          ),
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
