# UI/UX Design Request — H-Bot IoT Smart Home App

## App Overview
**H-Bot** is an IoT smart home app built in Flutter (iOS 13+ / Android). It controls smart devices (switches, sensors, lights, shutters) via cloud infrastructure. The app is the consumer-facing product for **Momentum Solutions (MSOL)** hardware — a white-label IoT platform. Users should never see any underlying protocol or firmware branding.

**Target audience:** Homeowners installing MSOL smart home hardware. Non-technical. Expect Apple Home / Google Home level polish.

## Current Tech Stack
- **Framework:** Flutter 3.24+ (Dart)
- **Backend:** Supabase (auth, database, realtime)
- **Platforms:** iOS (13+), Android
- **Font:** Inter (system fallback)

---

## Current Design System

### Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Primary | `#2196F3` | Buttons, links, active states |
| Secondary | `#03DAC6` | Accent elements |
| Accent/Success | `#4CAF50` | Success states, toggles |
| Warning | `#2196F3` | Warning banners (currently same as primary — needs fix) |
| Error | `#F44336` | Error states, destructive actions |
| Background (dark) | `#121212` | Dark mode scaffold |
| Surface (dark) | `#1E1E1E` | Dark mode cards |
| Card (dark) | `#2C2C2C` | Dark mode elevated cards |
| Background (light) | `#FFFFFF` | Light mode scaffold |
| Secondary BG (light) | Light grey | Section backgrounds |
| Card (light) | `#F5F7FA` | Card backgrounds |
| Elevated Card (light) | Slightly lighter | Elevated card backgrounds |
| Card Border | `#E5E7EB` | Card/divider borders |
| Text Primary (light) | `#1F2937` | Main text |
| Text Secondary (light) | `#4B5563` | Descriptions, labels |
| Text Disabled (light) | `#9CA3AF` | Disabled/hint text |
| Nav Inactive | `#6B7280` | Bottom nav inactive |

### Spacing & Radius
| Token | Value |
|-------|-------|
| Padding Small | 8px |
| Padding Medium | 16px |
| Padding Large | 24px |
| Padding XLarge | 32px |
| Radius Small | 8px |
| Radius Medium | 12px |
| Radius Large | 16px |
| Radius XLarge | 24px |

### Typography
- **Font Family:** Inter
- App bar titles: 20px, weight 600
- Button text: 16px, weight 600
- Body: system default sizes

---

## App Structure & Navigation

### Bottom Navigation Bar (3 tabs)
| Tab | Icon (inactive) | Icon (active) | Label |
|-----|-----------------|---------------|-------|
| 1 | `home_outlined` | `home` | Home |
| 2 | `auto_awesome_outlined` | `auto_awesome` | Scenes |
| 3 | `person_outline` | `person` | Profile |

---

## Screen-by-Screen Inventory

### 1. Authentication Flow

#### 1a. Sign In Screen (`sign_in_screen.dart` — 378 lines)
- **Background:** Dark (`#1C1C1E`)
- **Elements:**
  - App title/logo area (currently text-only, no logo asset exists)
  - Email text field
  - Password text field with visibility toggle
  - "Sign In" primary button (full-width)
  - Google Sign-In button with `google_logo.png`
  - "Forgot Password?" text button
  - "Don't have an account? Sign Up" text button
- **States:** Loading (spinner replaces button text), error (SnackBar)

#### 1b. Sign Up Screen (`sign_up_screen.dart` — 456 lines)
- **Background:** Dark (`#1C1C1E`)
- **Elements:**
  - Back arrow (AppBar)
  - Email text field
  - Password text field with visibility toggle
  - Confirm password text field with visibility toggle
  - "Sign Up" primary button
  - Google Sign-In button
  - "Already have an account? Sign In" link
- **States:** Loading, error, email confirmation sent

#### 1c. Email Confirmation Screen (`email_confirmation_screen.dart`)
- Post-signup email verification prompt

#### 1d. Forgot Password Screen (`forgot_password_screen.dart`)
- Email input + reset request

#### 1e. OTP Verification Screen (`otp_verification_screen.dart`)
- Code entry for verification

#### 1f. Reset Password Screen (`reset_password_screen.dart`)
- New password + confirm

---

### 2. Home Dashboard (`home_dashboard_screen.dart` — 2,908 lines) ⭐ MAIN SCREEN

This is the primary screen users see daily. Currently the most complex screen.

