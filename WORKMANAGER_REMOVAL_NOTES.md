# Workmanager Package Removal - Technical Notes

## 🔴 Issue Encountered

When attempting to build the app with `workmanager: ^0.5.2`, the following compilation errors occurred:

```
e: file:///C:/Users/HP/AppData/Local/Pub/Cache/hosted/pub.dev/workmanager-0.5.2/android/src/main/kotlin/dev/fluttercommunity/workmanager/BackgroundWorker.kt:14:44 Unresolved reference 'shim'.
e: file:///C:/Users/HP/AppData/Local/Pub/Cache/hosted/pub.dev/workmanager-0.5.2/android/src/main/kotlin/dev/fluttercommunity/workmanager/BackgroundWorker.kt:98:55 Unresolved reference 'registerWith'.
e: file:///C:/Users/HP/AppData/Local/Pub/Cache/hosted/pub.dev/workmanager-0.5.2/android/src/main/kotlin/dev/fluttercommunity/workmanager/BackgroundWorker.kt:98:68 Unresolved reference 'ShimPluginRegistry'.
e: file:///C:/Users/HP/AppData/Local/Pub/Cache/hosted/pub.dev/workmanager-0.5.2/android/src/main/kotlin/dev/fluttercommunity/workmanager/WorkmanagerPlugin.kt:35:52 Unresolved reference 'PluginRegistrantCallback'.
e: file:///C:/Users/HP/AppData/Local/Pub/Cache/hosted/pub.dev/workmanager-0.5.2/android/src/main/kotlin/dev/fluttercommunity/workmanager/WorkmanagerPlugin.kt:38:52 Unresolved reference 'Registrar'.
```

**Root Cause:** The `workmanager` package v0.5.2 is incompatible with newer Flutter versions (Flutter 3.x+). The package uses deprecated Flutter embedding APIs that have been removed.

---

## ✅ Solution Applied

### Changes Made:

1. **Removed workmanager dependency from `pubspec.yaml`:**
   ```yaml
   # REMOVED:
   # workmanager: ^0.5.2
   ```

2. **Deleted `lib/services/background_scene_executor.dart`:**
   - This file contained the workmanager integration
   - No longer needed since we're using in-app scheduler only

3. **Updated `lib/main.dart`:**
   - Removed import: `import 'services/background_scene_executor.dart';`
   - Removed initialization: `await BackgroundSceneExecutor.initialize();`

4. **Kept Android permissions in `AndroidManifest.xml`:**
   - `WAKE_LOCK` - Still useful for general background execution
   - `RECEIVE_BOOT_COMPLETED` - May be useful for future implementations
   - `FOREGROUND_SERVICE` - Useful for long-running tasks
   - These permissions don't cause any issues and may be useful later

5. **Updated documentation:**
   - `VERIFICATION_CHECKLIST.md` - Added note about workmanager removal
   - Created this document for technical reference

---

## 🎯 Current Implementation

### What Still Works:

✅ **SceneTriggerScheduler Service** (`lib/services/scene_trigger_scheduler.dart`)
- Uses `Timer.periodic` to check triggers every minute
- Runs in the Flutter app's main isolate
- Works when app is in **foreground** or **background** (minimized)
- Automatically starts when app launches
- Automatically stops when app is disposed

✅ **Scene Trigger Creation**
- Users can create scenes with time-based triggers
- Triggers are saved to Supabase database
- Trigger configuration: `{"hour": X, "minute": Y, "days": [1,2,3,4,5,6,7]}`

✅ **Scene Execution**
- Scenes execute automatically at scheduled times
- Supports all device types: relay, dimmer, shutter
- Sends MQTT commands correctly
- Logs execution in `scene_runs` table

### What Doesn't Work:

❌ **Execution when app is completely terminated**
- If user force-closes the app, triggers will NOT fire
- This is a limitation of the in-app scheduler approach
- Most mobile apps run in background, so this is acceptable for most use cases

---

## 🔄 Alternative Solutions (Future Enhancement)

If you need scene execution when the app is completely terminated, consider these alternatives:

### Option 1: flutter_background_service (Recommended)

**Package:** `flutter_background_service: ^5.0.0`

**Pros:**
- More modern and actively maintained
- Better compatibility with Flutter 3.x+
- Supports both Android and iOS
- Can run Dart code in background isolate

**Cons:**
- Requires more complex setup
- May have battery impact
- Requires foreground service notification on Android

**Implementation:**
```dart
import 'package:flutter_background_service/flutter_background_service.dart';

void onStart(ServiceInstance service) async {
  // This runs in a separate isolate
  Timer.periodic(Duration(minutes: 1), (timer) async {
    // Check and execute scene triggers
  });
}

void main() async {
  await initializeService();
  runApp(MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: false,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}
```

### Option 2: Native Platform Channels

**Approach:** Implement native Android AlarmManager and iOS Background Tasks

**Pros:**
- Full control over background execution
- Most reliable solution
- No third-party dependencies

**Cons:**
- Requires native Android (Kotlin/Java) and iOS (Swift/Objective-C) code
- More complex to maintain
- Need to handle platform-specific differences

