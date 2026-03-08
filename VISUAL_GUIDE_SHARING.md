# Visual Guide: Device Sharing Features

## Feature 1: Single Device Sharing

```
┌─────────────────────────────────────────────────────────────┐
│                    SINGLE DEVICE SHARING                     │
└─────────────────────────────────────────────────────────────┘

Owner (Device A)                    Recipient (Device B)
─────────────────                   ────────────────────

1. Profile Tab                      1. Profile Tab
   ↓                                   ↓
2. Shared with Me                   2. Shared with Me
   ↓                                   ↓
3. Select Device                    3. Tap Camera Icon
   ↓                                   ↓
4. Generate QR                      4. Scan QR Code
   ↓                                   ↓
5. Authenticate 🔐                  5. Confirm "Add Device"
   ↓                                   ↓
6. Show QR Code ─────────────────> 6. Device Added! ✅
                                       ↓
                                   7. Appears in Dashboard
```

## Feature 2: Multi-Device Sharing

```
┌─────────────────────────────────────────────────────────────┐
│                  MULTI-DEVICE SHARING (NEW!)                 │
└─────────────────────────────────────────────────────────────┘

Owner (Device A)                    Recipient (Device B)
─────────────────                   ────────────────────

1. Profile Tab                      1. Profile Tab
   ↓                                   ↓
2. Share Multiple Devices 🆕        2. Shared with Me
   ↓                                   ↓
3. Select 3 Devices ☑️☑️☑️           3. Tap Camera Icon
   ↓                                   ↓
4. Generate QR                      4. Scan QR Code (once!)
   ↓                                   ↓
5. Authenticate 🔐                  5. See 3 Devices Listed
   ↓                                   ↓
6. Show QR Code ─────────────────> 6. Tap "Add All"
                                       ↓
                                   7. All 3 Devices Added! ✅
                                       ↓
                                   8. All in Dashboard
```

## Feature 3: Auto Home/Room Creation

```
┌─────────────────────────────────────────────────────────────┐
│              AUTO HOME/ROOM CREATION (NEW!)                  │
└─────────────────────────────────────────────────────────────┘

New User (Device C) - No Homes Yet
───────────────────────────────────

1. Sign Up
   ↓
2. Skip Home Creation
   ↓
3. Profile → Shared with Me → Camera
   ↓
4. Scan QR Code
   ↓
5. System Auto-Creates:
   ┌──────────────────────────┐
   │ Home: "Shared Devices"   │
   │ Room: "Shared Devices"   │
   └──────────────────────────┘
   ↓
6. Devices Added to New Home
   ↓
7. Ready to Use! ✅
```

## UI Screens

### Profile Screen (Modified)
```
┌─────────────────────────────────┐
│          Profile                │
├─────────────────────────────────┤
│                                 │
│  👤 User Name                   │
│  📧 user@email.com              │
│                                 │
├─────────────────────────────────┤
│  🏠 Manage Homes                │
│  🔔 Notifications               │
│  👥 Shared with Me              │
│  📱 Share Multiple Devices 🆕   │ ← NEW!
│  ⚙️  Settings                   │
│  ℹ️  Help & Support             │
└─────────────────────────────────┘
```

### Multi-Device Share Screen (New)
```
┌─────────────────────────────────┐
│   Share Multiple Devices        │
├─────────────────────────────────┤
│  3 devices selected             │
│  [Clear]  [Generate QR]         │
├─────────────────────────────────┤
│                                 │
│  ☑️ Living Room Light           │
│  ☑️ Bedroom Fan                 │
│  ☐ Kitchen Light                │
│  ☑️ Garage Door                 │
│  ☐ Bathroom Heater              │
│                                 │
└─────────────────────────────────┘
```

### QR Code Display (Multi-Device)
```
┌─────────────────────────────────┐
│                                 │
│     ┌─────────────────┐         │
│     │                 │         │
│     │   QR CODE       │         │
│     │   [█████████]   │         │
│     │   [█████████]   │         │
│     │                 │         │
│     └─────────────────┘         │
│                                 │
│   Sharing 3 device(s)           │
│                                 │
│   [Cancel QR Code]              │
│                                 │
└─────────────────────────────────┘
```

### Scan Confirmation (Multi-Device)
```
┌─────────────────────────────────┐
│   Add Shared Devices?           │
├─────────────────────────────────┤
│                                 │
│  3 device(s) will be added:     │
│                                 │
│  • Living Room Light            │
│  • Bedroom Fan                  │
│  • Garage Door                  │
│                                 │
├─────────────────────────────────┤
│  [Cancel]        [Add All]      │
└─────────────────────────────────┘
```

## Comparison Chart

```
┌──────────────────────────────────────────────────────────────┐
│                    BEFORE vs AFTER                           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  BEFORE (Single Device Only):                                │
│  ────────────────────────────                                │
│  Share 5 devices:                                            │
│    → Generate 5 QR codes                                     │
│    → Recipient scans 5 times                                 │
│    → 5 separate confirmations                                │
│    → New users must create home manually                     │
│                                                              │
│  AFTER (Multi-Device + Auto Home):                           │
│  ──────────────────────────────                              │
│  Share 5 devices:                                            │
│    → Generate 1 QR code ✅                                   │
│    → Recipient scans once ✅                                 │
│    → 1 confirmation for all ✅                               │
│    → New users get auto-created home ✅                      │
│                                                              │
│  Result: 5x faster! 🚀                                       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Security Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                           │
└─────────────────────────────────────────────────────────────┘

1. Owner Authentication
   ├─ Biometric (fingerprint/face) 🔐
   ├─ PIN/Password fallback
   └─ Required before QR generation

2. Invitation Codes
   ├─ Unique per device
   ├─ 32 characters long
   ├─ Expire after 24 hours ⏰
   └─ One-time use

3. RLS Policies
   ├─ Recipients can only add themselves
   ├─ Cannot add others
   ├─ Owner verification
   └─ Permission enforcement

4. Revocation
   ├─ Owner can revoke anytime
   ├─ Immediate effect
   └─ Device removed from recipient
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      DATA FLOW                               │
└─────────────────────────────────────────────────────────────┘

Owner Generates QR:
───────────────────
1. Select device(s)
2. Authenticate
3. Create invitation(s) in DB
4. Generate QR with invitation codes
5. Display QR

Recipient Scans QR:
──────────────────
1. Scan QR code
2. Parse invitation codes
3. Validate invitations (not expired)
4. Check if user has home
   ├─ No → Create "Shared Devices" home/room
   └─ Yes → Use existing home
5. Create shared_device entries
6. Devices appear in dashboard

Dashboard Display:
─────────────────
1. Load owned devices
2. Load shared devices
3. Merge both lists
4. Display all devices
5. MQTT control works for both
```

## Quick Reference

```
┌─────────────────────────────────────────────────────────────┐
│                    QUICK REFERENCE                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Share Single Device:                                        │
│    Profile → Shared with Me → Select → Generate QR          │
│                                                              │
│  Share Multiple Devices:                                     │
│    Profile → Share Multiple Devices → Select → Generate QR  │
│                                                              │
│  Scan QR Code:                                               │
│    Profile → Shared with Me → Camera Icon → Scan            │
│                                                              │
│  View Shared Devices:                                        │
│    Profile → Shared with Me → List                          │
│                                                              │
│  Revoke Access:                                              │
│    Profile → Shared with Me → Device → Delete               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```
