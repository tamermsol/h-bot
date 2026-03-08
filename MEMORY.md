
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
