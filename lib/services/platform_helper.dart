import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Lightweight platform helpers that avoid importing `dart:io` so the code
/// can be compiled for web. Use `isAndroid` / `isIOS` instead of
/// `Platform.isAndroid` / `Platform.isIOS`.
bool get isWeb => kIsWeb;

bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
