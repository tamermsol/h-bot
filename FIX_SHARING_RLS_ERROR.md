# FIX: Sharing RLS Policy Error

## The Problem

When scanning a QR code, you get this error:
```
Error: Failed to share device: PostgrestException(message: new row violates row-level security policy for table "shared_devices", code: 42501, details: Forbidden, hint: null)
```

## The Cause

The `shared_devices` table has RLS enabled, but there was no policy allowing users to INSERT themselves as recipients of shared devices.

## The Solution

I've updated the migration file to include the missing policy. You need to apply this additional policy.

## How to Fix

### Option 1: Run the Complete Migration Again

Open Supabase SQL Editor and run the entire file:
```
supabase_migrations/instant_device_sharing.sql
```

### Option 2: Run Just the Missing Policy

Open Supabase SQL Editor and run this:

```sql
-- CRITICAL FIX: Allow users to add themselves to shared_devices (instant sharing)
DROP POLICY IF EXISTS "Users can add shared devices" ON shared_devices;

CREATE POLICY "Users can add shared devices"
    ON shared_devices FOR INSERT
    WITH CHECK (auth.uid() = shared_with_id);

COMMENT ON POLICY "Users can add shared devices" ON shared_devices IS 'Allow users to add themselves as recipients of shared devices (instant sharing via QR code)';
```

## Verify the Fix

After applying the policy, check that it exists:

```sql
SELECT * FROM pg_policies 
WHERE tablename = 'shared_devices' 
AND policyname = 'Users can add shared devices';
```

You should see one row returned.

## Test Again

1. **Device A (Owner)**: Generate QR code
2. **Device B (Recipient)**: Scan QR code
3. Should work without the RLS error!

## What This Policy Does

- Allows any authenticated user to INSERT a row into `shared_devices`
- BUT only if they are setting themselves as the `shared_with_id`
- This prevents users from adding other people without permission
- The owner_id and device_id come from the invitation, which was created by the owner

## Security

This is secure because:
1. The invitation code is validated first (must exist and not be expired)
2. The device_id and owner_id come from the invitation (created by the owner)
3. Users can only set themselves as the recipient (shared_with_id = auth.uid())
4. Users cannot share devices they don't own to others

## Next Steps

After applying this fix, the instant sharing should work perfectly!