- **Elements:**
  - **App bar:** Home name as title, connectivity banner (online/offline status)
  - **Tab bar:** Horizontal room tabs (All + individual rooms) — `TabController`
  - **Room content:** Scrollable grid of device cards
  - **Device cards:** Show device name, room, type icon, power state toggle
  - **Sensor data:** Temperature/humidity readings displayed on sensor-type cards
  - **Floating Action Button:** "+" to add new device
  - **Empty state:** When no devices exist
- **Device types with distinct icons:**
  - Light → `lightbulb_outline`
  - Thermostat → `thermostat_outlined`
  - Shutter/Blind → `window`
  - Unknown → `device_unknown`
- **Interactions:**
  - Tap device card → navigate to Device Control Screen
  - Toggle switch on card → instant on/off
  - Long press → quick actions menu
  - Pull to refresh
  - Tab switching filters by room

---

### 3. Scenes Screen (`scenes_screen.dart` — 596 lines)

- **Elements:**
  - Scene cards in a list/grid
  - Each card: scene name, icon (customizable), color indicator, toggle switch
  - "Create Scene" button (ElevatedButton.icon with `+` icon)
  - Empty state with illustration icon
- **Scene card details:**
  - Custom color per scene
  - Custom icon (from `SceneIconSelector` — 20+ icons)
  - Tap to view/edit, toggle to activate

#### 3a. Add/Edit Scene Screen (`add_scene_screen.dart`)
- Scene name input
- Icon selector (grid of icons)
- Color picker
- Device action list (select devices → set target state)
- Save/delete buttons

---

### 4. Profile Screen (`profile_screen.dart` — 1,066 lines)

- **Elements:**
  - **Profile header:** Avatar (from 10 prebuilt avatars), name, email — with gradient background
  - Edit avatar button (camera icon overlay)
  - **Stats cards:** Device count, Room count, Scene count — in a row
  - **Settings sections:**
    - Home Management (multi-home support)
    - WiFi Profiles
    - Device Sharing
    - Notifications Settings
    - Appearance (Light/Dark mode toggle)
    - Help Center
    - Feedback
    - App version info
    - Sign Out button
  - Each setting is a `SettingsTile` widget (icon + title + subtitle + chevron)

#### 4a. Profile Edit Screen (`profile_edit_screen.dart`)
- Edit name, avatar selection

#### 4b. Avatar Picker Dialog (`avatar_picker_dialog.dart`)
- Grid of 10 pre-built avatar images (`avatar_1.png` through `avatar_10.png`)
- Tap to select, highlight current selection

#### 4c. Appearance Settings (`appearance_settings_screen.dart`)
- Light/Dark mode radio selection

#### 4d. Notifications Settings (`notifications_settings_screen.dart`)
- Toggle switches for notification categories

#### 4e. Help Center (`help_center_screen.dart`)
- FAQ/support content

#### 4f. Feedback Screen (`feedback_screen.dart`)
- Text input for user feedback

#### 4g. H-Bot Account Screen (`hbot_account_screen.dart`)
- Account management details

---

### 5. Device Control Screen (`device_control_screen.dart` — 1,782 lines)

Detailed control for a single device. Varies by device type.

- **App bar:** Device name, back button, timer icon, refresh, more menu (edit/delete)
- **Elements by device type:**
  - **Switch/Relay:** Large power toggle button, on/off state indicator
  - **Light:** Power toggle + brightness slider + color picker (if RGB)
  - **Sensor:** Temperature display (large), humidity display, historical data
  - **Shutter:** Open/close/stop buttons, position slider, slat angle control
- **Device info section:** Firmware version, IP address, signal strength, uptime
- **Shutter control widget** (`shutter_control_widget.dart` — 1,000+ lines):
  - Custom painters: `_ShutterSlatsPainter`, `_CurtainFoldsPainter`
  - Visual representation of shutter position
  - Calibration button → navigates to calibration screens

#### 5a. Shutter Calibration (`shutter_calibration_screen.dart`)
- Step-by-step shutter calibration wizard

#### 5b. Manual Calibration (`shutter_manual_calibration_screen.dart`)
- Manual timing-based calibration

#### 5c. Device Timers (`device_timers_screen.dart`)
- Schedule on/off times for devices
- List of active timers
- Add/edit timer

#### 5d. Add Timer Screen (`add_timer_screen.dart`)
- Time picker, repeat days, device action selection

---

### 6. Homes & Rooms

