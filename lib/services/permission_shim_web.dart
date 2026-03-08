class PermissionStatus {
  final bool isGranted;
  const PermissionStatus(this.isGranted);
  bool get isDenied => !isGranted;

  static const granted = PermissionStatus(true);
  static const denied = PermissionStatus(false);
}

class Permission {
  static Permission get location => Permission();
  static Permission get locationWhenInUse => Permission();
  static Permission get nearbyWifiDevices => Permission();

  Future<PermissionStatus> get status async => const PermissionStatus(true);
  Future<PermissionStatus> request() async => const PermissionStatus(true);
}

// Extension for list of permissions
extension PermissionListExtension on List<Permission> {
  Future<Map<Permission, PermissionStatus>> request() async {
    final Map<Permission, PermissionStatus> result = {};
    for (final permission in this) {
      result[permission] = await permission.request();
    }
    return result;
  }
}

Future<bool> openAppSettings() async {
  // Web doesn't have app settings
  return false;
}

class PermissionHelper {
  static const PermissionStatus granted = PermissionStatus(true);
  static const PermissionStatus denied = PermissionStatus(false);

  static Permission get location => Permission.location;
  static Permission get locationWhenInUse => Permission.locationWhenInUse;
  static Permission get nearbyWifiDevices => Permission.nearbyWifiDevices;
}
