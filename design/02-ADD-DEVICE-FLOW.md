# Add Device Flow — Complete UI Spec

> Priority 1 redesign. Multi-step wizard for pairing IoT devices.
> All measurements in logical pixels. Reference `01-DESIGN-TOKENS.md` for color/typography tokens.

---

## Overview

A 4-step linear wizard with a calm, confidence-building progression. The flow should feel like a premium unboxing experience — each step is clear, achievable, and celebrates progress.

### Entry Points
1. **FAB on Home Dashboard** — "+" button → navigates to Add Device Flow
2. **QR Code Scanner** — Opens camera, scans device QR, pre-fills device info, skips to Step 1

### Flow Structure
```
[Step 1: WiFi Setup] → [Step 2: Find Device] → [Step 3: Connecting] → [Step 4: Done!]
```

---

## Global Wizard Chrome

### Step Indicator (top of every step screen)

```
Position: Below AppBar, horizontal, full width
Height: 68 (indicator + labels)
Padding: horizontal 20

Layout:
  ○────○────○────○
  WiFi  Find  Connect  Done

Step dot:
  Completed: 24x24 circle, primary (#3B6EE6), white checkmark (14px)
  Current: 24x24 circle, primary (#3B6EE6), white fill, pulse animation (scale 1.0↔1.05, 2s loop)
  Future: 24x24 circle, border 2px border (#E2E8F0), transparent fill

Connector line:
  Height: 2
  Completed: primary (#3B6EE6)
  Future: border (#E2E8F0)
  Animates fill left→right when transitioning (400ms)

Step label:
  Below each dot, space4 gap
  labelSmall (12/500)
  Current/Completed: textPrimary
  Future: textTertiary
```

### AppBar
```
Leading: back arrow (← previous step, or close X on step 1)
Title: "Add Device" — headlineMedium (20/600)
No actions
Close X shows confirmation dialog: "Stop setup? You can restart anytime."
```

### Screen Layout Template
```
Scaffold(
  backgroundColor: background (#F8FAFC),
  appBar: [...],
  body: Column(
    children: [
      StepIndicator,        // 68px
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: [...content...],
        ),
      ),
      BottomActionBar,      // safe area + button
    ],
  ),
)
```

### Bottom Action Bar (consistent across steps)
```
Background: surface (#FFFFFF)
Border top: 1px borderLight
Padding: horizontal 20, vertical 12, + bottom safe area
Shadow: none (border is enough)

Primary button: full-width, height 52
Secondary action (if any): TextButton above or beside primary

iPad: Center content, maxWidth 500
```

---

## Step 1: WiFi Setup

**Purpose:** Capture home WiFi credentials to send to the device later.

### Screen Layout

```
┌──────────────────────────────────────┐
│ ←                Add Device          │  AppBar
├──────────────────────────────────────┤
│     ● ──── ○ ──── ○ ──── ○          │  Step indicator
│    WiFi   Find  Connect  Done        │
├──────────────────────────────────────┤
│                                      │
│         [WiFi Icon - 64px]           │  Icon: wifi_rounded, primary, in
│                                      │  80x80 circle, primarySurface bg
│     Connect to your home WiFi        │  headlineLarge (24/600), center
│                                      │
│   Your device needs WiFi to work.    │  bodyMedium (14/400), textSecondary
│   Enter your home network details.   │  center, max-width 280
│                                      │  
│  ┌──────────────────────────────┐    │
│  │ 📶  Network name (SSID)     │    │  SmartInputField
│  └──────────────────────────────┘    │
│                                      │  space12 gap
│  ┌──────────────────────────────┐    │
│  │ 🔒  Password          [👁]  │    │  SmartInputField + visibility toggle
│  └──────────────────────────────┘    │
│                                      │  space16 gap
│  [ 📡 Auto-detect WiFi         ]    │  TextButton, left-aligned
│                                      │
│                                      │
├──────────────────────────────────────┤
│  [ ████████ Continue ████████████ ]  │  Primary button, disabled until
│                                      │  both fields have content
└──────────────────────────────────────┘
```

### Auto-Detect WiFi Button

A smart feature that reads the phone's current WiFi SSID and auto-fills saved credentials.

**Button States:**