#### 6a. Homes Screen (`homes_screen.dart`)
- List of user's homes
- Create/edit/delete home
- Switch active home

#### 6b. Rooms Screen (`rooms_screen.dart` — 711 lines)
- List of rooms in current home
- Create room dialog (name + icon selection)
- Room icon picker (`room_icon_picker.dart`) — grid of home-related icons
- Each room card shows: name, icon, device count
- Tap → room detail

---

### 7. Device Sharing

#### 7a. Share Device Screen (`share_device_screen.dart`)
- Share individual device with another user (by email)

#### 7b. Multi-Device Share (`multi_device_share_screen.dart`)
- Bulk share multiple devices

#### 7c. Shared Devices Screen (`shared_devices_screen.dart`)
- View devices shared with you / by you

---

### 8. WiFi Profiles (`wifi_profile_screen.dart` — 405 lines)
- **Elements:**
  - List of saved WiFi networks
  - Each entry: WiFi icon, SSID, checkmark if default
  - Add new profile: SSID field, password field (with visibility toggle), "Save to account" toggle
  - Edit/delete existing profiles
- Used during device pairing to auto-fill credentials

---

### 9. Add Device Flow (`add_device_flow_screen.dart` — ~3,100 lines) ⚠️ HIGHEST PRIORITY FOR REDESIGN

Multi-step wizard for pairing new IoT devices. Currently developer-built UI, needs professional design.

#### Flow Overview
4 steps with linear progression:

**Step 1: WiFi Setup**
- Purpose: Capture home WiFi credentials to send to device
- Elements:
  - SSID text field (editable)
  - Password text field with visibility toggle
  - "Auto-detect WiFi" button — attempts to read current SSID, loads matching password from saved profiles
  - Button states: idle → detecting (spinner) → success (✅ green) → failure (⚠️ orange with checklist) → error (❌ red)
  - "Next" button (disabled until both fields filled)
- Auto-detect failure shows checklist: WiFi connected? Location permission? Precise location?
- Manual entry always available

**Step 2: Device Discovery (iOS)**
- Purpose: Connect phone to device's WiFi access point
- iOS cannot programmatically join WiFi (captive portal issue), so uses guided flow:
  - 4 numbered instruction steps with icons:
    1. Put device in pairing mode (power cycle)
    2. Open WiFi Settings (with prominent blue button)
    3. Connect to "hbot-XXXX" network
    4. Return to this app
  - "Open WiFi Settings" button → opens iOS Settings > WiFi
  - Auto-detection timer polls every 5 seconds
  - When connected to hbot-* network, auto-proceeds to step 3
  - Manual "I'm Connected" fallback button
  - Status message area for connection feedback

**Step 2: Device Discovery (Android)**
- Auto-scans for nearby hbot-* WiFi networks
- Shows list of discovered devices
- Tap to connect

**Step 3: Provisioning**
- Purpose: Send WiFi credentials to device, wait for it to connect
- Elements:
  - Progress indicator showing current stage
  - Stages: Connecting → Sending credentials → Device restarting → Verifying connection → Done
  - Timeout: 3 minutes
  - Error handling with retry option

**Step 4: Success**
- Purpose: Name the device and assign to a room
- Elements:
  - Success animation/icon
  - Device name text field (pre-filled from device info)
  - Room dropdown/selector
  - "Done" / "Add Another" buttons

#### QR Code Scanner (`scan_device_qr_screen.dart`)
- Alternative entry point: scan device QR code for quick pairing
- Uses `mobile_scanner` package

---

### 10. Utility Widgets

| Widget | Purpose |
|--------|---------|
| `DeviceCard` | Card component for device display on dashboard |
| `DeviceControlWidget` | Basic device control toggle |
| `EnhancedDeviceControlWidget` | Full device control with extended options |
| `ShutterControlWidget` | Visual shutter/curtain control with custom painters |
| `SceneCard` | Scene display card with toggle |
| `ProfileCard` | Stats card on profile page |
| `SettingsTile` | Standard settings row (icon + title + chevron) |
| `SmartInputField` | Text input with prefix icon and validation |
| `ConnectivityBanner` | Online/offline status bar |
| `ErrorMessageWidget` | Standardized error display |
| `PriceDisplay` | Price/cost display component |
| `BackgroundContainer` | Background image/gradient wrapper |
| `BackgroundImagePicker` | Room background selection |
| `RoomIconPicker` | Room icon selection grid |
| `SceneIconSelector` | Scene icon selection grid |
| `AvatarPickerDialog` | Avatar selection dialog |
| `DeviceSelector` | Multi-device selection list |
| `WiFiPermissionGate` | Permission request flow for WiFi features |
| `MqttDebugSheet` | Debug panel (dev-only, hide in production) |

