# Scene Automation Flow Diagrams

## Overall Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SUPABASE CLOUD                               │
│                                                                      │
│  ┌────────────────┐                                                 │
│  │   pg_cron      │  Triggers every minute                          │
│  │   Extension    │                                                 │
│  └────────┬───────┘                                                 │
│           │                                                          │
│           v                                                          │
│  ┌────────────────────────────────────────────────────┐            │
│  │  Edge Function: scene-trigger-monitor              │            │
│  │                                                     │            │
│  │  1. Get all enabled scenes                         │            │
│  │  2. Get their schedule triggers                    │            │
│  │  3. Check if current time matches                  │            │
│  │  4. Create commands in scene_commands table        │            │
│  │  5. Log execution in scene_runs table              │            │
│  └────────────────────┬───────────────────────────────┘            │
│                       │                                              │
│                       v                                              │
│  ┌────────────────────────────────────────────────────┐            │
│  │  Database Tables                                    │            │
│  │                                                     │            │
│  │  ┌──────────────┐  ┌──────────────┐               │            │
│  │  │   scenes     │  │scene_triggers│               │            │
│  │  └──────────────┘  └──────────────┘               │            │
│  │                                                     │            │
│  │  ┌──────────────┐  ┌──────────────┐               │            │
│  │  │ scene_steps  │  │ scene_runs   │               │            │
│  │  └──────────────┘  └──────────────┘               │            │
│  │                                                     │            │
│  │  ┌──────────────────────────────────┐             │            │
│  │  │     scene_commands                │             │            │
│  │  │  (Commands waiting to execute)    │             │            │
│  │  └──────────────┬───────────────────┘             │            │
│  └─────────────────┼─────────────────────────────────┘            │
│                    │                                                │
│                    │ Realtime Subscription                          │
│                    │ (PostgreSQL LISTEN/NOTIFY)                    │
└────────────────────┼────────────────────────────────────────────────┘
                     │
                     │ WebSocket Connection
                     │
                     v
┌────────────────────────────────────────────────────────────────────┐
│                      FLUTTER MOBILE APP                             │
│                                                                     │
│  ┌──────────────────────────────────────────────────┐             │
│  │  SceneCommandExecutor Service                     │             │
│  │                                                   │             │
│  │  • Subscribes to scene_commands table            │             │
│  │  • Receives new commands via Realtime            │             │
│  │  • Processes pending commands on startup         │             │
│  │  • Marks commands as executed                    │             │
│  └────────────────────┬─────────────────────────────┘             │
│                       │                                             │
│                       v                                             │
│  ┌──────────────────────────────────────────────────┐             │
│  │  MQTT Device Manager                              │             │
│  │                                                   │             │
│  │  • Connects to MQTT broker                       │             │
│  │  • Publishes commands to devices                 │             │
│  │  • Handles power, shutter, dimmer actions        │             │
│  └────────────────────┬─────────────────────────────┘             │
│                       │                                             │
└───────────────────────┼─────────────────────────────────────────────┘
                        │
                        │ MQTT Protocol
                        │
                        v
┌────────────────────────────────────────────────────────────────────┐
│                      MQTT BROKER                                    │
│                                                                     │
│  Routes commands to appropriate devices                             │
└────────────────────┬───────────────────────────────────────────────┘
                     │
                     v
┌────────────────────────────────────────────────────────────────────┐
│                   SMART HOME DEVICES                                │
│                                                                     │
│  • Lights, switches, shutters, dimmers                              │
│  • Subscribe to their MQTT topics                                   │
│  • Execute commands (ON/OFF, position, brightness)                  │
└─────────────────────────────────────────────────────────────────────┘
```

## Flow 1: Scene Execution (App Open)

```
┌─────────┐
│  Cron   │ Every minute
│  Job    │
└────┬────┘
     │
     v
┌────────────────────┐
│  Edge Function     │
│  Checks triggers   │
└────┬───────────────┘
     │
     │ Time matches!
     v
