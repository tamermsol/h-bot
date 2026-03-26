# Remaining Screen Designs — H-Bot Mobile App

> Supplements `04-SCREEN-DESIGNS.md` with screens not yet detailed. All token references from `01-DESIGN-TOKENS.md`. All measurements in logical pixels.

---

## 1. Auth — OTP Verification

```
┌──────────────────────────────────────────────┐
│  ←  Verify Email                             │
│                                              │
│              ┌────────┐                      │
│              │  ✅    │                      │
│              └────────┘                      │
│                                              │
│       Verify Your Email                      │
│                                              │
│   We sent a code to                          │
│   tim@example.com                            │
│                                              │
│   ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐           │
│   │  │ │  │ │  │ │  │ │  │ │  │           │
│   └──┘ └──┘ └──┘ └──┘ └──┘ └──┘           │
│                                              │
│   ┌────────────────────────────────────────┐ │
│   │          Verify Email                  │ │
│   └────────────────────────────────────────┘ │
│                                              │
│       Resend code in 0:45                    │
│                                              │
│       [ Skip for now ]                       │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Icon** | Verified/shield icon, 48px, `$primary` |
| **Title** | `$headlineLarge` (24px/700), `$textPrimary` |
| **Email display** | `$bodyMedium`, `$primary`, bold |
| **OTP boxes** | 6 individual boxes, 48×56px each, `$surfaceCard` bg, `$borderDefault` border, `$radiusSmall` (8px). Focused: `$primary` border 2px. Filled: `$textPrimary` 24px/700 centered |
| **Verify button** | Primary gradient, full width, disabled until 6 digits entered |
| **Resend timer** | `$bodySmall`, `$textSecondary`. When expired: "Resend Code" in `$primary` |
| **Skip link** | Ghost button, `$textSecondary` |

---

## 2. Auth — Email Confirmation

```
┌──────────────────────────────────────────────┐
│  ←  Email Confirmation                       │
│                                              │
│              ┌────────┐                      │
│              │  ✉️    │                      │
│              └────────┘                      │
│                                              │
│       Check Your Email                       │
│                                              │
│   We've sent a confirmation email to         │
│   tim@example.com                            │
│                                              │
│   Please check your inbox and click          │
│   the confirmation link to activate          │
│   your account.                              │
│                                              │
│   ┌────────────────────────────────────────┐ │
│   │          Resend Email                  │ │
│   └────────────────────────────────────────┘ │
│                                              │
│   ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐  │
│   │  Continue Without Confirmation        │  │
│   └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘  │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Icon** | Mail icon, 48px, `$primary` |
| **Title** | `$headlineLarge` (24px/700), `$textPrimary` |
| **Description** | `$bodyMedium`, `$textSecondary`, center-aligned |
| **Email** | `$bodyMedium`, `$primary`, bold |
| **Resend button** | Primary gradient, full width |
| **Continue button** | Secondary outlined, full width |

---

## 3. Auth — Reset Password

```
┌──────────────────────────────────────────────┐
│  ←  Reset Password                           │
│                                              │
│              ┌────────┐                      │
│              │  🔒    │                      │
│              └────────┘                      │
│                                              │
│       Reset Your Password                    │
│                                              │
│   Enter the code sent to your email          │
│                                              │
│   ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐           │
│   │  │ │  │ │  │ │  │ │  │ │  │           │
│   └──┘ └──┘ └──┘ └──┘ └──┘ └──┘           │
│                                              │
│   New Password                               │
│   ┌────────────────────────────────────────┐ │
│   │  🔒  ••••••••                      👁  │ │
│   └────────────────────────────────────────┘ │
│                                              │
│   Confirm Password                           │
│   ┌────────────────────────────────────────┐ │
│   │  🔒  ••••••••                      👁  │ │
│   └────────────────────────────────────────┘ │
│                                              │
│   ┌────────────────────────────────────────┐ │
│   │          Reset Password                │ │
│   └────────────────────────────────────────┘ │
│                                              │
│       Resend Code (0:45)                     │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **OTP input** | Same as OTP Verification screen |
| **Password fields** | SmartInputField (§3.1 in Component Library), lock_outline prefix, visibility toggle |
| **Reset button** | Primary gradient, disabled until OTP + both passwords filled and matching |
| **Resend** | Same countdown pattern as OTP screen |

---

## 4. Homes Management

### 4.1 Homes List

```
┌──────────────────────────────────────────────┐
│  ←  My Homes                         +       │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  🏠  My Home                     >  │    │
│  │      4 members · 8 devices           │    │
│  ├──────────────────────────────────────┤    │
│  │  🏢  Office                      >  │    │
│  │      2 members · 3 devices           │    │
│  └──────────────────────────────────────┘    │
│                                              │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **App bar** | Back arrow, "My Homes" title, plus icon button |
| **Home cards** | Settings item group, 72px per item |
| **Leading icon** | 28px emoji, `$surfacePrimarySubtle` circle bg |
| **Title** | `$titleMedium` (16px/600), `$textPrimary` |
| **Subtitle** | `$bodySmall` (12px/400), `$textSecondary` — "{N} members · {N} devices" |
| **Trailing** | Chevron right, `$iconDefault` |
| **Tap** | Opens home detail (rooms, members, settings) |
| **Long press / swipe** | Edit, Delete options |

