#!/usr/bin/env python3
"""Fix all remaining hardcoded English strings across multiple screens."""
import re
import json

# ============================================================
# Step 1: Collect all hardcoded strings from target screens
# ============================================================

# Map: file -> list of (english_string, app_strings_key)
# We'll add new keys to app_strings.dart as needed

fixes_by_file = {}

# ---- notifications_settings_screen.dart ----
fixes_by_file['lib/screens/notifications_settings_screen.dart'] = [
    ("'Notification Preferences'", "AppStrings.get('notifications_settings_notification_preferences')"),
    ("'Manage how you receive notifications from HBOT'", "AppStrings.get('notifications_settings_manage_desc')"),
    ("'Enable Notifications'", "AppStrings.get('notifications_settings_enable_notifications')"),
    ("'You will receive notifications about device status, automations, and updates'", "AppStrings.get('notifications_settings_enable_desc')"),
    ("'Notification Types'", "AppStrings.get('notifications_settings_notification_types')"),
    ("title: 'Device Offline'", "title: AppStrings.get('notifications_settings_device_offline')"),
    ("subtitle: 'When a device goes offline'", "subtitle: AppStrings.get('notifications_settings_device_offline_desc')"),
    ("title: 'Device Online'", "title: AppStrings.get('notifications_settings_device_online')"),
    ("subtitle: 'When a device comes back online'", "subtitle: AppStrings.get('notifications_settings_device_online_desc')"),
    ("title: 'Scene Executed'", "title: AppStrings.get('notifications_settings_scene_executed')"),
    ("subtitle: 'When a scene or automation runs'", "subtitle: AppStrings.get('notifications_settings_scene_executed_desc')"),
    ("title: 'State Changes'", "title: AppStrings.get('notifications_settings_state_changes')"),
    ("subtitle: 'When a device is turned on/off'", "subtitle: AppStrings.get('notifications_settings_state_changes_desc')"),
]

# ---- feedback_screen.dart ----
fixes_by_file['lib/screens/feedback_screen.dart'] = [
    ("'We value your feedback'", "AppStrings.get('feedback_we_value_your_feedback')"),
    ("'Help improve HBOT by sharing your thoughts, suggestions, or reporting issues'", "AppStrings.get('feedback_help_improve')"),
    ("'Your Feedback'", "AppStrings.get('feedback_your_feedback')"),
    ("'Tell us what you think...'", "AppStrings.get('feedback_tell_us')"),
    ("'You can share:'", "AppStrings.get('feedback_you_can_share')"),
    ("'Feature suggestions'", "AppStrings.get('feedback_feature_suggestions')"),
    ("'Bug reports'", "AppStrings.get('feedback_bug_reports')"),
    ("'General feedback'", "AppStrings.get('feedback_general_feedback')"),
    ("'Questions or concerns'", "AppStrings.get('feedback_questions_concerns')"),
    ("'Send via'", "AppStrings.get('feedback_send_via')"),
    ("'Your feedback matters'", "AppStrings.get('feedback_matters')"),
    ("'We read every message and use your feedback to improve HBOT. We typically respond within 24 hours during business days.'", "AppStrings.get('feedback_response_time')"),
]

# ---- profile_edit_screen.dart ----
fixes_by_file['lib/screens/profile_edit_screen.dart'] = [
    ("'Update your profile information. Phone numbers must be in E.164 format (e.g., +1234567890).'", "AppStrings.get('profile_edit_info_desc')"),
    ("'Update Profile'", "AppStrings.get('profile_edit_update_profile')"),
    ("'Save'", "AppStrings.get('common_save')"),
]

# ---- homes_screen.dart ----
fixes_by_file['lib/screens/homes_screen.dart'] = [
    ("'My Homes'", "AppStrings.get('homes_my_homes')"),
    ("'Created Today'", "AppStrings.get('homes_created_today')"),
]

# ---- rooms_screen.dart ----
fixes_by_file['lib/screens/rooms_screen.dart'] = [
    ("'No Rooms Yet'", "AppStrings.get('rooms_no_rooms_yet')"),
    ("'Add rooms to organize your smart devices by location'", "AppStrings.get('rooms_add_rooms_desc')"),
    ("'Your First Room'", "AppStrings.get('rooms_your_first_room')"),
]

# ---- profile_screen.dart (change password dialog) ----
fixes_by_file['lib/screens/profile_screen.dart'] = [
    ("'Change Password'", "AppStrings.get('change_password')"),
    ("'Verify Email'", "AppStrings.get('profile_verify_email')"),
    ("'New Password'", "AppStrings.get('profile_new_password')"),
    ("\"We'll send a verification code to your email to confirm your identity.\"", "AppStrings.get('profile_change_password_desc')"),
    ("'We\\'ll send a verification code to your email to confirm your identity.'", "AppStrings.get('profile_change_password_desc')"),
]

# ---- home_dashboard_screen.dart ----
fixes_by_file['lib/screens/home_dashboard_screen.dart'] = [
    ("'View & Filter Options'", "AppStrings.get('home_dashboard_view_filter_options')"),
]

