# Run Device Sharing Migration - Quick Guide

## ⚠️ IMPORTANT: You MUST run this migration before using the device sharing feature!

The errors you're seeing are because the database tables don't exist yet.

## Step-by-Step Instructions

### 1. Open Supabase Dashboard
Go to: https://supabase.com/dashboard

### 2. Select Your Project
Click on your HBOT project

### 3. Open SQL Editor
- Click "SQL Editor" in the left sidebar
- Click "New Query"

### 4. Copy the Migration SQL
Open the file: `supabase_migrations/device_sharing_system.sql`

Copy ALL the content (the entire file)

### 5. Paste and Run
- Paste the SQL into the SQL Editor
- Click "Run" button (or press Ctrl+Enter / Cmd+Enter)

### 6. Verify Success
You should see a success message. The migration creates:
- ✅ `device_share_invitations` table
- ✅ `device_share_requests` table  
- ✅ `shared_devices` table
- ✅ Row Level Security (RLS) policies
- ✅ Helper functions

### 7. Test the Feature
After running the migration:
1. Restart your app
2. Go to any device → tap menu (⋮) → "Share Device"
3. Tap "Generate QR Code" - should work now!
4. Go to Profile → Settings → "Shared with Me" - should work now!

## What Was Fixed

### Code Fixes Applied:
✅ Changed `devices(device_name, type)` to `devices(name, device_type)` in all queries
✅ Fixed column name references to match actual database schema
✅ Added proper null checks for device fetching

### Files Fixed:
- `lib/repos/device_sharing_repo.dart` - Fixed all device column references

## Common Issues

### Issue: "relation 'device_share_invitations' does not exist"
**Solution**: You haven't run the migration yet. Follow steps above.

### Issue: "column devices_1.device_name does not exist"
**Solution**: This was a code bug (now fixed). Update your code and restart app.

### Issue: "Could not find a relationship between 'shared_devices' and 'profiles'"
**Solution**: Run the migration - it creates the proper foreign key relationships.

## Migration Content Summary

The migration creates a complete device sharing system:

```sql
-- 3 Main Tables:
1. device_share_invitations (QR codes, 24h expiry)
2. device_share_requests (pending approvals)
3. shared_devices (approved shares)

-- Security:
- Row Level Security (RLS) enabled
- Users can only see their own data
- Owners control approvals

-- Helper Functions:
- generate_invitation_code() - Creates unique codes
- cleanup_expired_invitations() - Auto cleanup
```

## After Migration

The feature will work completely:
- ✅ Generate QR codes for devices
- ✅ Scan QR codes to request access
- ✅ Approve/reject sharing requests
- ✅ View devices shared with you
- ✅ Manage sharing permissions (view/control)
- ✅ Revoke access anytime

## Need Help?

If you encounter any issues:
1. Check Supabase logs for detailed error messages
2. Verify you're connected to the correct project
3. Ensure you have admin access to run migrations
4. Try running the migration in smaller chunks if it fails

## Next Steps After Migration

1. Test QR code generation
2. Test scanning with another account
3. Test approval workflow
4. Test device access from shared devices list
5. Test revoking access

---

**Status**: Migration ready to run ✅  
**Code fixes**: Applied ✅  
**Ready to use**: After migration ⏳
