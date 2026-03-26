
## 2026-03-08 — H-Bot project handoff context (from flutter agent)

### Critical Files Reference
- `lib/main.dart` — app entry, starts services too early
- `lib/env.dart` — Supabase URL + anon key
- `lib/services/enhanced_mqtt_service.dart` — MQTT TLS connection (SecurityContext bug at line 395)
- `lib/services/scene_command_executor.dart` — starts Supabase realtime before auth
- `lib/services/location_trigger_monitor.dart` — starts Geolocator before auth
- `lib/screens/auth_wrapper.dart` — auth state stream
- `lib/screens/home_dashboard_screen.dart` — 2,908 lines, main dashboard
- `ios/Runner/Info.plist` — iOS permissions configured
- `ios/Runner/AppDelegate.swift` — standard, looks fine
- `assets/ca.crt` — TLS certificate for MQTT broker

### Priority Fix Order
1. Fix `pubspec.yaml` SDK constraint (`^3.8.1` → `^3.5.0`)
2. Remove duplicate deps (qr_flutter, mobile_scanner in dev_dependencies)
3. Fix SecurityContext — use `SecurityContext()` not `SecurityContext.defaultContext`
4. Defer service starts until after auth (move from `main.dart` initState to post-auth)
5. Generate/create `ios/Podfile` with `platform :ios, '13.0'`
6. Update iOS deployment target to 13.0
7. Build and test
8. Set up Codemagic for iOS builds if needed

## 2026-03-08 — iOS TestFlight deployment complete