# ============================================================
# Step 2: Define new keys (en + ar) that might not exist yet
# ============================================================
new_keys = {
    'notifications_settings_manage_desc': ('Manage how you receive notifications from HBOT', 'إدارة طريقة تلقي الإشعارات من HBOT'),
    'notifications_settings_enable_desc': ('You will receive notifications about device status, automations, and updates', 'ستتلقى إشعارات حول حالة الأجهزة والأتمتة والتحديثات'),
    'notifications_settings_notification_types': ('Notification Types', 'أنواع الإشعارات'),
    'notifications_settings_device_offline': ('Device Offline', 'الجهاز غير متصل'),
    'notifications_settings_device_offline_desc': ('When a device goes offline', 'عندما يصبح الجهاز غير متصل'),
    'notifications_settings_device_online': ('Device Online', 'الجهاز متصل'),
    'notifications_settings_device_online_desc': ('When a device comes back online', 'عندما يعود الجهاز للاتصال'),
    'notifications_settings_scene_executed': ('Scene Executed', 'تم تنفيذ السيناريو'),
    'notifications_settings_scene_executed_desc': ('When a scene or automation runs', 'عندما يتم تشغيل سيناريو أو أتمتة'),
    'notifications_settings_state_changes': ('State Changes', 'تغييرات الحالة'),
    'notifications_settings_state_changes_desc': ('When a device is turned on/off', 'عندما يتم تشغيل/إيقاف جهاز'),
    'feedback_help_improve': ('Help improve HBOT by sharing your thoughts, suggestions, or reporting issues', 'ساعد في تحسين HBOT بمشاركة أفكارك أو اقتراحاتك أو الإبلاغ عن مشاكل'),
    'feedback_your_feedback': ('Your Feedback', 'ملاحظاتك'),
    'feedback_tell_us': ('Tell us what you think...', 'أخبرنا برأيك...'),
    'feedback_you_can_share': ('You can share:', 'يمكنك مشاركة:'),
    'feedback_feature_suggestions': ('Feature suggestions', 'اقتراحات ميزات'),
    'feedback_bug_reports': ('Bug reports', 'تقارير أخطاء'),
    'feedback_general_feedback': ('General feedback', 'ملاحظات عامة'),
    'feedback_questions_concerns': ('Questions or concerns', 'أسئلة أو استفسارات'),
    'feedback_send_via': ('Send via', 'إرسال عبر'),
    'feedback_matters': ('Your feedback matters', 'ملاحظاتك مهمة'),
    'feedback_response_time': ('We read every message and use your feedback to improve HBOT. We typically respond within 24 hours during business days.', 'نقرأ كل رسالة ونستخدم ملاحظاتك لتحسين HBOT. نستجيب عادةً خلال 24 ساعة في أيام العمل.'),
    'profile_edit_info_desc': ('Update your profile information. Phone numbers must be in E.164 format (e.g., +1234567890).', 'تحديث معلومات ملفك الشخصي. يجب أن تكون أرقام الهاتف بتنسيق E.164 (مثال: +1234567890).'),
    'common_save': ('Save', 'حفظ'),
    'homes_created_today': ('Created Today', 'أُنشئ اليوم'),
    'rooms_add_rooms_desc': ('Add rooms to organize your smart devices by location', 'أضف غرفاً لتنظيم أجهزتك الذكية حسب الموقع'),
    'rooms_your_first_room': ('Your First Room', 'غرفتك الأولى'),
    'profile_verify_email': ('Verify Email', 'تأكيد البريد'),
    'profile_new_password': ('New Password', 'كلمة مرور جديدة'),
    'profile_change_password_desc': ("We'll send a verification code to your email to confirm your identity.", 'سنرسل رمز تحقق إلى بريدك الإلكتروني لتأكيد هويتك.'),
}

# ============================================================
# Step 3: Add new keys to app_strings.dart
# ============================================================
with open('lib/l10n/app_strings.dart', 'r') as f:
    content = f.read()

existing_keys = set(re.findall(r"'([a-z_0-9]+)':", content))

en_entries = []
ar_entries = []
for key, (en, ar) in new_keys.items():
    if key not in existing_keys:
        # Escape single quotes in values
        en_esc = en.replace("'", "\\'")
        ar_esc = ar.replace("'", "\\'")
        en_entries.append(f"      '{key}': '{en_esc}',")
        ar_entries.append(f"      '{key}': '{ar_esc}',")

if en_entries:
    # Find end of 'en' dict
    en_start = content.index("'en': {")
    bc = 0
    en_end = None
    for i in range(en_start, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0:
                en_end = i
                break

    # Find end of 'ar' dict
    ar_start = content.index("'ar': {")
    bc = 0
    ar_end = None
    for i in range(ar_start, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0:
                ar_end = i
                break

    # Insert ar first (so en positions don't shift)
    content = content[:ar_end] + '\n' + '\n'.join(ar_entries) + '\n    ' + content[ar_end:]

    # Recalculate en_end
    en_start = content.index("'en': {")
    bc = 0
    for i in range(en_start, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0:
                en_end = i
                break

    content = content[:en_end] + '\n' + '\n'.join(en_entries) + '\n    ' + content[en_end:]

    with open('lib/l10n/app_strings.dart', 'w') as f:
        f.write(content)

print(f'Added {len(en_entries)} new keys to app_strings.dart')

# ============================================================
# Step 4: Apply replacements in each file
# ============================================================
total_fixes = 0
for filepath, replacements in fixes_by_file.items():
    try:
        with open(filepath, 'r') as f:
            c = f.read()
    except FileNotFoundError:
        print(f'SKIP: {filepath} not found')
        continue

    file_fixes = 0
    for old, new in replacements:
        if old in c:
            c = c.replace(old, new)
            file_fixes += 1

    # Remove const from Text/SnackBar widgets that now use AppStrings
    c = re.sub(r'const\s+(Text\s*\(\s*AppStrings)', r'\1', c)
    c = re.sub(r'const\s+(SnackBar\s*\([^)]*AppStrings)', r'\1', c)

    with open(filepath, 'w') as f:
        f.write(c)

    total_fixes += file_fixes
    print(f'{filepath}: {file_fixes} fixes')

print(f'\nTotal: {total_fixes} string replacements across {len(fixes_by_file)} files')
