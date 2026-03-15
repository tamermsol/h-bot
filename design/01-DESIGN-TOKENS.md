# Design Tokens — H-Bot Mobile App

> Every token traces back to h-bot.tech. Every value has a reason.
> This replaces the previous token system with one derived from deep website analysis.

---

## 1. Color Palette — Primitives

These are the raw color values. **Never use primitives directly in components** — always use semantic tokens (Section 2).

### Blues (from website gradient + accent system)

| Token | Hex | RGB | Website Origin |
|---|---|---|---|
| `$blue50` | `#F0F7FF` | 240,247,255 | Lightest tint (app-only, derived) |
| `$blue100` | `#D6ECFE` | 214,236,254 | Light tint for backgrounds |
| `$blue200` | `#8CD1FB` | 140,209,251 | **Website gradient endpoint** |
| `$blue300` | `#5BBDF7` | 91,189,247 | Midpoint (derived) |
| `$blue400` | `#2FB8EC` | 47,184,236 | **Website bright blue accent** |
| `$blue500` | `#0883FD` | 8,131,253 | **Website primary blue** — CTAs, gradient start |
| `$blue600` | `#1070AD` | 16,112,173 | **Website decorative lines** |
| `$blue700` | `#094972` | 9,73,114 | **Website radial gradient center** |
| `$blue800` | `#006080` | 0,96,128 | **Website dark teal** |
| `$blue900` | `#0A1628` | 10,22,40 | Deep navy (app text color base) |
| `$blue950` | `#010510` | 1,5,16 | **Website page background** |

### Neutrals (blue-tinted — NOT pure gray)

| Token | Hex | RGB | Usage / Origin |
|---|---|---|---|
| `$neutral0` | `#FFFFFF` | 255,255,255 | Pure white |
| `$neutral50` | `#F8F9FB` | 248,249,251 | App scaffold background (blue-tinted off-white) |
| `$neutral100` | `#F0F2F5` | 240,242,245 | Secondary background |
| `$neutral200` | `#E8ECF1` | 232,236,241 | Borders, dividers (light mode) |
| `$neutral300` | `#D1D7E0` | 209,215,224 | Disabled backgrounds |
| `$neutral400` | `#A0AAB8` | 160,170,184 | Placeholder text |
| `$neutral500` | `#7A8494` | 122,132,148 | Secondary text |
| `$neutral600` | `#5A6577` | 90,101,119 | Body text |
| `$neutral700` | `#3D4A5C` | 61,74,92 | Strong text |
| `$neutral800` | `#1A202B` | 26,32,43 | **Website card bg** — dark mode surfaces |
| `$neutral900` | `#0F1520` | 15,21,32 | Dark mode body text alternative |
| `$neutral950` | `#010510` | 1,5,16 | **Website bg** — dark mode scaffold |

### Decorative Neutrals

| Token | Hex | Origin |
|---|---|---|
| `$silver` | `#CBD9DE` | Website decorative gradient endpoint |
| `$darkBorder` | `#181B1F` | Website card borders |

### Semantic Colors

| Token | Hex | Usage |
|---|---|---|
| `$success` | `#22C55E` | Device online, toggle on, success states |
| `$successLight` | `#DCFCE7` | Success background tint |
| `$warning` | `#F59E0B` | Firmware update needed, caution |
| `$warningLight` | `#FEF3C7` | Warning background tint |
| `$error` | `#EF4444` | Offline, errors, destructive actions |
| `$errorLight` | `#FEE2E2` | Error background tint |

---

## 2. Semantic Tokens — Light Mode

These are what components reference. Organized by purpose.

### Surfaces