### 4.2 Add / Edit Home

Bottom sheet:

```
┌──────────────────────────────────────────────┐
│              ━━━━                             │
│                                              │
│  New Home                                    │
│                                              │
│  Home Name                                   │
│  ┌────────────────────────────────────────┐  │
│  │  My Home                               │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Create Home                   │  │
│  └────────────────────────────────────────┘  │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Sheet** | Bottom sheet, `$radiusXL` top corners |
| **Title** | `$titleLarge` (18px/600), `$textPrimary` |
| **Name input** | SmartInputField |
| **Create button** | Primary gradient, full width |

---

## 5. Device Sharing

### 5.1 Share Device Screen

```
┌──────────────────────────────────────────────┐
│  ←  Share Device                             │
│                                              │
│  Living Room Light                           │
│                                              │
│  Share with                                  │
│  ┌────────────────────────────────────────┐  │
│  │  ✉️  Enter email address               │  │
│  └────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────┐  │
│  │          Share                          │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Shared with                                 │
│  ┌──────────────────────────────────────┐    │
│  │  👤  john@example.com           🗑   │    │
│  ├──────────────────────────────────────┤    │
│  │  👤  sarah@example.com          🗑   │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Empty: "Not shared with anyone yet"         │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Device name** | `$titleLarge`, `$textPrimary` |
| **Email input** | SmartInputField, email_outlined prefix |
| **Share button** | Primary gradient, full width, disabled until valid email |
| **Shared list** | Settings item group |
| **User item** | person icon, email text, trailing delete (trash icon, `$error`) |
| **Delete** | Confirmation dialog: "Remove access for {email}?" |

### 5.2 Multi-Device Share

```
┌──────────────────────────────────────────────┐
│  ←  Share Devices                            │
│                                              │
│  Select devices to share                     │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  ☑  Living Room Light                │    │
│  ├──────────────────────────────────────┤    │
│  │  ☑  Kitchen Shutter                  │    │
│  ├──────────────────────────────────────┤    │
│  │  ☐  Bedroom Sensor                   │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Share with                                  │
│  ┌────────────────────────────────────────┐  │
│  │  ✉️  Enter email address               │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │     Share 2 Devices                    │  │
│  └────────────────────────────────────────┘  │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Device list** | Checkbox list items, device type icon + name |
| **Selected** | `$primary` checkbox fill, `$surfacePrimarySubtle` row bg |
| **Email input** | SmartInputField |
| **Share button** | Primary gradient, shows count "Share {N} Devices", disabled until ≥1 device + valid email |

### 5.3 Shared with Me

```
┌──────────────────────────────────────────────┐
│  ←  Shared with Me                           │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  💡  Living Room Light                │    │
│  │      Shared by john@example.com       │    │
│  ├──────────────────────────────────────┤    │
│  │  🪟  Office Shutter                   │    │
│  │      Shared by sarah@example.com      │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Empty: "No devices shared with you yet"     │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Device items** | Device type icon, device name (`$titleMedium`), "Shared by {email}" subtitle (`$bodySmall`, `$textSecondary`) |
| **Tap** | Opens device control screen (with limited permissions) |

---

## 6. Scene Editor — 6-Step Flow (Detailed)

Step indicator: 6 dots connected by lines, current step filled `$primary`.

### 6.1 Step 1 — Basic Info

