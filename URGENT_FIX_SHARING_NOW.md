# 🚨 URGENT FIX: Apply This Now

## The Error You're Seeing

```
Error: Failed to share device: PostgrestException
new row violates row-level security policy for table "shared_devices"
```

## The Fix (30 seconds)

### Step 1: Open Supabase SQL Editor

Go to your Supabase project → SQL Editor

### Step 2: Copy and Paste This

```sql
-- FIX: Allow users to add themselves to shared_devices
DROP POLICY IF EXISTS "Users can add shared devices" ON shared_devices;

CREATE POLICY "Users can add shared devices"
    ON shared_devices FOR INSERT
    WITH CHECK (auth.uid() = shared_with_id);
```

### Step 3: Click "Run"

That's it!

## Test Again

1. **Device A**: Generate QR code
2. **Device B**: Scan QR code
3. ✅ Should work now!

## What Happened?

The `shared_devices` table had RLS enabled but was missing the policy that allows users to add themselves as recipients. This policy fixes that.

## Files

- Quick fix SQL: `supabase_migrations/fix_instant_sharing_rls.sql`
- Complete migration: `supabase_migrations/instant_device_sharing.sql`
- Full explanation: `FIX_SHARING_RLS_ERROR.md`
