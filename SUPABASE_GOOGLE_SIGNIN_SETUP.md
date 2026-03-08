# Supabase Google Sign-In Setup Guide

## 📋 **Your Information**
- **Package Name**: `com.example.hbot`
- **SHA-1 Fingerprint**: `AC:F5:4C:A0:B6:71:BE:60:E7:94:6F:08:A7:E8:DA:61:BB:0F:C8:93`

## 🔧 **Step 1: Google Cloud Console Setup**

1. **Go to [Google Cloud Console](https://console.cloud.google.com/)**
2. **Create a new project** or select existing one
3. **Enable APIs**:
   - Go to "APIs & Services" → "Library"
   - Search for "Google+ API" and enable it
   - Search for "Google Sign-In API" and enable it

4. **Create OAuth 2.0 Credentials**:
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "OAuth 2.0 Client IDs"
   - Choose "Android"
   - **Package name**: `com.example.hbot`
   - **SHA-1 certificate fingerprint**: `AC:F5:4C:A0:B6:71:BE:60:E7:94:6F:08:A7:E8:DA:61:BB:0F:C8:93`
   - Click "Create"

5. **Also create Web Client** (for Supabase):
   - Click "Create Credentials" → "OAuth 2.0 Client IDs"
   - Choose "Web application"
   - **Authorized redirect URIs**: `https://mvmvqycvorstsftcldzs.supabase.co/auth/v1/callback`
   - Click "Create"

6. **Copy both Client IDs and Secrets** (you'll need them for Supabase)

## 🔧 **Step 2: Download google-services.json**

1. **In Google Cloud Console**, go to your project
2. **Go to "APIs & Services" → "Credentials"**
3. **Find your Android OAuth client**
4. **Download the `google-services.json` file**
5. **Replace** the template file at `android/app/google-services.json` with the real one

## 🔧 **Step 3: Supabase Configuration**

1. **Go to your Supabase Dashboard**: https://supabase.com/dashboard
2. **Select your project**: `mvmvqycvorstsftcldzs`
3. **Navigate to Authentication** → **Providers**
4. **Enable Google Provider**:
   - Toggle "Enable sign in with Google"
   - **Client ID**: Paste the **Web Client ID** from Google Cloud Console
   - **Client Secret**: Paste the **Web Client Secret** from Google Cloud Console
   - **Redirect URL**: `https://mvmvqycvorstsftcldzs.supabase.co/auth/v1/callback`
   - Save changes

## 🔧 **Step 4: Update Flutter App**

1. **Update the Client ID** in `lib/auth/auth_repo.dart`:
   ```dart
   final GoogleSignIn _googleSignIn = GoogleSignIn(
     clientId: 'YOUR_ANDROID_CLIENT_ID.apps.googleusercontent.com', // Use Android Client ID here
   );
   ```

2. **Replace** `YOUR_ANDROID_CLIENT_ID` with the **Android Client ID** from Google Cloud Console

## 🧪 **Step 5: Test**

1. **Build the app**: `flutter build apk --debug`
2. **Install on device/emulator**
3. **Try Google Sign-In** - should work without errors

## 📝 **Important Notes**

### **Two Different Client IDs**
- **Android Client ID**: Used in Flutter app (`GoogleSignIn` widget)
- **Web Client ID**: Used in Supabase configuration

### **File Locations**
- ✅ `android/app/build.gradle.kts` - Updated with Google Services plugin
- ✅ `android/build.gradle.kts` - Updated with Google Services classpath
- 🔄 `android/app/google-services.json` - Replace with real file from Google Cloud Console
- 🔄 `lib/auth/auth_repo.dart` - Update with real Android Client ID

### **Current Status**
- ✅ SHA-1 fingerprint generated
- ✅ Android configuration updated
- ✅ Template files created
- ⏳ Waiting for Google Cloud Console setup
- ⏳ Waiting for real google-services.json file
- ⏳ Waiting for Supabase provider configuration

## 🎯 **Next Steps**

1. **Complete Google Cloud Console setup** (Steps 1-2)
2. **Configure Supabase provider** (Step 3)
3. **Update Client ID in app** (Step 4)
4. **Test Google Sign-In** (Step 5)

## 🔄 **Alternative: Keep Using Email/Password**

If Google Sign-In setup seems complex, you can continue using email/password authentication which is fully working and provides the same functionality.

The app works perfectly without Google Sign-In! 🚀