---

## Existing Assets

| Asset | Path | Description |
|-------|------|-------------|
| Avatars | `assets/images/avatars/avatar_1-10.png` | 10 pre-built user avatars |
| Backgrounds | `assets/images/backgrounds/default_1-5.jpg` | 5 room background images |
| Google Logo | `assets/images/google_logo.png` | Google OAuth button icon |
| **No app logo** | — | App currently has no logo/icon asset |

---

## Design Priorities

### Priority 1: Add Device Flow (complete redesign)
- Modern, friendly onboarding-style wizard
- Clear visual progress indicator across 4 steps
- Each step needs all states designed: idle, loading, success, error, timeout
- iOS guided WiFi connection flow must feel intuitive for non-technical users
- Provisioning progress should feel alive (animations, stage transitions)
- Success celebration moment
- **iPad layout:** Center content with max-width 500px

### Priority 2: Home Dashboard
- Device card redesign for better visual hierarchy
- Room tab bar styling
- Sensor data presentation (temp/humidity should be glanceable)
- Empty state when no devices
- Connection status indicator

### Priority 3: Device Control Screen
- Type-specific control layouts (switch vs. light vs. sensor vs. shutter)
- Shutter visual control is already custom-painted — needs design direction
- Timer management UI

### Priority 4: Overall Design Language
- **App logo/icon** — doesn't exist yet, needs creation
- Color palette (current blue may not match premium IoT vibe)
- Typography scale with Inter font
- Icon style guide (currently using Material Icons throughout)
- Card/container patterns
- Button hierarchy (primary, secondary, text, icon)
- Empty states across all screens
- Loading states / skeleton screens
- Error states
- Toast/snackbar styling

### Priority 5: Auth Screens
- Sign in/up currently dark background — may not match final light theme
- Needs logo prominently displayed
- Social sign-in button styling

---

## Design Constraints

1. **Responsive:** Must work on phone AND iPad (max-width containers on tablet)
2. **iOS 13+:** No iOS 17+ only visual patterns
3. **Light mode only** for initial release (dark mode exists but deprioritized)
4. **Premium feel:** Ships with physical hardware — must feel consumer-grade, not hobbyist
5. **White-label ready:** No third-party branding visible anywhere (no "Tasmota", "MQTT", "firmware", "ESP")
6. **Accessibility:** Minimum WCAG contrast ratios, tap targets ≥ 44px
7. **Flutter implementation:** Designs must be implementable in Flutter Material/Cupertino widgets
8. **Existing architecture:** 3-tab bottom nav structure should be preserved unless there's a strong reason to change

---

## Deliverables Expected

1. **Screen-by-screen mockups** (Figma preferred) for all screens listed above
2. **Design tokens** document (colors, typography, spacing, radius, shadows)
3. **Component library** specs (buttons, cards, inputs, toggles, sliders, progress indicators, badges)
4. **Add Device Flow** — detailed mockups for EVERY step and EVERY state (loading, error, success, empty, timeout)
5. **iPad adaptations** showing responsive behavior on tablet
6. **App icon/logo** design
7. **Empty state illustrations** (or icon compositions) for: no devices, no scenes, no rooms, no shared devices

---

## Reference Apps for Inspiration

- **Apple Home** — Clean, minimal, card-based smart home UI
- **Tuya Smart / Smart Life** — Device pairing flow, device type variety
- **Philips Hue** — Device control, scene management, premium feel
- **Govee Home** — Modern IoT app, good onboarding
- **Meross** — Simple IoT device management

---

## Technical Notes for Designer

- Bottom nav uses Material `BottomNavigationBar` (not NavigationBar)
- Cards use `Card` widget with `BoxDecoration` for borders/shadows
- Buttons: `ElevatedButton`, `TextButton`, `OutlinedButton`, `IconButton`
- Toggle: `Switch` widget
- Sliders: `Slider` widget
- Custom painting used for shutter visualization (Flutter `CustomPainter`)
- `Hero` animations available for screen transitions
- `AnimatedContainer`, `AnimatedOpacity` available for micro-interactions
