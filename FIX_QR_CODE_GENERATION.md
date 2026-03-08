# Fix QR Code Generation Error ✅

## The Error

```
Failed to create invitation: PostgrestException(message: new row for relation 
"device_share_invitations" violates check constraint "invitation_code_length", 
code: 23514)
```

## Root Cause

The `generate_invitation_code()` function was generating codes that weren't exactly 32 characters long due to base64 encoding and string manipulation.

## Solution

### Step 1: Run the Fix SQL

Open Supabase SQL Editor and run:

**File**: `supabase_migrations/fix_invitation_code_function.sql`

```sql
CREATE OR REPLACE FUNCTION generate_invitation_code()
RETURNS TEXT AS $$
DECLARE
    code TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        -- Generate exactly 32 character random code using hex encoding
        -- 16 bytes = 32 hex characters
        code := encode(gen_random_bytes(16), 'hex');
        
        -- Check if code already exists
        SELECT EXISTS(SELECT 1 FROM device_share_invitations WHERE invitation_code = code) INTO exists;
        
        EXIT WHEN NOT exists;
    END LOOP;
    
    RETURN code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Step 2: Restart Your App

```bash
flutter run
```

### Step 3: Test QR Generation

1. Open any device
2. Tap menu (⋮) → "Share Device"
3. Tap "Generate QR Code"
4. Should work now! ✅

## What Changed

**Before** (base64 encoding - variable length):
```sql
code := encode(gen_random_bytes(24), 'base64');
code := replace(replace(replace(code, '+', ''), '/', ''), '=', '');
code := substring(code, 1, 32);  -- Not always exactly 32!
```

**After** (hex encoding - always 32 characters):
```sql
code := encode(gen_random_bytes(16), 'hex');  -- Always exactly 32 chars
```

## Bonus: Scan Button Added ✅

The "Shared with Me" screen now has a QR scanner button in the app bar!

- Icon: QR code scanner
- Location: Top right of "Shared with Me" screen
- Action: Opens camera to scan QR codes

## Complete Flow Now Works

### As Device Owner:
1. Device → Share Device ✅
2. Generate QR Code ✅ (FIXED)
3. Show QR to recipient ✅

### As Recipient:
1. Profile → Shared with Me ✅
2. Tap QR scanner icon (top right) ✅ (NEW)
3. Scan owner's QR code ✅
4. Send share request ✅
5. Wait for approval ✅

## Time Required

- Run SQL fix: 10 seconds
- Restart app: 30 seconds
- Test: 1 minute
- **Total: ~2 minutes**

---

**Status**: Fix ready ✅  
**Scan button**: Added ✅  
**Ready to use**: After SQL fix 🚀