**Android Implementation (Kotlin):**
```kotlin
// Use AlarmManager to schedule periodic checks
val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
val intent = Intent(context, SceneTriggerReceiver::class.java)
val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, 0)

alarmManager.setRepeating(
    AlarmManager.RTC_WAKEUP,
    System.currentTimeMillis(),
    60 * 1000, // Every minute
    pendingIntent
)
```

**iOS Implementation (Swift):**
```swift
// Use BGTaskScheduler for background tasks
import BackgroundTasks

BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.example.hbot.scene-trigger",
    using: nil
) { task in
    handleSceneTriggerCheck(task: task as! BGAppRefreshTask)
}
```

### Option 3: Supabase Edge Functions + Webhooks

**Approach:** Use server-side cron jobs to trigger scenes

**Pros:**
- No client-side background execution needed
- Reliable and scalable
- Works even if device is offline (executes when back online)

**Cons:**
- Requires internet connection
- Requires webhook endpoint on device (complex networking)
- May have latency issues
- Requires Supabase Edge Functions setup

**Implementation:**
```typescript
// Supabase Edge Function (runs every minute via cron)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  // 1. Query scene_triggers table for triggers that should fire now
  // 2. For each trigger, send webhook to device
  // 3. Device receives webhook and executes scene
})
```

---

## 📊 Comparison Table

| Solution | Complexity | Reliability | Battery Impact | Works Offline | Maintenance |
|----------|-----------|-------------|----------------|---------------|-------------|
| **Current (In-App Scheduler)** | ⭐ Low | ⭐⭐⭐ Good | ⭐⭐⭐ Low | ✅ Yes | ⭐⭐⭐ Easy |
| **flutter_background_service** | ⭐⭐ Medium | ⭐⭐⭐⭐ Very Good | ⭐⭐ Medium | ✅ Yes | ⭐⭐ Medium |
| **Native Platform Channels** | ⭐⭐⭐ High | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐ Medium | ✅ Yes | ⭐ Hard |
| **Supabase Edge Functions** | ⭐⭐⭐ High | ⭐⭐⭐⭐ Very Good | ⭐⭐⭐ Low | ❌ No | ⭐⭐ Medium |

---

## 🎯 Recommendation

**For most use cases, the current in-app scheduler is sufficient:**

1. **Mobile apps typically run in background** - Users rarely force-close apps
2. **Battery-friendly** - No additional background services
3. **Simple and maintainable** - Pure Dart code, no native dependencies
4. **Reliable when app is running** - Timer.periodic is very reliable

**Consider upgrading to `flutter_background_service` if:**
- Users frequently force-close the app
- Critical scenes must execute even when app is terminated
- You're willing to accept some battery impact
- You can handle the additional complexity

**Consider native platform channels if:**
- You need maximum reliability
- You have native development expertise
- You need fine-grained control over background execution

**Consider Supabase Edge Functions if:**
- Devices are always connected to internet
- You want server-side control
- You can implement webhook infrastructure

---

## 🧪 Testing the Current Implementation

### Test 1: Foreground Execution
1. Create scene with trigger time = current time + 2 minutes
2. Keep app open in foreground
3. Wait for trigger time
4. **Expected:** Scene executes automatically ✅

### Test 2: Background Execution
1. Create scene with trigger time = current time + 2 minutes
2. Minimize app (press home button)
3. Wait for trigger time
4. **Expected:** Scene executes automatically ✅

### Test 3: App Terminated
1. Create scene with trigger time = current time + 2 minutes
2. Force-close app (swipe away from recent apps)
3. Wait for trigger time
4. **Expected:** Scene does NOT execute ❌ (known limitation)

---

## 📝 Files Modified

### Removed:
- ❌ `lib/services/background_scene_executor.dart`

### Modified:
- ✅ `pubspec.yaml` - Removed workmanager dependency
- ✅ `lib/main.dart` - Removed BackgroundSceneExecutor initialization
- ✅ `VERIFICATION_CHECKLIST.md` - Added workmanager removal note

### Kept (No Changes):
- ✅ `lib/services/scene_trigger_scheduler.dart` - Still works perfectly
- ✅ `lib/screens/add_scene_screen.dart` - Trigger creation logic
- ✅ `lib/repos/scenes_repo.dart` - Scene execution logic
- ✅ `android/app/src/main/AndroidManifest.xml` - Permissions kept for future use
- ✅ `ios/Runner/Info.plist` - Background modes kept for future use

---

## ✅ Build Status

After removing workmanager:
- ✅ `flutter pub get` - Success
- ✅ No compilation errors
- ✅ App builds successfully
- ✅ Scene trigger scheduler works correctly

---

## 🔗 References

- **workmanager package:** https://pub.dev/packages/workmanager
- **flutter_background_service:** https://pub.dev/packages/flutter_background_service
- **Android AlarmManager:** https://developer.android.com/reference/android/app/AlarmManager
- **iOS Background Tasks:** https://developer.apple.com/documentation/backgroundtasks
- **Supabase Edge Functions:** https://supabase.com/docs/guides/functions

---

**Last Updated:** 2025-01-15  
**Status:** ✅ Production Ready (with known limitation)

