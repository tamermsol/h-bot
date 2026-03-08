# Google Sign-In Setup for Mobile

To enable Google Sign-In on mobile, you need to configure it properly. Here's the complete setup:

## 1. Google Cloud Console Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Sign-In API
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client IDs"

### For Android:
- Application type: Android
- Package name: `com.example.hbot` (from your build.gradle.kts)
- SHA-1 certificate fingerprint: Get it by running:
  ```bash
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```

### For iOS (if needed):
- Application type: iOS
- Bundle ID: `com.example.hbot`

## 2. Download Configuration Files

### For Android:
1. Download `google-services.json` from Google Cloud Console
2. Place it in `android/app/google-services.json`

### For iOS:
1. Download `GoogleService-Info.plist`
2. Place it in `ios/Runner/GoogleService-Info.plist`

## 3. Update Android Configuration

Add to `android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Add this line
}

dependencies {
    implementation("com.google.android.gms:play-services-auth:20.7.0") // Add this line
}
```

Add to `android/build.gradle.kts`:

```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.3.15") // Add this line
    }
}
```

## 4. Update AuthRepo Configuration

In `lib/auth/auth_repo.dart`, replace the placeholder client ID:

```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: 'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com', // Replace with your actual client ID
);
```

## 5. Supabase Configuration

1. Go to your Supabase project dashboard
2. Navigate to Authentication → Providers
3. Enable Google provider
4. Add your Google OAuth client ID and secret
5. Set the redirect URL to: `com.example.hbot://login-callback/`

## 6. Test the Implementation

1. Run `flutter pub get`
2. Run the app on an Android device/emulator
3. Try Google Sign-In - it should now work properly

## Current Status

- ✅ NDK version fixed (27.0.12077973)
- ✅ Google Sign-In implementation ready
- ⏳ Requires Google Cloud Console setup
- ⏳ Requires google-services.json file
- ⏳ Requires Supabase Google provider configuration

## Temporary Workaround

For now, you can use email/password authentication which is fully working. The Google Sign-In will show an error message asking users to use email/password until the full setup is completed.

## Quick Test

To test that the app works without Google Sign-In:
1. Use the email/password sign-up/sign-in
2. Use the dev menu to create demo data
3. Test realtime device state updates
