# Device Icon Contrast Fix - Light Mode

## Issue
Device icons in Light Mode were hard to see when devices were offline or closed:
- Grey icons (`#374151`) on grey card backgrounds (`#F5F7FA`) had poor contrast
- Shutter control buttons used hardcoded dark theme colors
- Icon background was too subtle in Light Mode

## Solution Applied

### 1. Device Icon Color (Grid View)
**Changed from:**
```dart
color: isDark ? AppTheme.textHint : iconDefault  // #374151 - too similar to card
```

**Changed to:**
```dart
color: isDark ? AppTheme.textHint : AppTheme.lightTextSecondary  // #4B5563 - better contrast
```

### 2. Icon Background (Grid View)
**Changed from:**
```dart
color: AppTheme.lightIconInactive.withValues(alpha: 0.15)  // Very subtle grey
```

**Changed to:**
```dart
color: Colors.white  // Pure white for clear separation from card
```

### 3. Shutter Control Buttons (Both Views)
**Changed from:**
```dart
color: canControl ? AppTheme.textPrimary : AppTheme.textHint  // Hardcoded
```

**Changed to:**
```dart
final textPrimary = AppTheme.getTextPrimary(context);
final textHint = AppTheme.getTextHint(context);
color: canControl ? textPrimary : textHint  // Theme-aware
```

## Visual Result

### Light Mode - Offline/Closed Devices:
- Icon: `#4B5563` (darker grey) on white background
- Card: `#F5F7FA` (light grey)
- Clear visual separation and readability

### Light Mode - Online/On Devices:
- Icon: `#2196F3` (blue) on light blue background
- Card: `#F5F7FA` (light grey)
- Maintains existing active state appearance

### Dark Mode:
- No changes - continues to use existing dark theme colors
- Icon: `#666666` on dark background when offline
- Icon: `#2196F3` on blue background when online

## Files Modified
- `lib/screens/home_dashboard_screen.dart`
  - `_buildGridCardContent()` - Device icon color and background
  - `_buildShutterControls()` - Button colors made theme-aware

## Testing Checklist
- [x] Offline relay devices visible in Light Mode
- [x] Closed shutter devices visible in Light Mode
- [x] Online/On devices still show blue correctly
- [x] Shutter buttons readable in both themes
- [x] Dark Mode unchanged
- [x] No diagnostic errors
