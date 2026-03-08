# Channel Type API Reference

## Database Schema

### Table: `device_channels`

```sql
CREATE TABLE device_channels (
  device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
  channel_no INT NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  label_is_custom BOOLEAN NOT NULL DEFAULT false,
  channel_type TEXT NOT NULL DEFAULT 'switch',  -- NEW FIELD
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (device_id, channel_no),
  CONSTRAINT check_channel_type CHECK (channel_type IN ('light', 'switch'))
);
```

### RPC Functions

#### `update_channel_type()`
Updates the type of a specific channel.

```sql
update_channel_type(
  p_device_id UUID,
  p_channel_no INT,
  p_channel_type TEXT  -- 'light' or 'switch'
) RETURNS VOID
```

**Parameters:**
- `p_device_id`: UUID of the device
- `p_channel_no`: Channel number (1-8)
- `p_channel_type`: Type to set ('light' or 'switch')

**Throws:**
- `not authenticated` - User not logged in
- `invalid channel type` - Type not 'light' or 'switch'
- `device not found or access denied` - Device doesn't exist or user doesn't own it
- `channel not found` - Channel doesn't exist

**Example:**
```dart
await supabase.rpc(
  'update_channel_type',
  params: {
    'p_device_id': 'device-uuid',
    'p_channel_no': 1,
    'p_channel_type': 'light',
  },
);
```

## Dart Models

### DeviceChannel

```dart
class DeviceChannel {
  final String deviceId;
  final int channelNo;
  final String label;
  final bool labelIsCustom;
  final String channelType;  // 'light' or 'switch'
  final DateTime createdAt;
  final DateTime updatedAt;

  // Helper methods
  bool isLight();    // Returns true if channelType == 'light'
  bool isSwitch();   // Returns true if channelType == 'switch'
}
```

### DeviceWithChannels

```dart
class DeviceWithChannels {
  // ... other fields ...
  final Map<String, dynamic>? channelLabels;

  // Channel type methods
  String getChannelType(int channelNo);        // Returns 'light' or 'switch'
  bool isChannelLight(int channelNo);          // Returns true if light
  bool isChannelSwitch(int channelNo);         // Returns true if switch
  
  // Existing methods
  String getChannelLabel(int channelNo);       // Returns channel label
  bool hasCustomChannelLabel(int channelNo);   // Returns true if custom
}
```

**Channel Labels Structure:**
```json
{
  "1": {
    "label": "Living Room",
    "is_custom": true,
    "type": "light"
  },
  "2": {
    "label": "Channel 2",
    "is_custom": false,
    "type": "switch"
  }
}
```

## Repository Methods

### DeviceManagementRepo

```dart
class DeviceManagementRepo {
  /// Update channel type (light or switch)
  Future<void> updateChannelType({
    required String deviceId,
    required int channelNo,
    required String channelType,  // 'light' or 'switch'
  });
}
```

**Usage:**
```dart
final repo = DeviceManagementRepo();
await repo.updateChannelType(
  deviceId: device.id,
  channelNo: 1,
  channelType: 'light',
);
```

**Throws:**
- `String` - Error message describing the failure

### DevicesRepo

```dart
class DevicesRepo {
  /// Update channel type (light or switch)
  Future<void> updateChannelType({
    required String deviceId,
    required int channelNo,
    required String channelType,  // 'light' or 'switch'
  });
  
  /// Get device with channel information
  Future<DeviceWithChannels?> getDeviceWithChannels(String deviceId);
}
```

**Usage:**
```dart
final repo = DevicesRepo();

// Update channel type
await repo.updateChannelType(
  deviceId: device.id,
  channelNo: 1,
  channelType: 'light',
);

// Get device with channels
final deviceWithChannels = await repo.getDeviceWithChannels(device.id);
if (deviceWithChannels != null) {
  final type = deviceWithChannels.getChannelType(1);
  print('Channel 1 type: $type');
}
```

## UI Components

### Device Control Screen

**State Variables:**
```dart
final Map<int, String> _channelTypes = {};  // Channel number -> type
```

**Methods:**
```dart
// Show options dialog (rename + change type)
void _showChannelOptionsDialog(int channel);

// Update channel type with optimistic UI
Future<void> _updateChannelType(int channel, String newType);

// Load channel types from database
Future<void> _loadChannelNames();  // Also loads types
```

**Usage in Build:**
```dart
Widget _buildCircularChannelButton({
  required int channel,
  required bool isOn,
  required bool canControl,
}) {
  final channelType = _channelTypes[channel] ?? 'switch';
  final isLight = channelType == 'light';
  
  return GestureDetector(
    onTap: canControl ? () => _toggleChannel(channel) : null,
    onLongPress: () => _showChannelOptionsDialog(channel),
    child: Container(
      child: Icon(
        isLight ? Icons.lightbulb : Icons.power_settings_new,
        color: isOn ? Colors.white : AppTheme.textSecondary,
      ),
    ),
  );
}
```

