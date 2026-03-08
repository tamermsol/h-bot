# App Name Change: hbot → HBOT

## Changes Made

Changed the app name from "hbot" (lowercase) to "HBOT" (uppercase) across all platforms and configurations.

## Files Modified

### 1. **Main App Configuration**
- **lib/main.dart**
  - Changed `title: 'My Home'` → `title: 'HBOT'`

### 2. **Sign-In Screen**
- **lib/screens/sign_in_screen.dart**
  - Changed app logo text from `'My Home'` → `'HBOT'`

### 3. **Windows Platform**
- **windows/runner/Runner.rc**
  - FileDescription: `"hbot"` → `"HBOT"`
  - InternalName: `"hbot"` → `"HBOT"`
  - OriginalFilename: `"hbot.exe"` → `"HBOT.exe"`
  - ProductName: `"hbot"` → `"HBOT"`

### 4. **Web Platform**
- **web/manifest.json**
  - name: `"hbot"` → `"HBOT"`
  - short_name: `"hbot"` → `"HBOT"`

- **web/index.html**
  - apple-mobile-web-app-title: `"hbot"` → `"HBOT"`
  - title: `"hbot"` → `"HBOT"`

### 5. **macOS Platform**
- **macos/Runner/Configs/AppInfo.xcconfig**
  - PRODUCT_NAME: `hbot` → `HBOT`

### 6. **Linux Platform**
- **linux/runner/my_application.cc**
  - gtk_header_bar_set_title: `"hbot"` → `"HBOT"`
  - gtk_window_set_title: `"hbot"` → `"HBOT"`

## What Users Will See

### Before:
- App title: "My Home" or "hbot"
- Sign-in screen: "My Home"
- Window title: "hbot"
- Web app name: "hbot"

### After:
- App title: "HBOT" ✅
- Sign-in screen: "HBOT" ✅
- Window title: "HBOT" ✅
- Web app name: "HBOT" ✅

## Platform-Specific Display

### Android
- App name in launcher: Controlled by `android/app/src/main/AndroidManifest.xml` (android:label)
- Currently uses: `@string/app_name` from `android/app/src/main/res/values/strings.xml`
- **Note**: If you want to change the Android launcher name, update `strings.xml`

### iOS
- App name in home screen: Controlled by `ios/Runner/Info.plist` (CFBundleDisplayName)
- **Note**: If you want to change the iOS home screen name, update `Info.plist`

### Windows
- Window title: "HBOT" ✅
- Executable name: Still "hbot.exe" (binary name unchanged)
- Product name in properties: "HBOT" ✅

### macOS
- App name: "HBOT" ✅
- Bundle name: "HBOT" ✅

### Linux
- Window title: "HBOT" ✅
- Binary name: Still "hbot" (binary name unchanged)

### Web
- Browser tab title: "HBOT" ✅
- PWA name: "HBOT" ✅
- PWA short name: "HBOT" ✅

## Notes

### Binary Names (Not Changed)
The following binary/executable names remain lowercase for technical reasons:
- `pubspec.yaml`: `name: hbot` (Dart package name - should stay lowercase)
- `windows/CMakeLists.txt`: `BINARY_NAME "hbot"` (executable filename)
- `linux/CMakeLists.txt`: `BINARY_NAME "hbot"` (executable filename)
- `android/app/build.gradle.kts`: `namespace = "com.example.hbot"` (package name)

These are technical identifiers and should remain lowercase following platform conventions.

### What Changed
Only **user-facing display names** were changed to "HBOT" (uppercase):
- App window titles
- Browser tab titles
- Sign-in screen branding
- PWA manifest names
- Product metadata

## Testing

After these changes, you should see:

1. **Sign-In Screen**: "HBOT" logo text
2. **Window Title**: "HBOT" in title bar (Windows/Linux/macOS)
3. **Browser Tab**: "HBOT" when running as web app
4. **Task Manager**: "HBOT" in Windows task manager
5. **About Dialog**: "HBOT" in app information

## Rebuild Required

After making these changes, you need to rebuild the app:

```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Run on your platform
flutter run
```

For production builds:
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release

# Web
flutter build web --release
```

## Conclusion

The app name has been successfully changed from "hbot"/"My Home" to "HBOT" across all user-facing elements while maintaining lowercase technical identifiers where required by platform conventions.