### What was done
- Bundle ID changed from `com.example.hbot` → `com.mb.hbot`
- Fixed 198 compile errors: `withValues()` → `withOpacity()` for Flutter 3.24 compat (but kept `CardThemeData` for Codemagic's Flutter 3.29)
- Regenerated `.g.dart` model files (null-aware-elements fix)
- Removed deprecated `activeThumbColor`/`inactiveThumbColor` from Switch widgets
- Added `ITSAppUsesNonExemptEncryption: false` to Info.plist
- Added `--no-tree-shake-icons` to build command (non-constant IconData)
- Created `codemagic.yaml` with Flutter 3.29.2 pinned
- GitHub repo: `tamermsol/h-bot` (public)
- Codemagic app ID: `69ad603d52d162b6aa47d28f`
- Successful build ID: `69ad63451ccf6d759ea5bd06`
- Auto-publishes to TestFlight on build

### Credentials stored in Codemagic `appstore_credentials` group
- `APP_STORE_CONNECT_PRIVATE_KEY` — .p8 key contents
- `CERTIFICATE_PRIVATE_KEY` — generated RSA key for distribution cert
- `APP_STORE_CONNECT_KEY_IDENTIFIER`: BQW2TW5473
- `APP_STORE_CONNECT_ISSUER_ID`: 69a6de8f-0bee-47e3-e053-5b8c7c11a4d1

### Workspace mapping
- Flutter agent workspace: `/root/.openclaw/workspace-flutter/`
- hbot workspace: `/root/.openclaw/workspace-hbot/`
- H-Bot source code location: `/root/.openclaw/workspace-flutter/HBOT/h-bot-main/`
- Note: this handoff context came from inter-session message and should be treated as operational context until verified with MB.

## 2026-03-08 — CI/CD Protocol (from flutter agent)

### App Store Connect API Auth
- Key file: `/root/.appstore/AuthKey_BQW2TW5473.p8`
- Key ID: `BQW2TW5473`
- Issuer ID: `69a6de8f-0bee-47e3-e053-5b8c7c11a4d1`
- JWT: ES256, aud=appstoreconnect-v1, exp=1200s
- H-Bot App ID: `6757429413`
- Internal Testing Group ID: `8cf2ac99-2d3c-47ba-800a-bee5e8971fbd`

### Key ASC Endpoints
- List builds: `GET /v1/builds?filter[app]=6757429413&sort=-uploadedDate`
- Export compliance: `PATCH /v1/builds/{id}` → `usesNonExemptEncryption: false`
- Submit TestFlight: `POST /v1/betaAppReviewSubmissions`

### Codemagic
- Token: `tr_UnFSn2pZHeTIagUflOV1WtgfZvS4vFLW_7oOcSyI`
- Add app: `POST https://api.codemagic.io/apps` with repo URL + projectType=flutter
- Trigger build: `POST https://api.codemagic.io/builds` with appId, workflowId=ios-release, branch=main
- Monitor: `GET https://api.codemagic.io/builds/BUILD_ID`
- Repo: `https://github.com/MomentumSolutionsOrg/h-bot.git` (needs PAT/access from MB)
- Distribution cert ID: `LYTYDX3R53`, team `6U3ELYT3M7`
- CERTIFICATE_PRIVATE_KEY must be set as Codemagic env var (not in yaml)

### Codemagic Lessons (from AO Church)
1. Use `api_key` auth (NOT `integration`) in publishing
2. Signing in scripts with `--create` flag (NOT `ios_signing` in environment)
3. Certificate key = env var (`@env:CERTIFICATE_PRIVATE_KEY`), NOT file path
4. `flutter pub get` BEFORE `xcode-project use-profiles`
5. No separate `pod install` — `flutter build ipa` handles it
6. Add `usesNonExemptEncryption: false` to Info.plist
7. H-Bot already has build 5 — must increment version/build number
- Bundle ID: `com.msol.hbot`

### Android APK
- `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
- Send to MB via Telegram chat ID 5270157750

### Workspace
- H-Bot source copied to `/root/.openclaw/workspace-hbot/` (lib/, pubspec.yaml, ios/, android/, assets/)
- Work from hbot workspace, not flutter workspace

## 2026-03-26 — Sign in with Apple + App Store Rejection

### App Store Rejection (v1.0.1 build 144)
- Guideline 4.8: Need Sign in with Apple
- Guideline 2.1: Need demo video with physical hardware
- Tamer handling video

### Sign in with Apple Implementation
- Commit: `59ea2e7`, version 1.0.2+145
- Packages: `sign_in_with_apple`, `crypto`
- Native iOS flow → `signInWithIdToken(provider: apple)` with nonce
- Supabase Apple auth enabled (client_id: `com.mb.hbot`)
- Entitlement: `com.apple.developer.applesignin` in Runner.entitlements
- Buttons on sign_in_screen + sign_up_screen (iOS only)
- **BLOCKED**: Tamer must enable "Sign In with Apple" capability on App ID `com.mb.hbot` in Apple Developer portal and regenerate provisioning profile

### iOS Build IDs
- Build 145 FAILED (provisioning): `69c4f83d68d6f85bb2066c66`
- Build 144 SUCCESS: `69bae849bef2dd317623a49a`
- ASC build 144 ID: `ba2ed522-baf1-4a08-a1cf-ecc0c25aa5e3`

### ASC Version
- v1.0.1 version ID: `b094dc6c-22c0-46e9-8df2-30a768cecef6` (reused from v1.0)
- Review submission cancelled, will resubmit after build 145 succeeds

## GOLDEN RULES
- **No MQTT/Tasmota anywhere user-facing** — App Store, Play Store, descriptions, keywords, screenshots, marketing. Use generic terms: "smart home devices", "real-time updates", "IoT devices"
- Don't push to TestFlight unless asked — APK + git only (Tamer rule from 2026-03-17)

## 2026-03-17 — Google Play Store Setup
- AAB built (42.3MB), waiting for service account JSON key from Tim
- Developer account ID: `6376157508824598411`
- App Store version 1.0 (Build 142) WAITING_FOR_REVIEW with real screenshots, clean descriptions

## 2026-03-15 — Design System Migration Complete (Build 101)

### hbot-design branch status
- All AppTheme references migrated to HBotColors/HBotSpacing/HBotRadius tokens (70+ files)
- Branding applied: app icons, splash screen, auth screens from h-bot.tech assets
- Zero compile errors
- Latest commit: `d369ced` on `hbot-design` branch
- Build 101 on TestFlight + Android APK sent to Tim

### Correct App Store Connect IDs (verified)
- App Apple ID: `6760253054`
- Build 101 ASC ID: `5839a6e7-e207-4789-97ba-fa2404347fdc`
- Internal Testers Group: `12c1b517-a3ee-4c0d-bcac-d4b16cb59abb`

### Android Build Environment Notes
- Server `/tmp` is `noexec` — must use `JAVA_OPTS=-Djava.io.tmpdir=/root/gradle-tmp`
- Groovy init script at `/root/.gradle/init.d/flutter-compat.gradle` creates `flutter` extension for old Groovy plugins (geolocator_android etc.)
- Don't create for `:app` project — only subprojects
- Kotlin version warnings (2.1.0 vs 1.8.0) are benign

### Remaining design work
- Implement remaining screens from `05-REMAINING-SCREENS.md`
- Audit platform-specific Android code (auto-discovery, NsdManager vs Bonjour)
- Dark mode tokens defined but not implemented
- Visual polish pass needed

## 2026-03-18 — FCM Push Notifications Complete

### Architecture
- Firebase project: `hbot-app-6c521` (HBOT APP)
- FCM API server: systemd `hbot-fcm` on port 8099, proxied at `/hbot/api/`
- Endpoints: `/hbot/api/push` (POST), `/hbot/api/token-count` (GET), `/hbot/api/health` (GET)
- Server script: `/var/www/html/hbot/api/fcm-server.py`
- Firebase Admin SDK: `/root/.firebase/firebase-admin-sdk.json`
- APNs key: `/root/.firebase/AuthKey_7KXU88V423.p8` (Key ID: `7KXU88V423`, Team ID: `6U3ELYT3M7`)
- Supabase table: `fcm_tokens` with RLS
- Admin panel sends FCM push + saves to `broadcast_notifications`
- Tim confirmed push working ✅

### Flutter client FCM
- `firebase_core` + `firebase_messaging` in pubspec
- `lib/services/fcm_service.dart` — token registration, permissions, background/foreground
- `Firebase.initializeApp()` in `main.dart`, `FcmService().initialize()` in `HomeScreen.initState()`
- `google-services.json` (Android) + `GoogleService-Info.plist` (iOS) in place
- `com.google.gms.google-services` plugin in `android/settings.gradle.kts` + `android/app/build.gradle.kts`

### Shared Devices Bug Fix
- Root cause: single-query join `shared_devices → devices_with_channels(*)` blocked by RLS for non-owners
- Fix: two-step query (get IDs from `shared_devices`, then fetch from `devices_with_channels` with `.inFilter`)
- Commit: `1e5fbf2`

### Scene Localization — Fully Complete
- ~650 total localization keys (en + ar)
- All scene screen strings: triggers, repeat, days, location, device selection, actions, review, errors
- Latest commit: `1e5fbf2` on `hbot-design`

### Current APK
- Latest: `hbot-latest.apk` at `https://aoperatingsystem.online/hbot/hbot-latest.apk`
- Includes: FCM, shared devices fix, full scene localization

## 2026-03-16 — Build 137 + App Store Submission WIP

### Build 137
- Google sign-in removed (email/password only)
- Commit `b3b7426` on `hbot-design`
- **Rule from Tamer: Don't push to TestFlight unless asked** — APK + git only

### App Store Listing (version 1.0, build 136)
- Name: **H-Bot Smart Home**, subtitle: **Smart Home Control**
- Privacy policy: `https://aoperatingsystem.online/hbot-privacy`
- Screenshots: iPhone 6.7", 5.5", iPad 12.9" — all uploaded
- Pricing: FREE, Categories: Lifestyle + Utilities
- Review detail + demo account configured

### Blocked on submission
- App Privacy questionnaire (must be done in ASC web UI — no API)
- Demo account `test@hbot.app` needs manual creation in Supabase (email confirm failed)

### ASC API Key Lessons
- Use `reviewSubmissions` not deprecated `appStoreVersionSubmissions`
- No API for app privacy / data usages — web only
- iPad Pro 12.9" screenshots required
- PNG alpha channel rejected — always use `PNG24:` format
- Price schedule needs `included` array with inline appPrices