┌────────────────────┐
│  INSERT INTO       │
│  scene_commands    │
└────┬───────────────┘
     │
     │ Realtime notification (instant)
     v
┌────────────────────┐
│  Flutter App       │
│  (OPEN)            │
│  SceneCommand      │
│  Executor          │
└────┬───────────────┘
     │
     │ Immediately
     v
┌────────────────────┐
│  MQTT Device       │
│  Manager           │
│  Publishes command │
└────┬───────────────┘
     │
     v
┌────────────────────┐
│  Device            │
│  Executes action   │
│  (Light turns ON)  │
└────────────────────┘
     │
     v
┌────────────────────┐
│  UPDATE            │
│  scene_commands    │
│  SET executed=true │
└────────────────────┘

Total Time: < 1 second
```

## Flow 2: Scene Execution (App Closed)

```
┌─────────┐
│  Cron   │ Every minute
│  Job    │
└────┬────┘
     │
     v
┌────────────────────┐
│  Edge Function     │
│  Checks triggers   │
└────┬───────────────┘
     │
     │ Time matches!
     v
┌────────────────────┐
│  INSERT INTO       │
│  scene_commands    │
│  executed = false  │
└────┬───────────────┘
     │
     │ App is CLOSED
     │ Command waits...
     │
     │ (User opens app later)
     v
┌────────────────────┐
│  Flutter App       │
│  (OPENS)           │
│  SceneCommand      │
│  Executor.start()  │
└────┬───────────────┘
     │
     │ Checks for pending
     v
┌────────────────────┐
│  SELECT * FROM     │
│  scene_commands    │
│  WHERE executed=   │
│  false             │
└────┬───────────────┘
     │
     │ Found pending!
     v
┌────────────────────┐
│  MQTT Device       │
│  Manager           │
│  Publishes command │
└────┬───────────────┘
     │
     v
┌────────────────────┐
│  Device            │
│  Executes action   │
│  (Light turns ON)  │
└────────────────────┘
     │
     v
┌────────────────────┐
│  UPDATE            │
│  scene_commands    │
│  SET executed=true │
└────────────────────┘

Total Time: Executes when app opens
```

## Flow 3: Schedule Trigger Check

```
Current Time: 14:30
Day: Monday (1)

┌────────────────────┐
│  Edge Function     │
│  Runs at 14:30     │
└────┬───────────────┘
     │
     v
┌────────────────────────────────────┐
│  Query Database                     │
│                                     │
│  SELECT * FROM scenes               │
│  WHERE is_enabled = true            │
│                                     │
│  JOIN scene_triggers                │
│  WHERE kind = 'schedule'            │
│  AND is_enabled = true              │
└────┬───────────────────────────────┘
     │
     v
┌────────────────────────────────────┐
│  For each scene:                    │
│                                     │
│  Scene A:                           │
│    Trigger: { hour: 14, minute: 30, │
│               days: [1,2,3,4,5] }   │
│                                     │
│  Check:                             │
│    ✓ hour matches (14 == 14)       │
│    ✓ minute matches (30 == 30)     │
│    ✓ day matches (1 in [1,2,3,4,5])│
│                                     │
│  Result: TRIGGER!                   │
└────┬───────────────────────────────┘
     │
     v
┌────────────────────────────────────┐
│  Check for duplicate execution:     │
│                                     │
│  SELECT * FROM scene_runs           │
│  WHERE scene_id = 'Scene A'         │
│  AND started_at > now() - 1 minute  │
│                                     │
│  Result: None found                 │
└────┬───────────────────────────────┘
     │
     v
