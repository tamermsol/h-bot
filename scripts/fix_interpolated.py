#!/usr/bin/env python3
"""Fix interpolated strings by replacing them with AppStrings.get() + variable concat"""
import os

def fix_file(filepath, replacements):
    """Apply list of (old, new) replacements to a file"""
    with open(filepath, 'r') as f:
        content = f.read()
    
    count = 0
    for old, new in replacements:
        if old in content:
            content = content.replace(old, new, 1)
            count += 1
    
    if count > 0:
        # Add import if needed
        if "import '../l10n/app_strings.dart';" not in content:
            last_import = content.rfind("import '")
            if last_import >= 0:
                end = content.index('\n', last_import) + 1
                content = content[:end] + "import '../l10n/app_strings.dart';\n" + content[end:]
        
        with open(filepath, 'w') as f:
            f.write(content)
    
    return count

total = 0

# reset_password_screen.dart
n = fix_file('lib/screens/reset_password_screen.dart', [
    ("Text('Failed to reset password: ${e.toString()}')",
     "Text('${AppStrings.get(\"error_reset_password\")}: ${e.toString()}')"),
    ("Text('Failed to resend code: ${e.toString()}')",
     "Text('${AppStrings.get(\"error_resend_code\")}: ${e.toString()}')"),
])
if n: print(f'  📝 reset_password_screen.dart: {n}'); total += n

# devices_screen.dart
n = fix_file('lib/screens/devices_screen.dart', [
    ("Text('Failed to control shutter: ${e.toString()}')",
     "Text('${AppStrings.get(\"error_control_shutter\")}: ${e.toString()}')"),
    ("Text('Failed to control device: ${e.toString()}')",
     "Text('${AppStrings.get(\"error_control_device\")}: ${e.toString()}')"),
    ('Text(\'Device "${device.deviceName}" deleted successfully\')',
     "Text('${AppStrings.get(\"success_device_deleted\")}: ${device.deviceName}')"),
])
if n: print(f'  📝 devices_screen.dart: {n}'); total += n

# sign_in_screen.dart
n = fix_file('lib/screens/sign_in_screen.dart', [
    ("Text('Google sign-in error: ${e.toString()}')",
     "Text('${AppStrings.get(\"error_google_sign_in\")}: ${e.toString()}')"),
])
if n: print(f'  📝 sign_in_screen.dart: {n}'); total += n

# homes_screen.dart
n = fix_file('lib/screens/homes_screen.dart', [
    ('Text(\'Home "${home.name}" created successfully!\')',
     "Text('${AppStrings.get(\"success_home_created\")}: ${home.name}')"),
    ('Text(\'Home "${home.name}" deleted successfully!\')',
     "Text('${AppStrings.get(\"success_home_deleted\")}: ${home.name}')"),
])
if n: print(f'  📝 homes_screen.dart: {n}'); total += n

# device_control_screen.dart
n = fix_file('lib/screens/device_control_screen.dart', [
    ("Text('Failed to control channel $channel: $e')",
     "Text('${AppStrings.get(\"error_control_channel\")}: $e')"),
    ("Text('Channel $channel renamed successfully')",
     "Text('${AppStrings.get(\"success_channel_renamed\")}')"),
    ("Text('Failed to rename channel: $e')",
     "Text('${AppStrings.get(\"error_rename_channel\")}: $e')"),
    ("Text('Channel $channel changed to $typeName')",
     "Text('${AppStrings.get(\"success_channel_type_changed\")}')"),
    ("Text('Failed to update channel type: $e')",
     "Text('${AppStrings.get(\"error_update_channel_type\")}: $e')"),
    ("Text('Failed to load rooms: $e')",
     "Text('${AppStrings.get(\"error_load_rooms\")}: $e')"),
    ("Text('Failed to move device: $e')",
     "Text('${AppStrings.get(\"error_move_device\")}: $e')"),
    ("Text('Failed to refresh: $e')",
     "Text('${AppStrings.get(\"error_refresh\")}: $e')"),
])
if n: print(f'  📝 device_control_screen.dart: {n}'); total += n

