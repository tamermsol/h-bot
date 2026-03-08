// Conditional export: real wifi_iot for native, simple stub for web
export 'wifi_plugin_io.dart' if (dart.library.html) 'wifi_plugin_web.dart';
