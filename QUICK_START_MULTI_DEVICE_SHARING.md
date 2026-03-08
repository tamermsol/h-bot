# Quick Start: Multi-Device Sharing

## Step 1: Apply RLS Fix (If Not Done Yet)

Run this in Supabase SQL Editor:

```sql
DROP POLICY IF EXISTS "Users can add shared devices" ON shared_devices;

CREATE POLICY "Users can add shared devices"
    ON shared_devices FOR INSERT
    WITH CHECK (auth.uid() = shared_with_id);
```

## Step 2: Test Multi-Device Sharing

### On Device A (Owner):

1. Open app
2. Go to **Profile** tab
3. Tap **Share Multiple Devices** (new option!)
4. Select 2-3 devices by checking them
5. Tap **Generate QR** button
6. Authenticate with fingerprint/face/PIN
7. Show the QR code to Device B

### On Device B (Recipient):

1. Open app
2. Go to **Profile** tab
3. Tap **Shared with Me**
4. Tap the **camera icon**
5. Scan the QR code from Device A
6. Review the list of devices
7. Tap **Add All**
8. Go to **Dashboard** - all devices should appear!

## Step 3: Test Auto Home/Room Creation

### On Device C (Brand New User):

1. Sign up with a new account
2. **Don't create any homes** (skip setup)
3. Go to **Profile** → **Shared with Me** → Camera icon
4. Scan a QR code from Device A
5. Confirm addition
6. Check **Dashboard** - devices appear!
7. Check **Homes** - "Shared Devices" home was auto-created!

## Visual Guide

```
Owner (Device A)                    Recipient (Device B)
      |                                    |
      v                                    v
Profile Tab                          Profile Tab
      |                                    |
      v                                    v
Share Multiple Devices               Shared with Me
      |                                    |
      v                                    v
Select 3 devices                     Tap Camera Icon
      |                                    |
      v                                    v
Generate QR                          Scan QR Code
      |                                    |
      v                                    v
Authenticate                         See 3 devices listed
      |                                    |
      v                                    v
Show QR Code  --------------------> Tap "Add All"
                                           |
                                           v
                                    All 3 devices in dashboard!
```

## Features

✅ Share multiple devices with one QR code
✅ Auto-creates home/room for new users
✅ Works with existing single-device sharing
✅ Same security (biometric auth, expiring codes)
✅ Instant access - no approval needed

## Comparison

**Before:**
- Share 5 devices = Generate 5 QR codes
- Recipient scans 5 times
- New users must create home manually

**After:**
- Share 5 devices = Generate 1 QR code
- Recipient scans once
- New users get auto-created home
- Much faster and easier!

## Need Help?

- Full documentation: `MULTI_DEVICE_SHARING_COMPLETE.md`
- RLS fix: `APPLY_THIS_SQL_NOW.md`
- Original sharing docs: `INSTANT_DEVICE_SHARING_COMPLETE.md`
