# Scene Icon and Color Fix

## Problem
Users could select custom icons and colors when creating/editing scenes, but these selections were not being saved to the database. All scenes displayed with default icon and color in the scenes list.

## Root Cause
The `scenes` table in the database did not have columns for storing icon and color data. The Scene model also lacked these fields, so they were never persisted.

## Solution
Added icon and color fields to the database, model, and all related methods to properly save and load user selections.

## Changes Made

### 1. Database Migration
**File**: `supabase_migrations/add_icon_color_to_scenes.sql`

Added two new columns to the `scenes` table:
- `icon_code` (INTEGER): Stores Flutter IconData.codePoint
- `color_value` (BIGINT): Stores Flutter Color.value (ARGB format) - BIGINT is required because Color.value can exceed signed 32-bit integer range

**To apply this migration**:
```sql
-- Run this SQL in your Supabase SQL Editor
-- 1) icon_code can stay INTEGER
ALTER TABLE scenes
ADD COLUMN IF NOT EXISTS icon_code INTEGER;

-- 2) color_value MUST be BIGINT (Flutter Color.value can exceed int32)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name='scenes' AND column_name='color_value'
  ) THEN
    ALTER TABLE scenes ADD COLUMN color_value BIGINT;
  ELSE
    -- if it exists but is INTEGER, upgrade it
    IF (SELECT data_type
        FROM information_schema.columns
        WHERE table_name='scenes' AND column_name='color_value') = 'integer' THEN
      ALTER TABLE scenes
      ALTER COLUMN color_value TYPE BIGINT USING color_value::bigint;
    END IF;
  END IF;
END $$;

COMMENT ON COLUMN scenes.icon_code IS 'Flutter IconData codePoint (int)';
COMMENT ON COLUMN scenes.color_value IS 'Flutter Color.value (ARGB) stored as bigint';

-- Set defaults for existing scenes
UPDATE scenes
SET
  icon_code = COALESCE(icon_code, 57535),
  color_value = COALESCE(color_value, 4282339571::bigint);
```

### 2. Scene Model Update
**File**: `lib/models/scene.dart`

Added two new optional fields:
```dart
@JsonKey(name: 'icon_code')
final int? iconCode;

@JsonKey(name: 'color_value')
final int? colorValue;
```

Updated constructor and copyWith method to include these fields.

**Regenerated model**: Ran `flutter pub run build_runner build --delete-conflicting-outputs`

### 3. Repository Layer
**File**: `lib/repos/scenes_repo.dart`

Updated `createScene` method:
```dart
Future<Scene> createScene(
  String homeId,
  String name, {
  bool isEnabled = true,
  int? iconCode,
  int? colorValue,
}) async {
  // Saves icon_code and color_value to database
}
```

Updated `updateScene` method:
```dart
Future<Scene> updateScene(
  String sceneId, {
  String? name,
  bool? isEnabled,
  int? iconCode,
  int? colorValue,
}) async {
  // Updates icon_code and color_value in database
}
```

### 4. Service Layer
**File**: `lib/services/smart_home_service.dart`

Updated both `createScene` and `updateScene` methods to accept and pass through `iconCode` and `colorValue` parameters.

### 5. UI Layer
**File**: `lib/screens/add_scene_screen.dart`

**Create Mode**:
```dart
final scene = await _service.createScene(
  widget.homeId,
  _nameController.text.trim(),
  isEnabled: true,
  iconCode: _selectedIcon.codePoint,
  colorValue: _selectedColor.value,
);
```

**Edit Mode**:
```dart
await _service.updateScene(
  widget.sceneId!,
  name: _nameController.text.trim(),
  iconCode: _selectedIcon.codePoint,
  colorValue: _selectedColor.value,
);
```

**Load Existing Scene**:
```dart
// Load icon and color if available
if (scene.iconCode != null) {
  _selectedIcon = IconData(scene.iconCode!, fontFamily: 'MaterialIcons');
}
if (scene.colorValue != null) {
  _selectedColor = Color(scene.colorValue!);
}
```

## How It Works

### Creating a Scene:
1. User selects icon and color in the UI
2. When saving, `_selectedIcon.codePoint` and `_selectedColor.value` are extracted
3. These integer values are passed to `createScene` method
4. Values are stored in database columns `icon_code` and `color_value`

### Editing a Scene:
1. Scene is loaded from database with `iconCode` and `colorValue`
2. IconData and Color objects are reconstructed from the integer values
3. UI displays the saved icon and color
4. User can change them, and new values are saved via `updateScene`

### Displaying Scenes:
The scenes list should now use `scene.iconCode` and `scene.colorValue` to display the correct icon and color for each scene.

## Data Format

### Icon Code
- Type: Integer (PostgreSQL INTEGER, Dart int)
- Value: IconData.codePoint (e.g., 57535 for Icons.auto_awesome)
- Range: -2,147,483,648 to 2,147,483,647 (signed 32-bit)
- Reconstruction: `IconData(iconCode, fontFamily: 'MaterialIcons')`

### Color Value
- Type: BIGINT (PostgreSQL BIGINT, Dart int)
- Value: Color.value in ARGB format (e.g., 4282339571 for blue #2196F3)
- Range: Can exceed signed 32-bit integer range (uses unsigned 32-bit values)
- Why BIGINT: Flutter Color.value returns values like 0xFF2196F3 (4282339571) which are treated as unsigned 32-bit integers. PostgreSQL INTEGER is signed and has a max value of 2,147,483,647, so some color values would overflow. BIGINT safely stores all possible color values.
- Reconstruction: `Color(colorValue)`

### Example Color Values:
- Red (0xFFFF0000): 4294901760 (exceeds INTEGER max)
- Blue (0xFF2196F3): 4282339571 (exceeds INTEGER max)
- Green (0xFF4CAF50): 4283215696 (exceeds INTEGER max)
- White (0xFFFFFFFF): 4294967295 (exceeds INTEGER max)

## Testing Checklist

- [ ] Run database migration in Supabase SQL Editor
- [ ] Create a new scene with custom icon and color
- [ ] Verify scene appears in list with correct icon and color
- [ ] Edit the scene and change icon/color
- [ ] Verify changes are saved and displayed correctly
- [ ] Check existing scenes have default icon and color after migration
- [ ] Verify scene execution still works correctly

## Migration Steps

1. **Apply Database Migration**:
   - Open Supabase SQL Editor
   - Run the SQL from `supabase_migrations/add_icon_color_to_scenes.sql`
   - Verify columns are added: `SELECT icon_code, color_value FROM scenes LIMIT 1;`

2. **Rebuild Flutter App**:
   - The model has already been regenerated
   - Run `flutter clean` (optional)
   - Run `flutter pub get`
   - Run `flutter run` to test

3. **Verify**:
   - Create a new scene with custom icon/color
   - Check database to confirm values are saved
   - Restart app and verify scene still shows correct icon/color

## Files Modified

- `lib/models/scene.dart` - Added iconCode and colorValue fields
- `lib/models/scene.g.dart` - Auto-generated (regenerated)
- `lib/repos/scenes_repo.dart` - Updated create/update methods
- `lib/services/smart_home_service.dart` - Updated create/update methods
- `lib/screens/add_scene_screen.dart` - Save and load icon/color

## Files Created

- `supabase_migrations/add_icon_color_to_scenes.sql` - Database migration

## Next Steps

After applying the migration, you may need to update the scenes list UI to use the saved icon and color values instead of defaults. Check `lib/screens/scenes_screen.dart` or wherever scenes are displayed.
