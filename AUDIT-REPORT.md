# H-Bot Flutter App — Production Readiness Audit

**Date:** 2026-03-15  
**Auditor:** hbot subagent (deep-dive session)  
**Scope:** All screens in `lib/screens/`, all widgets in `lib/widgets/`, `lib/main.dart`, `lib/theme/app_theme.dart`, `lib/services/`

---

## Executive Summary

The app has a solid functional core — MQTT device control, Supabase auth, scene management, and provisioning all appear wired to real services. However, there are **5 production blockers**, **7 broken/dead UI elements**, and **1 dev-only screen that must be removed** before shipping.

---

## 🔴 Production Blockers (Must Fix)

| # | Location | Issue |
|---|----------|-------|
| 1 | `profile_screen.dart:318` | **COMPILE ERROR** — `RoomsScreen()` called without required `home` parameter |
| 2 | `figma_service.dart:8` | **Hardcoded placeholder token** — `'YOUR_FIGMA_PERSONAL_ACCESS_TOKEN'` — all Figma API calls fail |
| 3 | `app_theme.dart` | **Dark theme is a stub** — `darkTheme()` calls `lightTheme().copyWith(...)` with minimal overrides; entire app stays light-colored in dark mode |
| 4 | `main.dart` | **Flutter boilerplate left in** — `MyHomePage` counter-app class is in production `main.dart`, never used |
| 5 | `figma_dev_screen.dart` | **Dev-only screen in production codebase** — pre-filled with internal Figma URL, broken API token, should not ship |

---

## Screen-by-Screen Breakdown

---

### `main.dart`

| Element | Status | Notes |
|---------|--------|-------|
| App entry flow (`SplashScreen` → `AuthWrapper` → `HomeScreen`) | ✅ WORKS | Correct, clean |
| Supabase init | ✅ WORKS | |
| ThemeService Provider setup | ✅ WORKS | Correctly wraps app |
| Auth listener for service start/stop | ✅ WORKS | `SceneTriggerScheduler`, `LocationTriggerMonitor`, `SceneCommandExecutor` |
| `MyHomePage` class (Flutter counter boilerplate) | 🗑️ REMOVE | ~60 lines of default Flutter counter code with comments like "TRY THIS:", never referenced, clutters main.dart |

---

### `home_screen.dart` (Bottom Nav shell)

| Element | Status | Notes |
|---------|--------|-------|
| Bottom navigation (Home / Scenes / Profile) | ✅ WORKS | |
| Connectivity banner | ✅ WORKS | Polls `NetworkConnectivityService` every 10s |
| `HomeScreen` background color | ⚠️ PARTIAL | Hardcoded `HBotColors.backgroundLight` — won't respect dark mode |

---

### `home_dashboard_screen.dart`

| Element | Status | Notes |
|---------|--------|-------|
| Home selector / home switching | ✅ WORKS | |
| Device list by room | ✅ WORKS | Real Supabase data |
| MQTT device state updates | ✅ WORKS | |
| Add device (HBOT via Wi-Fi) | ✅ WORKS | Navigates to `AddDeviceFlowScreen` |
| **"Other Device" option** | ❌ BROKEN | `enabled: false`, subtitle `'Coming soon...'` — visually dead placeholder |
| **Notification bell** | ❌ BROKEN | `onPressed: () {}` — tapping does absolutely nothing (line 960) |
| Manage Homes menu item | ✅ WORKS | |
| Background picker | ✅ WORKS | |
| `_greeting` getter | ⚠️ PARTIAL | Has `@override` annotation on a non-overriding getter in a state class — annotation is wrong/misleading but functionally works |
| Room filter chips | ✅ WORKS | |
| Device cards / toggle | ✅ WORKS | Via `MqttDeviceManager` |

---

### `profile_screen.dart`

