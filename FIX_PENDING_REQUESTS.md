# Fix: Owner Not Seeing Pending Requests

## What I Fixed ✅

Added refresh functionality to Share Device screen:
- Refresh button (top right)
- Pull-to-refresh (pull down)
- Auto-refresh when screen opens

## What You Need To Do

### 1. Restart Your App

```bash
flutter run
```

### 2. Test the Refresh

**As Owner:**
1. Open device → Share Device
2. Tap refresh icon (top right) ✅
3. Or pull down to refresh ✅
4. Pending requests should appear

### 3. If Still Not Showing

Run this SQL in Supabase to check if request exists:

```sql
SELECT 
    requester_email,
    status,
    requested_at
FROM device_share_requests
ORDER BY requested_at DESC
LIMIT 5;
```

If you see the request there, it means:
- Request was saved ✅
- Just need to refresh the screen ✅

## Quick Test

1. Recipient: Scan QR → Send request
2. Owner: Open Share Device screen
3. Owner: Tap refresh button
4. Owner: Should see request! ✅

---

**Time**: 1 minute  
**Refresh added**: ✅  
**See**: `TROUBLESHOOT_SHARING_REQUESTS.md` for detailed debugging
