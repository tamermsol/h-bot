# Component Library — H-Bot Mobile App

> Every component is specified with exact token references. A Flutter developer should be able to implement any component from this spec alone. All measurements in logical pixels.

---

## 1. Buttons

### 1.1 Primary Button (Gradient)

The hero CTA. Uses the brand gradient — the signature element from the website.

```
┌─────────────────────────────────────────┐
│          Get Started  →                 │
└─────────────────────────────────────────┘
```

| Property | Value |
|---|---|
| **Height** | 52px |
| **Min width** | 120px |
| **Padding** | 16px horizontal, 14px vertical |
| **Background** | `$gradientPrimary` (#0883FD → #8CD1FB, left→right) |
| **Border** | none |
| **Border radius** | `$radiusMedium` (12px) |
| **Text** | `$labelLarge` (Inter 16px/500) |
| **Text color** | `$textOnPrimary` (#FFFFFF) |
| **Icon size** | 20px, white |
| **Icon gap** | `$space2` (8px) from text |
| **Shadow** | `$shadowMedium` |

**States:**

| State | Change |
|---|---|
| **Rest** | As above |
| **Pressed** | Scale 0.97, shadow → `$shadowSmall`, duration `$durationFast` |
| **Disabled** | Background → `$primaryDisabled` (#D1D7E0), text → `$neutral400`, no gradient, no shadow |
| **Loading** | Replace text with 20px CircularProgressIndicator (white, strokeWidth 2), maintain button width |

### 1.2 Secondary Button (Outlined)

```
┌─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
│           View Details                  │
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
```

| Property | Value |
|---|---|
| **Height** | 52px |
| **Padding** | 16px horizontal, 14px vertical |
| **Background** | transparent |
| **Border** | 1.5px solid `$primary` (#0883FD) |
| **Border radius** | `$radiusMedium` (12px) |
| **Text** | `$labelLarge` (Inter 16px/500) |
| **Text color** | `$primary` (#0883FD) |
| **Shadow** | none |

**States:**

| State | Change |
|---|---|
| **Pressed** | Background → `$surfacePrimarySubtle` (#F0F7FF), scale 0.97 |
| **Disabled** | Border → `$neutral300`, text → `$neutral400` |

### 1.3 Ghost Button (Text Only)

| Property | Value |
|---|---|
| **Height** | 44px |
| **Padding** | 12px horizontal |
| **Background** | transparent |
| **Border** | none |
| **Text** | `$labelLarge` (Inter 16px/500) |
| **Text color** | `$primary` (#0883FD) |

**States:**

| State | Change |
|---|---|
| **Pressed** | Background → `$surfacePrimarySubtle` (#F0F7FF) with `$radiusSmall` |
| **Disabled** | Text → `$neutral400` |

### 1.4 Destructive Button

Same dimensions as Secondary, but:

| Property | Value |
|---|---|
| **Border** | 1.5px solid `$error` (#EF4444) |
| **Text color** | `$error` (#EF4444) |
| **Pressed bg** | `$surfaceDestructiveSubtle` (#FEE2E2) |

### 1.5 Icon Button

| Property | Value |
|---|---|
| **Size** | 44×44px (touch target) |
| **Icon size** | 24px |
| **Icon color** | `$iconDefault` (#5A6577) |
| **Background** | transparent |
| **Border radius** | `$radiusFull` |
| **Pressed bg** | `$neutral100` (#F0F2F5) |
| **Active icon color** | `$iconActive` (#0883FD) |

### 1.6 Small Button (Compact)

For inline actions, card actions.

| Property | Value |
|---|---|
| **Height** | 36px |
| **Padding** | 12px horizontal, 8px vertical |
| **Border radius** | `$radiusSmall` (8px) |
| **Text** | `$labelMedium` (Inter 14px/500) |
| Everything else | Same as Primary or Secondary variant |

---

## 2. Cards

### 2.1 Device Card

The primary interactive element on the Home screen. 2-column grid.

```
┌──────────────────────────┐
│  ⚡  Living Room Light   │  ← icon + name
│                          │
│       ON                 │  ← state text
│  ───────────●            │  ← optional: brightness slider
│                          │
│  [Toggle ○━━]            │  ← on/off toggle
└──────────────────────────┘
```

| Property | Value |
|---|---|
| **Width** | Flexible (grid child, ~½ screen - gaps) |
| **Min height** | 140px |
| **Padding** | `$space4` (16px) all sides |
| **Background** | `$surfaceCard` (#FFFFFF) |
| **Border** | 1px solid `$borderDefault` (#E8ECF1) |
| **Border radius** | `$radiusLarge` (16px) |
| **Shadow** | `$shadowNone` (border-based depth, like website) |

**Internal layout:**

| Element | Style |
|---|---|
| **Device icon** | 32px, `$iconDefault` when off, `$iconActive` (#0883FD) when on |
| **Device name** | `$titleMedium` (16px/600), `$textPrimary`, max 2 lines, ellipsis |
| **Room label** | `$bodySmall` (12px/400), `$textSecondary`, optional |
| **State text** | `$bodyMedium` (14px/400), `$textSecondary` when off, `$primary` when on |
| **Toggle** | See Toggle component (§5.1) — bottom-right aligned |
| **Gap** | `$space2` (8px) between icon row and state, `$space3` (12px) to toggle |

**States:**

| State | Change |
|---|---|
| **Device ON** | Left border accent: 3px solid `$primary` (#0883FD) on left edge. Icon color → `$iconActive`. State text → `$primary` |
| **Device OFF** | Default border all sides. Icon → `$iconDefault`. State text → `$textSecondary` |
| **Unreachable** | Opacity 0.5, red dot indicator (6px) top-right, no toggle interaction |
| **Pressed** | Background → `$surfaceCardHover` (#F0F2F5), scale 0.98, `$durationFast` |
| **Loading** | Shimmer overlay on state text area |

### 2.2 Scene Card

```
┌──────────────────────────────────────────────┐
│  🌅  Morning Routine                    ▶️   │
│  5 devices · Every day at 7:00               │
└──────────────────────────────────────────────┘
```

| Property | Value |
|---|---|
| **Height** | 72px |
| **Padding** | `$space4` (16px) all sides |
| **Background** | `$surfaceCard` (#FFFFFF) |
| **Border** | 1px solid `$borderDefault` |
| **Border radius** | `$radiusLarge` (16px) |

**Internal layout:**

| Element | Style |
|---|---|
| **Scene icon** | 40×40px circle, `$surfacePrimarySubtle` bg, emoji or icon inside (24px) |
| **Scene name** | `$titleMedium` (16px/600), `$textPrimary` |
| **Subtitle** | `$bodySmall` (12px/400), `$textSecondary` |
| **Play button** | 40×40px, `$primary` icon (PhosphorIcons.play), `$surfacePrimarySubtle` bg circle |
| **Gap** | `$space3` (12px) between icon and text, text fills middle |

### 2.3 Settings Item

```
┌──────────────────────────────────────────────┐
│  👤  Account                              >  │
├──────────────────────────────────────────────┤
│  🔔  Notifications                   ON   >  │
├──────────────────────────────────────────────┤
│  🏠  Rooms                                >  │
└──────────────────────────────────────────────┘
```

| Property | Value |
|---|---|
| **Height** | 56px |
| **Padding** | `$space4` (16px) horizontal, 0 vertical |
| **Background** | `$surfaceCard` (#FFFFFF) |
| **Border** | none (grouped in card with inner dividers) |
| **Divider** | 1px `$borderSubtle` (#F0F2F5), inset 56px from left |

**Internal layout:**

| Element | Style |
|---|---|
| **Icon** | 24px, `$iconDefault` |
| **Label** | `$bodyLarge` (16px/400), `$textPrimary` |
| **Value** | `$bodyMedium` (14px/400), `$textSecondary`, right-aligned |
| **Chevron** | 16px, `$neutral400`, right-aligned |
| **Gap** | `$space3` (12px) after icon |

**Group wrapper:**

| Property | Value |
|---|---|
| **Border radius** | `$radiusLarge` (16px) on wrapper |
| **Border** | 1px solid `$borderDefault` |
| **Background** | `$surfaceCard` |
| **Margin bottom** | `$space6` (24px) between groups |

### 2.4 Stat Card

```
┌──────────────────────────┐
│  ↑ 23.5°C               │
│  Temperature             │
│  ▁▂▃▄▅▆▇█▇▆▅            │
└──────────────────────────┘
```

| Property | Value |
|---|---|
| **Width** | Flexible (½ screen) |
| **Height** | 120px |
| **Padding** | `$space4` (16px) |
| **Background** | `$surfaceCard` (#FFFFFF) |
| **Border** | 1px solid `$borderDefault` |
| **Border radius** | `$radiusLarge` (16px) |

| Element | Style |
|---|---|
| **Value** | `$headlineLarge` (24px/700), `$textPrimary` |
| **Label** | `$bodySmall` (12px/400), `$textSecondary` |
| **Sparkline** | 32px tall, stroke 1.5px, `$primary` color, bottom-aligned |

---

## 3. Input Fields

### 3.1 Text Input

```
┌──────────────────────────────────────────────┐
│  Email                                       │
│  ┌────────────────────────────────────────┐  │
│  │  user@example.com                      │  │
│  └────────────────────────────────────────┘  │
│  Please enter a valid email                  │
└──────────────────────────────────────────────┘
```

| Property | Value |
|---|---|
| **Height** | 52px (input only) |
| **Padding** | 16px horizontal, 14px vertical |
| **Background** | `$surfaceInput` (#FFFFFF) |
| **Border** | 1.5px solid `$borderDefault` (#E8ECF1) |
| **Border radius** | `$radiusMedium` (12px) |
| **Text** | `$bodyLarge` (16px/400), `$textPrimary` |
| **Placeholder** | `$bodyLarge` (16px/400), `$textTertiary` (#7A8494) |
| **Label** | `$labelMedium` (14px/500), `$textSecondary`, above input, `$space1` (4px) gap |
| **Helper/Error** | `$bodySmall` (12px/400), `$textSecondary` or `$textError`, below input, `$space1` gap |

**States:**

| State | Change |
|---|---|
| **Rest** | As above |
| **Focused** | Border → 2px solid `$borderFocused` (#0883FD), shadow → `$shadowGlow` |
| **Error** | Border → 1.5px solid `$borderError` (#EF4444), helper text → `$textError` |
| **Disabled** | Background → `$neutral100`, text → `$neutral400`, border → `$neutral200` |
| **Filled** | Border → `$borderDefault`, text → `$textPrimary` |

### 3.2 Password Input

Same as Text Input + suffix icon:

| Property | Value |
|---|---|
| **Suffix icon** | 24px eye/eye-off, `$iconDefault`, 44×44px touch target |
| **Obscured** | `•` characters, Inter 16px |

### 3.3 Search Input

| Property | Value |
|---|---|
| **Height** | 48px |
| **Prefix icon** | 20px magnifying glass, `$neutral400` |
| **Background** | `$neutral100` (#F0F2F5) |
| **Border** | none (no border in rest state) |
| **Border radius** | `$radiusMedium` (12px) |
| **Focused border** | 1.5px solid `$borderFocused` |
| **Clear button** | 20px X icon, `$neutral400`, appears when text entered |

### 3.4 Dropdown / Select

```
┌────────────────────────────────────────┐
│  Living Room                        ▼  │
└────────────────────────────────────────┘
```

Same dimensions as Text Input. Chevron-down icon (16px) as suffix, `$neutral400`.

---

## 4. Navigation

### 4.1 Bottom Navigation Bar

```
┌──────────────────────────────────────────────┐
│                                              │
│   🏠 Home        🎬 Scenes       👤 Profile  │
│                                              │
└──────────────────────────────────────────────┘
```

| Property | Value |
|---|---|
| **Height** | 64px + safe area bottom inset |
| **Background** | `$surfaceElevated` (#FFFFFF) |
| **Top border** | 1px solid `$borderSubtle` (#F0F2F5) |
| **Shadow** | `0 -2px 8px rgba(10,22,40,0.04)` |
| **Padding** | 0 horizontal (items evenly distributed) |

**Tab Item:**

| Property | Value |
|---|---|
| **Touch target** | ≥ 44×44px per item |
| **Icon size** | 24px |
| **Label** | `$labelSmall` (12px/500) |
| **Gap** | `$space1` (4px) between icon and label |
| **Inactive icon** | `$neutral400` (#A0AAB8) |
| **Inactive label** | `$neutral400` |
| **Active icon** | `$primary` (#0883FD) |
| **Active label** | `$primary` (#0883FD) |
| **Active indicator** | 4px wide dot below icon, `$primary`, `$radiusFull` |

**Animation:** Icon + label color transition `$durationMedium` with `$curveStandard`.

### 4.2 App Bar

```
┌──────────────────────────────────────────────┐
│  ← Back        Screen Title          ⋮      │
└──────────────────────────────────────────────┘
```

| Property | Value |
|---|---|
| **Height** | 56px + safe area top inset |
| **Background** | `$surfaceBackground` (#F8F9FB) — NOT elevated, blends with page |
| **Title** | `$headlineMedium` (22px/600), `$textPrimary`, left-aligned |
| **Back icon** | 24px arrow-left, `$iconDefault` |
| **Action icons** | 24px, `$iconDefault`, 44×44px touch target |
| **Border** | none (scrolled state adds 1px `$borderSubtle` bottom) |

**Scrolled state:** When content scrolls beneath, add `$shadowSmall` bottom shadow and 1px `$borderSubtle` bottom border. Transition: `$durationFast`.

### 4.3 Room Tabs (Horizontal Scroll)

```
  [ All ]  Living Room   Bedroom   Kitchen   +
    ^^^ active
```

| Property | Value |
|---|---|
| **Container height** | 40px |
| **Container padding** | `$space5` (20px) left, 0 right (scroll reveals more) |
| **Tab height** | 36px |
| **Tab padding** | 16px horizontal |
| **Tab gap** | `$space2` (8px) |
| **Border radius** | `$radiusFull` (pill) |
| **Inactive bg** | transparent |
| **Inactive text** | `$textSecondary` (14px/500) |
| **Active bg** | `$primary` (#0883FD) |
| **Active text** | `$textOnPrimary` (#FFFFFF, 14px/600) |
| **Add button** | 36px circle, `$borderDefault` border, `+` icon `$iconDefault` |

**Animation:** Active tab bg fills with `$durationMedium`, `$curveStandard`. Content below cross-fades.

---

## 5. Controls

### 5.1 Toggle Switch

```
OFF:  ┌───────────○┐     ON:  ┌●━━━━━━━━━━━┐
      └────────────┘          └────────────┘
```

| Property | Value |
|---|---|
| **Track size** | 52×32px |
| **Track radius** | `$radiusFull` |
| **Track OFF bg** | `$toggleTrackOff` (#D1D7E0) |
| **Track ON bg** | `$gradientPrimary` (#0883FD → #8CD1FB) — **gradient, not flat!** |
| **Thumb size** | 28×28px |
| **Thumb bg** | `$toggleThumb` (#FFFFFF) |
| **Thumb shadow** | `$shadowSmall` |
| **Thumb position OFF** | 2px from left |
| **Thumb position ON** | 2px from right |
| **Touch target** | 52×44px (extends beyond track) |
| **Animation** | `$durationMedium` + `$curveStandard` for thumb slide + track color |

### 5.2 Slider

```
─────────────●━━━━━━━━━━
    ^^^ inactive           ^^^ active gradient
```

| Property | Value |
|---|---|
| **Track height** | 4px |
| **Track radius** | `$radiusFull` |
| **Inactive track** | `$neutral200` (#E8ECF1) |
| **Active track** | `$gradientPrimary` (from left to thumb) |
| **Thumb size** | 24×24px |
| **Thumb bg** | `$neutral0` (#FFFFFF) |
| **Thumb border** | 2px solid `$primary` |
| **Thumb shadow** | `$shadowSmall` |
| **Touch target** | 44×44px around thumb |
| **Value label** | `$labelMedium`, `$textPrimary`, above slider, shows on drag |

### 5.3 Circular Progress (Shutter Position)

```
      ╭─────╮
     │  75%  │
      ╰─────╯
```

| Property | Value |
|---|---|
| **Size** | 120×120px |
| **Track** | 8px stroke, `$neutral200` |
| **Progress** | 8px stroke, `$gradientPrimary` (sweep gradient) |
| **Cap** | Round |
| **Center text** | `$headlineLarge` (24px/700), `$textPrimary` |
| **Center label** | `$bodySmall` (12px/400), `$textSecondary` |

### 5.4 Progress Bar (Linear)

| Property | Value |
|---|---|
| **Height** | 4px |
| **Background** | `$neutral200` |
| **Fill** | `$gradientPrimary` |
| **Border radius** | `$radiusFull` |

### 5.5 Checkbox

| Property | Value |
|---|---|
| **Size** | 24×24px |
| **Border** | 2px solid `$borderDefault` (unchecked), 2px solid `$primary` (checked) |
| **Border radius** | 6px |
| **Checked fill** | `$primary` (#0883FD) |
| **Check icon** | 16px check, white, 2px stroke |
| **Touch target** | 44×44px |

### 5.6 Radio Button

| Property | Value |
|---|---|
| **Size** | 24×24px |
| **Border** | 2px solid `$borderDefault` (unselected), 2px solid `$primary` (selected) |
| **Border radius** | `$radiusFull` |
| **Selected dot** | 12px circle, `$primary` |
| **Touch target** | 44×44px |

---

## 6. Feedback & Overlays

### 6.1 Snackbar

```
┌──────────────────────────────────────────────┐
│  ✓  Device added successfully        UNDO   │
└──────────────────────────────────────────────┘
```

| Property | Value |
|---|---|
| **Position** | Bottom, 16px above bottom nav |
| **Margin** | `$space4` (16px) horizontal |
| **Padding** | `$space4` (16px) |
| **Background** | `$blue900` (#0A1628) |
| **Border radius** | `$radiusMedium` (12px) |
| **Shadow** | `$shadowLarge` |
| **Text** | `$bodyMedium` (14px/400), `$textOnDark` (#FFFFFF) |
| **Action** | `$labelMedium` (14px/500), `$blue200` (#8CD1FB) |
| **Icon** | 20px, `$blue200` |
| **Duration** | 4 seconds, then slide down |
| **Enter animation** | Slide up + fade in, `$durationSlow` |

### 6.2 Dialog

```
┌──────────────────────────────────────┐
│                                      │
│         Delete Device?               │
│                                      │
│  This action cannot be undone.       │
│  The device will be removed from     │
│  all rooms and scenes.               │
│                                      │
│     [ Cancel ]   [ Delete ]          │
│                                      │
└──────────────────────────────────────┘
```

| Property | Value |
|---|---|
| **Width** | min(340px, screen width - 48px) |
| **Padding** | `$space6` (24px) |
| **Background** | `$surfaceElevated` (#FFFFFF) |
| **Border radius** | `$radiusXL` (24px) |
| **Shadow** | `$shadowXL` |
| **Scrim** | `$surfaceOverlay` rgba(10,22,40,0.4) |
| **Title** | `$titleLarge` (18px/600), `$textPrimary`, center-aligned |
| **Body** | `$bodyMedium` (14px/400), `$textSecondary`, center-aligned |
| **Title-body gap** | `$space3` (12px) |
| **Body-buttons gap** | `$space6` (24px) |
| **Button layout** | Row, 2 buttons, `$space3` (12px) gap, equal width |
| **Primary action** | Primary or Destructive button (compact) |
| **Cancel** | Ghost button |
| **Enter animation** | Scale from 0.9 → 1.0 + fade in, `$durationSlow`, `$curveDecelerate` |

### 6.3 Bottom Sheet

```
┌──────────────────────────────────────────────┐
│              ━━━━                             │  ← drag handle
│                                              │
│  Sheet Title                                 │
│                                              │
│  [Content]                                   │
│                                              │
│                                              │
└──────────────────────────────────────────────┘
```

| Property | Value |
|---|---|
| **Background** | `$surfaceElevated` (#FFFFFF) |
| **Border radius** | `$radiusXL` (24px) top-left and top-right only |
| **Shadow** | `$shadowLarge` |
| **Drag handle** | 36×4px, `$neutral300`, centered, `$space3` (12px) from top |
| **Padding** | `$space5` (20px) horizontal, `$space4` (16px) vertical |
| **Title** | `$titleLarge` (18px/600), `$textPrimary`, `$space4` below handle |
| **Max height** | 90% of screen |
| **Scrim** | `$surfaceOverlay` |
| **Enter animation** | Slide up, `$durationSlow`, `$curveDecelerate` |

### 6.4 Toast (Lightweight)

| Property | Value |
|---|---|
| **Position** | Top center, 8px below safe area |
| **Padding** | 12px horizontal, 8px vertical |
| **Background** | `$blue900` (#0A1628) at 90% opacity |
| **Border radius** | `$radiusFull` |
| **Text** | `$bodySmall` (12px/400), `$textOnDark` |
| **Duration** | 2 seconds |

---

## 7. Chips & Badges

### 7.1 Filter Chip (Room Tabs)

See §4.3 Room Tabs above.

### 7.2 Status Badge

```
 ● Online
```

| Property | Value |
|---|---|
| **Dot size** | 8px |
| **Dot color** | `$success` (online), `$error` (offline), `$warning` (updating) |
| **Text** | `$bodySmall` (12px/400), same color as dot |
| **Gap** | `$space1` (4px) between dot and text |

### 7.3 Count Badge

```
  ┌───┐
  │ 3 │
  └───┘
```

| Property | Value |
|---|---|
| **Min size** | 20×20px |
| **Padding** | 4px horizontal |
| **Background** | `$primary` (#0883FD) |
| **Border radius** | `$radiusFull` |
| **Text** | `$labelSmall` (12px/500), `$textOnPrimary` |

### 7.4 Device Type Chip

```
  ┌──────────────┐
  │  ⚡ Switch    │
  └──────────────┘
```

| Property | Value |
|---|---|
| **Height** | 32px |
| **Padding** | 12px horizontal |
| **Background** | `$surfacePrimarySubtle` (#F0F7FF) |
| **Border radius** | `$radiusSmall` (8px) |
| **Icon** | 16px, `$primary` |
| **Text** | `$labelSmall` (12px/500), `$primary` |
| **Gap** | `$space1` (4px) |

---

## 8. Lists

### 8.1 Simple List Item

| Property | Value |
|---|---|
| **Height** | 56px |
| **Padding** | `$space4` (16px) horizontal |
| **Leading** | Icon 24px or Avatar 40px |
| **Title** | `$bodyLarge` (16px/400), `$textPrimary` |
| **Subtitle** | `$bodySmall` (12px/400), `$textSecondary` |
| **Trailing** | Icon, toggle, or text |
| **Divider** | 1px `$borderSubtle`, inset matches leading width |
| **Pressed bg** | `$surfaceCardHover` |

### 8.2 WiFi Profile Item

```
┌──────────────────────────────────────────────┐
│  📶  HomeNetwork_5G                    ⋮     │
│      WPA2 · 3 devices                        │
└──────────────────────────────────────────────┘
```

| Property | Value |
|---|---|
| **Height** | 72px |
| **Leading icon** | 24px wifi icon, `$iconDefault` |
| **Title** | `$titleMedium` (16px/600), `$textPrimary` |
| **Subtitle** | `$bodySmall` (12px/400), `$textSecondary` |
| **Trailing** | 24px dots-three-vertical, `$iconDefault` |
| **Container** | Inside Settings Item Group card |

---

## 9. Empty States

```
┌──────────────────────────────────────────────┐
│                                              │
│                                              │
│              ┌────────┐                      │
│              │  📦   │                      │
│              └────────┘                      │
│                                              │
│         No devices yet                       │
│                                              │
│   Add your first smart device to             │
│   get started with your smart home.          │
│                                              │
│       [ + Add Device ]                       │
│                                              │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Style |
|---|---|
| **Illustration area** | 80×80px, centered |
| **Icon** | 48px, `$neutral300` (#D1D7E0) |
| **Icon bg** | 80×80px circle, `$neutral100` (#F0F2F5) |
| **Title** | `$titleLarge` (18px/600), `$textPrimary`, center, `$space4` below icon |
| **Description** | `$bodyMedium` (14px/400), `$textSecondary`, center, max 260px width, `$space2` below title |
| **CTA** | Primary button (gradient), `$space6` (24px) below description |
| **Vertical position** | Centered in available space (between app bar and bottom nav) |

---

## 10. Loading States

### 10.1 Skeleton Screen

Shimmer animation over placeholder shapes.

| Property | Value |
|---|---|
| **Base color** | `$neutral100` (#F0F2F5) |
| **Shimmer color** | `$neutral200` (#E8ECF1) |
| **Animation** | Linear gradient sweep, left→right, `$durationSkeleton` (1500ms), infinite |
| **Shape radius** | Match the element being replaced |

**Device Card Skeleton:**
```
┌──────────────────────────┐
│  ██  ████████            │  ← icon + name placeholder
│                          │
│  ████                    │  ← state placeholder
│                          │
│                  ████    │  ← toggle placeholder
└──────────────────────────┘
```

- Icon placeholder: 32×32px rounded rect
- Name placeholder: 100×14px rounded rect
- State placeholder: 40×12px rounded rect
- Toggle placeholder: 52×28px rounded rect

### 10.2 Inline Spinner

| Property | Value |
|---|---|
| **Size** | 20px (small), 32px (medium), 48px (large) |
| **Color** | `$primary` (on light bg), `$neutral0` (on primary bg) |
| **Stroke width** | 2px (small), 3px (medium/large) |
| **Animation** | Continuous rotation, 800ms per cycle |

### 10.3 Full-Screen Loader

| Property | Value |
|---|---|
| **Background** | `$surfaceBackground` |
| **Spinner** | 48px, `$primary` |
| **Text** | `$bodyMedium`, `$textSecondary`, "Loading…" or contextual message |
| **Position** | Centered in screen |

---

## 11. Add Device Wizard

A 4-step wizard flow in a full-screen modal or pushed screen.

### 11.1 Step Indicator

```
  ●────●────○────○
  1    2    3    4
```

| Property | Value |
|---|---|
| **Container height** | 48px |
| **Dot size (complete)** | 10px, `$primary` fill |
| **Dot size (current)** | 12px, `$primary` fill + `$shadowGlow` |
| **Dot size (future)** | 10px, `$neutral300` fill |
| **Line height** | 2px |
| **Line complete** | `$primary` |
| **Line incomplete** | `$neutral300` |
| **Step label** | `$bodySmall` (12px/400), `$textSecondary` (future) or `$primary` (current/complete) |
| **Line gap** | 0px (dots sit on line) |

### 11.2 Wizard Page Layout

```
┌──────────────────────────────────────────────┐
│  ←                          Step 2 of 4      │
│                                              │
│  ●────●────○────○                            │
│                                              │
│  Select WiFi Profile                         │
│  Choose the network for your device          │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  📶 HomeNetwork_5G              ✓   │    │
│  ├──────────────────────────────────────┤    │
│  │  📶 HomeNetwork_2.4G               │    │
│  ├──────────────────────────────────────┤    │
│  │  + Add WiFi Profile                 │    │
│  └──────────────────────────────────────┘    │
│                                              │
│                                              │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │          Continue                    │    │
│  └──────────────────────────────────────┘    │
└──────────────────────────────────────────────┘
```

| Element | Style |
|---|---|
| **App bar** | Back arrow + "Step X of Y" right-aligned, `$bodyMedium`, `$textSecondary` |
| **Step indicator** | See §11.1, `$space6` (24px) below app bar |
| **Title** | `$headlineMedium` (22px/600), `$textPrimary`, `$space6` below indicator |
| **Subtitle** | `$bodyMedium` (14px/400), `$textSecondary`, `$space2` below title |
| **Content** | `$space6` below subtitle |
| **Bottom CTA** | Primary gradient button, full width, `$space5` (20px) padding, pinned to bottom with `$space4` above safe area |

---

## 12. Device Control Layouts

### 12.1 Switch Control

```
┌──────────────────────────────────────────────┐
│  ←  Living Room Light              ⚙️ ⋮     │
│                                              │
│                                              │
│              ┌─────────────┐                 │
│              │             │                 │
│              │    💡 ON    │                 │
│              │             │                 │
│              └─────────────┘                 │
│                                              │
│         [═══════════════●═════]              │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  Power consumption    12.4W         │    │
│  ├──────────────────────────────────────┤    │
│  │  Today's usage        0.8 kWh       │    │
│  ├──────────────────────────────────────┤    │
│  │  Signal strength      -45 dBm       │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Style |
|---|---|
| **Central toggle area** | 160×160px centered card, `$radiusXL`, `$surfaceCard` bg |
| **Device icon** | 48px, `$primary` (on) or `$neutral400` (off) |
| **State text** | `$titleLarge` (18px/600), `$primary` (ON) or `$textSecondary` (OFF) |
| **Toggle** | Below central area, `$space6` gap |
| **Stats section** | Settings item group (§2.3), `$space6` below toggle |

### 12.2 Light Control (with brightness/color)

Same as Switch Control, plus:

| Element | Style |
|---|---|
| **Brightness slider** | Full width, see §5.2, label "Brightness" above |
| **Color temp slider** | Full width, warm→cool gradient track (#FFB347→#87CEEB) |
| **Slider labels** | `$labelMedium`, `$textSecondary`, "Brightness" / "Color Temperature" |
| **Slider value** | `$labelMedium`, `$textPrimary`, right-aligned, "75%" |

### 12.3 Sensor Display

```
┌──────────────────────────────────────────────┐
│  ←  Bedroom Sensor                    ⋮     │
│                                              │
│     ┌─────────┐   ┌─────────┐              │
│     │  23.5°C │   │  65%   │              │
│     │  Temp   │   │  Humid │              │
│     └─────────┘   └─────────┘              │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  Temperature (24h)                   │    │
│  │  ▁▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▄▅▆             │    │
│  │  20°C              26°C              │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  Battery              85%  ████░    │    │
│  ├──────────────────────────────────────┤    │
│  │  Last update          2 min ago      │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Style |
|---|---|
| **Stat cards** | 2-column grid, Stat Card component (§2.4) |
| **Chart card** | Full width, `$surfaceCard`, `$radiusLarge`, 180px height |
| **Chart** | Line chart, `$primary` stroke 2px, fill below with `$primary` at 10% opacity |
| **Axis labels** | `$bodySmall`, `$textTertiary` |

### 12.4 Shutter Control

```
┌──────────────────────────────────────────────┐
│  ←  Kitchen Shutter                   ⋮     │
│                                              │
│              ╭─────────╮                     │
│             │          │                     │
│             │   75%    │  ← circular progress│
│             │   Open   │                     │
│              ╰─────────╯                     │
│                                              │
│    ┌──┐     ┌──────┐      ┌──┐              │
│    │ ▲│     │ Stop │      │ ▼│              │
│    └──┘     └──────┘      └──┘              │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  Preset Positions                    │    │
│  │  [ 25% ] [ 50% ] [ 75% ] [ 100% ]   │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Style |
|---|---|
| **Circular progress** | See §5.3, 140×140px centered |
| **Up/Down buttons** | 56×56px, `$surfaceCard`, `$borderDefault` border, `$radiusMedium`, icon 24px `$iconDefault` |
| **Stop button** | 56×56px, `$surfaceCard`, `$borderDefault` border, `$radiusMedium`, icon 24px `$error` |
| **Button row gap** | `$space7` (32px) between buttons |
| **Preset chips** | Row of Small Buttons (§1.6), secondary style, `$space2` gap |

---

## 13. Avatar Picker

```
┌──────────────────────────────────────────────┐
│  Choose your avatar                          │
│                                              │
│  😀  🐱  🏠  🌟  🎮  🎵  🌈  🚀          │
│  🌺  🎨  🍕  ⚡  🔥  💧  🌙  ☀️          │
│  🎯  🎪  🎭  🎼  🎲  🎸  🎹  🎺          │
│                                              │
└──────────────────────────────────────────────┘
```

| Property | Value |
|---|---|
| **Grid** | 8 columns, `$space3` (12px) gap |
| **Item size** | 44×44px touch target |
| **Emoji size** | 28px |
| **Selected state** | `$surfacePrimarySubtle` bg circle (40px), 2px `$primary` border |
| **Container** | Bottom sheet |

---

## 14. Form Validation States

### Inline Error

```
  Email
  ┌────────────────────────────────────────┐
  │  not-an-email                          │
  └────────────────────────────────────────┘
  ⚠ Please enter a valid email address
```

| Element | Style |
|---|---|
| **Error border** | 1.5px `$error` (#EF4444) |
| **Error icon** | 16px warning-circle, `$error` |
| **Error text** | `$bodySmall` (12px/400), `$textError` |
| **Gap** | `$space1` (4px) below input |

### Success

| Element | Style |
|---|---|
| **Success border** | 1.5px `$success` |
| **Success icon** | 16px check-circle, `$success` |

---

## 15. Platform Adaptations

### iOS Specific
- Use `CupertinoSwitch` appearance for toggles (or custom matching §5.1)
- Edge swipe for back navigation
- Large title app bar option for top-level screens

### Android Specific
- Material ripple effects on interactive elements
- System back button support
- Edge-to-edge with `SystemUiOverlayStyle`

### iPad
- Max content width: 500px centered
- Wrapper: `ConstrainedBox(maxWidth: 500)` with `$surfaceBackground` fill on sides
- Bottom nav: same 500px constraint
- Dialogs: same max width
