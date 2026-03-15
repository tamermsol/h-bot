import 'package:flutter/material.dart';
import '../services/wifi_permission_service.dart';
import '../services/platform_helper.dart';
import '../theme/app_theme.dart';

/// Widget that gates Wi-Fi functionality behind proper permissions
class WiFiPermissionGate extends StatefulWidget {
  final Widget child;
  final String title;
  final String description;
  final VoidCallback? onPermissionsGranted;

  const WiFiPermissionGate({
    super.key,
    required this.child,
    this.title = 'Wi-Fi Permissions Required',
    this.description =
        'This feature requires Wi-Fi and location permissions to work properly.',
    this.onPermissionsGranted,
  });

  @override
  State<WiFiPermissionGate> createState() => _WiFiPermissionGateState();
}

class _WiFiPermissionGateState extends State<WiFiPermissionGate> {
  WiFiPermissionStatus _permissionStatus =
      WiFiPermissionStatus.permissionsDenied;
  bool _isLoading = false;
  String _explanation = '';
  bool _bypassGate = false; // Allow user to proceed anyway on iOS

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await WiFiPermissionService.checkPermissions();
      final explanation =
          await WiFiPermissionService.getPermissionExplanation();

      setState(() {
        _permissionStatus = status;
        _explanation = explanation;
        _isLoading = false;
      });

      // Notify parent if permissions are now granted
      if (status == WiFiPermissionStatus.granted &&
          widget.onPermissionsGranted != null) {
        widget.onPermissionsGranted!();
      }
    } catch (e) {
      setState(() {
        _permissionStatus = WiFiPermissionStatus.permissionsDenied;
        _explanation = 'Failed to check permissions: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await WiFiPermissionService.requestPermissions();
      setState(() {
        _permissionStatus = status;
        _isLoading = false;
      });

      // Notify parent if permissions are now granted
      if (status == WiFiPermissionStatus.granted &&
          widget.onPermissionsGranted != null) {
        widget.onPermissionsGranted!();
      }
    } catch (e) {
      setState(() {
        _permissionStatus = WiFiPermissionStatus.permissionsDenied;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openLocationSettings() async {
    final opened = await WiFiPermissionService.openLocationSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open location settings. Please enable manually.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    // Recheck permissions after user returns
    await Future.delayed(const Duration(seconds: 1));
    _checkPermissions();
  }

  Future<void> _openAppSettings() async {
    final opened = await WiFiPermissionService.openAppSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open app settings. Please enable permissions manually.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    // Recheck permissions after user returns
    await Future.delayed(const Duration(seconds: 1));
    _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: HBotColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: HBotSpacing.space4),
              Text('Checking permissions...'),
            ],
          ),
        ),
      );
    }

    // Allow bypass on iOS or if permissions are granted
    if (_permissionStatus.isGranted || _bypassGate) {
      return widget.child;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: HBotColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _permissionStatus == WiFiPermissionStatus.locationServicesDisabled
                  ? Icons.location_off
                  : Icons.wifi_off,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: HBotSpacing.space6),
            Text(
              _permissionStatus.message,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: HBotColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HBotSpacing.space4),
            Text(
              _explanation,
              style: const TextStyle(
                fontSize: 16,
                color: HBotColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HBotSpacing.space6),
            if (_permissionStatus ==
                WiFiPermissionStatus.locationServicesDisabled) ...[
              ElevatedButton.icon(
                onPressed: _openLocationSettings,
                icon: const Icon(Icons.location_on),
                label: const Text('Turn On Location Services'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HBotColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: HBotSpacing.space6,
                    vertical: HBotSpacing.space4,
                  ),
                ),
              ),
            ] else if (_permissionStatus ==
                WiFiPermissionStatus.permanentlyDenied) ...[
              ElevatedButton.icon(
                onPressed: _openAppSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open App Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HBotColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: HBotSpacing.space6,
                    vertical: HBotSpacing.space4,
                  ),
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.check),
                label: const Text('Grant Permissions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HBotColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: HBotSpacing.space6,
                    vertical: HBotSpacing.space4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: HBotSpacing.space4),
            TextButton.icon(
              onPressed: _checkPermissions,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Again'),
              style: TextButton.styleFrom(
                foregroundColor: HBotColors.primary,
              ),
            ),

            // iOS: Allow user to continue anyway since manual WiFi connection doesn't need permission
            if (isIOS) ...[
              const SizedBox(height: HBotSpacing.space4),
              const Divider(),
              const SizedBox(height: HBotSpacing.space4),
              Text(
                'On iPhone, you can continue without auto-detecting WiFi. You\'ll enter your WiFi name manually.',
                style: const TextStyle(
                  fontSize: 14,
                  color: HBotColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HBotSpacing.space4),
              TextButton(
                onPressed: () {
                  setState(() {
                    _bypassGate = true;
                  });
                  if (widget.onPermissionsGranted != null) {
                    widget.onPermissionsGranted!();
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: HBotColors.primary,
                ),
                child: const Text('Continue Without Auto-Detect'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