| Element | Status | Notes |
|---------|--------|-------|
| Profile header (name, email, avatar) | ✅ WORKS | Loads from Supabase auth + profile table |
| Avatar picker (gallery / camera / default) | ✅ WORKS | Via `AvatarService` |
| Statistics (homes, devices, rooms, scenes) | ✅ WORKS | Aggregates across all user homes |
| **"Rooms" tile** | ❌ BROKEN | Navigates to `const RoomsScreen()` — **compile error**, `RoomsScreen` requires `required Home home` (line 18 of `rooms_screen.dart`) |
| **"WiFi Profiles" tile** | ⚠️ PARTIAL | Navigates to `WiFiProfileScreen()` — compiles OK (all params optional), but no home context passed; user may see empty/confusing state |
| Notifications → `NotificationsSettingsScreen` | ✅ WORKS | |
| Appearance tile | ⚠️ PARTIAL | `value: 'Light'` is **hardcoded** — never updates to reflect actual theme mode |
| Appearance dialog (radio buttons) | ✅ WORKS | Correctly calls `ThemeService.setThemeMode()` |
| About → `HelpCenterScreen` | ✅ WORKS | |
| Personal Information → `ProfileEditScreen` | ✅ WORKS | |
| Change Password dialog | ✅ WORKS | Email/password auth only (`canChangePassword()` guard) |
| Manage Homes → `HomesScreen` | ✅ WORKS | |
| Share Devices → `MultiDeviceShareScreen` | ✅ WORKS | Queries Supabase for home ID first |
| Shared with Me → `SharedDevicesScreen` | ✅ WORKS | |
| Sign Out dialog | ✅ WORKS | |
| `_openHBOTAccountScreen()` method | 🗑️ REMOVE | Defined (line 453) but **never called** from any UI element — dead code |

---

### `appearance_settings_screen.dart`

| Element | Status | Notes |
|---------|--------|-------|
| Dark mode toggle (wiring) | ✅ WORKS | Calls `ThemeService.setThemeMode()`, listens for changes |
| Dark mode toggle (visual effect) | ❌ BROKEN | All colors hardcoded: `backgroundColor: isDark ? HBotColors.backgroundLight : HBotColors.backgroundLight` — **both branches are identical**. The screen stays white in dark mode. |
| Theme info card | ⚠️ PARTIAL | Says "Theme changes apply immediately across the entire app" — partially true, but dark mode doesn't actually work app-wide |

---

### `notifications_settings_screen.dart`

| Element | Status | Notes |
|---------|--------|-------|
| Enable/disable toggle | ✅ WORKS | `permission_handler` + SharedPreferences persist |
| Permission denied dialog | ✅ WORKS | |
| Permanently denied → Open Settings | ✅ WORKS | `openAppSettings()` |
| Permission status warning banner | ✅ WORKS | |
| "What you'll receive" info items | ⚠️ PARTIAL | Device Status / Automation Alerts / System Updates are **informational only** — no individual toggles, no backend notification routing per category |
| Background color in dark mode | ❌ BROKEN | Same pattern: `isDark ? HBotColors.backgroundLight : HBotColors.backgroundLight` |

---

### `scenes_screen.dart`

| Element | Status | Notes |
|---------|--------|-------|
| Load scenes from Supabase | ✅ WORKS | |
| Add scene → `AddSceneScreen` | ✅ WORKS | |
| Run scene | ✅ WORKS | Calls `SmartHomeService.runScene()` |
| Toggle scene enable/disable | ✅ WORKS | |
| Edit scene | ✅ WORKS | |
| Delete scene | ✅ WORKS | |
| **Scene action count** | ❌ BROKEN | Hardcoded `${0} action${0 != 1 ? "s" : ""}` — always shows "0 actions". `Scene` model has no `actions` field. Both in card view and bottom sheet detail. |
| No home selected state | ✅ WORKS | |
| Empty state + create button | ✅ WORKS | |

---

### `figma_dev_screen.dart`

| Element | Status | Notes |
|---------|--------|-------|
| **Entire screen** | 🗑️ REMOVE | Dev-only Figma API browser. Hardcoded internal Figma URL pre-filled. Uses `FigmaService` with placeholder API token — all calls fail. Not linked from any production UI. Has no place in a production build. |

---

### `feedback_screen.dart`

| Element | Status | Notes |
|---------|--------|-------|
| Send via Email | ✅ WORKS | Opens `mailto:support@h-bot.tech` via `url_launcher` |
| Send via WhatsApp | ✅ WORKS | Opens `wa.me/201281167100` |
| Empty feedback validation | ✅ WORKS | |
| Background color in dark mode | ❌ BROKEN | Hardcoded light colors |

---

### `help_center_screen.dart`

| Element | Status | Notes |
|---------|--------|-------|
| Website link | ✅ WORKS | |
| Email link | ✅ WORKS | |
| Phone link | ✅ WORKS | |
| WhatsApp link | ✅ WORKS | |
| Background color in dark mode | ❌ BROKEN | Hardcoded light colors |

---

### Other Screens (no major issues found)