```
┌──────────────────────────────────────────────┐
│  ←  New Scene                   Step 1 of 6  │
│                                              │
│  ●─○─○─○─○─○                                │
│                                              │
│  Name Your Scene                             │
│                                              │
│  Scene Name                                  │
│  ┌────────────────────────────────────────┐  │
│  │  Movie Night                           │  │
│  └────────────────────────────────────────┘  │
│  Hint: e.g., Movie Night, Good Morning       │
│                                              │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Next                          │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

### 6.2 Step 2 — Appearance

```
┌──────────────────────────────────────────────┐
│  ←  New Scene                   Step 2 of 6  │
│                                              │
│  ●─●─○─○─○─○                                │
│                                              │
│  Choose Icon & Color                         │
│                                              │
│  Icon                                        │
│  🎬 🌅 🌙 ☀️ 🏠 🎵 🎮 💡 🔒 ❄️              │
│                                              │
│  Color                                       │
│  🔵 🟣 🟢 🟠 🔴 🟡 ⚪ 🩷                    │
│                                              │
│  Preview                                     │
│  ┌──────────┐                                │
│  │ 🎬       │  Movie Night                   │
│  └──────────┘                                │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Next                          │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Icon grid** | Scrollable row, 44×44px targets, `$space2` gap. Selected: `$surfacePrimarySubtle` circle + 2px `$primary` ring |
| **Color grid** | Scrollable row, 36×36px circles. Selected: white checkmark overlay + 2px ring |
| **Preview card** | Shows selected icon in selected color circle + scene name |

### 6.3 Step 3 — Trigger

```
┌──────────────────────────────────────────────┐
│  ←  New Scene                   Step 3 of 6  │
│                                              │
│  ●─●─●─○─○─○                                │
│                                              │
│  How should this scene activate?             │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  ◉  Manual                           │    │
│  │     Tap to run                        │    │
│  ├──────────────────────────────────────┤    │
│  │  ○  Scheduled                        │    │
│  │     Set a time and days              │    │
│  ├──────────────────────────────────────┤    │
│  │  ○  Location-based                   │    │
│  │     Trigger on arrive/leave          │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  (If Scheduled selected:)                    │
│  Time:  [ 07 : 00  AM ]                     │
│  Days:  [M][T][W][T][F][S][S]               │
│                                              │
│  (If Location selected:)                     │
│  [ Detect Location ]                         │
│  ○ When I arrive  ○ When I leave             │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Next                          │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Trigger options** | Radio-style list items. Selected: `$primary` radio fill, `$surfacePrimarySubtle` bg |
| **Time picker** | Platform time picker, `$primary` accent |
| **Day selector** | 7 circular toggles (36px), `$borderDefault` inactive, `$primary` fill active, white text |
| **Location button** | Secondary outlined button |

### 6.4 Step 4 — Select Devices

```
┌──────────────────────────────────────────────┐
│  ←  New Scene                   Step 4 of 6  │
│                                              │
│  ●─●─●─●─○─○                                │
│                                              │
│  Select Devices                              │
│  Choose which devices this scene controls    │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  ☑  ⚡ Living Room Light             │    │
│  ├──────────────────────────────────────┤    │
│  │  ☑  💡 Bedroom Light                 │    │
│  ├──────────────────────────────────────┤    │
│  │  ☐  🌡 Temp Sensor                   │    │
│  ├──────────────────────────────────────┤    │
│  │  ☑  🪟 Kitchen Shutter               │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  3 devices selected                          │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Next                          │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Device list** | Checkbox items with device type icon + name |
| **Checkbox** | `$primary` fill when checked, `$borderDefault` when unchecked |
| **Selected row** | `$surfacePrimarySubtle` background |
| **Count text** | `$bodySmall`, `$textSecondary`, "{N} devices selected" |
| **Next** | Disabled until ≥1 device selected |

### 6.5 Step 5 — Device Actions

```
┌──────────────────────────────────────────────┐
│  ←  New Scene                   Step 5 of 6  │
│                                              │
│  ●─●─●─●─●─○                                │
│                                              │
│  Set Actions                                 │
│  Configure what each device does             │
│                                              │
│  ⚡ Living Room Light                        │
│  ┌──────────────────────────────────────┐    │
│  │  Channel: [ All Channels ▼ ]         │    │
│  │  Action:  [ ON ▼ ]                   │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  💡 Bedroom Light                            │
│  ┌──────────────────────────────────────┐    │
│  │  Channel: [ All Channels ▼ ]         │    │
│  │  Action:  [ ON ▼ ]                   │    │
│  │  Brightness: ───────●━━━  75%        │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  🪟 Kitchen Shutter                          │
│  ┌──────────────────────────────────────┐    │
│  │  Position: ─────●━━━━━━━  50%        │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Next                          │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Device sections** | Card per device, device icon + name as header |
| **Channel dropdown** | Select component. "All Channels" or "Channel 1", "Channel 2" etc. |
| **Action dropdown** | "ON" / "OFF" |
| **Dimmer slider** | Shows for dimmer devices. `$gradientPrimary` active track. Preset chips: 0%, 50%, 100% |
| **Shutter slider** | Shows for shutter devices. Position 0-100% |

### 6.6 Step 6 — Review & Create

```
┌──────────────────────────────────────────────┐
│  ←  New Scene                   Step 6 of 6  │
│                                              │
│  ●─●─●─●─●─●                                │
│                                              │
│  Review Scene                                │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  🎬  Movie Night                     │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Trigger                                     │
│  Manual — Tap to run                         │
│                                              │
│  Devices (3)                                 │
│  ┌──────────────────────────────────────┐    │
│  │  ⚡ Living Room Light    →  ON       │    │
│  ├──────────────────────────────────────┤    │
│  │  💡 Bedroom Light        →  ON 75%   │    │
│  ├──────────────────────────────────────┤    │
│  │  🪟 Kitchen Shutter      →  50%     │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Create Scene                  │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Scene preview** | Icon in color circle + name, `$surfaceCard` |
| **Trigger summary** | `$overline` label + `$bodyMedium` value |
| **Device list** | Settings group. Each: device icon + name → action summary |
| **Create button** | Primary gradient. "Create Scene" for new, "Update Scene" for edit |