#### Idle
```
TextButton with icon
Icon: wifi_find (or sensors), 20px, primary
Text: "Auto-detect WiFi", labelMedium (14/500), primary
Background: transparent
```

#### Detecting (loading)
```
Icon → SizedBox(16x16, CircularProgressIndicator(strokeWidth: 2, primary))
Text: "Detecting network...", textSecondary
Disabled (no tap)
Duration: 2-5 seconds typical
```

#### Success ✅
```
Entire button area becomes a success banner:
Background: successLight (#DCFCE7), radiusS
Padding: 12 horizontal, 10 vertical
Icon: check_circle, 20px, success (#22C55E)
Text: "Connected to MyHomeWiFi", bodyMedium (14/500), success
Auto-fills SSID field
If saved password found: auto-fills password field too
Banner auto-dismisses after 3 seconds → fields remain filled
```

#### Failure ⚠️ (WiFi not detected)
```
Banner expands to show checklist:
Background: warningLight (#FEF3C7), radiusS (8)
Padding: 16

Header row:
  Icon: warning_amber_rounded, 20px, warning (#F59E0B)
  Text: "Couldn't detect WiFi", bodyMedium (14/500), warning

Checklist (below, space8 gap):
  Each item: Row with 6px circle indicator + bodySmall text
  ○ Are you connected to WiFi?
  ○ Is Location permission enabled?
  ○ Is Precise Location turned on?

Footer: "You can enter details manually below" — bodySmall, textTertiary

Dismiss: tap X in top-right corner of banner, or auto-dismiss after 10s
```

#### Error ❌ (exception/crash)
```
Background: errorLight (#FEE2E2), radiusS
Icon: error_outline, 20px, error (#EF4444)
Text: "Something went wrong. Enter details manually.", bodyMedium, error
Dismiss: tap X or auto 5s
```

### WiFi Permission Gate
If location permission is not granted (required for WiFi SSID on both platforms):

```
Modal bottom sheet:
  Handle bar (standard)
  
  [Location pin icon, 48px, primary, in 72x72 primarySurface circle]
  
  "Location Permission Needed"    headlineSmall (18/600)
  
  "To auto-detect your WiFi       bodyMedium (14/400), textSecondary
   network, we need location       center
   access. This is an OS
   requirement — we don't
   track your location."
  
  [████ Allow Location ████]       Primary button
  [    Skip — I'll type it  ]      TextButton, textSecondary

  Bottom: bodySmall, textTertiary
  "You can always enter WiFi details manually"
```

### Saved WiFi Profiles

If user has saved WiFi profiles, show a chip row below the SSID field:

```
Position: Between SSID field and Password field
Horizontal scroll row
Each chip:
  Background: surfaceVariant
  Border radius: radiusFull
  Padding: horizontal 12, vertical 6
  Icon: wifi, 14px, textSecondary
  Text: SSID name, bodySmall (12/500)
  Tap → fills both SSID and password

Label above: "Saved networks", labelSmall, textTertiary
```

---

## Step 2: Find Device

**Two completely different UIs for iOS and Android.**

### Step 2 — iOS: Guided WiFi Connection

iOS cannot programmatically join WiFi networks due to captive portal restrictions. Instead, we guide the user through manual WiFi settings.

#### Screen Layout

```
┌──────────────────────────────────────┐
│ ←                Add Device          │
├──────────────────────────────────────┤
│     ✓ ──── ● ──── ○ ──── ○          │
│    WiFi   Find  Connect  Done        │
├──────────────────────────────────────┤
│                                      │
│     Connect to your device           │  headlineLarge (24/600), center
│                                      │
│   Follow these steps to connect      │  bodyMedium, textSecondary, center
│   your phone to the device.          │
│                                      │
│  ┌──────────────────────────────┐    │
│  │ ① Put device in pairing mode │    │  Instruction cards
│  │    Power cycle your device   │    │
│  │    (turn off, wait 5s, on)   │    │
│  └──────────────────────────────┘    │
│  ┌──────────────────────────────┐    │
│  │ ② Open WiFi Settings         │    │
│  │                              │    │
│  │  [█ Open WiFi Settings █]    │    │  Secondary button (outlined)
│  │                              │    │
│  └──────────────────────────────┘    │
│  ┌──────────────────────────────┐    │
│  │ ③ Connect to "hbot-XXXX"    │    │
│  │    Look for a network        │    │
│  │    starting with "hbot-"     │    │
│  └──────────────────────────────┘    │
│  ┌──────────────────────────────┐    │
│  │ ④ Return to this app         │    │
│  │    Come back here once       │    │
│  │    connected                 │    │
│  └──────────────────────────────┘    │
│                                      │
│  ┌─ Status area ────────────────┐    │
│  │  🔍 Waiting for connection...│    │  Polls every 5s
│  └──────────────────────────────┘    │
│                                      │
├──────────────────────────────────────┤
│  [    I'm Connected (manual)    ]    │  TextButton fallback
└──────────────────────────────────────┘
```

