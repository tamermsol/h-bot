#!/usr/bin/env python3
"""Second pass: fix remaining hardcoded English strings."""
import re

new_keys = {
    # notifications_settings_screen
    'notif_enabled_success': ('Notifications enabled successfully', 'تم تفعيل الإشعارات بنجاح'),
    'notif_disabled': ('Notifications disabled', 'تم إيقاف الإشعارات'),
    'notif_permission_denied': ('Notification permission was denied. You can enable it later from your device settings or try again.', 'تم رفض إذن الإشعارات. يمكنك تفعيله لاحقاً من إعدادات جهازك أو المحاولة مجدداً.'),
    'notif_permission_permanent': ('Notification permission is permanently denied. Please enable it from your device settings to receive notifications.', 'إذن الإشعارات مرفوض بشكل دائم. يرجى تفعيله من إعدادات جهازك لتلقي الإشعارات.'),
    'notif_turn_on': ('Turn on to receive notifications', 'قم بالتفعيل لتلقي الإشعارات'),
    'notif_permission_required': ('Permission Required', 'مطلوب إذن'),
    'notif_permission_required_desc': ('Notification permission is required to receive alerts. Enable notifications above to grant permission.', 'إذن الإشعارات مطلوب لتلقي التنبيهات. قم بتفعيل الإشعارات أعلاه لمنح الإذن.'),

    # homes_screen
    'homes_no_homes': ('No Homes Yet', 'لا توجد منازل بعد'),
    'homes_delete_home': ('Delete Home', 'حذف المنزل'),
    'homes_created': ('Created', 'أُنشئ'),
    'homes_today': ('Today', 'اليوم'),
    'homes_yesterday': ('Yesterday', 'أمس'),
    'homes_days_ago': ('days ago', 'أيام مضت'),

    # rooms_screen
    'rooms_tap_manage': ('Tap to manage devices', 'اضغط لإدارة الأجهزة'),

    # profile_screen
    'profile_password_min': ('Password must be at least 6 characters', 'يجب أن تكون كلمة المرور 6 أحرف على الأقل'),
    'profile_loading': ('Loading...', 'جارٍ التحميل...'),

    # feedback_screen (long text)
    'feedback_help_improve_desc': ('Help us improve HBOT by sharing your thoughts, suggestions, or reporting issues', 'ساعدنا في تحسين HBOT بمشاركة أفكارك أو اقتراحاتك أو الإبلاغ عن مشاكل'),
}

# Add keys to app_strings.dart
with open('lib/l10n/app_strings.dart', 'r') as f:
    content = f.read()

existing = set(re.findall(r"'([a-z_0-9]+)':", content))
en_entries = []
ar_entries = []
for key, (en, ar) in new_keys.items():
    if key not in existing:
        en_esc = en.replace("'", "\\'")
        ar_esc = ar.replace("'", "\\'")
        en_entries.append(f"      '{key}': '{en_esc}',")
        ar_entries.append(f"      '{key}': '{ar_esc}',")

