# Channel Type Feature - Architecture

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────┐    ┌──────────────────────┐     │
│  │ DeviceControlScreen  │    │ EnhancedDeviceControl│     │
│  │                      │    │      Widget          │     │
│  │ - Channel buttons    │    │ - List view          │     │
│  │ - Long press handler │    │ - Icons              │     │
│  │ - Options dialog     │    │ - State display      │     │
│  │ - Optimistic updates │    │                      │     │
│  └──────────┬───────────┘    └──────────┬───────────┘     │
│             │                           │                  │
└─────────────┼───────────────────────────┼──────────────────┘
              │                           │
              ▼                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      Repository Layer                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────┐    ┌──────────────────────┐     │
│  │   DevicesRepo        │    │ DeviceManagementRepo │     │
│  │                      │    │                      │     │
│  │ - updateChannelType()│◄───┤ - updateChannelType()│     │
│  │ - getDeviceWith      │    │ - renameChannel()    │     │
│  │   Channels()         │    │ - claimDevice()      │     │
│  └──────────┬───────────┘    └──────────┬───────────┘     │
│             │                           │                  │
└─────────────┼───────────────────────────┼──────────────────┘
              │                           │
              ▼                           ▼
┌─────────────────────────────────────────────────────────────┐
│                       Model Layer                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────┐    ┌──────────────────────┐     │
│  │  DeviceWithChannels  │    │   DeviceChannel      │     │
│  │                      │    │                      │     │
│  │ - getChannelType()   │    │ - channelType        │     │
│  │ - isChannelLight()   │    │ - isLight()          │     │
│  │ - isChannelSwitch()  │    │ - isSwitch()         │     │
│  │ - channelLabels      │    │ - label              │     │
│  └──────────┬───────────┘    └──────────┬───────────┘     │
│             │                           │                  │
└─────────────┼───────────────────────────┼──────────────────┘
              │                           │
              ▼                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Supabase Layer                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              RPC Functions                           │  │
│  │                                                      │  │
│  │  - update_channel_type(device_id, channel_no, type) │  │
│  │  - rename_channel(device_id, channel_no, label)     │  │
│  │                                                      │  │
│  └──────────────────────┬───────────────────────────────┘  │
│                         │                                   │
│                         ▼                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Database Tables                         │  │
│  │                                                      │  │
│  │  devices                    device_channels          │  │
│  │  ├─ id                      ├─ device_id             │  │
│  │  ├─ topic_base              ├─ channel_no            │  │
│  │  ├─ display_name            ├─ label                 │  │
│  │  ├─ channels                ├─ label_is_custom       │  │
│  │  └─ ...                     ├─ channel_type ◄─ NEW   │  │
│  │                             └─ ...                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Database Views                          │  │
│  │                                                      │  │
│  │  devices_with_channels                               │  │
│  │  ├─ Joins devices + device_channels                  │  │
│  │  ├─ Aggregates channel_labels JSON                   │  │
│  │  └─ Includes channel_type in JSON ◄─ NEW            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Load Channel Types (Read)

```
User Opens Device Screen
        ↓
DeviceControlScreen.initState()
        ↓
_loadChannelNames()
        ↓
DevicesRepo.getDeviceWithChannels(deviceId)
        ↓
Supabase Query: devices_with_channels view
        ↓
Returns: DeviceWithChannels with channel_labels JSON
        ↓
Parse: channelLabels['1']['type'] → 'light'
        ↓
Store: _channelTypes[1] = 'light'
        ↓
setState() → UI Updates with 💡 icon
```

### 2. Update Channel Type (Write)

```
User Long-Presses Channel
        ↓
_showChannelOptionsDialog(channel)
        ↓
User Selects "Light"
        ↓
_updateChannelType(channel, 'light')
        ↓
Optimistic Update: setState(() { _channelTypes[channel] = 'light' })
        ↓
UI Updates Immediately (💡 icon)
        ↓
DevicesRepo.updateChannelType(deviceId, channel, 'light')
        ↓
DeviceManagementRepo.updateChannelType(...)
        ↓
Supabase RPC: update_channel_type(device_id, channel_no, 'light')
        ↓
Database: UPDATE device_channels SET channel_type = 'light'
        ↓
Success → Show success message
        ↓
Error → Rollback: setState(() { _channelTypes[channel] = oldType })
```