---

## 7. Device Timers (Detailed)

### 7.1 Timer List

```
┌──────────────────────────────────────────────┐
│  ←  Living Room Light Timers         +       │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  ☀️  08:00 AM                  ━━●   │    │
│  │      Mon, Wed, Fri · Turn ON         │    │
│  │      Channel 1                       │    │
│  │                              🗑       │    │
│  ├──────────────────────────────────────┤    │
│  │  🌙  10:30 PM                  ○━━   │    │
│  │      Every day · Turn OFF            │    │
│  │      All Channels                    │    │
│  │                              🗑       │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Empty: timer_off icon                       │
│  "No timers set"                             │
│  "Add a timer to automate this device"       │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **App bar** | Back, "{Device Name} Timers", plus icon |
| **Time-of-day icon** | ☀️ sun (6AM-12PM), 🌤 afternoon (12PM-6PM), 🌙 moon (6PM-6AM), 🕐 clock (fallback) |
| **Time** | `$headlineMedium` (22px/600), `$textPrimary` |
| **Schedule** | `$bodySmall`, `$textSecondary` — "Mon, Wed, Fri" / "Every day" / "Weekdays" / "Once" |
| **Action** | `$bodySmall`, `$textSecondary` — "Turn ON" / "Turn OFF" |
| **Channel** | `$bodySmall`, `$textTertiary` — "Channel 1" / "All Channels" |
| **Enable toggle** | Switch component, `$primary` active |
| **Delete** | delete_outline icon, `$error`, 44×44px target |

### 7.2 Add / Edit Timer

```
┌──────────────────────────────────────────────┐
│  ←  Add Timer                     Save       │
│                                              │
│  Time                                        │
│  ┌────────────────────────────────────────┐  │
│  │         [ 08 : 00  AM ]               │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Repeat                                      │
│  [M] [T] [W] [T] [F] [S] [S]               │
│                                              │
│  Channel                                     │
│  ┌────────────────────────────────────────┐  │
│  │  All Channels                       ▼  │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Action                                      │
│  ┌────────┐  ┌────────┐                     │
│  │  ON    │  │  OFF   │                     │
│  └────────┘  └────────┘                     │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Save Timer                    │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Time picker** | Platform time picker or custom scroll wheels |
| **Day toggles** | 7 circular buttons (36px), same as Scene trigger days |
| **Channel dropdown** | Select: "All Channels", "Channel 1", "Channel 2", etc. |
| **Action toggle** | Segmented control: ON/OFF. Active: `$primary` fill, white text. Inactive: `$surfaceCard`, `$textSecondary` |
| **Save button** | Primary gradient, full width |

---

## 8. Notifications Settings

