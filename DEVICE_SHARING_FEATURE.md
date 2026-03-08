# Device Sharing Feature Implementation Guide

## Overview
This feature allows users to share their smart home devices with other users via QR codes. The owner generates a QR code, the recipient scans it, and the owner approves the sharing request.

## Database Schema Created
✅ `device_share_invitations` - Temporary QR code invitations (24h expiry)
✅ `device_share_requests` - Pending approval requests
✅ `shared_devices` - Approved device shares with permissions

## Models Created
✅ `DeviceShareInvitation` - lib/models/device_share_invitation.dart
✅ `DeviceShareRequest` - lib/models/device_share_request.dart  
✅ `SharedDevice` - lib/models/shared_device.dart

## Required Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  qr_flutter: ^4.1.0  # For generating QR codes
  mobile_scanner: ^5.2.3  # For scanning QR codes
```

## Implementation Steps

### 1. Run Database Migration
Execute `supabase_migrations/device_sharing_system.sql` in your Supabase SQL editor.

### 2. Generate Model Files
Run: `dart run build_runner build --delete-conflicting-outputs`

### 3. Create Repository (lib/repos/device_sharing_repo.dart)
Handles all database operations for device sharing.

### 4. Create Screens

#### A. Share Device Screen (lib/screens/share_device_screen.dart)
- Shows QR code for device
- Lists pending requests
- Approve/reject requests
- Manage existing shares

#### B. Scan QR Screen (lib/screens/scan_device_qr_screen.dart)
- Camera view for scanning QR codes
- Validates invitation code
- Sends sharing request

#### C. Shared Devices Screen (lib/screens/shared_devices_screen.dart)
- Lists devices shared with you
- Shows permission level
- Access shared device controls

#### D. Share Requests Screen (lib/screens/share_requests_screen.dart)
- View pending requests (for owners)
- Approve/reject with one tap

### 5. Add to Device Control Screen
Add "Share Device" button in device control screen menu.

### 6. Add to Profile/Settings
Add "Shared with Me" option to view devices others shared with you.

## User Flow

### Sharing Flow (Owner):
1. Owner opens device → "Share Device"
2. QR code is generated with invitation code
3. Recipient scans QR code
4. Owner receives notification of share request
5. Owner approves/rejects request
6. If approved, recipient gets access

### Receiving Flow (Recipient):
1. Tap "Scan Device QR" in app
2. Scan owner's QR code
3. Confirm device details
4. Send share request
5. Wait for owner approval
6. Access device from "Shared with Me"

## Security Features
- ✅ QR codes expire after 24 hours
- ✅ Owner must approve all requests
- ✅ Row Level Security (RLS) on all tables
- ✅ Permission levels (view/control)
- ✅ Can revoke access anytime

## Permission Levels
- **View**: Can see device status only
- **Control**: Can control device (turn on/off, adjust settings)

## Next Steps
1. Install dependencies
2. Run migration
3. Generate model files
4. Create repository
5. Create UI screens
6. Test sharing flow
7. Add notifications (optional)

## Notes
- QR codes contain: invitation_code, device_id, device_name
- Invitations auto-cleanup after 24h
- One device can be shared with multiple users
- Owners can revoke access anytime
- Shared devices appear in separate section
