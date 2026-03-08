# Setup Biometric Authentication - Quick Guide

## What It Does

Requires fingerprint/face/PIN authentication before generating QR codes for device sharing.

## Setup Steps

### 1. Install Package

```bash
flutter pub get
```

### 2. Restart App

```bash
flutter run
```

### 3. Test It

1. Open any device
2. Tap menu (⋮) → "Share Device"
3. Tap "Generate QR Code"
4. **Biometric prompt appears!** 📱
5. Authenticate with fingerprint/face/PIN
6. QR code generates ✅

## That's It!

Now every time someone wants to generate a QR code to share a device, they must authenticate first.

## What's Supported

- ✅ Fingerprint
- ✅ Face recognition
- ✅ Device PIN
- ✅ Device password
- ✅ Pattern lock

## Benefits

- 🔒 Extra security layer
- 📱 Uses device's built-in security
- ✅ No separate passwords to remember
- 🚀 Seamless user experience

---

**Time**: 1 minute  
**Complexity**: Easy  
**Security**: Enhanced 🔒