#### Instruction Card Component

```
Container:
  Background: surface (#FFFFFF)
  Border: 1px border (#E2E8F0)
  Border radius: radiusM (12)
  Padding: 16
  Margin bottom: space12

Layout:
  Row(crossAxisAlignment: start)
    Step number circle:
      28x28
      Background: primarySurface (#EEF2FC)
      Text: number, labelMedium (14/600), primary
      Border radius: radiusFull
    SizedBox(width: space12)
    Column(crossAxisAlignment: start)
      Title: bodyLarge (16/600), textPrimary
      SizedBox(height: space4)
      Description: bodyMedium (14/400), textSecondary
      [Optional: button or extra content]

Active step (current): border color → primary, shadowXS
Completed step: checkmark replaces number, primarySurface background on whole card
```

#### "Open WiFi Settings" Button (inside card ②)
```
OutlinedButton with icon
Icon: settings, 18px
Text: "Open WiFi Settings", labelLarge (16/600)
Full width within card
Height: 44
Border: 1.5px primary
Border radius: radiusS (8)
Tap → opens iOS Settings WiFi page (AppSettings.openAppSettings)
```

#### Connection Status Area

```
Container:
  Background: surfaceVariant (#F1F5F9)
  Border radius: radiusS (8)
  Padding: 12 horizontal, 10 vertical
  Full width

States:

Scanning:
  Row: [SizedBox(16x16, CircularProgressIndicator(strokeWidth: 2))] + space8 + "Waiting for device connection..."
  Text: bodyMedium, textSecondary
  Subtle pulse animation on container (opacity 0.8↔1.0, 2s)

Connected:
  Row: [check_circle, 18px, success] + space8 + "Connected to hbot-A1B2!"
  Background: successLight (#DCFCE7)
  Text: bodyMedium (14/500), success
  Auto-advances to Step 3 after 1.5 second (let user see the success)

Failed:
  Row: [error_outline, 18px, error] + space8 + "Connection lost. Please try again."
  Background: errorLight
  Text: bodyMedium, error
```

#### "I'm Connected" Manual Fallback
```
TextButton at bottom
Text: "I'm already connected", labelMedium, primary
No icon
Tap → attempts to verify connection, if on hbot-* network → proceed
If not → show snackbar: "Not connected to an hbot device. Please check WiFi settings."
```

### Step 2 — Android: Auto-Discovery

```
┌──────────────────────────────────────┐
│ ←                Add Device          │
├──────────────────────────────────────┤
│     ✓ ──── ● ──── ○ ──── ○          │
│    WiFi   Find  Connect  Done        │
├──────────────────────────────────────┤
│                                      │
│         [Radar animation]            │  Animated radar/pulse, 120x120
│                                      │  primarySurface bg circle
│     Searching for devices...         │  headlineLarge (24/600), center
│                                      │
│   Make sure your device is           │  bodyMedium, textSecondary, center
│   powered on and in pairing mode.    │
│                                      │
│  ┌──────────────────────────────┐    │  ← Discovered devices list
│  │ 📡 hbot-A1B2                 │    │  (appears when found)
│  │    Signal: Strong         [→]│    │
│  └──────────────────────────────┘    │
│  ┌──────────────────────────────┐    │
│  │ 📡 hbot-C3D4                 │    │
│  │    Signal: Medium         [→]│    │
│  └──────────────────────────────┘    │
│                                      │
│  💡 Tip: Power cycle device to       │  bodySmall, textTertiary, center
│     enable pairing mode              │
│                                      │
├──────────────────────────────────────┤
│  [████████ Refresh ██████████████ ]  │  Secondary button if 0 found
│  — or —                              │
│  (bottom bar hidden when devices     │
│   are visible — tap device to go)    │
└──────────────────────────────────────┘
```

