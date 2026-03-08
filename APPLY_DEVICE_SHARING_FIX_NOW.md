# 🚀 Apply Device Sharing Fix - Step by Step

## The Problem You're Seeing

Both screens show this error:
```
Could not find a relationship between 'shared_devices' and 'profiles' 
in the schema cache
```

## Why It Happens

The foreign keys were pointing to `auth.users` instead of `profiles`, so PostgREST couldn't auto-join the tables.

## ✅ The Fix (Already Applied to Code)

All code has been updated:
- Migration file now references `profiles` table
- Queries use proper join syntax with aliases
- All column names corrected

## 🎯 What You Need to Do

### Option A: First Time Setup (Recommended)

If you haven't run the migration yet:

1. **Open Supabase Dashboard**
   - Go to https://supabase.com/dashboard
   - Select your project

2. **Open SQL Editor**
   - Click "SQL Editor" in sidebar
   - Click "New Query"

3. **Run the Migration**
   - Copy ALL content from: `supabase_migrations/device_sharing_system.sql`
   - Paste into SQL Editor
   - Click "Run" (or Ctrl+Enter)

4. **Restart Your App**
   ```bash
   # Stop the app completely, then:
   flutter run
   ```

### Option B: Already Ran Old Migration

If you already ran the old migration with wrong foreign keys:

1. **Drop Old Tables First**
   - Open Supabase SQL Editor
   - Copy content from: `supabase_migrations/drop_old_device_sharing_tables.sql`
   - Paste and Run

2. **Then Run Updated Migration**
   - Copy content from: `supabase_migrations/device_sharing_system.sql`
   - Paste and Run

3. **Restart Your App**
   ```bash
   flutter run
   ```

## ✅ After Migration - Test It

### Test 1: Share Device Screen
1. Open any device
2. Tap menu (⋮) → "Share Device"
3. Should load without errors ✅
4. Tap "Generate QR Code" - should work ✅

### Test 2: Shared with Me Screen
1. Go to Profile → Settings → "Shared with Me"
2. Should load without errors ✅
3. Shows "No Shared Devices" (until someone shares) ✅

## 📋 What the Migration Creates

```sql
✅ device_share_invitations table
   - Stores QR code invitations (24h expiry)
   - Foreign keys: owner_id → profiles(id)

✅ device_share_requests table
   - Stores pending share requests
   - Foreign keys: owner_id, requester_id → profiles(id)

✅ shared_devices table
   - Stores approved shares
   - Foreign keys: owner_id, shared_with_id → profiles(id)

✅ Row Level Security (RLS) policies
   - Users can only see their own data
   - Owners control approvals

✅ Helper functions
   - generate_invitation_code()
   - cleanup_expired_invitations()
```

## 🔍 Verify Success

After running migration, check in Supabase:

1. Go to "Table Editor"
2. You should see 3 new tables:
   - `device_share_invitations`
   - `device_share_requests`
   - `shared_devices`

3. Click on any table → "Foreign Keys" tab
4. Verify they reference `profiles` (not `auth.users`)

## 🎉 Complete Feature Flow

Once working, you can:

### As Device Owner:
1. Share device → Generate QR code
2. Other user scans QR code
3. You receive share request
4. Approve with "view" or "control" permission
5. User gets access

### As Recipient:
1. Scan owner's QR code
2. Send share request
3. Wait for approval
4. Access device from "Shared with Me"
5. View status or control (based on permission)

## 📁 Files Updated

- ✅ `supabase_migrations/device_sharing_system.sql` - Fixed foreign keys
- ✅ `lib/repos/device_sharing_repo.dart` - Fixed query syntax
- ✅ All code errors resolved

## 🆘 Troubleshooting

### Error: "relation already exists"
You already ran the migration. Use Option B above to drop and recreate.

### Error: "permission denied"
Make sure you're logged into Supabase with admin access.

### Error: "foreign key violation"
The `profiles` table must exist first. It should already exist in your database.

### Still seeing errors after migration?
1. Verify migration ran successfully (check tables exist)
2. Do a FULL app restart (not hot reload)
3. Check Supabase logs for detailed errors

## ⏱️ Time Required

- Drop old tables (if needed): 10 seconds
- Run migration: 30 seconds
- Restart app: 30 seconds
- **Total: ~1 minute**

---

**Status**: Ready to apply ✅  
**Risk**: Low (can drop and recreate tables) ✅  
**Downtime**: None (feature is new) ✅

## 🚀 Ready? Let's Do This!

1. Open Supabase SQL Editor
2. Run the migration
3. Restart app
4. Test both screens
5. Enjoy device sharing! 🎉
