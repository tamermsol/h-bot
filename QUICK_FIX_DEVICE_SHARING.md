# Device Sharing - Quick Fix ⚡

## The Error
```
Could not find a relationship between 'shared_devices' and 'profiles'
```

## The Solution (2 Steps)

### Step 1: Run SQL in Supabase

**If first time:**
```sql
-- Copy and run: supabase_migrations/device_sharing_system.sql
```

**If already ran old migration:**
```sql
-- First run: supabase_migrations/drop_old_device_sharing_tables.sql
-- Then run: supabase_migrations/device_sharing_system.sql
```

### Step 2: Restart App
```bash
flutter run
```

## Done! ✅

Both screens will now work:
- ✅ Share Device screen
- ✅ Shared with Me screen

---

**Time**: 1 minute  
**Files**: See `APPLY_DEVICE_SHARING_FIX_NOW.md` for details