#### Discovered Device Card
```
Container:
  Background: surface
  Border: 1px border
  Border radius: radiusM (12)
  Padding: 16
  Margin bottom: space8

Layout: Row
  Left: wifi icon container (40x40, primarySurface, radiusFull)
  space12
  Column:
    Title: "hbot-A1B2", bodyLarge (16/600), textPrimary
    Subtitle: "Signal: Strong", bodySmall, textSecondary
  Spacer
  Right: chevron_right, 20px, textTertiary

Tap: connects to device, shows connecting spinner overlay on this card, then auto-proceeds to Step 3

Signal strength indicator (optional):
  Strong: 3 bars, success color
  Medium: 2 bars, warning color
  Weak: 1 bar, error color
```

#### Android Scanning States

**Scanning (no devices yet):**
```
Radar animation plays (concentric circles pulsing out from center)
"Searching for devices..." heading
Tip text visible
No device cards
```

**Devices Found:**
```
Radar shrinks to 80x80, moves up
Heading: "Devices found" — with count badge
Device list appears with staggered animation (each card fades in 100ms apart)
```

**No Devices After 30s:**
```
Radar stops
Heading: "No devices found"
Body: "Make sure your device is in pairing mode and nearby."
Show troubleshooting expandable:
  ▼ Troubleshooting tips
    • Power cycle your device (off, wait 5s, on)
    • Move closer to the device
    • Make sure no other phone is already pairing
Primary button: "Try Again"
```

---

## Step 3: Provisioning (Connecting)

**Purpose:** Send WiFi credentials to device, device reboots, connects to home WiFi, verifies in cloud.

### Screen Layout — Progress Animation

This screen should feel alive. The user is waiting — make it worth watching.

```
┌──────────────────────────────────────┐
│ ←                Add Device          │
├──────────────────────────────────────┤
│     ✓ ──── ✓ ──── ● ──── ○          │
│    WiFi   Find  Connect  Done        │
├──────────────────────────────────────┤
│                                      │
│                                      │
│                                      │
│         [Animated illustration]      │  Center of screen
│         Device connecting...         │  120x120 area
│                                      │
│                                      │
│     Setting up your device           │  headlineLarge (24/600)
│                                      │
│  ┌──────────────────────────────┐    │
│  │ ✅ Connected to device        │    │  Stage checklist
│  │ ✅ Sending WiFi credentials   │    │
│  │ ⏳ Device restarting...       │    │  ← current stage (animated)
│  │ ○  Verifying connection       │    │
│  │ ○  Registering in cloud       │    │
│  └──────────────────────────────┘    │
│                                      │
│     This usually takes about         │  bodySmall, textTertiary
│     30-60 seconds                    │
│                                      │
│  ████████████░░░░░░░░░░░░░░░░░░░░   │  Linear progress (estimated)
│                                      │
├──────────────────────────────────────┤
│                                      │  No button — auto-proceeds
└──────────────────────────────────────┘
```

### Stage Checklist Component

```
Container:
  Background: surface
  Border: 1px border
  Border radius: radiusM (12)
  Padding: 16
  Full width

Each stage row:
  Height: 36
  Row layout:

  Status icon (20x20):
    Completed: check_circle, success (#22C55E)
    Current: SizedBox(18x18, CircularProgressIndicator(strokeWidth: 2.5, primary)) 
    Pending: radio_button_unchecked, textTertiary (#94A3B8)
    Failed: error, error (#EF4444)

  space12

  Stage text:
    Completed: bodyMedium (14/400), textPrimary, no strikethrough
    Current: bodyMedium (14/500), textPrimary — slightly bolder
    Pending: bodyMedium (14/400), textTertiary
    Failed: bodyMedium (14/400), error

  Transition: each row animates in sequence, checkmark does a scale-spring (300ms elasticOut)
```

### Provisioning Stages

| Stage | Label | Estimated Time |
|-------|-------|---------------|
| 1 | Connected to device | 2s |
| 2 | Sending WiFi credentials | 3s |
| 3 | Device restarting... | 15-30s |
| 4 | Verifying connection | 5-10s |
| 5 | Registering in cloud | 3-5s |

