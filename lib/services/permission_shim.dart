// Conditional export: native permission_handler or web stub
export 'permission_shim_io.dart'
    if (dart.library.html) 'permission_shim_web.dart';
