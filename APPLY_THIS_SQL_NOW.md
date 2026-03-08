# 🎯 COPY AND PASTE THIS SQL

## Open Supabase SQL Editor

1. Go to your Supabase project
2. Click "SQL Editor" in the left sidebar
3. Click "New query"

## Paste This Code

```sql
-- FIX: Allow instant device sharing via QR codes
DROP POLICY IF EXISTS "Users can add shared devices" ON shared_devices;

CREATE POLICY "Users can add shared devices"
    ON shared_devices FOR INSERT
    WITH CHECK (auth.uid() = shared_with_id);
```

## Click "Run" (or press Ctrl+Enter)

You should see: ✅ Success. No rows returned

## That's It!

Now test device sharing again - it should work!

---

## What This Does

This policy allows users to add themselves as recipients when they scan a QR code. Without it, the database blocks the insert operation with an RLS error.

## Security

✅ Users can only add themselves (not others)
✅ Device and owner info comes from the invitation
✅ Cannot share devices they don't own
✅ Invitation codes expire after 24 hours

---

## Still Getting Errors?

Make sure you:
1. Applied the original device sharing migration first
2. Have the `shared_devices` table created
3. Are logged in to the app

Check: `supabase_migrations/device_sharing_system.sql`