if en_entries:
    ar_start = content.index("'ar': {"); bc = 0
    for i in range(ar_start, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0: ar_end = i; break
    content = content[:ar_end] + '\n' + '\n'.join(ar_entries) + '\n    ' + content[ar_end:]

    en_start = content.index("'en': {"); bc = 0
    for i in range(en_start, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0: en_end = i; break
    content = content[:en_end] + '\n' + '\n'.join(en_entries) + '\n    ' + content[en_end:]

with open('lib/l10n/app_strings.dart', 'w') as f:
    f.write(content)
print(f'Added {len(en_entries)} new keys')

# ---- Fix notifications_settings_screen.dart ----
fp = 'lib/screens/notifications_settings_screen.dart'
with open(fp) as f: c = f.read()

replacements = [
    ("'Notifications enabled successfully'", "AppStrings.get('notif_enabled_success')"),
    ("'Notifications disabled'", "AppStrings.get('notif_disabled')"),
    ("'Turn on to receive notifications'", "AppStrings.get('notif_turn_on')"),
    ("'Permission Required'", "AppStrings.get('notif_permission_required')"),
    ("'Notification permission is required to receive alerts. Enable notifications above to grant permission.'", "AppStrings.get('notif_permission_required_desc')"),
    # Long strings
    ("'Notification permission was denied. You can enable it later from your device settings or try again.'", "AppStrings.get('notif_permission_denied')"),
    ("'Notification permission is permanently denied. Please enable it from your device settings to receive notifications.'", "AppStrings.get('notif_permission_permanent')"),
    # These might be description: parameters
    ("description: 'When a device goes offline'", "description: AppStrings.get('notifications_settings_device_offline_desc')"),
    ("description: 'When a device comes back online'", "description: AppStrings.get('notifications_settings_device_online_desc')"),
    ("description: 'When a scene or automation runs'", "description: AppStrings.get('notifications_settings_scene_executed_desc')"),
    ("description: 'When a device is turned on/off'", "description: AppStrings.get('notifications_settings_state_changes_desc')"),
]
count = 0
for old, new in replacements:
    if old in c:
        c = c.replace(old, new)
        count += 1
c = re.sub(r'const\s+(Text\s*\(\s*AppStrings)', r'\1', c)
c = re.sub(r'const\s+(SnackBar[^)]*AppStrings)', r'\1', c)
with open(fp, 'w') as f: f.write(c)
print(f'{fp}: {count} fixes')

# ---- Fix feedback_screen.dart ----
fp = 'lib/screens/feedback_screen.dart'
with open(fp) as f: c = f.read()
replacements = [
    ("'Help us improve HBOT by sharing your thoughts, suggestions, or reporting issues'", "AppStrings.get('feedback_help_improve_desc')"),
]
# The multiline hint text
old_hint = "'Tell us what you think...\\n\\nYou can share:\\n\u2022 Feature suggestions\\n\u2022 Bug reports\\n\u2022 General feedback\\n\u2022 Questions or concerns'"
if old_hint in c:
    c = c.replace(old_hint, "AppStrings.get('feedback_tell_us')")
    count2 = 1
else:
    count2 = 0
    # Try alternate form
    for old, new in replacements:
        if old in c:
            c = c.replace(old, new)
            count2 += 1
c = re.sub(r'const\s+(Text\s*\(\s*AppStrings)', r'\1', c)
with open(fp, 'w') as f: f.write(c)
print(f'{fp}: {count2} fixes')

# ---- Fix homes_screen.dart ----
fp = 'lib/screens/homes_screen.dart'
with open(fp) as f: c = f.read()

# Fix _formatDate to use localized strings
old_format = """  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }"""

new_format = """  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return AppStrings.get('homes_today');
    } else if (difference.inDays == 1) {
      return AppStrings.get('homes_yesterday');
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${AppStrings.get('homes_days_ago')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }"""

count3 = 0
if old_format in c:
    c = c.replace(old_format, new_format)
    count3 += 1

# Fix "Created ..."
c = c.replace("'Created ${_formatDate(home.createdAt)}'", "'${AppStrings.get('homes_created')} ${_formatDate(home.createdAt)}'")
c = c.replace("'No Homes Yet'", "AppStrings.get('homes_no_homes')")
c = c.replace("'Delete Home'", "AppStrings.get('homes_delete_home')")
count3 += 3

c = re.sub(r'const\s+(Text\s*\(\s*AppStrings)', r'\1', c)
with open(fp, 'w') as f: f.write(c)
print(f'{fp}: {count3} fixes')

# ---- Fix rooms_screen.dart ----
fp = 'lib/screens/rooms_screen.dart'
with open(fp) as f: c = f.read()
c = c.replace("'Tap to manage devices'", "AppStrings.get('rooms_tap_manage')")
c = re.sub(r'const\s+(Text\s*\(\s*AppStrings)', r'\1', c)
with open(fp, 'w') as f: f.write(c)
print(f'{fp}: 1 fix')

# ---- Fix profile_screen.dart ----
fp = 'lib/screens/profile_screen.dart'
with open(fp) as f: c = f.read()
c = c.replace("'Password must be at least 6 characters'", "AppStrings.get('profile_password_min')")
c = c.replace("_userName ?? 'Loading...'", "_userName ?? AppStrings.get('profile_loading')")

# Fix the change password description — try both quote styles
c = c.replace(
    "\"We'll send a verification code to your email to confirm your identity.\"",
    "AppStrings.get('profile_change_password_desc')"
)
c = c.replace(
    "'We\\'ll send a verification code to your email to confirm your identity.'",
    "AppStrings.get('profile_change_password_desc')"
)
c = c.replace(
    "\"We'll send a verification code to your\\nemail to confirm your identity.\"",
    "AppStrings.get('profile_change_password_desc')"
)
c = re.sub(r'const\s+(Text\s*\(\s*AppStrings)', r'\1', c)
with open(fp, 'w') as f: f.write(c)
print(f'{fp}: done')

print('\nAll fixes applied!')
