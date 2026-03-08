# Scene Creation & Profile Containers Fixed - Light Mode

## Issues Found (from images)
1. **Scene Creation Screen**: Black/dark containers for trigger options, time picker, repeat options
2. **Profile/HBOT Account Screen**: Black/dark containers for email and delete account sections
3. **Help Center Screen**: Black/dark container for contact options
4. **White text on white backgrounds**: Trigger titles and descriptions not visible

## Solution Applied

### 1. Scene Creation Screen (`lib/screens/add_scene_screen.dart`)
Fixed all container backgrounds and text colors:

**Containers Fixed:**
- Preview card container
- Icon selection container
- All trigger option containers (Manual, Time Based, Location Based, Sensor Triggered)
- Time picker container
- Repeat options container
- Custom days selector container
- Location configuration containers
- Device selection containers
- Summary containers
- Step indicator containers

**Changes:**
- `color: AppTheme.cardColor` → `color: AppTheme.getCardColor(context)`
- `color: AppTheme.surfaceColor` → `color: AppTheme.getSurfaceColor(context)`

**Text Colors Fixed:**
- Trigger titles: Now use `AppTheme.getTextPrimary(context)` (when selected) or `AppTheme.getTextSecondary(context)` (when not selected)
- Trigger descriptions: Now use `AppTheme.getTextHint(context)`
- Trigger icons: Now use `AppTheme.getTextSecondary(context)` (when not selected)
- Tile backgrounds: Now use `AppTheme.getCardColor(context)` (when not selected)

### 2. HBOT Account Screen (`lib/screens/hbot_account_screen.dart`)
Fixed container backgrounds:

**Containers Fixed:**
- Email address section container
- Delete account section container

**Changes:**
- `color: AppTheme.cardColor` → `color: AppTheme.getCardColor(context)`

### 3. Help Center Screen (`lib/screens/help_center_screen.dart`)
Fixed container background:

**Container Fixed:**
- Contact options container (Website, Email, Phone, WhatsApp)

**Changes:**
- `color: AppTheme.cardColor` → `color: AppTheme.getCardColor(context)`

## Color Mapping

### Light Mode:
- Container backgrounds: `#F5F7FA` (light grey) with `#E5E7EB` borders
- Text primary: `#1F2937` (dark grey)
- Text secondary: `#4B5563` (medium grey)
- Text hint: `#6B7280` (light grey)

### Dark Mode:
- Container backgrounds: `#2C2C2C` (dark grey)
- Text primary: `#FFFFFF` (white)
- Text secondary: `#B3B3B3` (light grey)
- Text hint: `#666666` (medium grey)

## Visual Result

### Before (Light Mode):
- Scene trigger options: Black containers with white text (invisible)
- HBOT account sections: Black containers
- Help center: Black container
- Trigger titles: White text on white background (invisible)

### After (Light Mode):
- Scene trigger options: Light grey containers with dark text (clearly visible)
- HBOT account sections: Light grey containers
- Help center: Light grey container
- Trigger titles: Dark text on light grey (clearly visible)
- Selected items: Light blue background with blue text

### Dark Mode:
- All containers remain dark grey (unchanged)
- All text remains white/light grey (unchanged)

## Files Modified
1. `lib/screens/add_scene_screen.dart` - 15+ container fixes + text color fixes
2. `lib/screens/hbot_account_screen.dart` - 2 container fixes
3. `lib/screens/help_center_screen.dart` - 1 container fix

## Testing Checklist
- [x] Scene trigger options visible in Light Mode
- [x] Time picker container visible in Light Mode
- [x] Repeat options visible in Light Mode
- [x] Location options visible in Light Mode
- [x] HBOT account sections visible in Light Mode
- [x] Help center container visible in Light Mode
- [x] All text readable in Light Mode
- [x] Selected items show blue highlight
- [x] Dark Mode unchanged and working
- [x] No diagnostic errors

## Notes
- Used batch replacement for multiple identical patterns
- All containers now automatically adapt to theme
- Selected items use brand blue color for emphasis
- Borders use selected color (blue) for better visual feedback
- White checkmark icon on blue background is intentional (good contrast)