```
┌──────────────────────────────────────────────┐
│  ←  Notifications                            │
│                                              │
│  Push Notifications                          │
│  ┌──────────────────────────────────────┐    │
│  │  Device Alerts              ━━●      │    │
│  │  Get notified about device status     │    │
│  ├──────────────────────────────────────┤    │
│  │  Scene Triggers             ━━●      │    │
│  │  When scheduled scenes run            │    │
│  ├──────────────────────────────────────┤    │
│  │  Sharing Requests           ━━●      │    │
│  │  When someone shares a device         │    │
│  ├──────────────────────────────────────┤    │
│  │  Timer Alerts               ○━━      │    │
│  │  When device timers trigger           │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Section label** | `$overline`, `$textSecondary`, uppercase |
| **Toggle items** | SettingsTile with trailing Switch. Title `$titleMedium`, subtitle `$bodySmall` `$textSecondary` |
| **Toggle** | Switch component, `$primary` active, `$neutral300` inactive |

---

## 9. Help Center

```
┌──────────────────────────────────────────────┐
│  ←  Help Center                              │
│                                              │
│  Frequently Asked Questions                  │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  ▶ How do I add a device?            │    │
│  ├──────────────────────────────────────┤    │
│  │  ▶ My device is offline              │    │
│  ├──────────────────────────────────────┤    │
│  │  ▶ How do I share a device?          │    │
│  ├──────────────────────────────────────┤    │
│  │  ▶ WiFi requirements                 │    │
│  ├──────────────────────────────────────┤    │
│  │  ▶ How do scenes work?               │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Contact Support                             │
│  ┌──────────────────────────────────────┐    │
│  │  ✉️  Email Support               >  │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **FAQ items** | Expandable accordion. Chevron rotates on expand. Title `$titleMedium`. Content `$bodyMedium`, `$textSecondary` |
| **Contact** | SettingsTile, email icon, opens email compose |

---

## 10. Send Feedback

```
┌──────────────────────────────────────────────┐
│  ←  Send Feedback                            │
│                                              │
│  We'd love to hear from you                  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │                                        │  │
│  │  Tell us what you think...             │  │
│  │                                        │  │
│  │                                        │  │
│  │                                        │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Submit Feedback               │  │
│  └────────────────────────────────────────┘  │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Title** | `$titleLarge`, `$textPrimary` |
| **Text area** | Multi-line input, 5 rows min, `$surfaceCard`, `$borderDefault`, `$radiusSmall` |
| **Placeholder** | "Tell us what you think...", `$textTertiary` |
| **Submit** | Primary gradient, disabled until text entered |
| **Success** | Snackbar: "Thank you for your feedback!" |

---

## 11. HBOT Account

```
┌──────────────────────────────────────────────┐
│  ←  HBOT Account                             │
│                                              │
│  Account Information                         │
│  ┌──────────────────────────────────────┐    │
│  │  Email        tim@example.com        │    │
│  ├──────────────────────────────────────┤    │
│  │  Member since    March 2026          │    │
│  ├──────────────────────────────────────┤    │
│  │  Auth method     Email & Password    │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Data                                        │
│  ┌──────────────────────────────────────┐    │
│  │  Export My Data                   >  │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Danger Zone                                 │
│  ┌──────────────────────────────────────┐    │
│  │  🗑  Delete Account                   │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Info rows** | SettingsTile, label `$bodyMedium` `$textSecondary`, value `$bodyMedium` `$textPrimary` |
| **Export** | SettingsTile with chevron |
| **Delete Account** | `$error` text and icon, `$surfaceCard` bg. Tap shows destructive dialog: "Delete your account? This action cannot be undone. All your data, devices, and scenes will be permanently removed." with Cancel + Delete (destructive red) buttons |

---

## 12. Profile Edit

```
┌──────────────────────────────────────────────┐
│  ←  Edit Profile                    Save     │
│                                              │
│              ┌────────┐                      │
│              │  😀    │  ✏️                  │
│              └────────┘                      │
│                                              │
│  Full Name                                   │
│  ┌────────────────────────────────────────┐  │
│  │  Tim                                   │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Phone Number                                │
│  ┌────────────────────────────────────────┐  │
│  │  +1 555 0123                           │  │
│  └────────────────────────────────────────┘  │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Avatar** | 80px circle, tap → AvatarPickerDialog (10 preset avatars grid) |
| **Edit badge** | 24px circle, `$primary` bg, white pencil icon, positioned bottom-right of avatar |
| **Name field** | SmartInputField, person_outline prefix |
| **Phone field** | SmartInputField, phone_outlined prefix |
| **Save button** | Ghost button in app bar, `$primary`, disabled until changes made |

---

## 13. Appearance Settings

```
┌──────────────────────────────────────────────┐
│  ←  Appearance                               │
│                                              │
│  Theme                                       │
│  ┌──────────────────────────────────────┐    │
│  │  ◉  Light Mode                       │    │
│  │     Bright and clean interface        │    │
│  ├──────────────────────────────────────┤    │
│  │  ○  Dark Mode                        │    │
│  │     Easy on the eyes                  │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Radio items** | RadioListTile. Selected: `$primary` radio. Title `$titleMedium`, subtitle `$bodySmall` `$textSecondary` |
| **Change** | Immediate theme switch with `$durationSlow` animation |

---

*Source of truth hierarchy: Markdown specs > v0 prototype. The v0 prototype is a visual reference; these specs have exact token values for Flutter implementation.*

*Written by Pixel (🎨 Designer Agent) — 2026-03-15*
