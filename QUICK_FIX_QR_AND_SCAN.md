# Quick Fix: QR Code Generation + Scan Button

## What's Fixed

1. ✅ QR code generation error
2. ✅ Added scan button to "Shared with Me" screen

## What You Need To Do

### Run This SQL in Supabase:

```sql
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
```

### Then Restart App:

```bash
flutter run
```

## Done! ✅

- Generate QR Code button will work
- Scan QR button appears in "Shared with Me" screen (top right)

---

**Time**: 1 minute  
**File**: `supabase_migrations/fix_invitation_code_function.sql`