# add_scene_screen.dart
n = fix_file('lib/screens/add_scene_screen.dart', [
    ("Text('Failed to load scene data: $e')",
     "Text('${AppStrings.get(\"error_load_scene_data\")}: $e')"),
    ("label: Text('Channel $channelNum')",
     "label: Text('${AppStrings.get(\"scene_channel\")} $channelNum')"),
    ("Text('Failed to detect location: $e')",
     "Text('${AppStrings.get(\"error_detect_location\")}: $e')"),
])
if n: print(f'  📝 add_scene_screen.dart: {n}'); total += n

# profile_screen.dart
n = fix_file('lib/screens/profile_screen.dart', [
    ("Text('Could not load home: $e')",
     "Text('${AppStrings.get(\"error_load_home\")}: $e')"),
    ("Text('Error signing out: $e')",
     "Text('${AppStrings.get(\"error_signing_out\")}: $e')"),
])
if n: print(f'  📝 profile_screen.dart: {n}'); total += n

# scan_device_qr_screen.dart
n = fix_file('lib/screens/scan_device_qr_screen.dart', [
    ("Text('Device: $deviceName')",
     "Text('${AppStrings.get(\"scan_qr_device\")}: $deviceName')"),
])
if n: print(f'  📝 scan_device_qr_screen.dart: {n}'); total += n

# home_dashboard_screen.dart
n = fix_file('lib/screens/home_dashboard_screen.dart', [
    ("Text('Refreshed ${controllableDevices.length} devices')",
     "Text('${AppStrings.get(\"dashboard_refreshed\")} ${controllableDevices.length} ${AppStrings.get(\"common_devices\")}')"),
    ("Text('Failed to update background: $e')",
     "Text('${AppStrings.get(\"error_update_background\")}: $e')"),
    ("Text('Failed to control shutter: ${e.toString()}')",
     "Text('${AppStrings.get(\"error_control_shutter\")}: ${e.toString()}')"),
    ("Text('Failed to control ${device.name}: ${e.toString()}')",
     "Text('${AppStrings.get(\"error_control_device\")}: ${device.name} - ${e.toString()}')"),
])
if n: print(f'  📝 home_dashboard_screen.dart: {n}'); total += n

# rooms_screen.dart
n = fix_file('lib/screens/rooms_screen.dart', [
    ('Text(\'Room "${room.name}" created successfully!\')',
     "Text('${AppStrings.get(\"success_room_created\")}: ${room.name}')"),
    ('Text(\'Room "${updatedRoom.name}" updated successfully!\')',
     "Text('${AppStrings.get(\"success_room_updated\")}: ${updatedRoom.name}')"),
    ('Text(\'Room "${room.name}" deleted successfully!\')',
     "Text('${AppStrings.get(\"success_room_deleted\")}: ${room.name}')"),
])
if n: print(f'  📝 rooms_screen.dart: {n}'); total += n

# widgets
n = fix_file('lib/widgets/enhanced_device_control_widget.dart', [
    ("Text('Failed to control channel $channel: $e')",
     "Text('${AppStrings.get(\"error_control_channel\")}: $e')"),
])
if n: print(f'  📝 enhanced_device_control_widget.dart: {n}'); total += n

n = fix_file('lib/widgets/wifi_permission_gate.dart', [
    ("Text('Failed to request permissions: $e')",
     "Text('${AppStrings.get(\"error_request_permissions\")}: $e')"),
])
if n: print(f'  📝 wifi_permission_gate.dart: {n}'); total += n

n = fix_file('lib/widgets/device_control_widget.dart', [
    ("Text('Failed to control channel $channel: $e')",
     "Text('${AppStrings.get(\"error_control_channel\")}: $e')"),
])
if n: print(f'  📝 device_control_widget.dart: {n}'); total += n

print(f'\n✅ Total: {total} interpolated strings fixed')
