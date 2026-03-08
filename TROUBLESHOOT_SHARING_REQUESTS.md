# Troubleshoot: Owner Not Seeing Share Requests

## The Problem

Recipient scanned QR and sent request, but owner doesn't see it in the Share Device screen.

## Quick Fixes Applied ✅

1. **Added Refresh Button**: Tap refresh icon in Share Device screen
2. **Added Pull-to-Refresh**: Pull down on Share Device screen to refresh
3. **Auto-refresh**: Screen refreshes when you return to it

## How to Check if Request Was Saved

### Step 1: Run Debug SQL in Supabase

Open Supabase SQL Editor and run:

```sql
-- See all share requests
SELECT 
    requester_email,
    status,
    requested_at,
    device_id
FROM device_share_requests
ORDER BY requested_at DESC
LIMIT 10;
```

This shows if the request was actually saved to the database.

### Step 2: Check Owner's User ID

The owner might be logged in with a different account. Run:

```sql
-- Check who owns which devices
SELECT 
    d.name AS device_name,
    d.id AS device_id,
    d.user_id AS owner_id
FROM devices d
ORDER BY d.created_at DESC
LIMIT 10;
```

Compare the `owner_id` with the logged-in user's ID.

## Common Issues & Solutions

### Issue 1: Request Saved But Not Showing

**Cause**: Screen not refreshing  
**Solution**: 
1. Close and reopen Share Device screen
2. Or tap the refresh button (top right)
3. Or pull down to refresh

### Issue 2: Wrong Owner ID

**Cause**: Device owned by different user/account  
**Solution**: Make sure you're logged into the account that owns the device

### Issue 3: RLS Policy Blocking

**Cause**: Row Level Security preventing owner from seeing requests  
**Solution**: Run this SQL to check:

```sql
-- Test RLS policy
SELECT * FROM device_share_requests 
WHERE owner_id = auth.uid();
```

If this returns nothing but the first query shows requests, RLS is blocking.

### Issue 4: Profiles Table Mismatch

**Cause**: Foreign keys reference profiles but user IDs don't match  
**Solution**: Check if profiles.id matches auth.users.id:

```sql
-- Check profile IDs
SELECT 
    au.id AS auth_user_id,
    p.id AS profile_id,
    au.email
FROM auth.users au
LEFT JOIN profiles p ON p.id = au.id
LIMIT 10;
```

## Testing Steps

### As Owner (Device Owner):
1. Open device → Share Device
2. Tap refresh button (top right) ✅
3. Look for "Pending Requests" section
4. Should see requests there

### As Recipient (Scanner):
1. Scan QR code
2. Send request
3. Check for success message
4. Wait for owner to approve

## Force Refresh

If owner still doesn't see requests:

1. **Close app completely** (don't just minimize)
2. **Reopen app**
3. **Go to Share Device screen**
4. **Tap refresh button**

## Debug Checklist

- [ ] Request appears in database (run debug SQL)
- [ ] Owner is logged into correct account
- [ ] Device belongs to logged-in user
- [ ] Refresh button works
- [ ] Pull-to-refresh works
- [ ] RLS policies allow owner to see requests
- [ ] Profile IDs match auth user IDs

## Still Not Working?

Run the complete debug script:

**File**: `supabase_migrations/debug_sharing_requests.sql`

This shows:
- All share requests
- All invitations
- All shared devices
- Helps identify the issue

## Next Steps

1. ✅ Restart app
2. ✅ Open Share Device screen
3. ✅ Tap refresh button
4. ✅ Check for pending requests

If still not showing, run debug SQL and check the results.

---

**Refresh button**: Added ✅  
**Pull-to-refresh**: Added ✅  
**Debug tools**: Ready ✅
