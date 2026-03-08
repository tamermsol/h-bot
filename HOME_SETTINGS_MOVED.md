# Home Settings Moved to Filter Options

## What Changed

Moved the home settings (gear icon) functionality into the "View & Filter Options" menu for a cleaner UI.

### Before
```
[Home Selector] [⚙️ Settings] [+ Add] [WiFi Status]
```

### After
```
[Home Selector] [+ Add] [WiFi Status]
```

The settings icon is removed, and its functionality is now in the filter menu.

## Changes Made

### 1. Removed Gear Icon
- Removed the settings IconButton from the top bar
- Cleaner, less cluttered header

### 2. Added to Filter Options Menu
- "Dashboard Background" option now appears at the top of the filter menu
- Only shows when a home is selected
- Has an icon, title, subtitle, and chevron indicator
- Tapping it opens the background image picker

### 3. Removed Unused Code
- Removed `_showHomeSettings()` method (no longer needed)
- Background dialog method remains unchanged

## How to Use

### Access Dashboard Background

1. Tap the filter icon (☰) in the search bar
2. See "Dashboard Background" at the top of the menu
3. Tap it to open the background picker
4. Select from 5 default backgrounds
5. Background applies to the home dashboard

## UI Layout

### Filter Options Menu (Updated)
```
┌─────────────────────────────────────┐
│  View & Filter Options              │
├─────────────────────────────────────┤
│                                     │
│  🖼️  Dashboard Background          │
│     Set background image         →  │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  📋  View Mode                      │
│     List View                    ⚪ │
│                                     │
│  👁️  Hide Offline Devices          │
│                                  ⚪ │
│                                     │
├─────────────────────────────────────┤
│  Sort By                            │
│                                     │
│  🔤  Name (A-Z)                  ✓  │
│  🕐  Recently Added                 │
│  🏠  Room                            │
│  📦  Device Type                    │
│                                     │
└─────────────────────────────────────┘
```

## Benefits

1. **Cleaner Header**
   - Less visual clutter
   - More space for important elements
   - Consistent with mobile design patterns

2. **Logical Grouping**
   - Background setting is a view option
   - Makes sense to group with other view settings
   - Easier to discover

3. **Better UX**
   - All view-related settings in one place
   - Fewer buttons to understand
   - More intuitive navigation

## Files Modified

- `lib/screens/home_dashboard_screen.dart`
  - Removed gear icon button
  - Removed `_showHomeSettings()` method
  - Added "Dashboard Background" to filter options menu

## Testing

1. ✅ Open app
2. ✅ Verify gear icon is gone from header
3. ✅ Tap filter icon (☰)
4. ✅ See "Dashboard Background" at top
5. ✅ Tap it
6. ✅ Background picker opens
7. ✅ Select a background
8. ✅ Background applies to dashboard

## Code Changes Summary

### Removed
```dart
// Home settings button
if (_selectedHome != null)
  Container(
    decoration: BoxDecoration(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    ),
    child: IconButton(
      icon: const Icon(Icons.settings),
      onPressed: _showHomeSettings,
    ),
  ),
```

### Added
```dart
// Dashboard Background option (only if home is selected)
if (_selectedHome != null) ...[
  ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.image_outlined,
        color: AppTheme.primaryColor,
      ),
    ),
    title: const Text('Dashboard Background'),
    subtitle: const Text('Set background image'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      Navigator.pop(context);
      _showHomeBackgroundDialog();
    },
  ),
  const Divider(),
],
```

## Result

✅ Cleaner UI
✅ Better organization
✅ Same functionality
✅ More intuitive
✅ Less clutter

The home settings functionality is now integrated into the filter options menu where it logically belongs!