## Component Interaction

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interaction                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Long Press Detector                        │
│  GestureDetector(                                           │
│    onLongPress: () => _showChannelOptionsDialog(channel)    │
│  )                                                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Options Dialog                            │
│  AlertDialog(                                               │
│    title: "Channel Options"                                │
│    content: [                                               │
│      ListTile("Rename Channel"),                           │
│      ListTile("Light", onTap: updateType),                 │
│      ListTile("Switch", onTap: updateType)                 │
│    ]                                                        │
│  )                                                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  State Management                           │
│  final Map<int, String> _channelTypes = {};                │
│                                                             │
│  setState(() {                                              │
│    _channelTypes[channel] = newType;  // Optimistic        │
│  });                                                        │
│                                                             │
│  try {                                                      │
│    await repo.updateChannelType(...);  // Persist          │
│  } catch (e) {                                              │
│    setState(() {                                            │
│      _channelTypes[channel] = oldType;  // Rollback        │
│    });                                                      │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Icon Rendering                           │
│  Icon(                                                      │
│    _channelTypes[i] == 'light'                             │
│      ? Icons.lightbulb                                      │
│      : Icons.power_settings_new,                           │
│    color: isOn ? primaryColor : secondaryColor              │
│  )                                                          │
└─────────────────────────────────────────────────────────────┘
```

## State Management Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                    Local State                              │
│  _channelTypes: Map<int, String>                           │
│  _channelNames: Map<int, String>                           │
│  _channelStates: Map<int, bool>                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                 Optimistic Update                           │
│  1. Update local state immediately                          │
│  2. Trigger UI rebuild                                      │
│  3. Send API request                                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   API Response                              │
│  Success: Keep optimistic state                             │
│  Error: Rollback to previous state                          │
└─────────────────────────────────────────────────────────────┘
```

## Database Schema

```sql
-- device_channels table
CREATE TABLE device_channels (
  device_id UUID,
  channel_no INT,
  label TEXT,
  label_is_custom BOOLEAN,
  channel_type TEXT DEFAULT 'switch',  -- NEW
  inserted_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  PRIMARY KEY (device_id, channel_no),
  CONSTRAINT check_channel_type 
    CHECK (channel_type IN ('light', 'switch'))
);

-- devices_with_channels view
CREATE VIEW devices_with_channels AS
SELECT
  d.*,
  jsonb_object_agg(
    dc.channel_no::text,
    jsonb_build_object(
      'label', dc.label,
      'is_custom', dc.label_is_custom,
      'type', dc.channel_type  -- NEW
    )
  ) as channel_labels
FROM devices d
LEFT JOIN device_channels dc ON dc.device_id = d.id
GROUP BY d.id;
```

## Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Request                           │
│  updateChannelType(deviceId, channelNo, type)              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Authentication Check                       │
│  IF auth.uid() IS NULL THEN                                │
│    RAISE EXCEPTION 'not authenticated'                      │
│  END IF                                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Input Validation                           │
│  IF type NOT IN ('light', 'switch') THEN                   │
│    RAISE EXCEPTION 'invalid channel type'                   │
│  END IF                                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Ownership Check                            │
│  IF NOT EXISTS (                                            │
│    SELECT 1 FROM devices                                    │
│    WHERE id = deviceId                                      │
│      AND owner_user_id = auth.uid()                        │
│  ) THEN                                                     │
│    RAISE EXCEPTION 'device not found or access denied'      │
│  END IF                                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Update Database                          │
│  UPDATE device_channels                                     │
│  SET channel_type = type, updated_at = now()               │
│  WHERE device_id = deviceId                                 │
│    AND channel_no = channelNo                              │
└─────────────────────────────────────────────────────────────┘
```

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Try Update                               │
└─────────────────────────────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                ▼                       ▼
┌─────────────────────┐   ┌─────────────────────┐
│      Success        │   │       Error         │
└─────────────────────┘   └─────────────────────┘
            │                         │
            ▼                         ▼
┌─────────────────────┐   ┌─────────────────────┐
│  Keep Optimistic    │   │  Rollback State     │
│  State              │   │                     │
│  Show Success Msg   │   │  Show Error Msg     │
└─────────────────────┘   └─────────────────────┘
```

## Performance Considerations

### Caching Strategy
```
┌─────────────────────────────────────────────────────────────┐
│                    First Load                               │
│  1. Query database for channel types                        │
│  2. Store in local state (_channelTypes)                   │
│  3. Use cached values for subsequent renders                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Updates                                  │
│  1. Optimistic update (instant UI)                          │
│  2. Background API call                                     │
│  3. No additional queries needed                            │
└─────────────────────────────────────────────────────────────┘
```

### Database Optimization
```
- Index on channel_type for filtering
- View pre-aggregates channel data
- Single query loads all channel info
- No N+1 query problems
```

## Scalability

```
┌─────────────────────────────────────────────────────────────┐
│                  Current Scale                              │
│  - Supports 1-8 channels per device                         │
│  - Instant UI updates                                       │
│  - Minimal database queries                                 │
│  - Efficient JSON aggregation                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  Future Scale                               │
│  - Can add more channel types                               │
│  - Can support more channels                                │
│  - Can add channel-specific metadata                        │
│  - Can implement bulk operations                            │
└─────────────────────────────────────────────────────────────┘
```

## Technology Stack

```
┌─────────────────────────────────────────────────────────────┐
│  Frontend: Flutter/Dart                                     │
│  - Material Design icons                                    │
│  - StatefulWidget for state management                      │
│  - GestureDetector for interactions                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Backend: Supabase                                          │
│  - PostgreSQL database                                      │
│  - RPC functions for business logic                         │
│  - Row Level Security (RLS)                                 │
│  - Real-time subscriptions (future)                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Data: JSON Serialization                                   │
│  - json_annotation package                                  │
│  - build_runner for code generation                         │
│  - Type-safe models                                         │
└─────────────────────────────────────────────────────────────┘
```