### Progress Bar
```
LinearProgressIndicator, estimated:
  Start at 0%, step through approximate % per stage
  Stage 1: 0→10%
  Stage 2: 10→25%
  Stage 3: 25→60% (slowest stage, animate slowly)
  Stage 4: 60→85%
  Stage 5: 85→100%
  
  Use AnimatedContainer for smooth width transitions
  Color: primary
  Background: surfaceVariant
  Height: 4, radiusFull
```

### Center Animation

A pulsing device icon that transforms through stages:

```
Stage 1-2: Phone ↔ Device icon with connecting dots animation
Stage 3: Device icon with rotating refresh indicator
Stage 4-5: Device icon with WiFi signal growing
Complete: Device icon with checkmark overlay

Container: 120x120
Background: primarySurface, radiusFull
Icon: 48px, primary
Pulse: scale 1.0↔1.03, 2s loop
```

### Error State — Provisioning Failed

```
┌──────────────────────────────────────┐
│ ←                Add Device          │
├──────────────────────────────────────┤
│     ✓ ──── ✓ ──── ● ──── ○          │
├──────────────────────────────────────┤
│                                      │
│     [Error icon — 80x80]             │  warning_amber_rounded, 48px
│                                      │  warningLight circle bg
│                                      │
│     Setup didn't complete            │  headlineLarge (24/600)
│                                      │
│  ┌──────────────────────────────┐    │
│  │ ✅ Connected to device        │    │  Shows where it failed
│  │ ✅ Sending WiFi credentials   │    │
│  │ ❌ Device restarting...       │    │  ← failed here
│  │    Timed out after 60s        │    │  bodySmall, error, indent
│  │ ○  Verifying connection       │    │
│  └──────────────────────────────┘    │
│                                      │
│  ┌─ Troubleshooting ───────────┐     │  Expandable section
│  │ • Check WiFi password        │    │
│  │ • Move device closer to      │    │
│  │   your router                │    │
│  │ • Make sure your WiFi is     │    │
│  │   2.4GHz (not 5GHz only)    │    │
│  └──────────────────────────────┘    │
│                                      │
├──────────────────────────────────────┤
│  [████████ Try Again ████████████ ]  │  Primary button
│  [       Start Over              ]   │  TextButton
└──────────────────────────────────────┘
```

### Timeout Handling
```
Overall timeout: 180 seconds (3 minutes)
After 120s with no progress: show "Taking longer than usual..." message
  bodySmall, warning, fade in below progress bar
After 180s: transition to error state
```

---

## Step 4: Success & Device Setup

**Purpose:** Celebrate, name the device, assign to a room.

### Success Moment (brief celebration before form)

```
Full screen for 2 seconds, then scrolls up to reveal form:

┌──────────────────────────────────────┐
│                                      │
│                                      │
│                                      │
│         [✓ Checkmark]                │  Animated: circle draws (300ms),
│                                      │  then check draws (200ms),
│                                      │  then scale-spring (300ms)
│                                      │  72x72, success bg, white check
│                                      │
│       Device connected! 🎉           │  displayMedium (28/700)
│                                      │  
│       Your device is online          │  bodyMedium, textSecondary
│       and ready to use.              │
│                                      │
│                                      │
└──────────────────────────────────────┘

After 2s, AnimatedContainer transitions to:
```

### Device Setup Form

```
┌──────────────────────────────────────┐
│ ←                Add Device          │
├──────────────────────────────────────┤
│     ✓ ──── ✓ ──── ✓ ──── ●          │
│    WiFi   Find  Connect  Done        │
├──────────────────────────────────────┤
│                                      │
│    [✓] 48x48 success circle          │  Smaller version, top-left of card
│    Device connected!                 │  headlineSmall (18/600)
│                                      │
│  ┌──────────────────────────────┐    │
│  │ Device Name                   │    │
│  │ ┌──────────────────────────┐ │    │
│  │ │ 📝  Living Room Light    │ │    │  SmartInputField
│  │ └──────────────────────────┘ │    │  Pre-filled from device info
│  │                              │    │
│  │ Room                         │    │
│  │ ┌──────────────────────────┐ │    │
│  │ │ 🏠  Select a room     ▼ │ │    │  Dropdown / bottom sheet picker
│  │ └──────────────────────────┘ │    │
│  │                              │    │
│  │ Device Type                  │    │  Read-only info
│  │ Switch · Firmware 1.2.3      │    │  bodySmall, textTertiary
│  │                              │    │
│  └──────────────────────────────┘    │
│                                      │
├──────────────────────────────────────┤
│  [████████ Done █████████████████ ]  │  Primary button → go to dashboard
│  [       Add Another Device      ]   │  TextButton → restart flow
└──────────────────────────────────────┘
```

