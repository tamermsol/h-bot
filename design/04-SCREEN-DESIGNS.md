# Screen Designs — H-Bot Mobile App

> Complete screen-by-screen specifications. Every element references design tokens from `01-DESIGN-TOKENS.md` and components from `03-COMPONENT-LIBRARY.md`. ASCII mockups show layout; token references provide exact styling.

---

## Table of Contents

1. [Splash / Launch Screen](#1-splash--launch-screen)
2. [Auth Flow](#2-auth-flow)
3. [Home Dashboard](#3-home-dashboard)
4. [Device Control Screens](#4-device-control-screens)
5. [Scenes](#5-scenes)
6. [Profile](#6-profile)
7. [Add Device Wizard](#7-add-device-wizard)
8. [WiFi Profiles](#8-wifi-profiles)
9. [Rooms Management](#9-rooms-management)

---

## 1. Splash / Launch Screen

```
┌──────────────────────────────────────────────┐
│                                              │
│                                              │
│                                              │
│                                              │
│                                              │
│                                              │
│               ┌────────┐                     │
│               │  LOGO  │                     │
│               └────────┘                     │
│                                              │
│              H-Bot                           │  ← gradient text
│        Smart Home, Simplified                │
│                                              │
│                                              │
│                                              │
│                                              │
│                                              │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Background** | `$surfaceBackground` (#F8F9FB) |
| **Logo** | H-Bot logomark, 64×64px, `$primary` color |
| **App name** | `$displayLarge` (32px/700), gradient text `$gradientPrimary` |
| **Tagline** | `$bodyLarge` (16px/400), `$textSecondary` |
| **Logo → name gap** | `$space4` (16px) |
| **Name → tagline gap** | `$space2` (8px) |
| **Vertical position** | Centered, offset 20% up from center |
| **Animation** | Logo fades in (300ms), then name slides up + fades in (300ms delay 200ms), then tagline fades in (200ms delay 400ms) |

**iPad:** Same layout, centered in 500px container.

---

## 2. Auth Flow

### 2.1 Sign In

```
┌──────────────────────────────────────────────┐
│                                              │
│                                              │
│               ┌────────┐                     │
│               │  LOGO  │                     │
│               └────────┘                     │
│                                              │
│           Welcome back                       │
│    Sign in to your smart home                │
│                                              │
│  Email                                       │
│  ┌────────────────────────────────────────┐  │
│  │  user@example.com                      │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Password                                    │
│  ┌────────────────────────────────────────┐  │
│  │  ••••••••                          👁  │  │
│  └────────────────────────────────────────┘  │
│                                              │
│                     Forgot password?         │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │            Sign In                     │  │
│  └────────────────────────────────────────┘  │
│                                              │
│       Don't have an account? Sign Up         │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Background** | `$surfaceBackground` (#F8F9FB) |
| **Logo** | 48×48px, `$primary`, `$space9` (48px) from safe area top |
| **Welcome text** | `$headlineLarge` (24px/700), `$textPrimary`, center |
| **Subtitle** | `$bodyMedium` (14px/400), `$textSecondary`, center |
| **Logo → welcome gap** | `$space4` (16px) |
| **Welcome → subtitle gap** | `$space2` (8px) |
| **Subtitle → form gap** | `$space7` (32px) |
| **Field gap** | `$space4` (16px) between fields |
| **Forgot password** | Ghost button, right-aligned, `$labelMedium`, `$textLink` |
| **Sign In button** | Primary gradient, full width, `$space6` (24px) below forgot |
| **Sign up link** | `$bodyMedium`, `$textSecondary` + `$textLink` for "Sign Up" |
| **Sign up position** | `$space6` below sign in button |
| **Horizontal padding** | `$space5` (20px) |

**States:**
- **Validation errors:** Fields show error state (§3.1 Text Input), error messages below each field
- **Loading:** Sign In button shows spinner, fields disabled
- **API error:** Snackbar with error message at bottom

**Animation:** Fields stagger-fade-in from top to bottom on screen appear (100ms delay each).

### 2.2 Sign Up

```
┌──────────────────────────────────────────────┐
│                                              │
│               ┌────────┐                     │
│               │  LOGO  │                     │
│               └────────┘                     │
│                                              │
│          Create account                      │
│     Set up your smart home                   │
│                                              │
│  Name                                        │
│  ┌────────────────────────────────────────┐  │
│  │  Tim                                   │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Email                                       │
│  ┌────────────────────────────────────────┐  │
│  │  tim@example.com                       │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Password                                    │
│  ┌────────────────────────────────────────┐  │
│  │  ••••••••                          👁  │  │
│  └────────────────────────────────────────┘  │
│  Must be at least 8 characters               │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Create Account                │  │
│  └────────────────────────────────────────┘  │
│                                              │
│      Already have an account? Sign In        │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Notes |
|---|---|
| Layout | Same as Sign In with additional Name field |
| **Title** | "Create account" |
| **Password hint** | `$bodySmall`, `$textTertiary`, below password field |
| **CTA** | "Create Account" gradient button |
| **Bottom link** | "Already have an account? Sign In" |

### 2.3 Forgot Password

```
┌──────────────────────────────────────────────┐
│  ←                                           │
│                                              │
│          Reset password                      │
│   Enter your email and we'll send            │
│   you a link to reset your password          │
│                                              │
│  Email                                       │
│  ┌────────────────────────────────────────┐  │
│  │  user@example.com                      │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Send Reset Link               │  │
│  └────────────────────────────────────────┘  │
│                                              │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Back button** | App Bar with back arrow only, no title |
| **Title** | `$headlineLarge` (24px/700), `$textPrimary`, center |
| **Description** | `$bodyMedium` (14px/400), `$textSecondary`, center, max 280px width |
| **CTA** | Primary gradient, "Send Reset Link" |

**Success state:** Replace form with:
```
│              ✉️                               │
│                                              │
│         Check your email                     │
│   We've sent a reset link to                 │
│   t***@example.com                           │
│                                              │
│       [ Back to Sign In ]                    │
```
- Envelope icon: 48px, `$primary`
- Success title: `$headlineLarge`
- Email hint: `$bodyMedium`, `$textSecondary`
- Button: Secondary outlined

---

## 3. Home Dashboard

### 3.1 Home — With Devices

```
┌──────────────────────────────────────────────┐
│                                              │
│  Home                              🔔  ⚙️   │
│                                              │
│  Good morning, Tim ☀️                        │
│  3 devices online                            │
│                                              │
│  [ All ] Living Room  Bedroom  Kitchen  +    │
│                                              │
│  ┌──────────┐  ┌──────────┐                  │
│  │⚡ Living  │  │💡 Bed    │                  │
│  │  Room    │  │  Light   │                  │
│  │  Light   │  │          │                  │
│  │          │  │  OFF     │                  │
│  │   ON     │  │   ○━━    │                  │
│  │   ━━●    │  │          │                  │
│  └──────────┘  └──────────┘                  │
│                                              │
│  ┌──────────┐  ┌──────────┐                  │
│  │🌡 Temp   │  │🪟 Kitchen│                  │
│  │  Sensor  │  │  Shutter │                  │
│  │          │  │          │                  │
│  │  23.5°C  │  │  75%     │                  │
│  │          │  │   ○━━    │                  │
│  └──────────┘  └──────────┘                  │
│                                              │
│                                              │
│  🏠 Home     🎬 Scenes     👤 Profile        │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Background** | `$surfaceBackground` (#F8F9FB) |
| **Screen title** | `$headlineLarge` (24px/700), `$textPrimary` |
| **Notification icon** | 24px bell, `$iconDefault`, 44×44px target |
| **Settings icon** | 24px gear, `$iconDefault`, 44×44px target |
| **Greeting** | `$titleLarge` (18px/600), `$textPrimary` |
| **Status line** | `$bodyMedium` (14px/400), `$textSecondary` |
| **Title → greeting gap** | `$space4` (16px) |
| **Greeting → status gap** | `$space1` (4px) |
| **Status → tabs gap** | `$space5` (20px) |
| **Room tabs** | See §4.3 Room Tabs component |
| **Tabs → grid gap** | `$space4` (16px) |
| **Device grid** | 2 columns, `$space3` (12px) gap, `$space5` (20px) horizontal margin |
| **Device cards** | See §2.1 Device Card component |
| **Scroll** | Vertical scroll for grid, tabs fixed |
| **Pull-to-refresh** | Standard, uses `$primary` color indicator |

**Greeting logic:**
- 05:00-11:59: "Good morning, {name} ☀️"
- 12:00-17:59: "Good afternoon, {name}"
- 18:00-21:59: "Good evening, {name} 🌙"
- 22:00-04:59: "Good night, {name} 🌙"

**Device status line:** "{N} devices online" — count in `$primary` color.

### 3.2 Home — Empty State

```
┌──────────────────────────────────────────────┐
│                                              │
│  Home                                        │
│                                              │
│  Welcome, Tim 👋                             │
│                                              │
│                                              │
│                                              │
│              ┌────────┐                      │
│              │  🏠    │                      │
│              └────────┘                      │
│                                              │
│       Your smart home awaits                 │
│                                              │
│   Add your first device to start             │
│   controlling your home.                     │
│                                              │
│       [ + Add Device ]                       │
│                                              │
│                                              │
│                                              │
│                                              │
│  🏠 Home     🎬 Scenes     👤 Profile        │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| All | See Empty States component (§9) |
| **Title** | "Your smart home awaits" |
| **Description** | "Add your first device to start controlling your home." |
| **CTA** | "+ Add Device" primary gradient button |
| **No room tabs** | Hidden when no devices |

### 3.3 Home — Loading State

```
┌──────────────────────────────────────────────┐
│                                              │
│  Home                              🔔  ⚙️   │
│                                              │
│  ██████████████ ☀️                           │  ← skeleton
│  ████████                                    │
│                                              │
│  [████] ██████  ████████  ██████  +          │
│                                              │
│  ┌──────────┐  ┌──────────┐                  │
│  │  ██  ████│  │  ██  ████│                  │
│  │          │  │          │                  │
│  │  ████    │  │  ████    │                  │
│  │      ████│  │      ████│                  │
│  └──────────┘  └──────────┘                  │
│                                              │
│  ┌──────────┐  ┌──────────┐                  │
│  │  ██  ████│  │  ██  ████│                  │
│  │          │  │          │                  │
│  │  ████    │  │  ████    │                  │
│  │      ████│  │      ████│                  │
│  └──────────┘  └──────────┘                  │
│                                              │
│  🏠 Home     🎬 Scenes     👤 Profile        │
└──────────────────────────────────────────────┘
```

4 skeleton device cards in 2×2 grid. Shimmer animation (§10.1).

---

## 4. Device Control Screens

### 4.1 Switch Device

```
┌──────────────────────────────────────────────┐
│  ←  Living Room Light              ⚙️  ⋮    │
│                                              │
│              ┌─────────────┐                 │
│              │             │                 │
│              │             │                 │
│              │    💡       │                 │
│              │             │                 │
│              │    ON       │                 │
│              │             │                 │
│              └─────────────┘                 │
│                                              │
│           ┌───────────●━━━━┐                 │
│           └────────────────┘                 │
│                                              │
│  Details                                     │
│  ┌──────────────────────────────────────┐    │
│  │  Power         ·        12.4W       │    │
│  ├──────────────────────────────────────┤    │
│  │  Today         ·        0.8 kWh     │    │
│  ├──────────────────────────────────────┤    │
│  │  Signal        ·        -45 dBm     │    │
│  ├──────────────────────────────────────┤    │
│  │  IP Address    ·     192.168.1.42   │    │
│  ├──────────────────────────────────────┤    │
│  │  Firmware      ·        v2.1.0      │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **App bar** | Back arrow, device name (`$headlineMedium`), gear + menu icons |
| **Control area** | Centered, `$space8` (40px) top margin |
| **Control card** | 180×180px, `$surfaceCard`, `$borderDefault`, `$radiusXL` (24px), centered |
| **Device icon** | 48px, centered in card. ON: `$primary`. OFF: `$neutral400` |
| **State text** | `$titleLarge` (18px/600), 8px below icon. ON: `$primary`. OFF: `$textSecondary` |
| **Toggle** | Centered, `$space6` (24px) below control card. See §5.1 |
| **Section title** | `$overline` (11px/600), `$textSecondary`, uppercase, `$space7` below toggle |
| **Details group** | Settings item group (§2.3) |
| **Detail label** | `$bodyMedium`, `$textSecondary` |
| **Detail value** | `$bodyMedium`, `$textPrimary`, right-aligned |

**ON → OFF animation:**
1. Toggle slides (`$durationMedium`)
2. Control card icon color transitions `$primary → $neutral400` (`$durationMedium`)
3. State text changes "ON" → "OFF" with cross-fade (`$durationFast`)

**Unreachable state:**
- Overlay on control card: `$surfaceOverlay` at 20% + "Unreachable" text
- Toggle disabled
- Snackbar: "Device is unreachable. Check network connection."

### 4.2 Light Device

Same as Switch, plus additional controls:

```
│  ─────────added below toggle──────────        │
│                                              │
│  Brightness                          75%     │
│  ───────────────────●━━━━━━━━━                │
│                                              │
│  Color Temperature                   Warm    │
│  ━━━━━━━●─────────────────────                │
│                                              │
```

| Element | Token / Value |
|---|---|
| **Brightness label** | `$labelMedium` (14px/500), `$textSecondary` |
| **Brightness value** | `$labelMedium` (14px/500), `$textPrimary`, right-aligned |
| **Brightness slider** | See §5.2, active track uses `$gradientPrimary` |
| **Color temp label** | `$labelMedium` (14px/500), `$textSecondary` |
| **Color temp value** | `$labelMedium` (14px/500), `$textPrimary`, right-aligned ("Warm" / "Neutral" / "Cool") |
| **Color temp slider** | Custom track: gradient `#FFB347 → #FFFFFF → #87CEEB`, 4px height |
| **Slider section gap** | `$space5` (20px) between sliders |
| **Section gap** | `$space6` (24px) above/below slider section |

### 4.3 Sensor Device

```
┌──────────────────────────────────────────────┐
│  ←  Bedroom Sensor                     ⋮    │
│                                              │
│  ┌──────────────┐  ┌──────────────┐          │
│  │   🌡         │  │   💧         │          │
│  │   23.5°C     │  │   65%        │          │
│  │   Temperature│  │   Humidity   │          │
│  └──────────────┘  └──────────────┘          │
│                                              │
│  Temperature                                 │
│  ┌──────────────────────────────────────┐    │
│  │  26° ·                               │    │
│  │      ·    ╱╲                          │    │
│  │  24° ·  ╱    ╲   ╱╲                  │    │
│  │      ·╱        ╲╱    ╲               │    │
│  │  22° ·              ╲              │    │
│  │      ·────────────────────────────   │    │
│  │      6h    12h    18h    24h         │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Humidity                                    │
│  ┌──────────────────────────────────────┐    │
│  │  [Similar chart]                      │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Details                                     │
│  ┌──────────────────────────────────────┐    │
│  │  Battery        ·      85%  ████░   │    │
│  ├──────────────────────────────────────┤    │
│  │  Last updated   ·      2 min ago    │    │
│  ├──────────────────────────────────────┤    │
│  │  Signal         ·      -52 dBm     │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Stat cards** | 2-column grid, Stat Card component (§2.4), `$space3` gap |
| **Stat icon** | 24px, `$primary`, top-left of card |
| **Stat value** | `$headlineLarge` (24px/700), `$textPrimary` |
| **Stat label** | `$bodySmall` (12px/400), `$textSecondary` |
| **Section label** | `$overline` (11px/600), `$textSecondary`, uppercase |
| **Chart card** | `$surfaceCard`, `$borderDefault`, `$radiusLarge`, 200px height, `$space4` padding |
| **Chart line** | 2px stroke, `$primary` |
| **Chart fill** | Below line, `$primary` at 8% opacity |
| **Chart axis** | `$bodySmall` (12px/400), `$textTertiary` |
| **Chart grid** | Horizontal dashed lines, `$borderSubtle` |
| **Battery bar** | 60×12px, `$radiusSmall`, `$neutral200` bg, `$success` fill (>50%), `$warning` (20-50%), `$error` (<20%) |

### 4.4 Shutter Device

```
┌──────────────────────────────────────────────┐
│  ←  Kitchen Shutter                    ⋮    │
│                                              │
│                                              │
│              ╭─────────╮                     │
│             ╱           ╲                    │
│            │    75%      │                   │
│            │    Open     │                   │
│             ╲           ╱                    │
│              ╰─────────╯                     │
│                                              │
│                                              │
│     ┌──┐       ┌──────┐       ┌──┐          │
│     │ ▲│       │ ■ Stop│       │ ▼│          │
│     └──┘       └──────┘       └──┘          │
│                                              │
│  Quick Positions                             │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐       │
│  │  0%  │ │ 25%  │ │ 50%  │ │ 100% │       │
│  └──────┘ └──────┘ └──────┘ └──────┘       │
│                                              │
│  Details                                     │
│  ┌──────────────────────────────────────┐    │
│  │  Current position  ·       75%      │    │
│  ├──────────────────────────────────────┤    │
│  │  Last moved        ·   5 min ago    │    │
│  ├──────────────────────────────────────┤    │
│  │  Signal            ·    -38 dBm     │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Circular progress** | 140×140px, centered, `$space8` top margin. See §5.3 |
| **Progress value** | `$headlineLarge` (24px/700), `$textPrimary` |
| **Progress label** | `$bodySmall` (12px/400), `$textSecondary`, "Open" / "Closed" / "Moving…" |
| **Up button** | 56×56px, `$surfaceCard`, `$borderDefault`, `$radiusMedium`, caret-up 24px `$iconDefault` |
| **Stop button** | 56×56px, `$surfaceCard`, `$borderDefault`, `$radiusMedium`, stop 24px `$error` |
| **Down button** | 56×56px, same as up, caret-down icon |
| **Button row** | Centered, `$space7` (32px) gaps, `$space7` below circle |
| **Quick positions label** | `$overline`, `$textSecondary`, uppercase |
| **Position chips** | Small buttons (§1.6), secondary style, row with `$space2` gaps |
| **Active position chip** | Primary small button (gradient) for current position |

**Moving animation:**
- Circular progress animates smoothly to target position
- "Moving…" replaces "Open"/"Closed" label
- Stop button pulsates with `$error` glow while moving

### 4.5 Device Settings (via gear icon)

```
┌──────────────────────────────────────────────┐
│  ←  Device Settings                          │
│                                              │
│  General                                     │
│  ┌──────────────────────────────────────┐    │
│  │  Name          ·  Living Room Light  │    │
│  ├──────────────────────────────────────┤    │
│  │  Room          ·  Living Room     >  │    │
│  ├──────────────────────────────────────┤    │
│  │  Icon          ·  💡             >  │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Network                                     │
│  ┌──────────────────────────────────────┐    │
│  │  WiFi Profile  ·  HomeNet_5G     >  │    │
│  ├──────────────────────────────────────┤    │
│  │  IP Address    ·  192.168.1.42      │    │
│  ├──────────────────────────────────────┤    │
│  │  MAC Address   ·  AA:BB:CC:DD:EE   │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Firmware                                    │
│  ┌──────────────────────────────────────┐    │
│  │  Version       ·  v2.1.0           │    │
│  ├──────────────────────────────────────┤    │
│  │  Check for updates              >   │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  🗑  Remove Device                   │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Section labels** | `$overline` (11px/600), `$textSecondary`, uppercase, `$space5` padding left |
| **Settings groups** | Settings Item component groups (§2.3) |
| **Remove device** | Standalone settings item, `$error` text and icon, `$surfaceCard` bg, `$borderDefault` border, `$radiusLarge` |
| **Remove tap** | Shows destructive dialog (§6.2): "Remove Device? This will remove the device from all rooms and scenes." with Cancel + Remove (destructive) buttons |

---

## 5. Scenes

### 5.1 Scenes List

```
┌──────────────────────────────────────────────┐
│                                              │
│  Scenes                              +       │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  🌅  Morning Routine           ▶️   │    │
│  │      5 devices · Daily at 7:00       │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  🌙  Good Night                ▶️   │    │
│  │      3 devices · Manual              │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  🎬  Movie Time                ▶️   │    │
│  │      4 devices · Manual              │    │
│  └──────────────────────────────────────┘    │
│                                              │
│                                              │
│                                              │
│                                              │
│  🏠 Home     🎬 Scenes     👤 Profile        │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Screen title** | `$headlineLarge` (24px/700), `$textPrimary` |
| **Add button** | Icon button, 24px plus, `$iconDefault`, 44×44px target |
| **Scene cards** | Scene Card component (§2.2), full width, `$space3` (12px) gap |
| **Horizontal padding** | `$space5` (20px) |
| **Title → list gap** | `$space5` (20px) |
| **Long press** | Shows bottom sheet: Edit, Duplicate, Delete |
| **Swipe left** | Reveals delete action (red bg, trash icon) |

**Empty state:**
- Icon: play-circle, 48px
- Title: "No scenes yet"
- Description: "Create scenes to control multiple devices with a single tap."
- CTA: "+ Create Scene"

### 5.2 Scene Create / Edit

```
┌──────────────────────────────────────────────┐
│  ←  New Scene                    Save        │
│                                              │
│  Scene Name                                  │
│  ┌────────────────────────────────────────┐  │
│  │  Morning Routine                       │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Icon                                        │
│  🌅 🌙 🎬 ☀️ 🏠 🎵 🎮 💡                   │
│     ^^^ selected                             │
│                                              │
│  Devices                                     │
│  ┌──────────────────────────────────────┐    │
│  │  💡  Living Room Light          ON   │    │
│  │      Brightness: 80%                 │    │
│  ├──────────────────────────────────────┤    │
│  │  🪟  Kitchen Shutter           50%  │    │
│  ├──────────────────────────────────────┤    │
│  │  + Add Device                        │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Schedule (optional)                         │
│  ┌──────────────────────────────────────┐    │
│  │  ⏰  Daily at 7:00 AM          ✕    │    │
│  └──────────────────────────────────────┘    │
│  ┌──────────────────────────────────────┐    │
│  │  + Add Schedule                      │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **App bar** | Back arrow, "New Scene" / "Edit Scene" title, "Save" ghost button right |
| **Save button** | `$labelLarge`, `$primary`, disabled (`$neutral400`) when form invalid |
| **Name input** | Text Input (§3.1) |
| **Icon grid** | Row of emojis, 44×44px targets, `$space2` gap. Selected: `$surfacePrimarySubtle` circle bg + 2px `$primary` ring |
| **Devices section** | Settings item group with device action items |
| **Device action item** | Leading icon + name, trailing: action value (ON/OFF/percentage) |
| **Add device row** | Plus icon + "Add Device" text, `$primary` color, taps opens device picker sheet |
| **Schedule item** | Clock icon + schedule text + remove (X) button |
| **Section labels** | `$overline`, `$textSecondary`, `$space6` gap above |

---

## 6. Profile

### 6.1 Profile Screen

```
┌──────────────────────────────────────────────┐
│                                              │
│  Profile                                     │
│                                              │
│              ┌────────┐                      │
│              │  😀    │                      │
│              └────────┘                      │
│              Tim                             │
│              tim@example.com                 │
│                                              │
│  Home                                        │
│  ┌──────────────────────────────────────┐    │
│  │  🏠  Rooms                       >  │    │
│  ├──────────────────────────────────────┤    │
│  │  📶  WiFi Profiles               >  │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  App                                         │
│  ┌──────────────────────────────────────┐    │
│  │  🔔  Notifications              >   │    │
│  ├──────────────────────────────────────┤    │
│  │  🎨  Appearance            Light  >  │    │
│  ├──────────────────────────────────────┤    │
│  │  ℹ️  About                       >  │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Account                                     │
│  ┌──────────────────────────────────────┐    │
│  │  🔑  Change Password             >  │    │
│  ├──────────────────────────────────────┤    │
│  │  🚪  Sign Out                        │    │
│  └──────────────────────────────────────┘    │
│                                              │
│                                              │
│  🏠 Home     🎬 Scenes     👤 Profile        │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Screen title** | `$headlineLarge` (24px/700), `$textPrimary` |
| **Avatar** | 80×80px circle, `$surfacePrimarySubtle` bg, emoji 40px centered. Tap → avatar picker sheet |
| **Name** | `$titleLarge` (18px/600), `$textPrimary`, center, `$space3` below avatar |
| **Email** | `$bodyMedium` (14px/400), `$textSecondary`, center, `$space1` below name |
| **Avatar → name area** | Centered, `$space6` below title |
| **Section labels** | `$overline` (11px/600), `$textSecondary`, uppercase, `$space5` left padding, `$space6` top margin |
| **Settings groups** | Settings Item component groups (§2.3) |
| **Sign Out** | `$error` text color, no chevron |
| **Sign Out tap** | Dialog: "Sign out of your account?" with Cancel + Sign Out (destructive) |

### 6.2 Edit Profile (inline)

Avatar tap → Avatar Picker bottom sheet (§13 in Component Library).
Name tap → inline text editing or sheet with name input.

---

## 7. Add Device Wizard

### 7.1 Step 1 — Select Device Type

```
┌──────────────────────────────────────────────┐
│  ←                          Step 1 of 4      │
│                                              │
│  ●────○────○────○                            │
│                                              │
│  What type of device?                        │
│  Choose the kind of device you're adding     │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  ⚡  Switch                          │    │
│  │     On/off control for any device     │    │
│  ├──────────────────────────────────────┤    │
│  │  💡  Light                           │    │
│  │     Dimmable light with brightness   │    │
│  ├──────────────────────────────────────┤    │
│  │  🌡  Sensor                          │    │
│  │     Temperature, humidity, etc.      │    │
│  ├──────────────────────────────────────┤    │
│  │  🪟  Shutter                         │    │
│  │     Motorized blinds and shutters    │    │
│  └──────────────────────────────────────┘    │
│                                              │
│                                              │
│                                              │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Continue                      │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Step indicator** | See Wizard Step Indicator (§11.1) |
| **Title** | `$headlineMedium` (22px/600), `$textPrimary` |
| **Subtitle** | `$bodyMedium` (14px/400), `$textSecondary` |
| **Device type list** | Settings item group, 72px height per item |
| **Item leading icon** | 32px, `$iconDefault` |
| **Item title** | `$titleMedium` (16px/600), `$textPrimary` |
| **Item description** | `$bodySmall` (12px/400), `$textSecondary` |
| **Selected item** | `$surfacePrimarySubtle` bg, left border 3px `$primary` |
| **Continue button** | Primary gradient, full width, pinned bottom, disabled until selection |

### 7.2 Step 2 — Select WiFi Profile

```
┌──────────────────────────────────────────────┐
│  ←                          Step 2 of 4      │
│                                              │
│  ●────●────○────○                            │
│                                              │
│  Select WiFi network                         │
│  The device will connect to this network     │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  📶  HomeNetwork_5G          ✓       │    │
│  ├──────────────────────────────────────┤    │
│  │  📶  HomeNetwork_2.4G               │    │
│  ├──────────────────────────────────────┤    │
│  │  +   Add WiFi Profile               │    │
│  └──────────────────────────────────────┘    │
│                                              │
│                                              │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Continue                      │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **WiFi list** | Radio-style list items. Selected: check icon `$primary`, `$surfacePrimarySubtle` bg |
| **Add WiFi** | Plus icon + text, `$primary` color. Taps → WiFi add form (inline or sheet) |
| **Continue** | Disabled until WiFi selected |

### 7.3 Step 3 — Device Connection

```
┌──────────────────────────────────────────────┐
│  ←                          Step 3 of 4      │
│                                              │
│  ●────●────●────○                            │
│                                              │
│  Connect your device                         │
│  Follow these steps:                         │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  1. Plug in your device              │    │
│  │                                      │    │
│  │  2. Press the button for 5 seconds   │    │
│  │     until the LED blinks rapidly     │    │
│  │                                      │    │
│  │  3. Tap "Start Pairing" below        │    │
│  └──────────────────────────────────────┘    │
│                                              │
│                                              │
│                   🔄                         │
│            Searching...                      │
│                                              │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │        Start Pairing                   │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Instructions card** | `$surfaceCard`, `$borderDefault`, `$radiusLarge`, `$space4` padding |
| **Step numbers** | `$labelMedium` (14px/500), `$primary` |
| **Step text** | `$bodyMedium` (14px/400), `$textPrimary` |
| **Step gap** | `$space4` (16px) between steps |
| **Searching state** | 32px spinner + "Searching…" text, `$textSecondary`, centered |
| **CTA** | "Start Pairing" → "Searching…" (disabled, spinner) → "Connected!" (success) |

**Connection states:**
- **Idle:** Instructions visible, CTA enabled
- **Searching:** Spinner, CTA disabled, instructions stay
- **Found:** Device name appears, auto-advance after 1s
- **Error:** Error snackbar "No device found. Try again.", CTA re-enabled

### 7.4 Step 4 — Name & Room

```
┌──────────────────────────────────────────────┐
│  ←                          Step 4 of 4      │
│                                              │
│  ●────●────●────●                            │
│                                              │
│  Name your device                            │
│  Give it a name and assign it to a room      │
│                                              │
│  Device Name                                 │
│  ┌────────────────────────────────────────┐  │
│  │  Living Room Light                     │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Room                                        │
│  ┌────────────────────────────────────────┐  │
│  │  Living Room                        ▼  │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Icon                                        │
│  💡 ⚡ 🔌 🌡 🪟                              │
│  ^^^ selected                                │
│                                              │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Add Device                    │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Name input** | Text Input, pre-filled with device type |
| **Room dropdown** | Select component (§3.4), populated from user's rooms |
| **Icon selection** | Horizontal row, 44×44px targets, same pattern as scene icons |
| **Add Device CTA** | Primary gradient, full width |
| **Success state** | Navigate to device control screen with success snackbar "Device added successfully!" |

---

## 8. WiFi Profiles

### 8.1 WiFi Profiles List

```
┌──────────────────────────────────────────────┐
│  ←  WiFi Profiles                    +       │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  📶  HomeNetwork_5G            ⋮     │    │
│  │      WPA2 · 3 devices using          │    │
│  ├──────────────────────────────────────┤    │
│  │  📶  HomeNetwork_2.4G          ⋮     │    │
│  │      WPA2 · 1 device using           │    │
│  └──────────────────────────────────────┘    │
│                                              │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **App bar** | Back arrow, title, plus icon button |
| **List** | WiFi Profile Items (§8.2 in Component Library), in settings group |
| **Menu (⋮)** | Bottom sheet: Edit, Delete |
| **Delete** | Destructive dialog if devices are using it: "This profile is used by 3 devices. Remove anyway?" |

### 8.2 Add / Edit WiFi Profile

```
┌──────────────────────────────────────────────┐
│  ←  Add WiFi Profile              Save       │
│                                              │
│  Network Name (SSID)                         │
│  ┌────────────────────────────────────────┐  │
│  │  HomeNetwork_5G                        │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Password                                    │
│  ┌────────────────────────────────────────┐  │
│  │  ••••••••                          👁  │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Security Type                               │
│  ┌────────────────────────────────────────┐  │
│  │  WPA2/WPA3                          ▼  │  │
│  └────────────────────────────────────────┘  │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Save** | Ghost button, `$primary`, disabled until form valid |
| **Fields** | Standard Text Input components |
| **Security dropdown** | Select with options: None, WPA2/WPA3, WEP |

---

## 9. Rooms Management

### 9.1 Rooms List

```
┌──────────────────────────────────────────────┐
│  ←  Rooms                            +       │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  🛋  Living Room                  >  │    │
│  │      4 devices                        │    │
│  ├──────────────────────────────────────┤    │
│  │  🛏  Bedroom                      >  │    │
│  │      2 devices                        │    │
│  ├──────────────────────────────────────┤    │
│  │  🍳  Kitchen                      >  │    │
│  │      3 devices                        │    │
│  └──────────────────────────────────────┘    │
│                                              │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **List items** | 72px height, leading emoji 28px, title `$titleMedium`, subtitle `$bodySmall` `$textSecondary`, trailing chevron |
| **Add** | Plus icon button → sheet with name input + icon picker |
| **Tap** | Navigate to room detail (shows devices in room) |
| **Long press** | Sheet: Rename, Delete |
| **Delete** | Destructive dialog if devices assigned: "Devices in this room will be unassigned." |

### 9.2 Add / Edit Room

Bottom sheet:

```
┌──────────────────────────────────────────────┐
│              ━━━━                             │
│                                              │
│  New Room                                    │
│                                              │
│  Room Name                                   │
│  ┌────────────────────────────────────────┐  │
│  │  Kitchen                               │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Icon                                        │
│  🛋 🛏 🍳 🚿 🏢 🌳 🚗 🎮                   │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Save                          │  │
│  └────────────────────────────────────────┘  │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Token / Value |
|---|---|
| **Sheet** | Bottom Sheet component (§6.3) |
| **Title** | `$titleLarge` (18px/600), `$textPrimary` |
| **Name input** | Text Input (§3.1) |
| **Icon grid** | 8-column emoji grid, 44×44px targets, `$space2` gap |
| **Selected icon** | `$surfacePrimarySubtle` circle bg + 2px `$primary` ring |
| **Save button** | Primary gradient, full width |

---

## 10. Global Patterns

### 10.1 Navigation Transitions

| Transition | Animation |
|---|---|
| **Push (forward)** | New screen slides in from right, old slides left. 60ms overlap for cross-fade on shared elements. `$durationSlow` (400ms), `$curveDecelerate`. |
| **Pop (back)** | Reverse of push. `$durationSlow`, `$curveAccelerate`. |
| **Tab switch** | Cross-fade content, `$durationMedium` (250ms). Bottom nav icons smoothly transition color. |
| **Sheet/Dialog** | Sheet slides up, dialog scales 0.9→1.0 + fades in. Both with `$durationSlow`, `$curveDecelerate`. Scrim fades in `$durationMedium`. |
| **Wizard steps** | Forward: slide left. Back: slide right. `$durationMedium`. |

### 10.2 Error Handling

| Error Type | UI Treatment |
|---|---|
| **Field validation** | Inline error below field (§14 in Components) |
| **API error** | Snackbar (§6.1) with error message, optional retry action |
| **Network offline** | Persistent banner at top: `$warning` bg, "No internet connection" |
| **Device unreachable** | Device card shows red dot + opacity. Device screen shows overlay. |
| **Session expired** | Dialog: "Session expired. Please sign in again." → navigate to Sign In |

### 10.3 Pull-to-Refresh

| Property | Value |
|---|---|
| **Indicator** | CircularProgressIndicator, `$primary` color |
| **Trigger distance** | 80px pull |
| **Background** | `$surfaceBackground` |
| **Available on** | Home dashboard, Scenes list, Device control |

### 10.4 iPad Adaptation Rules

All screens follow these rules on iPad (width ≥ 600px):

1. Content wrapped in `Center > ConstrainedBox(maxWidth: 500)`
2. `$surfaceBackground` fills beyond the constraint
3. Bottom nav constrained to same 500px width
4. Dialogs: same max width
5. Bottom sheets: same max width, centered
6. Grid columns stay at 2 (not expanding to 3+)
7. No changes to font sizes or spacing

### 10.5 Accessibility

| Requirement | Implementation |
|---|---|
| **Tap targets** | ≥ 44×44px on all interactive elements |
| **Color contrast** | All text meets WCAG AA (4.5:1 normal, 3:1 large) |
| **Focus indicators** | 2px `$primary` ring with `$shadowGlow` on keyboard focus |
| **Screen reader** | All icons have semantic labels, all images have alt text |
| **Reduce motion** | Respect `MediaQuery.of(context).disableAnimations` — skip animations |
| **Dynamic type** | Support up to 1.5× text scale, layouts flex accordingly |
| **Color blindness** | Status indicators use shape + color (not color alone). e.g., online = green dot + "Online" text |

---

## 11. Dark Mode (Future)

When dark mode is implemented, all screens use the dark semantic tokens from `01-DESIGN-TOKENS.md` §3. Key changes:

| Element | Light → Dark |
|---|---|
| Scaffold bg | `#F8F9FB` → `#010510` |
| Card bg | `#FFFFFF` → `#1A202B` |
| Card border | `#E8ECF1` → `#181B1F` |
| Text primary | `#0A1628` → `#FFFFFF` |
| Text secondary | `#5A6577` → `#C7C9CC` |
| Primary gradient | Same in both modes |
| Bottom nav bg | `#FFFFFF` → `#0F1520` |
| App bar bg | `#F8F9FB` → `#010510` |
| Input bg | `#FFFFFF` → `#141A26` |
| Snackbar bg | `#0A1628` → `#1A202B` |

The gradient elements (`$gradientPrimary`) remain identical — this is the visual thread that ties the app to the website across all themes.