| Screen | Status | Notes |
|--------|--------|-------|
| `sign_in_screen.dart` | ✅ WORKS | Supabase auth |
| `sign_up_screen.dart` | ✅ WORKS | |
| `splash_screen.dart` | ✅ WORKS | |
| `auth_wrapper.dart` | ✅ WORKS | Auth state routing |
| `forgot_password_screen.dart` | ✅ WORKS | |
| `reset_password_screen.dart` | ✅ WORKS | |
| `email_confirmation_screen.dart` | ✅ WORKS | |
| `homes_screen.dart` | ✅ WORKS | Navigates to `RoomsScreen(home: home)` correctly (unlike profile_screen) |
| `device_control_screen.dart` | ✅ WORKS | Full MQTT + channel management |
| `add_device_flow_screen.dart` | ✅ WORKS | Wi-Fi provisioning flow |
| `devices_screen.dart` | ✅ WORKS | |
| `rooms_screen.dart` | ✅ WORKS | CRUD rooms |
| `add_scene_screen.dart` | ✅ WORKS | |
| `add_timer_screen.dart` | ✅ WORKS | |
| `device_timers_screen.dart` | ✅ WORKS | |
| `profile_edit_screen.dart` | ✅ WORKS | |
| `hbot_account_screen.dart` | ✅ WORKS | |
| `share_device_screen.dart` | ✅ WORKS | |
| `multi_device_share_screen.dart` | ✅ WORKS | |
| `shared_devices_screen.dart` | ✅ WORKS | |
| `shutter_calibration_screen.dart` | ✅ WORKS | |
| `shutter_manual_calibration_screen.dart` | ✅ WORKS | |
| `scan_device_qr_screen.dart` | ✅ WORKS | |
| `otp_verification_screen.dart` | ✅ WORKS | |
| `wifi_profile_screen.dart` | ✅ WORKS | (optional params, compiles fine) |

---

## Widget Audit

| Widget | Status | Notes |
|--------|--------|-------|
| `device_card.dart` | ✅ WORKS | MQTT-driven |
| `device_control_widget.dart` | ✅ WORKS | |
| `enhanced_device_control_widget.dart` | ✅ WORKS | |
| `shutter_control_widget.dart` | ✅ WORKS | |
| `scene_card.dart` | ✅ WORKS | |
| `profile_card.dart` | ✅ WORKS | |
| `settings_tile.dart` | ✅ WORKS | Generic settings row |
| `connectivity_banner.dart` | ✅ WORKS | |
| `error_message_widget.dart` | ✅ WORKS | |
| `smart_input_field.dart` | ✅ WORKS | |
| `background_container.dart` | ✅ WORKS | |
| `background_image_picker.dart` | ✅ WORKS | |
| `avatar_picker_dialog.dart` | ✅ WORKS | |
| `room_icon_picker.dart` | ✅ WORKS | |
| `scene_icon_selector.dart` | ✅ WORKS | |
| `mqtt_debug_sheet.dart` | ⚠️ PARTIAL | Debug utility — acceptable if behind a flag; review whether it should be prod-accessible |
| `step_indicator.dart` | ✅ WORKS | |
| `device_selector.dart` | ✅ WORKS | |
| `wifi_permission_gate.dart` | ✅ WORKS | |
| **`price_display.dart`** | 🗑️ REMOVE | Unused — no screen or widget imports or uses `PriceDisplay`. Currency widget has no purpose in an IoT home automation app. |

---

## Services Audit

| Service | Used By | Status | Notes |
|---------|---------|--------|-------|
| `auth_service.dart` | auth screens, profile | ✅ WORKS | |
| `smart_home_service.dart` | nearly everything | ✅ WORKS | Main CRUD façade |
| `mqtt_device_manager.dart` | dashboard, device control | ✅ WORKS | Singleton |
| `enhanced_mqtt_service.dart` | main.dart, lifecycle | ✅ WORKS | |
| `theme_service.dart` | appearance settings, profile, main | ✅ WORKS | `ChangeNotifier`, SharedPreferences-backed |
| `current_home_service.dart` | dashboard, scenes, profile | ✅ WORKS | |
| `avatar_service.dart` | profile | ✅ WORKS | |
| `background_image_service.dart` | dashboard | ✅ WORKS | |
| `network_connectivity_service.dart` | home_screen | ✅ WORKS | |
| `wifi_provisioning_service.dart` | add_device_flow | ✅ WORKS | |
| `scene_trigger_scheduler.dart` | main.dart | ✅ WORKS | Starts/stops with auth |
| `location_trigger_monitor.dart` | main.dart | ✅ WORKS | |
| `scene_command_executor.dart` | main.dart | ✅ WORKS | |
| `device_state_cache.dart` | main.dart | ✅ WORKS | |
| **`figma_service.dart`** | figma_dev_screen only | 🗑️ REMOVE | Hardcoded `'YOUR_FIGMA_PERSONAL_ACCESS_TOKEN'` placeholder — all API calls 401. Only used by dev screen. Remove with screen. |
| `app_lifecycle_manager.dart` | main.dart | ✅ WORKS | |
| `room_change_notifier.dart` | rooms, dashboard | ✅ WORKS | |
| `device_discovery_service.dart` | provisioning | ✅ WORKS | |

