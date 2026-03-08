# Complete Light Mode Background Fix - All Screens

## Issue
Multiple screens and dialogs had hardcoded dark backgrounds (`AppTheme.backgroundColor` and `AppTheme.cardColor`) that didn't adapt to Light Mode, causing black/dark backgrounds even when Light Mode was active.

## Solution Applied
Made all screens, modal bottom sheets, and dialogs theme-aware by:
1. Detecting theme brightness: `final isDark = Theme.of(context).brightness == Brightness.dark;`
2. Using conditional backgrounds:
   - Scaffolds: `isDark ? AppTheme.backgroundColor : AppTheme.lightBackgroundColor`
   - AppBars: Same as scaffolds
   - Dialogs/Modals: `AppTheme.getCardColor(context)` (theme-aware helper)

## Files Modified

### Main Screens (Scaffold + AppBar)
1. `lib/screens/home_dashboard_screen.dart` - Home dashboard
2. `lib/screens/device_control_screen.dart` - Device control page
3. `lib/screens/add_scene_screen.dart` - Scene create/edit
4. `lib/screens/homes_screen.dart` - Homes list
5. `lib/screens/rooms_screen.dart` - Rooms list
6. `lib/screens/devices_screen.dart` - Devices list
7. `lib/screens/device_timers_screen.dart` - Device timers
8. `lib/screens/add_timer_screen.dart` - Add/edit timer
9. `lib/screens/add_device_flow_screen.dart` - Device pairing flow (2 scaffolds)
10. `lib/screens/wifi_profile_screen.dart` - WiFi profile
11. `lib/screens/profile_edit_screen.dart` - Edit profile
12. `lib/screens/hbot_account_screen.dart` - HBOT account
13. `lib/screens/notifications_settings_screen.dart` - Notifications
14. `lib/screens/appearance_settings_screen.dart` - Appearance settings
15. `lib/screens/feedback_screen.dart` - Feedback
16. `lib/screens/help_center_screen.dart` - Help center
17. `lib/screens/shutter_calibration_screen.dart` - Shutter calibration
18. `lib/screens/shutter_manual_calibration_screen.dart` - Manual calibration

### Modal Bottom Sheets
1. `lib/screens/home_dashboard_screen.dart`:
   - Options menu (Sort By, View Mode, Hide Offline)
   - Home selector
   - Add menu

### AlertDialogs (25+ dialogs fixed)
1. `lib/screens/home_dashboard_screen.dart`:
   - Dashboard background picker
   - Add device dialog
   - Select home for device
   - Create home first
   - MQTT debug info

2. `lib/screens/device_control_screen.dart`:
   - Device options menu
   - Rename device
   - Move to room
   - Delete device confirmation
   - Rename channel
   - Channel options
   - Loading dialog

3. `lib/screens/homes_screen.dart`:
   - Create new home
   - Edit home
   - Delete home

4. `lib/screens/rooms_screen.dart`:
   - Create new room
   - Edit room
   - Delete room
   - Room background picker

5. `lib/screens/devices_screen.dart`:
   - Add device
   - Delete device confirmation
   - Loading dialog

6. `lib/screens/device_timers_screen.dart`:
   - Delete timer confirmation
   - Timer sync dialogs

7. `lib/screens/profile_screen.dart`:
   - Change password
   - Sign out confirmation

8. `lib/screens/hbot_account_screen.dart`:
   - Email address
   - Delete account warning
   - Final confirmation

9. `lib/screens/add_timer_screen.dart`:
   - ExpansionTile backgrounds

### Widgets
1. `lib/widgets/avatar_picker_dialog.dart` - Avatar picker dialog

## Visual Result

### Light Mode:
- All screens: Pure white background (`#FFFFFF`)
- All AppBars: White background with dark text
- All dialogs/modals: Light grey cards (`#F5F7FA`) with borders
- All text: Dark colors for readability

### Dark Mode:
- All screens: Dark background (`#121212`)
- All AppBars: Dark surface (`#1E1E1E`)
- All dialogs/modals: Dark cards (`#2C2C2C`)
- All text: Light colors (unchanged)

## Testing Checklist
- [x] Home dashboard options menu - white in Light Mode
- [x] Device control screen - white background
- [x] Scene create/edit - white background
- [x] All dialogs - light grey cards in Light Mode
- [x] All modal bottom sheets - light grey in Light Mode
- [x] Dark Mode unchanged and working
- [x] No diagnostic errors

## Pattern Used
```dart
@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  return Scaffold(
    backgroundColor: isDark ? AppTheme.backgroundColor : AppTheme.lightBackgroundColor,
    appBar: AppBar(
      backgroundColor: isDark ? AppTheme.backgroundColor : AppTheme.lightBackgroundColor,
      // ...
    ),
    // ...
  );
}

// For dialogs/modals:
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    backgroundColor: AppTheme.getCardColor(context), // Theme-aware helper
    // ...
  ),
);
```

## Notes
- Used `AppTheme.getCardColor(context)` helper method for consistency
- All changes are theme-aware and automatically switch with system theme
- No hardcoded colors remain in any screen or dialog
- Maintains existing functionality while fixing visual issues