| Token | Value | Usage |
|---|---|---|
| `$surfaceBackground` | `$neutral50` (#F8F9FB) | Scaffold/page background |
| `$surfaceCard` | `$neutral0` (#FFFFFF) | Card backgrounds |
| `$surfaceCardHover` | `$neutral100` (#F0F2F5) | Card pressed/hover state |
| `$surfaceElevated` | `$neutral0` (#FFFFFF) | Bottom sheet, dialog, elevated surfaces |
| `$surfaceOverlay` | `rgba(10,22,40,0.4)` | Scrim behind modals |
| `$surfaceInput` | `$neutral0` (#FFFFFF) | Text field background |
| `$surfaceInputFocused` | `$neutral0` (#FFFFFF) | Text field focused (border changes, not bg) |
| `$surfacePrimarySubtle` | `$blue50` (#F0F7FF) | Primary-tinted backgrounds (active tab, chip) |
| `$surfaceDestructiveSubtle` | `$errorLight` (#FEE2E2) | Delete confirmation bg |

### Borders

| Token | Value | Usage |
|---|---|---|
| `$borderDefault` | `$neutral200` (#E8ECF1) | Card borders, dividers |
| `$borderSubtle` | `$neutral100` (#F0F2F5) | Very subtle separators |
| `$borderFocused` | `$blue500` (#0883FD) | Input focus ring |
| `$borderError` | `$error` (#EF4444) | Validation error |
| `$borderSuccess` | `$success` (#22C55E) | Success border |

### Text

| Token | Value | Usage |
|---|---|---|
| `$textPrimary` | `$blue900` (#0A1628) | Headings, primary body text |
| `$textSecondary` | `$neutral600` (#5A6577) | Descriptions, captions |
| `$textTertiary` | `$neutral500` (#7A8494) | Placeholder, timestamps |
| `$textOnPrimary` | `$neutral0` (#FFFFFF) | Text on primary buttons/gradient |
| `$textOnDark` | `$neutral0` (#FFFFFF) | Text on dark surfaces |
| `$textLink` | `$blue500` (#0883FD) | Interactive text links |
| `$textError` | `$error` (#EF4444) | Error messages |
| `$textSuccess` | `$success` (#22C55E) | Success messages |

### Interactive

| Token | Value | Usage |
|---|---|---|
| `$primary` | `$blue500` (#0883FD) | Primary actions, active states |
| `$primaryHover` | `#0773E0` | Primary hover/pressed (10% darker) |
| `$primaryDisabled` | `$neutral300` (#D1D7E0) | Disabled CTA |
| `$iconDefault` | `$neutral600` (#5A6577) | Default icon color |
| `$iconActive` | `$blue500` (#0883FD) | Active/selected icon |
| `$iconOnPrimary` | `$neutral0` (#FFFFFF) | Icon on primary surface |
| `$toggleTrackOn` | `$blue500` (#0883FD) | Toggle on track |
| `$toggleTrackOff` | `$neutral300` (#D1D7E0) | Toggle off track |
| `$toggleThumb` | `$neutral0` (#FFFFFF) | Toggle thumb |

---

## 3. Semantic Tokens — Dark Mode

Dark mode mirrors the website closely.

### Surfaces

| Token | Light Value | Dark Value |
|---|---|---|
| `$surfaceBackground` | `$neutral50` | `$neutral950` (#010510) |
| `$surfaceCard` | `$neutral0` | `$neutral800` (#1A202B) |
| `$surfaceCardHover` | `$neutral100` | `#222835` |
| `$surfaceElevated` | `$neutral0` | `#1E2433` |
| `$surfaceOverlay` | `rgba(10,22,40,0.4)` | `rgba(0,0,0,0.6)` |
| `$surfaceInput` | `$neutral0` | `#141A26` |
| `$surfacePrimarySubtle` | `$blue50` | `rgba(8,131,253,0.12)` |

### Borders

| Token | Light Value | Dark Value |
|---|---|---|
| `$borderDefault` | `$neutral200` | `$darkBorder` (#181B1F) |
| `$borderSubtle` | `$neutral100` | `#111520` |
| `$borderFocused` | `$blue500` | `$blue500` |

### Text

| Token | Light Value | Dark Value |
|---|---|---|
| `$textPrimary` | `$blue900` | `$neutral0` (#FFFFFF) |
| `$textSecondary` | `$neutral600` | `rgb(199,201,204)` |
| `$textTertiary` | `$neutral500` | `rgb(180,180,180)` |

---

## 4. Gradients

The brand's signature element. Use deliberately — never on everything.

### Primary Brand Gradient

```
Name:       $gradientPrimary
Type:       LinearGradient
Direction:  left → right (0° or 90° CSS)
Stops:      #0883FD (0%) → #8CD1FB (100%)
Usage:      Primary buttons, active toggle tracks, gradient text,
            splash accents, section headers in dark mode
Flutter:    LinearGradient(colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)])
```

### Reversed Brand Gradient

```
Name:       $gradientPrimaryReversed
Direction:  right → left (270° CSS)
Stops:      #8CD1FB (0%) → #0883FD (100%)
Usage:      Alternate direction for visual variety (e.g., right-aligned CTA)
```

### Subtle Background Gradient (Dark Mode)

```
Name:       $gradientBackgroundDark
Type:       RadialGradient
Stops:      rgba(9,73,114,0.3) center → rgba(1,5,16,0.3) edge
Usage:      Dark mode section backgrounds (creates ambient glow)
```

### Subtle Background Gradient (Light Mode)

```
Name:       $gradientBackgroundLight
Type:       RadialGradient
Stops:      rgba(8,131,253,0.04) center → rgba(248,249,251,0) edge
Usage:      Light mode section backgrounds (barely visible blue tint)
```

### Decorative Line Gradient

```
Name:       $gradientDecorative
Direction:  225° (top-right → bottom-left)
Stops:      #1070AD (0%) → #CBD9DE (100%)
Usage:      Divider lines, decorative accents
```

### Inactive/Ghost Gradient

```
Name:       $gradientInactive
Direction:  90°
Stops:      #1A202B (0%) → #1A202B (100%) [dark mode]
            #E8ECF1 (0%) → #E8ECF1 (100%) [light mode — effectively flat]
Usage:      Inactive tab/button background in gradient button groups
```

### Gradient Text (Flutter Implementation)

```dart
// Apply gradient to text (website signature effect)
ShaderMask(
  shaderCallback: (bounds) => const LinearGradient(
    colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
  ).createShader(bounds),
  child: Text('Smart Home', style: TextStyle(color: Colors.white)),
)
```

---

## 5. Typography

**Font Family:** Inter (app uses Inter, not Readex Pro from website — per design brief)

**Fallback:** system sans-serif

### Type Scale

| Token | Size | Weight | Line Height | Letter Spacing | Usage |
|---|---|---|---|---|---|
| `$displayLarge` | 32px | 700 | 40px (1.25) | -0.5px | Splash screen title |
| `$displayMedium` | 28px | 700 | 36px (1.29) | -0.5px | Screen titles (rare) |
| `$headlineLarge` | 24px | 700 | 32px (1.33) | -0.3px | Section headers |
| `$headlineMedium` | 22px | 600 | 28px (1.27) | -0.3px | Screen titles |
| `$headlineSmall` | 20px | 600 | 26px (1.30) | -0.2px | Sub-section headers |
| `$titleLarge` | 18px | 600 | 24px (1.33) | -0.1px | Card titles, dialog titles |
| `$titleMedium` | 16px | 600 | 22px (1.38) | 0px | List item titles |
| `$titleSmall` | 14px | 600 | 20px (1.43) | 0px | Chip labels, tab labels |
| `$bodyLarge` | 16px | 400 | 24px (1.50) | 0px | Primary body text |
| `$bodyMedium` | 14px | 400 | 20px (1.43) | 0px | Secondary body text |
| `$bodySmall` | 12px | 400 | 16px (1.33) | 0.1px | Captions, timestamps |
| `$labelLarge` | 16px | 500 | 22px (1.38) | 0px | Button text |
| `$labelMedium` | 14px | 500 | 20px (1.43) | 0.1px | Input labels, nav labels |
| `$labelSmall` | 12px | 500 | 16px (1.33) | 0.2px | Tags, badges, overlines |
| `$overline` | 11px | 600 | 16px (1.45) | 1.0px | Section overlines (UPPERCASE) |

### Gradient Text Tokens

| Token | Size | Weight | Gradient | Usage |
|---|---|---|---|---|
| `$gradientDisplayLarge` | 32px | 700 | `$gradientPrimary` | Hero accent on splash |
| `$gradientHeadlineLarge` | 24px | 700 | `$gradientPrimary` | Accent in section headers |
| `$gradientTitleLarge` | 18px | 600 | `$gradientPrimary` | Feature highlight text |

---

## 6. Spacing

Based on 4px base unit. The website uses generous spacing — the app should feel airy, not cramped.

| Token | Value | Usage |
|---|---|---|
| `$space0` | 0px | No space |
| `$space1` | 4px | Icon-to-text gap, badge inset |
| `$space2` | 8px | Tight internal padding |
| `$space3` | 12px | Standard internal padding, list item gap |
| `$space4` | 16px | Card internal padding, section gap |
| `$space5` | 20px | Screen horizontal padding |
| `$space6` | 24px | Section vertical padding |
| `$space7` | 32px | Large section gap |
| `$space8` | 40px | Major section separation |
| `$space9` | 48px | Screen top/bottom breathing room |
| `$space10` | 64px | Splash screen spacing |

### Screen Padding
- **Horizontal:** `$space5` (20px) on phone, `$space6` (24px) on tablet
- **Safe Area:** Always respect platform safe area insets
- **iPad max-width:** 500px centered container

---

## 7. Border Radius

Derived from website patterns (cards use ~24px, buttons ~8-12px).

| Token | Value | Usage |
|---|---|---|
| `$radiusNone` | 0px | No rounding |
| `$radiusSmall` | 8px | Chips, tags, small badges |
| `$radiusMedium` | 12px | Buttons, inputs, toggles |
| `$radiusLarge` | 16px | Cards, bottom sheets |
| `$radiusXL` | 24px | Large cards, hero sections, dialogs |
| `$radiusFull` | 9999px | Circular: avatar, FAB, pill buttons |

---

## 8. Elevation & Shadows

The website avoids traditional drop shadows. The app uses shadows sparingly.

### Light Mode Shadows

| Token | Value | Usage |
|---|---|---|
| `$shadowNone` | none | Default for most cards (use border instead) |
| `$shadowSmall` | `0 1px 3px rgba(10,22,40,0.06), 0 1px 2px rgba(10,22,40,0.04)` | Subtle lift: pressed states |
| `$shadowMedium` | `0 4px 12px rgba(10,22,40,0.08)` | Cards with elevation, FAB |
| `$shadowLarge` | `0 8px 24px rgba(10,22,40,0.12)` | Bottom sheet, dialog |
| `$shadowXL` | `0 12px 40px rgba(10,22,40,0.16)` | Tooltip, dropdown |
| `$shadowInset` | `inset 0 0 6px rgba(10,22,40,0.08)` | Recessed inputs (optional) |
| `$shadowGlow` | `0 0 20px rgba(8,131,253,0.15)` | Focus glow on primary elements |

### Dark Mode Shadows

| Token | Light Shadow | Dark Shadow |
|---|---|---|
| `$shadowSmall` | above | `0 1px 3px rgba(0,0,0,0.2)` |
| `$shadowMedium` | above | `0 4px 12px rgba(0,0,0,0.3)` |
| `$shadowLarge` | above | `0 8px 24px rgba(0,0,0,0.4)` |
| `$shadowGlow` | above | `0 0 20px rgba(8,131,253,0.25)` |

---

## 9. Motion / Animation

All values derived from the website's smooth, controlled animations.

| Token | Value | Usage |
|---|---|---|
| `$durationFast` | 150ms | Ripple, color change, icon swap |
| `$durationMedium` | 250ms | Toggle, card press, tab switch |
| `$durationSlow` | 400ms | Page transition, sheet open/close |
| `$durationSkeleton` | 1500ms | Skeleton shimmer cycle |
| `$curveStandard` | `Curves.easeInOut` | General transitions |
| `$curveDecelerate` | `Curves.easeOut` | Enter animations |
| `$curveAccelerate` | `Curves.easeIn` | Exit animations |
| `$curveSharp` | `Curves.easeInOutCubic` | Tab switching, quick snaps |

### Motion Principles
1. **No bouncing.** No `Curves.bounceOut`, no `Curves.elasticOut`.
2. **Pressed states:** scale to `0.97` with `$durationFast`
3. **Page transitions:** `SlideTransition` + `FadeTransition` with `$durationSlow`
4. **Shimmer:** Linear gradient sweep with `$durationSkeleton`, using `$neutral100 → $neutral200 → $neutral100`
5. **Device toggle:** gradient fill wipe from left with `$durationMedium`

---

## 10. Iconography

| Property | Value |
|---|---|
| **Icon set** | Phosphor Icons (line/regular weight) |
| **Stroke weight** | 1.5px (regular) |
| **Standard size** | 24×24px |
| **Small size** | 20×20px |
| **Large size** | 32×32px |
| **XL size** | 48×48px (empty states) |
| **Nav icon size** | 24×24px |
| **Touch target** | Always ≥44×44px (even if icon is smaller) |
| **Default color** | `$iconDefault` |
| **Active color** | `$iconActive` ($primary) |

### Device Type Icons (Custom or Phosphor)

| Device | Icon | Phosphor equivalent |
|---|---|---|
| Switch | `toggle-right` | `PhosphorIcons.toggleRight` |
| Light | `lightbulb` | `PhosphorIcons.lightbulb` |
| Sensor | `thermometer` | `PhosphorIcons.thermometer` |
| Shutter | `blinds` | `PhosphorIcons.blinds` (or custom) |
| Power meter | `lightning` | `PhosphorIcons.lightning` |

---

## 11. Breakpoints & Layout

| Breakpoint | Width | Behavior |
|---|---|---|
| Phone | < 600px | Standard mobile layout |
| Tablet | ≥ 600px | Centered container, max-width 500px |

### Grid System

| Context | Columns | Gap | Margin |
|---|---|---|---|
| Device grid (phone) | 2 | 12px | 20px horizontal |
| Device grid (tablet) | 2 | 16px | centered 500px |
| Scene list | 1 | 12px | 20px horizontal |
| Settings list | 1 | 0px (dividers) | 20px horizontal |

---

## 12. Z-Index Layers

| Token | Value | Usage |
|---|---|---|
| `$zBase` | 0 | Default content |
| `$zCard` | 1 | Elevated cards |
| `$zAppBar` | 10 | App bar |
| `$zBottomNav` | 10 | Bottom navigation |
| `$zFAB` | 15 | Floating action button |
| `$zSheet` | 20 | Bottom sheet |
| `$zDialog` | 30 | Dialog |
| `$zSnackbar` | 40 | Snackbar (above dialog) |
| `$zOverlay` | 50 | Scrim/overlay |

---

## 13. Token Quick Reference Card

```
Background:     #F8F9FB (light)  #010510 (dark)
Card:           #FFFFFF (light)  #1A202B (dark)
Border:         #E8ECF1 (light)  #181B1F (dark)
Text Primary:   #0A1628 (light)  #FFFFFF (dark)
Text Secondary: #5A6577 (light)  #C7C9CC (dark)
Primary:        #0883FD (both modes)
Primary Light:  #8CD1FB (both modes)
Gradient:       #0883FD → #8CD1FB (both modes)
Success:        #22C55E
Warning:        #F59E0B
Error:          #EF4444
Font:           Inter
Radius:         8/12/16/24px
Spacing:        4px base (4/8/12/16/20/24/32/40/48/64)
```