### Room Selector Bottom Sheet

```
Triggered by tapping Room field.

Bottom sheet (standard):
  Title: "Select a Room", headlineSmall (18/600)
  
  Room list:
    Each item: 56px height
      [Room icon, 24px, in 36x36 surfaceVariant circle] + space12 + Room name (bodyLarge)
      Selected: primary color icon, primarySurface bg, checkmark right
    
    Divider before last item
    Last item: "+ Create New Room" — primary color text, add icon
    Tap "Create" → inline text field appears at bottom of list

  Max height: 60% of screen
  Scrollable if many rooms
```

### Device Type Auto-Detection Display
```
Below the form, show detected device info:
  Container: surfaceVariant bg, radiusS, padding 12
  Row: [device type icon, 20px] + space8 + Column:
    "Switch" (or Light, Sensor, etc.) — bodyMedium, textPrimary
    "Firmware 1.2.3 · MAC: AA:BB:CC" — bodySmall, textTertiary
  
  This is informational only — not editable.
```

---

## QR Code Scanner (Alternative Entry)

### Screen Layout
```
Full-screen camera viewfinder

Overlay:
  Top: AppBar with close X, transparent bg, white icons
  Center: 250x250 scanning frame
    Border: 2px white, radiusL (16)
    Corner accents: 4px thick, 32px long, primary color — only corners
    Scanning line: horizontal line, primary with glow, animates top→bottom, 2s loop
  
  Below frame:
    "Scan the QR code on your device"  bodyLarge, white
    "or on the quick start card"       bodyMedium, white/70%
  
  Bottom:
    [   Enter manually instead   ]     TextButton, white
    → Navigates to Step 1 (WiFi Setup)

Camera: uses mobile_scanner package
On successful scan: haptic feedback (medium), frame turns success green briefly, auto-navigates to Step 1 with pre-filled data
```

---

## iPad Adaptations

All screens in the Add Device Flow:
```dart
body: Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 500),
    child: screenContent,
  ),
)
```

- Step indicator: constrained to 400px width, centered
- Instruction cards: full width within 500px constraint
- Buttons: full width within constraint
- QR Scanner: camera full screen, but overlay frame stays 250x250 centered

---

## Transition Animations Between Steps

```
Forward (next step):
  Current screen slides left + fades out (300ms, easeInOut)
  New screen slides in from right + fades in (300ms, easeInOut)
  Step indicator animates: dot fills, connector line draws

Back (previous step):
  Reverse of forward

Step indicator:
  Dot completion: scale from 1.0 → 1.2 → 1.0 (spring, 300ms) as checkmark appears
  Connector line: width animates 0% → 100% (400ms, easeOut)
```

---

## Accessibility Notes

- All tap targets ≥ 44px
- Step indicator labels provide screen reader context: "Step 1 of 4: WiFi Setup, current"
- Auto-detect button: announce state changes to screen reader
- Provisioning progress: announce each stage completion
- Error states: announce immediately
- QR scanner: provide manual entry alternative prominently
- Color is never the sole indicator — always paired with icon/text
- All text meets WCAG AA contrast (4.5:1 for body, 3:1 for large text)

---

## State Summary Table

| Screen | States |
|--------|--------|
| Step 1: WiFi | Empty, Filled, Auto-detecting, Auto-success, Auto-failure, Auto-error, Permission needed |
| Step 2: iOS | Instructions shown, Scanning, Connected, Failed |
| Step 2: Android | Scanning, Devices found, No devices, Connecting to device |
| Step 3: Provision | Stage 1-5 progress, Taking long, Timeout error, Generic error |
| Step 4: Success | Celebration, Form (empty room), Form (room selected) |
| QR Scanner | Camera active, Scanning, Code found, Invalid code |
