import '../services/platform_helper.dart';

import '../services/permission_shim.dart' as ph;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';

/// Service for handling Wi-Fi permissions and location services
class WiFiPermissionService {
  /// Check if all required permissions are granted for Wi-Fi operations
  static Future<WiFiPermissionStatus> checkPermissions() async {
    if (isIOS) {
      // iOS: Check location permission (required for SSID reading)
      final locationStatus = await ph.Permission.locationWhenInUse.status;

      // iOS can return 'limited' which is acceptable for WiFi SSID reading
      if (locationStatus == ph.PermissionStatus.granted ||
          locationStatus == ph.PermissionStatus.limited) {
        // Check if location services are enabled
        final locationEnabled = await Geolocator.isLocationServiceEnabled();
        if (!locationEnabled) {
          return WiFiPermissionStatus.locationServicesDisabled;
        }

        return WiFiPermissionStatus.granted;
      }

      // Check if permanently denied
      if (locationStatus == ph.PermissionStatus.permanentlyDenied) {
        return WiFiPermissionStatus.permanentlyDenied;
      }

      return WiFiPermissionStatus.permissionsDenied;
    }

    if (!isAndroid) {
      // Web or other platforms
      return WiFiPermissionStatus.granted;
    }

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    // Check location services first (required on all Android 10+ versions)
    final locationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationEnabled) {
      return WiFiPermissionStatus.locationServicesDisabled;
    }

    // Check permissions based on Android version
    if (sdkInt >= 33) {
      // Android 13/14 (API 33+)
      // CRITICAL: Need BOTH permissions to read SSID
      final nearbyWifiDevices = await ph.Permission.nearbyWifiDevices.status;
      final fineLocation = await ph.Permission.locationWhenInUse.status;

      if (nearbyWifiDevices != ph.PermissionStatus.granted ||
          fineLocation != ph.PermissionStatus.granted) {
        return WiFiPermissionStatus.permissionsDenied;
      }
    } else if (sdkInt >= 29) {
      // Android 10-12 (API 29-32)
      final fineLocation = await ph.Permission.locationWhenInUse.status;

      if (fineLocation != ph.PermissionStatus.granted) {
        return WiFiPermissionStatus.permissionsDenied;
      }
    } else {
      // Android 9 and below (API 28-)
      final coarseLocation = await ph.Permission.locationWhenInUse.status;

      if (coarseLocation != ph.PermissionStatus.granted) {
        return WiFiPermissionStatus.permissionsDenied;
      }
    }

    return WiFiPermissionStatus.granted;
  }

  /// Request all required permissions for Wi-Fi operations
  static Future<WiFiPermissionStatus> requestPermissions() async {
    if (isIOS) {
      // iOS: Request location permission
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationEnabled) {
        return WiFiPermissionStatus.locationServicesDisabled;
      }

      final status = await ph.Permission.locationWhenInUse.request();

      // iOS can return 'limited' which is acceptable for WiFi SSID reading
      if (status == ph.PermissionStatus.granted ||
          status == ph.PermissionStatus.limited) {
        return WiFiPermissionStatus.granted;
      }

      // Check if permanently denied
      if (status == ph.PermissionStatus.permanentlyDenied) {
        return WiFiPermissionStatus.permanentlyDenied;
      }

      return WiFiPermissionStatus.permissionsDenied;
    }

    if (!isAndroid) {
      // Web or other platforms
      return WiFiPermissionStatus.granted;
    }

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    // Check location services first
    final locationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationEnabled) {
      return WiFiPermissionStatus.locationServicesDisabled;
    }

    List<ph.Permission> permissionsToRequest = [];

    if (sdkInt >= 33) {
      // Android 13/14 (API 33+)
      // CRITICAL: Request BOTH permissions to read SSID
      permissionsToRequest = [
        ph.Permission.nearbyWifiDevices,
        ph.Permission.locationWhenInUse, // Still needed for SSID reading!
      ];
    } else if (sdkInt >= 29) {
      // Android 10-12 (API 29-32)
      permissionsToRequest = [ph.Permission.locationWhenInUse];
    } else {
      // Android 9 and below (API 28-)
      permissionsToRequest = [ph.Permission.locationWhenInUse];
    }

    final statuses = await permissionsToRequest.request();

    // Check if all permissions were granted
    for (final status in statuses.values) {
      if (status != ph.PermissionStatus.granted) {
        return WiFiPermissionStatus.permissionsDenied;
      }
    }

    return WiFiPermissionStatus.granted;
  }

  /// Open location settings
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      return false;
    }
  }

  /// Open app settings
  static Future<bool> openAppSettings() async {
    try {
      return await ph.openAppSettings();
    } catch (e) {
      return false;
    }
  }

  /// Get user-friendly permission explanation based on platform
  static Future<String> getPermissionExplanation() async {
    if (isIOS) {
      return 'Location permission is required to read Wi-Fi network names (SSID) on iOS. This is an Apple requirement for privacy.';
    }

    if (!isAndroid) {
      return 'Location permission is required to access Wi-Fi information.';
    }

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      return 'This app needs BOTH "Nearby Wi-Fi devices" AND "Location" permissions (plus Location Services ON) to read Wi-Fi names and connect to device networks.';
    } else if (sdkInt >= 29) {
      return 'This app needs Location permission and Location Services ON to read Wi-Fi names and connect to device networks.';
    } else {
      return 'This app needs Location permission to access Wi-Fi information.';
    }
  }
}

/// Status of Wi-Fi permissions
enum WiFiPermissionStatus {
  granted,
  permissionsDenied,
  locationServicesDisabled,
  permanentlyDenied,
}

/// Extension for user-friendly status messages
extension WiFiPermissionStatusExtension on WiFiPermissionStatus {
  String get message {
    switch (this) {
      case WiFiPermissionStatus.granted:
        return 'All permissions granted';
      case WiFiPermissionStatus.permissionsDenied:
        return 'Wi-Fi permissions are required';
      case WiFiPermissionStatus.locationServicesDisabled:
        return 'Location Services must be enabled';
      case WiFiPermissionStatus.permanentlyDenied:
        return 'Permissions permanently denied. Please enable in Settings.';
    }
  }

  bool get isGranted => this == WiFiPermissionStatus.granted;
}
