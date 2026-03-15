import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../services/platform_helper.dart';
import '../services/ios_hotspot_service.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/home.dart';
import '../models/room.dart';
import '../models/device.dart';
import '../models/tasmota_device_info.dart';
import '../models/wifi_profile.dart';
import '../services/enhanced_wifi_service.dart';
import '../services/wifi_permission_service.dart';
import '../services/tasmota_mqtt_service.dart';
import '../services/smart_home_service.dart';
import '../services/simplified_device_service.dart';
import '../services/mqtt_device_manager.dart';
import '../services/platform_service.dart';
import '../services/network_connectivity_service.dart';
import '../repos/device_management_repo.dart';
import '../utils/channel_detection_utils.dart';
import '../widgets/wifi_permission_gate.dart';
import '../widgets/enhanced_device_control_widget.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_shell.dart';

/// Complete device pairing flow: Wi-Fi Setup → Device Discovery → Provisioning → Success
class AddDeviceFlowScreen extends StatefulWidget {
  final Home home;
  final Room? room;
  final VoidCallback? onDeviceAdded;

  const AddDeviceFlowScreen({
    super.key,
    required this.home,
    this.room,
    this.onDeviceAdded,
  });

  @override
  State<AddDeviceFlowScreen> createState() => _AddDeviceFlowScreenState();
}

enum PairingStep { wifiSetup, deviceDiscovery, provisioning, success }

class _AddDeviceFlowScreenState extends State<AddDeviceFlowScreen> {
  final EnhancedWiFiService _wifiService = EnhancedWiFiService();
  final TasmotaMqttService _mqttService = TasmotaMqttService();
  final SmartHomeService _smartHomeService = SmartHomeService();
  final SimplifiedDeviceService _deviceService = SimplifiedDeviceService();
  final MqttDeviceManager _mqttManager = MqttDeviceManager();
  final DeviceManagementRepo _deviceManagementRepo = DeviceManagementRepo();

  final TextEditingController _wifiPasswordController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _deviceAPController = TextEditingController(); // Separate controller for device AP name

  PairingStep _currentStep = PairingStep.wifiSetup;
  bool _isLoading = false;
  String _statusMessage = '';
  String _debugLog = '';

  // Wi-Fi Setup
  String? _currentSSID;
  String? _wifiPassword;
  bool _passwordVisible = false;
  bool _rememberPassword = true;
  bool _manualSSIDEntry = false; // Show manual SSID input field
  bool _ssidFromLiveDetection = false; // true = live WiFi detection, false = saved profile
  bool _isDetectingSSID = false; // Loading state for auto-detect button
  String? _detectMessage; // Feedback message for auto-detect
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _apSuffixController = TextEditingController();

  // Device Discovery
  List<String> _availableDeviceAPs = [];
  String? _selectedDeviceAP;
  bool _isConnectedToDevice = false;

  // Provisioning & Success
  TasmotaDeviceInfo? _discoveredDevice;
  Device? _createdDevice;

  // Deferred device creation (when offline)
  Map<String, dynamic>? _pendingDeviceData;

  // Auto-detection timer for manual AP connection
  Timer? _apDetectionTimer;

  // Room selection
  List<Room> _availableRooms = [];
  Room? _selectedRoom;

  @override
  void initState() {
    super.initState();
    _initializePairing();
    _loadAvailableRooms();
  }

