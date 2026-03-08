import '../services/platform_helper.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for platform-specific functionality
class PlatformService {
  /// Open Wi-Fi settings on the device
  static Future<bool> openWiFiSettings() async {
    try {
      if (isAndroid) {
        // Open Android Wi-Fi settings
        final uri = Uri.parse('android.settings.WIFI_SETTINGS');
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        // Fallback to general settings
        final settingsUri = Uri.parse('android.settings.SETTINGS');
        if (await canLaunchUrl(settingsUri)) {
          return await launchUrl(
            settingsUri,
            mode: LaunchMode.externalApplication,
          );
        }
      } else if (isIOS) {
        // Open iOS Wi-Fi settings
        final uri = Uri.parse('App-Prefs:root=WIFI');
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        // Fallback to general settings
        final settingsUri = Uri.parse('App-Prefs:root=General');
        if (await canLaunchUrl(settingsUri)) {
          return await launchUrl(
            settingsUri,
            mode: LaunchMode.externalApplication,
          );
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Open general device settings
  static Future<bool> openSettings() async {
    try {
      if (isAndroid) {
        final uri = Uri.parse('android.settings.SETTINGS');
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else if (isIOS) {
        final uri = Uri.parse('App-Prefs:root=General');
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
