# ✅ Tables Already Exist - Just Run This!

## Good News!

Your tables already exist from a previous migration. You just need to fix the QR code function.

## Run This SQL in Supabase:

**File**: `supabase_migrations/update_existing_tables.sql`

Or copy and paste this:

```sql
-- Fix the QR code generation function
CREATE OR REPLACE FUNCTION generate_invitation_code()
RETURNS TEXT AS $$
DECLARE
    code TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        code := encode(gen_random_bytes(16), 'hex');
        SELECT EXISTS(SELECT 1 FROM device_share_invitations WHERE invitation_code = code) INTO exists;
        EXIT WHEN NOT exists;
    END LOOP;
    RETURN code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Test it
SELECT length(generate_invitation_code()) AS code_length;
```

## Then Restart Your App:

```bash
flutter run
```

## Done! ✅

Now test:
1. Device → Share Device → Generate QR Code ✅
2. Profile → Shared with Me → Tap QR scanner icon ✅

---

**Time**: 30 seconds  
**That's all you need!** 🎉