  @override
  void dispose() {
    _wifiPasswordController.dispose();
    _deviceNameController.dispose();
    _ssidController.dispose();
    _apSuffixController.dispose();
    _deviceAPController.dispose();
    _mqttService.dispose();
    _apDetectionTimer?.cancel();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  Future<void> _initializePairing() async {
    _addDebugLog('Initializing device pairing flow (platform: ${isIOS ? "iOS" : "Android"})');

    // Set initial loading state
    _safeSetState(() {
      _currentSSID = null; // Show loading initially
    });

    try {
      // Fields start empty — user presses auto-detect or types manually
      _addDebugLog('WiFi fields start empty. Press auto-detect or enter manually.');
    } catch (e) {
      _addDebugLog('Error initializing: $e');
    }
  }

  Future<void> _refreshCurrentSSID() async {
    _safeSetState(() {
      _isDetectingSSID = true;
      _detectMessage = 'Detecting WiFi network...';
    });
    try {
      _addDebugLog('Refreshing current SSID...');

      // Try to request permissions but don't block on failure —
      // the iOS APIs themselves will return null if permissions aren't right
      try {
        var permissionStatus = await WiFiPermissionService.checkPermissions();
        _addDebugLog('Permission status: ${permissionStatus.message}');
        if (!permissionStatus.isGranted) {
          _addDebugLog('Requesting permissions...');
          permissionStatus = await WiFiPermissionService.requestPermissions();
          _addDebugLog('After request: ${permissionStatus.message}');
          if (permissionStatus == WiFiPermissionStatus.permanentlyDenied) {
            _addDebugLog('Permissions marked as permanently denied by Geolocator — trying SSID read anyway');
          }
        }
      } catch (e) {
        _addDebugLog('Permission check error (proceeding anyway): $e');
      }

      // Small delay to let permission state propagate
      await Future.delayed(const Duration(milliseconds: 500));

      String? ssid;
      if (isIOS) {
        // iOS 14+: SSID reading requires PRECISE location, not just "When In Use"
        // Request temporary full accuracy via native plugin
        _addDebugLog('iOS: Requesting precise location (required for SSID)...');
        try {
          final hasPrecise = await IOSHotspotService.requestPreciseLocation();
          _addDebugLog('iOS: Precise location granted: $hasPrecise');
          if (!hasPrecise) {
            // Also try Geolocator as fallback to trigger the prompt
            await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 5),
            );
          }
        } catch (e) {
          _addDebugLog('iOS: Precise location request failed: $e (continuing anyway)');
        }

        // Wait for iOS to register the precise location grant
        await Future.delayed(const Duration(milliseconds: 500));

        // Try native plugin first (NEHotspot + CNC fallback)
        _addDebugLog('iOS: Reading SSID via IOSHotspotService (NEHotspot + CNC fallback)...');
        ssid = await IOSHotspotService.getCurrentSSID();
        _addDebugLog('iOS: First attempt returned: ${ssid ?? "null"}');

        // Retry after 1 second if null
        if (ssid == null || ssid.isEmpty) {
          _addDebugLog('iOS: Retrying in 1s...');
          await Future.delayed(const Duration(seconds: 1));
          ssid = await IOSHotspotService.getCurrentSSID();
          _addDebugLog('iOS: Retry returned: ${ssid ?? "null"}');
        }

        // Final fallback: network_info_plus
        if (ssid == null || ssid.isEmpty) {
          _addDebugLog('iOS: Trying NetworkInfo fallback...');
          final networkInfo = NetworkInfo();
          ssid = await networkInfo.getWifiName();
          ssid = ssid?.replaceAll('"', '');
          if (ssid == '<unknown ssid>' || (ssid != null && ssid.isEmpty)) {
            ssid = null;
          }
          _addDebugLog('iOS: NetworkInfo returned: ${ssid ?? "null"}');
        }
      } else {
        // Android: permissions work fine, use service normally
        ssid = await _wifiService.getCurrentSSID();
      }

      _safeSetState(() {
        // Only overwrite if we actually detected something
        // Don't null out a saved profile SSID
        if (ssid != null && ssid.isNotEmpty) {
          _currentSSID = ssid;
          _ssidController.text = ssid;
          _ssidFromLiveDetection = true;
        }
      });

      if (ssid != null) {
        _addDebugLog('✅ Current SSID detected: $ssid');
        _safeSetState(() {
          _detectMessage = '✅ Connected to: $ssid';
          _isDetectingSSID = false;
        });
        // Try to load saved password for this SSID from DB
        try {
          final profile = await _smartHomeService.getDefaultWiFiProfile();
          if (profile != null && profile.ssid == ssid && profile.password.isNotEmpty) {
            _safeSetState(() {
              _wifiPassword = profile.password;
              _wifiPasswordController.text = profile.password;
              _detectMessage = '✅ Connected to: $ssid (password filled)';
            });
            _addDebugLog('✅ Auto-filled password from saved profile');
          }
        } catch (e) {
          _addDebugLog('Could not load saved password: $e');
        }
      } else {
        _addDebugLog(
          '⚠️ SSID not available - please enter manually. On iOS, ensure Precise Location is enabled in Settings > Privacy > Location Services.',
        );
        _safeSetState(() {
          _detectMessage = '⚠️ Could not detect WiFi. Check:\n• WiFi is connected (not cellular)\n• Settings → MB Hbot → Location → "While Using"\n• Settings → MB Hbot → Location → Precise Location ON\n• Then try again';
          _isDetectingSSID = false;
        });
      }

      // If null, that's OK - we'll show manual entry UI
    } catch (e) {
      _addDebugLog('❌ Error refreshing SSID: $e');
      _safeSetState(() {
        _isDetectingSSID = false;
        _detectMessage = '❌ Error: $e\nPlease enter WiFi details manually.';
      });
    }
  }

  void _addDebugLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _safeSetState(() {
      _debugLog += '[$timestamp] $message\n';
    });
    debugPrint('[DevicePairing] $message');
  }

  /// Show debug log in a bottom sheet with copy/share buttons
  void _showDebugLog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Header with actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, size: 20),
                  const SizedBox(width: 8),
                  const Text('Debug Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _debugLog));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Log copied to clipboard'), duration: Duration(seconds: 1)),
                      );
                    },
                    tooltip: 'Copy',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    onPressed: () {
                      Share.share('H-Bot Device Pairing Log:\n\n$_debugLog');
                    },
                    tooltip: 'Share',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Log content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _debugLog.isEmpty ? 'No log entries yet.' : _debugLog,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Load available rooms for the current home
  Future<void> _loadAvailableRooms() async {
    try {
      _addDebugLog('Loading available rooms...');
      final rooms = await _smartHomeService.getRooms(widget.home.id);
      _safeSetState(() {
        _availableRooms = rooms;
        _selectedRoom = widget.room; // Pre-select if passed from parent
      });
      _addDebugLog('Loaded ${rooms.length} rooms');
    } catch (e) {
      _addDebugLog('Error loading rooms: $e');
    }
  }

  @override
  Widget build(BuildContext context) {

    // iOS: Skip permission gate - location permission only needed for auto-detect SSID
    // Local Network permission will be requested automatically when accessing 192.168.4.1
    if (isIOS) {
      return Scaffold(
        backgroundColor: HBotColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: HBotColors.backgroundLight,
          title: const Text('Add Device'),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report, size: 20),
              onPressed: _showDebugLog,
              tooltip: 'Debug Log',
            ),
          ],
        ),
        body: _buildCurrentStep(),
      );
    }

    // Android: Keep permission gate for location and nearby WiFi devices permissions
    return WiFiPermissionGate(
      title: 'Add Device',
      description:
          'Wi-Fi and location permissions are required to connect to devices and read network information.',
      onPermissionsGranted: () {
        // Refresh SSID when permissions are granted
        _refreshCurrentSSID();
        // Also refresh device discovery
        if (_currentStep == PairingStep.deviceDiscovery) {
          _startDeviceDiscovery();
        }
      },
      child: Scaffold(
        backgroundColor: HBotColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: HBotColors.backgroundLight,
          title: const Text('Add Device'),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report, size: 20),
              onPressed: _showDebugLog,
              tooltip: 'Debug Log',
            ),
          ],
        ),
        body: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case PairingStep.wifiSetup:
        return _buildWiFiSetupStep();
      case PairingStep.deviceDiscovery:
        return _buildDeviceDiscoveryStep();
      case PairingStep.provisioning:
        return _buildProvisioningStep();
      case PairingStep.success:
        return _buildSuccessStep();
    }
  }

  // Step 1: Wi-Fi Setup (like competitor's 2.jpeg)
  Widget _buildWiFiSetupStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: HBotSpacing.space6,
        right: HBotSpacing.space6,
        top: HBotSpacing.space6,
        bottom:
            HBotSpacing.space6 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose a 2.4GHz WiFi for device pairing and enter the right password',
            style: TextStyle(fontSize: 16, color: HBotColors.textSecondaryLight),
          ),
          const SizedBox(height: HBotSpacing.space2),
          const Text(
            'If your 2.4GHz WiFi and 5GHz WiFi share the same WiFi SSID, you\'re recommended to change your router settings or try compatible pairing mode.',
            style: TextStyle(fontSize: 14, color: HBotColors.textSecondaryLight),
          ),
          const SizedBox(height: HBotSpacing.space6),

          // 2.4GHz indicator
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: HBotSpacing.space2),
              const Text(
                'WiFi-2.4GHz',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: HBotSpacing.space6),

          // Wi-Fi SSID input - auto-detected or manual
          if (_currentSSID != null && !_manualSSIDEntry && _ssidFromLiveDetection)
            // Auto-detected SSID (live from WiFi)
            Container(
              padding: const EdgeInsets.all(HBotSpacing.space4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi, color: Colors.green),
                  const SizedBox(width: HBotSpacing.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentSSID!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'Auto-detected',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _safeSetState(() {
                        _manualSSIDEntry = true;
                        _ssidController.text = _currentSSID ?? '';
                      });
                    },
                    child: const Text('Edit'),
                  ),
                ],
              ),
            )
          else
            // Manual SSID entry
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _ssidController,
                  decoration: InputDecoration(
                    labelText: 'Wi-Fi Network Name (SSID)',
                    hintText: 'Enter your 2.4GHz Wi-Fi name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.wifi),
                  ),
                ),
                const SizedBox(height: HBotSpacing.space2),
                Container(
                  padding: const EdgeInsets.all(HBotSpacing.space2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: HBotSpacing.space2),
                      Expanded(
                        child: Text(
                          'If your router uses the same name for 2.4GHz and 5GHz, make sure you\'re connected to the 2.4GHz band.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: HBotSpacing.space2),
                ElevatedButton.icon(
                  onPressed: _isDetectingSSID ? null : _refreshCurrentSSID,
                  icon: _isDetectingSSID 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.wifi_find, size: 18),
                  label: Text(_isDetectingSSID ? 'Detecting...' : (_currentSSID == null ? 'Auto-detect WiFi' : 'Re-detect WiFi')),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                if (_detectMessage != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _detectMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _detectMessage!.startsWith('✅') ? Colors.green[700] : 
                               _detectMessage!.startsWith('⚠️') ? Colors.orange[700] : 
                               _detectMessage!.startsWith('❌') ? Colors.red[700] : Colors.grey[600],
                      ),
                    ),
                  ),
                  if (!_detectMessage!.startsWith('✅'))
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await Geolocator.openAppSettings();
                        } catch (_) {
                          await Geolocator.openLocationSettings();
                        }
                      },
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Open App Settings'),
                    ),
                ],
              ],
            ),
          const SizedBox(height: HBotSpacing.space4),

          // Password field
          TextField(
            controller: _wifiPasswordController,
            obscureText: !_passwordVisible,
            decoration: InputDecoration(
              hintText: 'Enter WiFi password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  _safeSetState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: HBotSpacing.space4),

          // Remember password checkbox
          Row(
            children: [
              Checkbox(
                value: _rememberPassword,
                onChanged: (value) {
                  _safeSetState(() {
                    _rememberPassword = value ?? true;
                  });
                },
              ),
              const Text('Remember password'),
            ],
          ),

          const SizedBox(height: HBotSpacing.space6),

          // Next button
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canProceedFromWiFiSetup()
                      ? _proceedToDeviceDiscovery
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HBotColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: HBotSpacing.space4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),),);
  }

  bool _canProceedFromWiFiSetup() {
    // Can proceed if we have SSID (auto or manual) and password
    final hasSSID = _currentSSID != null || _ssidController.text.isNotEmpty;
    final hasPassword = _wifiPasswordController.text.isNotEmpty;
    return hasSSID && hasPassword;
  }

  String _getEffectiveSSID() {
    // Return manual SSID if entered, otherwise auto-detected
    if (_manualSSIDEntry || _currentSSID == null) {
      return _ssidController.text.trim();
    }
    return _currentSSID!;
  }

  Future<void> _proceedToDeviceDiscovery() async {
    _addDebugLog('Proceeding to device discovery');

    // Get the effective SSID (manual or auto-detected)
    final effectiveSSID = _getEffectiveSSID();

    // Save Wi-Fi profile if user opted to remember
    if (_rememberPassword &&
        effectiveSSID.isNotEmpty &&
        _wifiPasswordController.text.isNotEmpty) {
      try {
        final request = WiFiProfileRequest(
          ssid: effectiveSSID,
          password: _wifiPasswordController.text,
          isDefault: true,
        );

        // Check if profile already exists
        final existingProfile = await _smartHomeService.findWiFiProfileBySSID(
          effectiveSSID,
        );
        if (existingProfile != null) {
          // Update existing profile
          await _smartHomeService.updateWiFiProfile(
            existingProfile.id,
            request,
          );
          _addDebugLog('Updated existing Wi-Fi profile for $effectiveSSID');
        } else {
          // Create new profile
          await _smartHomeService.createWiFiProfile(request);
          _addDebugLog('Created new Wi-Fi profile for $effectiveSSID');
        }
      } catch (e) {
        _addDebugLog('Error saving Wi-Fi profile: $e');
        // Don't block the flow if profile saving fails
      }
    } else {
      _addDebugLog(
        'Wi-Fi profile not saved (remember password: $_rememberPassword)',
      );
    }

    _safeSetState(() {
      _wifiPassword = _wifiPasswordController.text;
      _currentSSID = effectiveSSID; // Update with effective SSID
      _currentStep = PairingStep.deviceDiscovery;
    });

    // Start scanning for devices
    _startDeviceDiscovery();
  }

  // Step 2: Device Discovery (like competitor's 4.jpeg - "Searching for devices...")
  Widget _buildDeviceDiscoveryStep() {
    // iOS: Show scanning UI with instructions to put device in pairing mode
    // We'll auto-connect using NEHotspotConfigurationManager when device AP is detected
    if (isIOS && !_isConnectedToDevice && _availableDeviceAPs.isEmpty) {
      // Start auto-detection timer
      if (_apDetectionTimer == null || !_apDetectionTimer!.isActive) {
        _startApDetectionTimer();
      }
      return _buildIOSAutoDiscoveryView();
    }

    // Android can scan and connect automatically
    return Padding(
      padding: const EdgeInsets.all(HBotSpacing.space6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
        children: [
          const SizedBox(height: HBotSpacing.space6 * 2),

          // Searching animation
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  HBotColors.primary.withOpacity(0.3),
                  HBotColors.primary.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HBotColors.primary.withOpacity(0.2),
                ),
                child: const Icon(
                  Icons.wifi_find,
                  size: 50,
                  color: HBotColors.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: HBotSpacing.space6),

          Text(
            _isConnectedToDevice
                ? 'Device Connected!'
                : 'Searching for devices...',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: HBotColors.textPrimaryLight,
            ),
          ),

          const SizedBox(height: HBotSpacing.space4),

          Text(
            _statusMessage.isNotEmpty
                ? _statusMessage
                : 'Please set the device in pairing mode based on the user manual.',
            style: const TextStyle(fontSize: 16, color: HBotColors.textSecondaryLight),
            textAlign: TextAlign.center,
          ),

          if (_availableDeviceAPs.isNotEmpty) ...[
            const SizedBox(height: HBotSpacing.space6),
            Text(
              'Found ${_availableDeviceAPs.length} device${_availableDeviceAPs.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: HBotColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),
            ...(_availableDeviceAPs.map(
              (ap) => Card(
                child: ListTile(
                  leading: const Icon(Icons.wifi),
                  title: Text(ap),
                  trailing: _selectedDeviceAP == ap
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () => _connectToDeviceAP(ap),
                ),
              ),
            )),
          ],

          const Spacer(),

          if (_isLoading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: HBotSpacing.space4),
          ],

          // Refresh button only
          Center(
            child: TextButton.icon(
              onPressed: _isLoading ? null : _startDeviceDiscovery,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(
                foregroundColor: HBotColors.primary,
              ),
            ),
          ),
        ],
      ),
    ),),);
  }

  /// iOS auto-discovery view - scans for device AP and connects automatically
  Widget _buildIOSAutoDiscoveryView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(HBotSpacing.space6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: HBotSpacing.space4),

              // Step indicator pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: HBotColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Connect to Device',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HBotColors.primary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // WiFi icon with pulse effect
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      HBotColors.primary.withOpacity(0.2),
                      HBotColors.primary.withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HBotColors.primary.withOpacity(0.15),
                    ),
                    child: Icon(
                      _isLoading ? Icons.wifi : Icons.wifi_find,
                      size: 32,
                      color: HBotColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Status text
              Text(
                _isLoading
                    ? 'Waiting for device connection...'
                    : 'Connect to your device\'s WiFi',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: HBotSpacing.space4),

              // Instructions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    _buildInstructionStep(
                      number: '1',
                      text: 'Make sure your device is in pairing mode',
                      subtitle: 'LED should be blinking rapidly',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      number: '2',
                      text: 'Tap "Open WiFi Settings" below',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      number: '3',
                      text: 'Connect to the network starting with "hbot-"',
                      subtitle: 'If asked about no internet, tap "Use Without Internet"',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      number: '4',
                      text: 'Return to this app',
                      subtitle: 'It will detect the connection automatically',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: HBotSpacing.space6),

              // Main action button — Open WiFi Settings (always tappable)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    _addDebugLog('Opening WiFi settings for manual device AP connection');
                    // Start detection timer if not already running
                    if (_apDetectionTimer == null || !_apDetectionTimer!.isActive) {
                      _startApDetectionTimer();
                    }
                    _safeSetState(() {
                      _isLoading = true;
                      _statusMessage = 'Waiting for you to connect...';
                    });
                    // Open iOS WiFi settings
                    final url = Uri.parse('App-Prefs:root=WIFI');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      // Fallback to general settings
                      await launchUrl(Uri.parse('app-settings:'));
                    }
                  },
                  icon: const Icon(Icons.settings, size: 22),
                  label: const Text(
                    'Open WiFi Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HBotColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),

              if (_isLoading) ...[
                const SizedBox(height: HBotSpacing.space4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HBotColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HBotColors.primary.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Flexible(
                        child: Text(
                          'Waiting for device connection...\nReturn here after connecting to hbot-xxx',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF555555),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Fallback: manual entry (collapsed by default)
              TextButton(
                onPressed: () {
                  _safeSetState(() {
                    _availableDeviceAPs = ['manual'];
                  });
                },
                child: const Text(
                  'Having trouble? Enter device name manually',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a numbered instruction step for iOS discovery
  Widget _buildInstructionStep({
    required String number,
    required String text,
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HBotColors.primary.withOpacity(0.15),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: HBotColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Connect to device AP on iOS using NEHotspotConfigurationManager
  Future<void> _connectToDeviceAPiOS(String ssid) async {
    _addDebugLog('iOS: Connecting to device AP $ssid via NEHotspotConfiguration');
    _safeSetState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to $ssid...';
    });

    try {
      // Use NEHotspotConfigurationManager - no password for device APs
      final result = await IOSHotspotService.joinNetwork(ssid);

      if (result.success) {
        _addDebugLog('✅ iOS: NEHotspot joined $ssid, waiting for network...');
        
        // Wait for iOS to fully establish the connection
        // NEHotspotConfigurationManager returns before the network is fully ready
        await Future.delayed(const Duration(seconds: 4));
        
        // Verify we can actually reach the device
        _addDebugLog('Verifying device reachability...');
        bool reachable = false;
        for (int i = 0; i < 3; i++) {
          reachable = await _wifiService.isConnectedToHbotAP();
          if (reachable) break;
          _addDebugLog('Device not reachable yet, retrying... (${i + 1}/3)');
          await Future.delayed(const Duration(seconds: 2));
        }
        
        if (!reachable) {
          _addDebugLog('⚠️ Device not reachable after NEHotspot join — falling back to manual');
          _addDebugLog('iOS may not route traffic through device AP while home WiFi is active');
          
          // Remove the failed NEHotspot config so it doesn't interfere
          await IOSHotspotService.leaveNetwork(ssid);
          
          _safeSetState(() {
            _isLoading = false;
            _statusMessage = 'iOS could not connect to the device network.\n\n'
                'Please connect manually:\n'
                '1. Go to Settings → Wi-Fi\n'
                '2. Tap "$ssid"\n'
                '3. If prompted about no internet, tap "Use Without Internet"\n'
                '4. Return to this app — it will detect automatically';
          });
          
          // Start auto-detection timer to detect when user comes back
          _startApDetectionTimer();
          return;
        }
        
        _safeSetState(() {
          _isConnectedToDevice = true;
          _selectedDeviceAP = ssid;
          _statusMessage = 'Connected! Fetching device info...';
        });

        // Proceed to fetch device info and provision
        _handleDeviceConnectionWithTimeout();
      } else {
        _addDebugLog('❌ iOS: Failed to connect: ${result.message}');
        _safeSetState(() {
          _isLoading = false;
          _statusMessage = 'Could not connect to $ssid.\n${result.message}\n\nMake sure the device is in pairing mode.';
        });
      }
    } catch (e) {
      _addDebugLog('Error connecting to device AP: $e');
      _safeSetState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  // iOS-specific manual connection guide (fallback)
  Widget _buildIOSManualConnectionGuide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HBotSpacing.space6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: HBotSpacing.space4),

          // Header
          Center(
            child: Column(
              children: [
                Icon(Icons.wifi_find, size: 80, color: HBotColors.primary),
                const SizedBox(height: HBotSpacing.space4),
                const Text(
                  'Connect to Your Device',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: HBotColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: HBotSpacing.space2),
                const Text(
                  'We\'ll automatically detect when you connect',
                  style: TextStyle(fontSize: 16, color: HBotColors.textSecondaryLight),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: HBotSpacing.space6),

          // Auto-detection status
          Container(
            padding: const EdgeInsets.all(HBotSpacing.space4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200, width: 2),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: HBotSpacing.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-detecting device...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusMessage.isNotEmpty
                            ? _statusMessage
                            : 'Connect to your device and we\'ll detect it automatically',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: HBotSpacing.space6),

          // Simplified steps
          const Text(
            'Quick Steps:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: HBotSpacing.space4),

          _buildIOSStep(
            1,
            'Put device in pairing mode',
            'Press and hold button until LED blinks rapidly',
            Icons.power_settings_new,
          ),
          _buildIOSStep(
            2,
            'Open Settings → WiFi',
            'Go to iPhone Settings and tap WiFi',
            Icons.settings,
          ),
          _buildIOSStep(
            3,
            'Connect to "hbot-XXXX"',
            'Tap the hbot network (no password needed)',
            Icons.wifi,
          ),
          _buildIOSStep(
            4,
            'Return here',
            'We\'ll automatically detect and continue!',
            Icons.check_circle,
          ),

          const SizedBox(height: HBotSpacing.space6),

          // Important notes
          Container(
            padding: const EdgeInsets.all(HBotSpacing.space4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: HBotSpacing.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'iOS may ask for "Local Network" permission',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please tap "OK" when prompted to allow device communication',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: HBotSpacing.space6),

          // Manual check button (optional, if auto-detection not working)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _checkIOSDeviceConnection,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Check Connection Now'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: HBotSpacing.space4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: HBotSpacing.space2),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    await WiFiPermissionService.openAppSettings();
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open WiFi Settings'),
                ),
              ),
            ),
          ),

          if (_isLoading) ...[
            const SizedBox(height: HBotSpacing.space4),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    ),),);
  }

  Widget _buildIOSStep(
    int number,
    String title,
    String description,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HBotSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HBotColors.primary,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: HBotSpacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: HBotColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: HBotColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkIOSDeviceConnection() async {
    _safeSetState(() {
      _isLoading = true;
      _statusMessage = 'Checking connection to device...';
    });
    _addDebugLog('iOS: Starting device connection check');

    try {
      // Check if connected to hbot network
      final ssid = await _wifiService.getCurrentSSID();
      _addDebugLog('iOS: getCurrentSSID returned: ${ssid ?? "null"}');
      
      // Also check via HTTP probe
      final probeOk = await _wifiService.isConnectedToHbotAP();
      _addDebugLog('iOS: isConnectedToHbotAP (with probe): $probeOk');

      // If we can read SSID and it's not hbot, show warning
      if (ssid != null && !ssid.toLowerCase().startsWith('hbot')) {
        _safeSetState(() {
          _isLoading = false;
        });

        // Show warning dialog but allow proceeding
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Wrong Network?'),
            content: Text(
              'You appear to be connected to "$ssid" instead of a device network (hbot-XXXX).\n\nMake sure you\'re connected to the correct network in Settings, or tap Continue to try anyway.',
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
                child: const Text('Continue Anyway'),
              ),
            ],
          ),
        );

        if (proceed != true) {
          return;
        }

        _safeSetState(() {
          _isLoading = true;
        });
      }

      // If SSID is null, we can't detect it - that's OK, proceed anyway
      if (ssid == null) {
        _addDebugLog('Cannot detect SSID - proceeding anyway (iOS limitation)');
      } else {
        _addDebugLog('Connected to network: $ssid');
      }

      _safeSetState(() {
        _statusMessage = 'Connecting to device at 192.168.4.1...';
      });
      _addDebugLog('iOS: Attempting fetchDeviceInfo at 192.168.4.1...');

      // Try to fetch device info (this will trigger local network permission if not granted)
      final deviceInfo = await _wifiService.fetchDeviceInfo().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw 'Timeout connecting to device.\n\nPossible issues:\n• Device not in pairing mode\n• Not connected to device network\n• Local Network permission denied';
        },
      );

      _addDebugLog('Device info fetched: ${deviceInfo.module}');

      _safeSetState(() {
        _discoveredDevice = deviceInfo;
        _isConnectedToDevice = true;
        _selectedDeviceAP = ssid ?? 'hbot-device';
        _currentStep = PairingStep.provisioning;
      });

      // Start provisioning
      await _provisionDevice();
    } catch (e) {
      _addDebugLog('Error checking device connection: $e');

      // Check if it's a network unreachable error (Local Network permission issue)
      final errorStr = e.toString().toLowerCase();
      final isNetworkError =
          errorStr.contains('network is unreachable') ||
          errorStr.contains('errno = 101') ||
          errorStr.contains('connection refused');

      _safeSetState(() {
        _isLoading = false;
        if (isNetworkError) {
          _statusMessage = '''Error: Cannot reach device

This usually means:
• You're not connected to the device network (hbot-XXXX)
• iOS blocked "Local Network" permission

To fix:
1. Make sure you're connected to hbot-XXXX in Settings > WiFi
2. Check Settings > HBOT > Local Network is ON
3. If permission is OFF, enable it and try again
4. If permission option doesn't exist, uninstall and reinstall the app

Technical error: $e''';
        } else {
          _statusMessage = '''Error: $e

Troubleshooting:
• Make sure device is in pairing mode (LED blinking)
• Make sure you're connected to hbot-XXXX network
• Try restarting the device
• Check that device is powered on''';
        }
      });
    }
  }

  // Step 3: Provisioning
  Widget _buildProvisioningStep() {
    return Padding(
      padding: const EdgeInsets.all(HBotSpacing.space6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
        children: [
          const SizedBox(height: HBotSpacing.space6 * 2),

          const CircularProgressIndicator(),
          const SizedBox(height: HBotSpacing.space6),

          const Text(
            'Configuring Device...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: HBotColors.textPrimaryLight,
            ),
          ),

          const SizedBox(height: HBotSpacing.space4),

          Text(
            _statusMessage.isNotEmpty
                ? _statusMessage
                : 'Sending Wi-Fi credentials to your device.',
            style: const TextStyle(fontSize: 16, color: HBotColors.textSecondaryLight),
            textAlign: TextAlign.center,
          ),

          if (_discoveredDevice != null) ...[
            const SizedBox(height: HBotSpacing.space6),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(HBotSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device Information:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space2),
                    Text('Name: ${_discoveredDevice!.module}'),
                    Text('Channels: ${_discoveredDevice!.channels}'),
                  ],
                ),
              ),
            ),
          ],

          const Spacer(),

          // Show retry button if there's an error or timeout
          if (_statusMessage.contains('Retry') ||
              _statusMessage.contains('error') ||
              _statusMessage.contains('failed')) ...[
            ElevatedButton(
              onPressed: () async {
                if (_pendingDeviceData != null) {
                  // Retry device creation
                  await _createDeviceImmediately();
                } else {
                  // Retry provisioning
                  await _provisionDevice();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: HBotColors.primary,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: HBotSpacing.space4),
          ],

          // Debug log (for development)
          if (_debugLog.isNotEmpty) ...[
            Container(
              height: 100,
              padding: const EdgeInsets.all(HBotSpacing.space2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _debugLog,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ],
      ),
    ),),);
  }

  // Step 4: Success (like competitor's 6.jpeg and 7.jpeg)
  Widget _buildSuccessStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HBotSpacing.space6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
        children: [
          const SizedBox(height: HBotSpacing.space6),

          const Icon(Icons.check_circle, size: 80, color: Colors.green),

          const SizedBox(height: HBotSpacing.space6),

          const Text(
            'Device Added Successfully!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: HBotColors.textPrimaryLight,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: HBotSpacing.space4),

          const Text(
            'Your device is now connected and ready to use. You can control it below or from the home screen.',
            style: TextStyle(fontSize: 16, color: HBotColors.textSecondaryLight),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: HBotSpacing.space6),

          // Device control widget
          if (_createdDevice != null) ...[
            EnhancedDeviceControlWidget(
              device: _createdDevice!,
              mqttManager: _mqttManager,
              showBulkControls: false,
            ),

            const SizedBox(height: HBotSpacing.space4),

            // Device rename option
            Card(
              child: ListTile(
                leading: const Icon(Icons.edit, color: HBotColors.primary),
                title: const Text('Rename Device'),
                subtitle: Text('Current name: ${_createdDevice!.deviceName}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _editDeviceName,
              ),
            ),

            const SizedBox(height: HBotSpacing.space4),

            // Room selection
            Card(
              child: ListTile(
                leading: const Icon(Icons.room, color: HBotColors.primary),
                title: const Text('Choose Room'),
                subtitle: Text(_selectedRoom?.name ?? 'No room selected'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showRoomSelection,
              ),
            ),
          ],

          const SizedBox(height: HBotSpacing.space6),

          // Action buttons
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _finishPairing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HBotColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: HBotSpacing.space4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: HBotSpacing.space4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    // Add another device
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddDeviceFlowScreen(
                          home: widget.home,
                          room: widget.room,
                          onDeviceAdded: widget.onDeviceAdded,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Add Another Device',
                    style: TextStyle(
                      fontSize: 16,
                      color: HBotColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),),);
  }

  // Device discovery and connection methods
  Future<void> _startDeviceDiscovery() async {
    _addDebugLog('Starting device discovery');
    _safeSetState(() {
      _isLoading = true;
      _statusMessage = 'Scanning for device networks...';
    });

    try {
      // Add overall timeout for device discovery
      await _performDeviceDiscoveryWithTimeout();
    } catch (e) {
      _addDebugLog('Error scanning for devices: $e');
      _safeSetState(() {
        _isLoading = false;
        _statusMessage = 'Error scanning for devices: $e';
      });
    }
  }

  /// Perform device discovery with timeout handling
  Future<void> _performDeviceDiscoveryWithTimeout() async {
    const discoveryTimeout = Duration(minutes: 2);

    await Future.any([
      _performDeviceDiscovery(),
      Future.delayed(discoveryTimeout).then((_) {
        throw TimeoutException(
          'Device discovery timed out after ${discoveryTimeout.inMinutes} minutes. Please make sure your device is in pairing mode and try again.',
          discoveryTimeout,
        );
      }),
    ]);
  }

  /// Perform the actual device discovery steps
  Future<void> _performDeviceDiscovery() async {
    // Check if already connected to a device AP first
    final isConnected = await _wifiService.isConnectedToHbotAP().timeout(
      const Duration(seconds: 10),
      onTimeout: () => false,
    );

    if (isConnected) {
      _addDebugLog('Already connected to device AP');
      _handleDeviceConnectionWithTimeout();
      return;
    }

    // Scan for hbot-* networks with retry logic and timeouts
    List<String> aps = [];
    for (int attempt = 1; attempt <= 3; attempt++) {
      _addDebugLog('Scan attempt $attempt/3');
      _safeSetState(() {
        _statusMessage = 'Scanning for device networks... (attempt $attempt/3)';
      });

      try {
        aps = await _wifiService.scanForHbotAPs().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            _addDebugLog('Scan attempt $attempt timed out');
            return <String>[];
          },
        );

        _addDebugLog(
          'Scan attempt $attempt found ${aps.length} networks: ${aps.join(', ')}',
        );

        if (aps.isNotEmpty) break;

        if (attempt < 3) {
          await Future.delayed(const Duration(seconds: 3));
        }
      } catch (e) {
        _addDebugLog('Scan attempt $attempt failed: $e');
        if (attempt == 3) {
          // Last attempt failed, rethrow the error
          rethrow;
        }
        // Continue to next attempt
        await Future.delayed(const Duration(seconds: 3));
      }
    }

    _safeSetState(() {
      _availableDeviceAPs = aps;
      _isLoading = false;
      if (aps.isEmpty) {
        _statusMessage =
            'No device networks found. Make sure your device is in pairing mode.';
      } else {
        _statusMessage =
            'Found ${aps.length} device network(s). Tap to connect.';
      }
    });
    _addDebugLog('Final result: Found ${aps.length} device networks');

    // Start auto-detection timer for manual AP connection
    _startApDetectionTimer();
  }

  void _startApDetectionTimer() {
    _apDetectionTimer?.cancel();

    // iOS: poll every 5s (HTTP probe is heavier than SSID check)
    // Android: poll every 5s using SSID check
    final pollInterval = const Duration(seconds: 5);

    _apDetectionTimer = Timer.periodic(pollInterval, (timer) async {
      if (_currentStep != PairingStep.deviceDiscovery || _isConnectedToDevice) {
        timer.cancel();
        return;
      }

      try {
        final isConnected = await _wifiService.isConnectedToHbotAP();
        if (isConnected) {
          _addDebugLog('✅ Auto-detected connection to device AP');
          timer.cancel();

          if (isIOS) {
            // iOS: Device AP detected, proceed to fetch device info
            _safeSetState(() {
              _isConnectedToDevice = true;
              _statusMessage = 'Device detected! Fetching info...';
            });
            _handleDeviceConnectionWithTimeout();
          } else {
            // Android: Use existing flow
            _handleDeviceConnectionWithTimeout();
          }
        } else {
          // Update status to show we're still looking
          if (mounted) {
            _safeSetState(() {
              _statusMessage = 'Listening for device connection...\nConnect to the hbot-xxx network in WiFi Settings';
            });
          }
        }
      } catch (e) {
        _addDebugLog('Error checking AP connection: $e');
      }
    });

    _addDebugLog(
      'Started auto-detection timer (${pollInterval.inSeconds}s interval)',
    );
  }

  Future<void> _connectToDeviceAP(String ssid) async {
    _addDebugLog('Attempting to connect to $ssid');
    _safeSetState(() {
      _isLoading = true;
      _selectedDeviceAP = ssid;
      _statusMessage = 'Connecting to $ssid...';
    });

    try {
      final result = await _wifiService
          .connectToHbotAP(ssid)
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () => WiFiConnectionResult(
              success: false,
              message:
                  'Connection to device network timed out. Please try again.',
            ),
          );

      if (result.success) {
        _addDebugLog('Successfully connected to $ssid');
        _safeSetState(() {
          _isConnectedToDevice = true;
          _statusMessage = 'Connected to device!';
        });

        // Wait a moment then proceed to provisioning
        await Future.delayed(const Duration(seconds: 2));

        // Handle device connection with timeout
        _handleDeviceConnectionWithTimeout();
      } else {
        _addDebugLog('Failed to connect to $ssid: ${result.message}');
        _safeSetState(() {
          _isLoading = false;
          _statusMessage = result.message;
        });

        if (result.requiresManualConnection) {
          _openWiFiSettings();
        }
      }
    } catch (e) {
      _addDebugLog('Error connecting to $ssid: $e');
      _safeSetState(() {
        _isLoading = false;
        _statusMessage = 'Failed to connect: $e';
      });
    }
  }

  Future<void> _openWiFiSettings() async {
    _addDebugLog('Opening Wi-Fi settings');
    try {
      if (isAndroid || isIOS) {
        await PlatformService.openWiFiSettings();
      }
    } catch (e) {
      _addDebugLog('Error opening Wi-Fi settings: $e');
    }
  }

  /// Handle device connection with overall timeout
  void _handleDeviceConnectionWithTimeout() {
    _handleDeviceConnection()
        .timeout(
          const Duration(minutes: 3), // Overall timeout for the entire process
          onTimeout: () {
            _addDebugLog('Device connection process timed out');
            _safeSetState(() {
              _isLoading = false;
              _statusMessage = 'Device connection timed out. Please try again.';
            });
          },
        )
        .catchError((error) {
          _addDebugLog('Device connection error: $error');
          _safeSetState(() {
            _isLoading = false;
            _statusMessage = 'Connection failed: $error';
          });
        });
  }

  Future<void> _handleDeviceConnection() async {
    _addDebugLog('Handling device connection');
    _safeSetState(() {
      _currentStep = PairingStep.provisioning;
      _statusMessage = 'Fetching device information...';
    });

    try {
      // Fetch device info with timeout to prevent hanging
      final deviceInfo = await _wifiService.fetchDeviceInfo().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'Failed to fetch device information. Please make sure you are connected to the device network.',
          const Duration(seconds: 30),
        ),
      );
      _addDebugLog('Device info fetched: ${deviceInfo.module}');

      // Determine device type (pass deviceInfo for shutter detection)
      DeviceType deviceType = _determineDeviceType(
        deviceInfo.module,
        deviceInfo: deviceInfo,
      );

      // Store device info with type
      final statusWithType = Map<String, dynamic>.from(deviceInfo.status);
      statusWithType['DetectedDeviceType'] = deviceType.name;

      _safeSetState(() {
        _discoveredDevice = deviceInfo.copyWith(status: statusWithType);
        _deviceNameController.text = deviceInfo.module;
        _statusMessage = 'Provisioning device with Wi-Fi credentials...';
      });

      // Provision device
      await _provisionDevice();
    } catch (e) {
      _addDebugLog('Error handling device connection: $e');
      _safeSetState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  DeviceType _determineDeviceType(
    String deviceName, {
    TasmotaDeviceInfo? deviceInfo,
  }) {
    // PRIORITY: Check if device info indicates shutter
    if (deviceInfo?.isShutter == true) {
      debugPrint('🪟 Device type determined as SHUTTER from device info');
      return DeviceType.shutter;
    }

    // Fallback to name-based detection
    final name = deviceName.toLowerCase();
    if (name.contains('light') || name.contains('bulb')) {
      return DeviceType.dimmer;
    } else if (name.contains('sensor')) {
      return DeviceType.sensor;
    } else if (name.contains('shutter') || name.contains('blind')) {
      return DeviceType.shutter;
    }
    return DeviceType.relay;
  }

  Future<void> _provisionDevice() async {
    _addDebugLog('Starting device provisioning');

    try {
      // Add overall timeout for the entire provisioning process
      await _provisionDeviceWithTimeout();
    } catch (e) {
      _addDebugLog('Error provisioning device: $e');

      // Provide more user-friendly error messages and automatic recovery
      String userMessage = 'Provisioning error: $e';

      if (e.toString().contains('Network restoration timed out') ||
          e.toString().contains('multiple attempts')) {
        userMessage =
            'Device provisioning completed, but automatic network restoration failed.\n\n'
            'The device has been configured with your Wi-Fi credentials, but you may need to manually reconnect to your home network.\n\n'
            'Please check your Wi-Fi settings and tap "Retry" to continue with device setup.';
      } else if (e.toString().contains('internet connectivity')) {
        userMessage =
            'Device provisioning completed, but internet connectivity could not be verified.\n\n'
            'Please ensure you\'re connected to your home network and have internet access, then tap "Retry" to continue.';
      }

      _safeSetState(() {
        _statusMessage = userMessage;
      });
    }
  }

  /// Provision device with proper timeout handling
  Future<void> _provisionDeviceWithTimeout() async {
    // Set overall timeout for provisioning process
    const provisioningTimeout = Duration(minutes: 3);

    await Future.any([
      _performProvisioning(),
      Future.delayed(provisioningTimeout).then((_) {
        throw TimeoutException(
          'Device provisioning timed out after ${provisioningTimeout.inMinutes} minutes. Please try again.',
          provisioningTimeout,
        );
      }),
    ]);
  }

  /// Perform the actual provisioning steps
  Future<void> _performProvisioning() async {
    // Step 1: Check if we're still connected to device network
    _safeSetState(() {
      _statusMessage = 'Checking device connection...';
    });

    final isConnectedToDevice = await _wifiService
        .isConnectedToHbotAP()
        .timeout(const Duration(seconds: 10), onTimeout: () => false);

    if (!isConnectedToDevice) {
      _addDebugLog(
        'No longer connected to device network - device may already be provisioned',
      );

      // Skip provisioning and go directly to network restoration
      _safeSetState(() {
        _statusMessage =
            'Device appears to be already configured. Finalizing setup...';
      });

      // Wait a moment for device to fully restart and connect to user's network
      await Future.delayed(const Duration(seconds: 5));

      // Check if we're back on the home network, if not try to reconnect
      try {
        await _ensureHomeNetworkConnection();
      } catch (e) {
        _addDebugLog('Failed to ensure home network connection: $e');
        // Continue anyway - device creation might still work
      }

      // Create device in account
      await _createDeviceInAccountWithTimeout();
      return;
    }

    // Step 2: Provision WiFi credentials (only if still connected to device)
    _safeSetState(() {
      _statusMessage = 'Sending Wi-Fi credentials to device...';
    });

    _addDebugLog('Sending WiFi creds to device: SSID=$_currentSSID');
    
    final response = await _wifiService
        .provisionWiFiTasmota(ssid: _currentSSID!, password: _wifiPassword!)
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException(
            'Failed to send Wi-Fi credentials to device. Please try again.',
            const Duration(seconds: 60),
          ),
        );

    _addDebugLog('Provision response: success=${response.success}, msg=${response.message}');
    
    if (!response.success) {
      throw 'Device provisioning failed: ${response.message}';
    }

    _addDebugLog('✅ Device provisioned successfully — device will restart');

    // Wait for device to restart and connect to the user's network
    // Tasmota restart takes ~5-10 seconds, then it tries to connect to WiFi
    _safeSetState(() {
      _statusMessage =
          'Device is restarting and connecting to your network...\nThis may take 15-20 seconds.';
    });
    _addDebugLog('Waiting 15s for device to restart and join home WiFi...');

    await Future.delayed(const Duration(seconds: 15));

    // Step 3: Disconnect from device and return to home network
    await _disconnectFromDeviceAndReturnHome();

    // Step 4: Create device in account
    await _createDeviceInAccountWithTimeout();
  }

  /// Create device immediately after provisioning without LAN discovery
  Future<void> _createDeviceImmediately() async {
    _addDebugLog('Creating device immediately using known information');
    _safeSetState(() {
      _statusMessage = 'Creating device...';
    });

    try {
      if (_discoveredDevice == null) {
        throw 'No device information available';
      }

      final deviceInfo = _discoveredDevice!;
      final deviceName = _deviceNameController.text.trim().isNotEmpty
          ? _deviceNameController.text.trim()
          : deviceInfo.module;

      // Use discovered MQTT topic or generate from MAC as fallback
      String mqttTopic = deviceInfo.topicBase.isNotEmpty
          ? deviceInfo.topicBase
          : '';

      // If no topic discovered and MAC is available, generate from MAC
      if (mqttTopic.isEmpty &&
          deviceInfo.mac != 'Unknown' &&
          deviceInfo.mac.isNotEmpty) {
        mqttTopic = TasmotaDeviceInfo.generateTopicFromMac(deviceInfo.mac);
      }

      // If still no topic, generate a unique one with timestamp
      if (mqttTopic.isEmpty) {
        final timestamp = DateTime.now().millisecondsSinceEpoch
            .toString()
            .substring(7);
        mqttTopic = 'hbot_$timestamp';
      }

      _addDebugLog(
        'Using MQTT topic: $mqttTopic (discovered: ${deviceInfo.topicBase}, MAC: ${deviceInfo.mac})',
      );

      // Determine channel count from device status
      int channels = _parseChannelCount(deviceInfo.status);
      _addDebugLog('Detected $channels channels');

      // Create device using simplified service
      final device = await _deviceService.createDeviceFromProvisioning(
        homeId: widget.home.id,
        roomId: widget.room?.id,
        deviceName: deviceName,
        deviceMac: deviceInfo.mac,
        mqttTopic: mqttTopic,
        channels: channels,
        deviceIp: deviceInfo.ip,
        hostname: deviceInfo.hostname,
        module: deviceInfo.module,
        version: deviceInfo.version,
        additionalMeta: {
          'sensors': deviceInfo.sensors,
          'fullTopic': deviceInfo.fullTopic,
          'status': deviceInfo.status,
        },
      );

      _addDebugLog('Device created successfully: ${device.id}');

      _safeSetState(() {
        _createdDevice = device;
        _currentStep = PairingStep.success;
        _statusMessage = 'Device added successfully!';
        // Initialize the device name controller with the actual device name
        // Use deviceName getter which handles displayName/name logic correctly
        _deviceNameController.text = device.deviceName;
      });

      // Initialize MQTT connection asynchronously (don't block UI)
      _initializeMqttConnectionAsync();

      // Notify parent about device addition
      widget.onDeviceAdded?.call();
    } catch (e) {
      _addDebugLog('❌ Error creating device: $e');
      debugPrint('❌ FULL ERROR DETAILS: $e');
      debugPrint('❌ ERROR TYPE: ${e.runtimeType}');

      // Handle specific error types with appropriate user messages
      String userMessage;
      bool isNetworkIssue = false;

      if (e.toString().contains('already linked to another account')) {
        userMessage = e.toString();
      } else if (e.toString().contains('Permission denied') ||
          e.toString().contains('Check your Supabase policies')) {
        userMessage =
            'Permission denied:\n\n$e\n\nPlease contact support if this issue persists.';
      } else if (e.toString().contains('Authentication required')) {
        userMessage =
            'Authentication required:\n\n$e\n\nPlease log in and try again.';
      } else if (e.toString().contains('Invalid home or room ID')) {
        userMessage =
            'Invalid location selected:\n\n$e\n\nPlease try selecting a different room.';
      } else if (e.toString().contains('Invalid device parameters')) {
        userMessage =
            'Invalid device configuration:\n\n$e\n\nPlease try the setup process again.';
      } else if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('No address associated with hostname')) {
        userMessage =
            'Network Connection Issue\n\n'
            'Unable to connect to the cloud database.\n'
            'This could be due to:\n\n'
            '• DNS resolution problems\n'
            '• Firewall or network restrictions\n'
            '• Internet connectivity issues\n\n'
            'Please check your connection and try again.';
        isNetworkIssue = true;
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('timed out')) {
        userMessage =
            'Connection Timeout\n\n'
            'The request took too long to complete.\n'
            'Please check your internet connection\n'
            'and try again.';
        isNetworkIssue = true;
      } else if (e.toString().contains(
        'Unable to save device to cloud database',
      )) {
        // This is our custom network error message
        userMessage = e.toString().replaceFirst('Exception: ', '');
        isNetworkIssue = true;
      } else {
        // For unknown errors, log the full error for debugging
        userMessage = 'Error creating device: ${e.toString()}';
      }

      _safeSetState(() {
        _statusMessage = userMessage;
        _isLoading = false;
      });

      // Show appropriate dialog based on error type
      if (isNetworkIssue) {
        _showNetworkErrorDialog(userMessage);
      } else {
        _showDeviceErrorDialog(userMessage);
      }
    }
  }

  /// Initialize MQTT connection asynchronously (non-blocking)
  void _initializeMqttConnectionAsync() {
    // Run MQTT initialization in background without blocking UI
    Future.microtask(() async {
      try {
        _addDebugLog('Initializing MQTT connection asynchronously...');

        // Get actual user ID from auth service
        final user = Supabase.instance.client.auth.currentUser;
        final userId =
            user?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

        // Initialize MQTT manager with timeout
        await _mqttManager
            .initialize(userId)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                _addDebugLog('MQTT initialization timed out');
                throw TimeoutException(
                  'MQTT initialization timeout',
                  const Duration(seconds: 10),
                );
              },
            );

        // Connect to MQTT broker with timeout
        final connected = await _mqttManager.connect().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            _addDebugLog('MQTT connection timed out');
            return false;
          },
        );

        if (connected) {
          _addDebugLog('MQTT connected successfully');

          // Register the created device if available
          if (_createdDevice != null) {
            await _mqttManager
                .registerDevice(_createdDevice!)
                .timeout(
                  const Duration(seconds: 15),
                  onTimeout: () {
                    _addDebugLog('Device registration timed out');
                  },
                );
            _addDebugLog('Device registered with MQTT manager');
          }
        } else {
          _addDebugLog('Failed to connect to MQTT broker');
        }
      } catch (e) {
        _addDebugLog('MQTT initialization error: $e');
        // Don't fail device creation if MQTT fails - this is background operation
      }
    });
  }

  /// Parse channel count from device status using enhanced detection
  int _parseChannelCount(Map<String, dynamic> status) {
    return ChannelDetectionUtils.detectChannelCount(status);
  }

  // Success step actions
  void _editDeviceName() {
    // Pre-populate the text field with the current device name
    if (_createdDevice != null) {
      _deviceNameController.text = _createdDevice!.deviceName;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Device Name'),
        content: TextField(
          controller: _deviceNameController,
          decoration: const InputDecoration(hintText: 'Enter device name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateDeviceName();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDeviceName() async {
    if (_createdDevice == null) return;

    try {
      final newName = _deviceNameController.text.trim();
      if (newName.isEmpty) {
        _addDebugLog('Device name cannot be empty');
        return;
      }

      // Use the new rename_device RPC which handles display_name and name_is_custom
      await _deviceManagementRepo.renameDevice(
        deviceId: _createdDevice!.id,
        newName: newName,
      );

      _safeSetState(() {
        // Update the device with the new display name and mark as custom
        _createdDevice = _createdDevice!.copyWith(
          displayName: newName,
          nameIsCustom: true,
        );
      });

      _addDebugLog('Device name updated to: $newName');
    } catch (e) {
      _addDebugLog('Error updating device name: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update device name: $e')),
        );
      }
    }
  }

  void _finishPairing() {
    _addDebugLog('Pairing completed');
    widget.onDeviceAdded?.call();
    Navigator.pop(context);
  }

  /// Show room selection dialog
  void _showRoomSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Room'),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scrollable list of rooms
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // No room option
                        ListTile(
                          leading: const Icon(Icons.home_outlined),
                          title: const Text('No Room'),
                          subtitle: const Text('Place device in the main area'),
                          onTap: () {
                            Navigator.pop(context);
                            _assignDeviceToRoom(null);
                          },
                          selected: _selectedRoom == null,
                        ),
                        const Divider(),
                        // Available rooms
                        if (_availableRooms.isNotEmpty) ...[
                          const Text(
                            'Available Rooms:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...(_availableRooms.map(
                            (room) => ListTile(
                              leading: const Icon(Icons.room),
                              title: Text(room.name),
                              onTap: () {
                                Navigator.pop(context);
                                _assignDeviceToRoom(room);
                              },
                              selected: _selectedRoom?.id == room.id,
                            ),
                          )),
                        ] else ...[
                          const Text(
                            'No rooms available. You can create rooms from the home screen.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  /// Assign device to a room
  Future<void> _assignDeviceToRoom(Room? room) async {
    if (_createdDevice == null) return;

    try {
      _addDebugLog('Assigning device to room: ${room?.name ?? 'No room'}');

      // Update device in database
      if (room == null) {
        await _smartHomeService.updateDevice(
          _createdDevice!.id,
          clearRoom: true,
        );
      } else {
        await _smartHomeService.updateDevice(
          _createdDevice!.id,
          roomId: room.id,
        );
      }

      // Update local state
      _safeSetState(() {
        _selectedRoom = room;
      });

      _addDebugLog('Device successfully moved to room');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              room != null
                  ? 'Device moved to ${room.name}'
                  : 'Device moved to main area',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _addDebugLog('Error moving device to room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to move device. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show network error dialog with retry option
  void _showNetworkErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.orange),
              SizedBox(width: 8),
              Text('Network Issue'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Troubleshooting Steps:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Check your Wi-Fi connection'),
                    const Text(
                      '• Make sure you\'re connected to your home network',
                    ),
                    const Text('• Try turning Wi-Fi off and on'),
                    const Text('• Check if other apps can access the internet'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Go back to WiFi setup
                setState(() {
                  _currentStep = PairingStep.wifiSetup;
                  _isLoading = false;
                });
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkWiFiSettings();
              },
              child: const Text('Wi-Fi Settings'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkConnectivityAndRetry();
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  /// Show device error dialog for non-network issues
  void _showDeviceErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Device Setup Error'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What you can try:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• Try the setup process again'),
                    Text('• Reset the device and start over'),
                    Text('• Check if the device is already added'),
                    Text('• Contact support if the issue persists'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Go back to WiFi setup
                setState(() {
                  _currentStep = PairingStep.wifiSetup;
                  _isLoading = false;
                });
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _retryDeviceCreation();
              },
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  /// Retry device creation after error
  void _retryDeviceCreation() {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Retrying device creation...';
    });
    _createDeviceImmediately();
  }

  /// Open Wi-Fi settings to help user troubleshoot
  void _checkWiFiSettings() {
    // This would open Wi-Fi settings on the device
    // For now, we'll show a helpful message
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wi-Fi Settings'),
        content: const Text(
          'Please go to your device\'s Wi-Fi settings and:\n\n'
          '1. Make sure Wi-Fi is enabled\n'
          '2. Connect to your home network\n'
          '3. Test internet connectivity\n'
          '4. Return to this app and try again',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Check connectivity and retry device creation
  Future<void> _checkConnectivityAndRetry() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // First, get detailed connectivity status
      final connectivityStatus =
          await NetworkConnectivityService.getDetailedConnectivityStatus();

      if (!connectivityStatus.hasInternet) {
        _addDebugLog('No internet connection detected');
        _showNetworkErrorDialog(
          'No internet connection detected. Please check your Wi-Fi connection and try again.',
        );
        return;
      }

      if (!connectivityStatus.isSupabaseReachable) {
        _addDebugLog(
          'Supabase not reachable: ${connectivityStatus.errorMessage}',
        );
        _showNetworkErrorDialog(
          connectivityStatus.errorMessage ??
              'Cannot reach the home automation server. Please check your internet connection.',
        );
        return;
      }

      _addDebugLog('Network connectivity verified successfully');

      // Update status to show we're proceeding
      setState(() {
        _statusMessage = 'Network connection verified. Creating device...';
      });

      // Small delay to show the status update
      await Future.delayed(const Duration(milliseconds: 500));

      // Retry the original operation
      await _createDeviceImmediately();
    } catch (e) {
      _addDebugLog('Network connectivity check failed: $e');
      _showNetworkErrorDialog(
        'Failed to verify network connection: $e\n\nPlease check your internet connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Helper method to disconnect from device and return to home network with automatic retry
  Future<void> _disconnectFromDeviceAndReturnHome() async {
    const maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        _safeSetState(() {
          _statusMessage = retryCount == 0
              ? 'Returning to your home network...'
              : 'Retrying network reconnection (attempt ${retryCount + 1}/$maxRetries)...';
        });

        _addDebugLog(
          'Disconnecting from device AP and reconnecting to user Wi-Fi (attempt ${retryCount + 1}/$maxRetries)',
        );
        _addDebugLog(
          'Current credentials - SSID: $_currentSSID, Password: ${_wifiPassword != null ? "***" : "null"}',
        );

        // Step 1: Unbind from device network
        await _wifiService.disconnectFromHbotAP().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException(
            'Failed to unbind from device network',
            const Duration(seconds: 10),
          ),
        );

        _addDebugLog('Unbound from device network');

        // Step 2: Reconnect to user's Wi-Fi using WifiNetworkSuggestion (Android 10+)
        // Use _currentSSID which was set in _proceedToDeviceDiscovery from either auto-detect or manual entry
        if (_currentSSID != null && _wifiPassword != null) {
          _safeSetState(() {
            _statusMessage = 'Reconnecting to $_currentSSID...';
          });

          _addDebugLog('🔄 Reconnecting to user Wi-Fi: $_currentSSID');

          final reconnectResult = await _wifiService
              .reconnectToUserWifi(
                ssid: _currentSSID!,
                password: _wifiPassword!,
              )
              .timeout(
                const Duration(minutes: 1),
                onTimeout: () => throw TimeoutException(
                  'Reconnection timed out',
                  const Duration(minutes: 1),
                ),
              );

          if (!reconnectResult.success) {
            _addDebugLog(
              '⚠️ Automatic reconnection failed: ${reconnectResult.message}',
            );
            throw 'Reconnection failed: ${reconnectResult.message}';
          }

          _addDebugLog('✅ Successfully reconnected to $_currentSSID');
        } else {
          _addDebugLog(
            '⚠️ No user Wi-Fi credentials available (SSID: $_currentSSID, Password: ${_wifiPassword != null ? "set" : "null"})',
          );
          _addDebugLog('Relying on automatic system reconnection...');

          // Wait for system to reconnect automatically
          await Future.delayed(const Duration(seconds: 5));
        }

        _addDebugLog('Successfully returned to home network');
        return; // Success - exit the retry loop
      } catch (e) {
        retryCount++;
        _addDebugLog('Network reconnection attempt $retryCount failed: $e');

        if (retryCount >= maxRetries) {
          // All retries exhausted - throw error for manual intervention
          _addDebugLog('All automatic retry attempts exhausted');

          final errorMessage =
              'Unable to automatically reconnect to your Wi-Fi network after $maxRetries attempts.\n\n'
              'Please manually:\n'
              '1. Open Wi-Fi settings\n'
              '2. Connect to "$_currentSSID"\n'
              '3. Return to this app\n\n'
              'Then tap "Retry" to continue.';

          throw errorMessage;
        }

        // Wait before retrying
        _addDebugLog('Waiting 3 seconds before retry...');
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  /// Helper method to create device in account with timeout
  Future<void> _createDeviceInAccountWithTimeout() async {
    _safeSetState(() {
      _statusMessage = 'Creating device in your account...';
    });

    await _createDeviceImmediately().timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw TimeoutException(
        'Failed to create device in your account. Please check your internet connection.',
        const Duration(seconds: 45),
      ),
    );
  }

  /// Helper method to ensure we're connected to home network with comprehensive verification
  Future<void> _ensureHomeNetworkConnection() async {
    _safeSetState(() {
      _statusMessage = 'Verifying network connection...';
    });

    // Check if we're still connected to device network
    final stillOnDevice = await _wifiService.isConnectedToHbotAP().timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    );

    if (stillOnDevice) {
      _addDebugLog(
        'Still connected to device network, attempting to disconnect',
      );
      await _disconnectFromDeviceAndReturnHome();
    } else {
      _addDebugLog('Already disconnected from device network');
    }

    // Verify internet connectivity with retry logic
    _safeSetState(() {
      _statusMessage = 'Verifying internet connectivity...';
    });

    bool hasInternet = false;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http
            .get(Uri.https('google.com'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          hasInternet = true;
          break;
        }
      } catch (e) {
        _addDebugLog('Internet connectivity check attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(
            Duration(seconds: attempt * 2),
          ); // Progressive delay
        }
      }
    }

    if (!hasInternet) {
      throw 'Unable to verify internet connectivity. Please check your Wi-Fi connection and try again.';
    }

    _addDebugLog('Network connection verified successfully');
  }
}