### Enhanced Device Control Widget

**State Variables:**
```dart
final Map<int, String> _channelTypes = {};  // Channel number -> type
```

**Usage in Build:**
```dart
Widget _buildMultiChannelControls() {
  return Column(
    children: [
      for (int i = 1; i <= widget.device.effectiveChannels; i++)
        Row(
          children: [
            Icon(
              _channelTypes[i] == 'light' 
                ? Icons.lightbulb 
                : Icons.power_settings_new,
              color: (_channelStates[i] ?? false) 
                ? AppTheme.primaryColor 
                : AppTheme.textSecondary,
            ),
            // ... rest of row
          ],
        ),
    ],
  );
}
```

## Icon Reference

### Material Icons Used

| Type | Icon | Constant |
|------|------|----------|
| Light | 💡 | `Icons.lightbulb` |
| Switch | ⚡ | `Icons.power_settings_new` |
| Edit | ✏️ | `Icons.edit` |
| Check | ✓ | `Icons.check` |

### Color States

| State | Color | Usage |
|-------|-------|-------|
| Active (ON) | `AppTheme.primaryColor` | Channel is powered on |
| Inactive (OFF) | `AppTheme.textSecondary` | Channel is powered off |
| Selected | `AppTheme.primaryColor` | Current selection in dialog |
| Unselected | `AppTheme.textSecondary` | Other options in dialog |

## Constants

```dart
// Valid channel types
const String CHANNEL_TYPE_LIGHT = 'light';
const String CHANNEL_TYPE_SWITCH = 'switch';

// Default channel type
const String DEFAULT_CHANNEL_TYPE = 'switch';
```

## Error Handling

### Common Errors

```dart
try {
  await repo.updateChannelType(
    deviceId: device.id,
    channelNo: 1,
    channelType: 'light',
  );
} catch (e) {
  // Handle errors
  if (e.toString().contains('device not found')) {
    // Device doesn't exist or user doesn't own it
  } else if (e.toString().contains('invalid channel type')) {
    // Invalid type provided
  } else if (e.toString().contains('channel not found')) {
    // Channel doesn't exist
  } else if (e.toString().contains('not authenticated')) {
    // User not logged in
  } else {
    // Unknown error
  }
}
```

### Optimistic Updates with Rollback

```dart
Future<void> _updateChannelType(int channel, String newType) async {
  final oldType = _channelTypes[channel] ?? 'switch';
  
  // Optimistic update
  setState(() {
    _channelTypes[channel] = newType;
  });

  try {
    await _devicesRepo.updateChannelType(
      deviceId: widget.device.id,
      channelNo: channel,
      channelType: newType,
    );
    // Success - show confirmation
  } catch (e) {
    // Rollback on error
    setState(() {
      _channelTypes[channel] = oldType;
    });
    // Show error message
  }
}
```

## Migration Script

```sql
-- File: supabase_migrations/add_channel_type.sql

-- Add column
ALTER TABLE device_channels 
ADD COLUMN IF NOT EXISTS channel_type TEXT NOT NULL DEFAULT 'switch';

-- Add constraint
ALTER TABLE device_channels
ADD CONSTRAINT check_channel_type 
CHECK (channel_type IN ('light', 'switch'));

-- Create function
CREATE OR REPLACE FUNCTION update_channel_type(
  p_device_id UUID,
  p_channel_no INT,
  p_channel_type TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
-- ... function body ...
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION update_channel_type TO authenticated;
```

## Testing

### Unit Test Example

```dart
test('DeviceWithChannels returns correct channel type', () {
  final device = DeviceWithChannels(
    // ... other fields ...
    channelLabels: {
      '1': {'label': 'Light', 'is_custom': true, 'type': 'light'},
      '2': {'label': 'Switch', 'is_custom': false, 'type': 'switch'},
    },
  );

  expect(device.getChannelType(1), 'light');
  expect(device.getChannelType(2), 'switch');
  expect(device.isChannelLight(1), true);
  expect(device.isChannelSwitch(2), true);
});
```

### Integration Test Example

```dart
testWidgets('Long press shows channel options dialog', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Navigate to device control screen
  // ...
  
  // Long press on channel
  await tester.longPress(find.text('Channel 1'));
  await tester.pumpAndSettle();
  
  // Verify dialog appears
  expect(find.text('Channel 1 Options'), findsOneWidget);
  expect(find.text('Rename Channel'), findsOneWidget);
  expect(find.text('Light'), findsOneWidget);
  expect(find.text('Switch'), findsOneWidget);
});
```