---

## `app_theme.dart` — Dark Mode Analysis

**Verdict: Dark mode is declared but non-functional.**

- `AppTheme.darkTheme()` calls `lightTheme().copyWith(brightness: Brightness.dark, scaffoldBackgroundColor: HBotColors.backgroundDark, colorScheme: ...)` 
- This only overrides scaffold background and colorScheme
- **All screens hardcode light colors** with patterns like:
  ```dart
  backgroundColor: isDark ? HBotColors.backgroundLight : HBotColors.backgroundLight
  ```
  Both branches return the same value — the condition is meaningless.
- `HBotColors.backgroundDark`, `HBotColors.cardDark`, `HBotColors.textPrimaryDark` are all defined but never used in screen files
- `AppTheme.getCardColor(context)` and `AppTheme.getTextPrimary(context)` exist as context-adaptive helpers but are **not used** by any screen
- **Effect:** Toggling dark mode changes `ThemeData.brightness` but no widget actually responds to it — the app stays white

---

## Summary: All Items to Fix/Remove

### 🔴 Critical (Crashes / Blockers)

1. **`profile_screen.dart:318`** — `const RoomsScreen()` missing required `home:` param → compile/runtime crash  
   **Fix:** Either pass a home object, or navigate via `HomesScreen` which handles home selection first

2. **`main.dart`** — Remove `MyHomePage` boilerplate class (~60 lines) that was never cleaned up from Flutter project creation

3. **`figma_dev_screen.dart` + `figma_service.dart`** — Remove entirely; pure dev tool with broken API credentials, not linked from production UI

### 🟠 Broken Features (High Priority)

4. **Dark mode** — Screen files hardcode `HBotColors.backgroundLight`/`cardLight` everywhere. Either:
   - Use `AppTheme.getCardColor(context)` / `AppTheme.getTextPrimary(context)` throughout, OR
   - Replace hardcoded color refs with `Theme.of(context).scaffoldBackgroundColor` etc.
   - Fix the identical-branch anti-pattern: `isDark ? HBotColors.backgroundLight : HBotColors.backgroundLight`

5. **Notification bell in `home_dashboard_screen.dart:960`** — `onPressed: () {}` — implement or remove the bell icon

6. **Scene action count in `scenes_screen.dart`** — `${0} action${0 != 1 ? "s" : ""}` always shows "0 actions". Either add `actions` to `Scene` model and load them, or remove the count label until it's implemented.

7. **"Other Device" option in `home_dashboard_screen.dart`** — `enabled: false, subtitle: 'Coming soon...'` — remove from production until it's implemented

### 🟡 Partial / Cosmetic (Medium Priority)

8. **`profile_screen.dart`** — Appearance tile `value: 'Light'` hardcoded — should reflect actual current theme mode dynamically from `ThemeService`

9. **`profile_screen.dart`** — `_openHBOTAccountScreen()` is defined but never called from any UI element — dead method, remove or wire it

10. **`wifi_profile_screen.dart`** — Accessible from profile but no home context; `WiFiProfileScreen` works standalone but user experience may be confusing without home association

11. **`notifications_settings_screen.dart`** — "What you'll receive" section items are info-only with no per-category toggle — acceptable UX but may confuse users who expect individual controls

### 🗑️ Remove

12. **`lib/widgets/price_display.dart`** — Unused widget (no imports anywhere); currency/price display has no purpose in this IoT app

13. **`figma_dev_screen.dart`** (repeated for emphasis) — 🗑️ REMOVE

14. **`figma_service.dart`** (repeated for emphasis) — 🗑️ REMOVE

---

## Quick Fix Checklist

```
[ ] Remove MyHomePage from main.dart
[ ] Delete figma_dev_screen.dart + figma_service.dart  
[ ] Fix profile_screen.dart:318 RoomsScreen() missing home param
[ ] Fix scene action count (or remove label)
[ ] Wire notification bell (or remove icon)
[ ] Remove "Other Device" coming-soon item
[ ] Fix dark mode: replace hardcoded light colors with context-adaptive values
[ ] Fix Appearance tile hardcoded 'Light' value in profile
[ ] Remove unused _openHBOTAccountScreen() method
[ ] Delete lib/widgets/price_display.dart
```
