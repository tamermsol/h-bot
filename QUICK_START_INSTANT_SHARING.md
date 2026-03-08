# Quick Start: Instant Device Sharing

## Step 1: Apply Database Migration

Open your Supabase SQL Editor and run:

```sql
-- Copy the entire contents of supabase_migrations/instant_device_sharing.sql
```

Or run this command if you have Supabase CLI:

```bash
supabase db push
```

## Step 2: Restart Your App

Close and restart the app to reload the dashboard with shared devices support.

## Step 3: Test Sharing

### On Device A (Owner):
1. Open the app
2. Go to **Profile** tab
3. Tap **Share Device**
4. Select a device to share
5. Authenticate with fingerprint/face/PIN
6. Show the QR code to the other person

### On Device B (Recipient):
1. Open the app
2. Go to **Profile** tab
3. Tap **Shared Devices**
4. Tap the **camera icon** (QR scanner button)
5. Scan the QR code from Device A
6. Tap **Add Device** to confirm
7. Go to **Dashboard** - the device should appear immediately!

## That's It!

The shared device now appears in the recipient's dashboard and can be controlled just like their own devices.

## Visual Guide

```
Owner Device                    Recipient Device
    |                                |
    v                                v
Profile Tab                     Profile Tab
    |                                |
    v                                v
Share Device                    Shared Devices
    |                                |
    v                                v
Select Device                   Tap Camera Icon
    |                                |
    v                                v
Authenticate                    Scan QR Code
    |                                |
    v                                v
Show QR Code  ----------------> Confirm Add
                                     |
                                     v
                              Device in Dashboard!
```

## Troubleshooting

**Shared device doesn't appear in dashboard?**
- Make sure you applied the database migration
- Restart the app completely
- Check that the QR code hasn't expired (24 hours)

**Can't control the shared device?**
- Check your internet connection
- Verify the device is online (green dot)
- Make sure you have 'control' permission (not just 'view')

**QR scanner doesn't open?**
- Grant camera permissions to the app
- Check that your device has a working camera

## Need Help?

Check the full documentation in `INSTANT_DEVICE_SHARING_COMPLETE.md`