┌────────────────────────────────────┐
│  Execute Scene A                    │
│                                     │
│  1. Create scene_run record         │
│  2. Get scene_steps                 │
│  3. For each step:                  │
│     - Create scene_command          │
│  4. Update scene_run (success)      │
└─────────────────────────────────────┘
```

## Flow 4: Command Execution Details

```
┌────────────────────────────────────┐
│  scene_commands row inserted:       │
│                                     │
│  {                                  │
│    device_id: "abc-123",            │
│    action_type: "power",            │
│    action_data: {                   │
│      channels: [1, 2],              │
│      state: true                    │
│    }                                │
│  }                                  │
└────┬───────────────────────────────┘
     │
     v
┌────────────────────────────────────┐
│  SceneCommandExecutor receives      │
│  via Realtime subscription          │
└────┬───────────────────────────────┘
     │
     v
┌────────────────────────────────────┐
│  Parse action_type                  │
│                                     │
│  if (action_type == "power")        │
│    → _executePowerCommand()         │
│                                     │
│  else if (action_type == "shutter") │
│    → _executeShutterCommand()       │
└────┬───────────────────────────────┘
     │
     v
┌────────────────────────────────────┐
│  _executePowerCommand()             │
│                                     │
│  1. Get device info from DB         │
│  2. Check channel count             │
│  3. If all channels:                │
│     → Use POWER0 (bulk)             │
│  4. Else:                           │
│     → Loop through channels         │
│     → Send POWER1, POWER2, etc.     │
└────┬───────────────────────────────┘
     │
     v
┌────────────────────────────────────┐
│  MqttDeviceManager                  │
│                                     │
│  Publish to MQTT:                   │
│  Topic: cmnd/tasmota_ABC123/POWER1  │
│  Payload: "ON"                      │
└────┬───────────────────────────────┘
     │
     v
┌────────────────────────────────────┐
│  Device receives and executes       │
│                                     │
│  Publishes state back:              │
│  Topic: stat/tasmota_ABC123/POWER1  │
│  Payload: "ON"                      │
└────┬───────────────────────────────┘
     │
     v
┌────────────────────────────────────┐
│  Mark command as executed:          │
│                                     │
│  UPDATE scene_commands              │
│  SET executed = true,               │
│      executed_at = now()            │
│  WHERE id = 'command-id'            │
└─────────────────────────────────────┘
```

## Data Flow Summary

```
User Creates Scene
       ↓
Stores in Database (scenes, scene_steps, scene_triggers)
       ↓
Cron Job Triggers Edge Function (every minute)
       ↓
Edge Function Checks Triggers
       ↓
If Match → Creates scene_commands
       ↓
Realtime Notifies App (if open)
       ↓
App Executes via MQTT
       ↓
Marks Command as Executed
       ↓
Device State Updated
```

## Error Handling Flow

```
┌────────────────────┐
│  Command Received  │
└────┬───────────────┘
     │
     v
┌────────────────────┐
│  Try Execute       │
└────┬───────────────┘
     │
     ├─ Success ──────────────────┐
     │                            v
     │                   ┌────────────────┐
     │                   │ Mark executed  │
     │                   │ executed=true  │
     │                   └────────────────┘
     │
     └─ Error ───────────────────┐
                                 v
                        ┌────────────────┐
                        │ Mark failed    │
                        │ executed=true  │
                        │ error_message  │
                        │ = "..."        │
                        └────────────────┘
```

## Cleanup Flow

```
Daily at 2 AM
     │
     v
┌────────────────────────────────────┐
│  cleanup_old_scene_commands()       │
│                                     │
│  DELETE FROM scene_commands         │
│  WHERE executed = true              │
│  AND executed_at < now() - 7 days   │
└─────────────────────────────────────┘
     │
     v
Old commands removed
Database stays clean
```

## Monitoring Flow

```
┌────────────────────┐
│  Supabase          │
│  Dashboard         │
└────┬───────────────┘
     │
     ├─ Edge Function Logs ──────> View execution logs
     │
     ├─ Database Tables ─────────> Query scene_commands
     │
     └─ Cron Job Status ─────────> Check job_run_details
```
