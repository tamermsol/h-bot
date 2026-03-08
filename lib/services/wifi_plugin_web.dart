class WifiNetwork {
  final String? ssid;
  WifiNetwork(this.ssid);
}

class WiFiForIoTPlugin {
  static Future<List<WifiNetwork>> loadWifiList() async => [];
  static Future<bool> connect(
    String ssid, {
    String? password,
    bool joinOnce = true,
    int? timeoutInSeconds,
  }) async => false;
  static Future<void> disconnect() async {}
}
