#!/usr/bin/env python3
"""Fix all remaining localization issues found in screenshots"""
import re, os

BASE = 'lib'

# ========== 1. Add new keys to app_strings.dart ==========
new_keys = {
    # Greetings
    'greeting_good_night': ('Good night', 'مساء الخير'),
    'greeting_good_morning': ('Good morning', 'صباح الخير'),
    'greeting_good_afternoon': ('Good afternoon', 'مساء الخير'),
    'greeting_good_evening': ('Good evening', 'مساء الخير'),
    
    # Device count
    'dashboard_device_count_singular': ('device', 'جهاز'),
    'dashboard_device_count_plural': ('devices', 'أجهزة'),
    
    # Profile screen menu items
    'profile_rooms': ('Rooms', 'الغرف'),
    'profile_wifi_profiles': ('WiFi Profiles', 'ملفات Wi-Fi'),
    'profile_personal_information': ('Personal Information', 'المعلومات الشخصية'),
    'profile_share_devices': ('Share Devices', 'مشاركة الأجهزة'),
    'profile_shared_with_me': ('Shared with Me', 'مشارك معي'),
    'profile_send_feedback': ('Send Feedback', 'إرسال الملاحظات'),
    
    # Notifications screen
    'notifications_title': ('Notifications', 'الإشعارات'),
    'notifications_mark_all_read': ('Mark all read', 'تحديد الكل كمقروء'),
    'notifications_yesterday': ('Yesterday', 'أمس'),
    'notifications_minutes_ago': ('m ago', 'د'),
    'notifications_hours_ago': ('h ago', 'س'),
    'notifications_days_ago': ('d ago', 'ي'),
}

filepath = os.path.join(BASE, 'l10n/app_strings.dart')
with open(filepath, 'r') as f:
    content = f.read()

existing_keys = set(re.findall(r"'([a-z_0-9]+)':", content))

en_entries = []
ar_entries = []
for key, (en, ar) in new_keys.items():
    if key in existing_keys:
        continue
    en_entries.append(f"      '{key}': '{en}',")
    ar_entries.append(f"      '{key}': '{ar}',")

if en_entries:
    # Find en map end
    en_start = content.index("'en': {")
    bc = 0
    for i in range(en_start, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0: en_end = i; break

    ar_start = content.index("'ar': {")
    bc = 0
    for i in range(ar_start, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0: ar_end = i; break

    ar_block = '\n' + '\n'.join(ar_entries) + '\n'
    content = content[:ar_end] + ar_block + '    ' + content[ar_end:]

    en_start2 = content.index("'en': {")
    bc = 0
    for i in range(en_start2, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0: en_end2 = i; break

    en_block = '\n' + '\n'.join(en_entries) + '\n'
    content = content[:en_end2] + en_block + '    ' + content[en_end2:]

# Fix "المشاهد" → "السيناريوهات" for scenes (more natural in smart home context)
content = content.replace("'المشاهد'", "'السيناريوهات'")
content = content.replace("'لا توجد مشاهد بعد'", "'لا توجد سيناريوهات بعد'")
content = content.replace("'أنشئ أول مشهد لأتمتة منزلك الذكي'", "'أنشئ أول سيناريو لأتمتة منزلك الذكي'")
content = content.replace("لإدارة المشاهد'", "لإدارة السيناريوهات'")
content = content.replace("بالمشاهد", "بالسيناريوهات")

with open(filepath, 'w') as f:
    f.write(content)
print(f'✅ Added {len(en_entries)} new keys + fixed scenes translation in app_strings.dart')

# ========== 2. Fix home_dashboard_screen.dart — greeting + device count ==========
fp = os.path.join(BASE, 'screens/home_dashboard_screen.dart')
with open(fp, 'r') as f:
    c = f.read()

# Fix greeting
old_greeting = """  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night 🌙';
    if (hour < 12) return 'Good morning ☀️';
    if (hour < 18) return 'Good afternoon';
    if (hour < 22) return 'Good evening';
    return 'Good night 🌙';
  }"""

new_greeting = """  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return '\${AppStrings.get("greeting_good_night")} 🌙';
    if (hour < 12) return '\${AppStrings.get("greeting_good_morning")} ☀️';
    if (hour < 18) return AppStrings.get("greeting_good_afternoon");
    if (hour < 22) return AppStrings.get("greeting_good_evening");
    return '\${AppStrings.get("greeting_good_night")} 🌙';
  }"""

c = c.replace(old_greeting, new_greeting)

# Fix device count "device" / "devices"
c = c.replace(
    "text: ' device\${_devices.length == 1 ? '' : 's'}'",
    "text: ' \${_devices.length == 1 ? AppStrings.get(\"dashboard_device_count_singular\") : AppStrings.get(\"dashboard_device_count_plural\")}'"
)

with open(fp, 'w') as f:
    f.write(c)
print('✅ Fixed greeting + device count in home_dashboard_screen.dart')

# ========== 3. Fix profile_screen.dart — menu items ==========
fp = os.path.join(BASE, 'screens/profile_screen.dart')
with open(fp, 'r') as f:
    c = f.read()

profile_fixes = [
    ("title: 'Rooms'", "title: AppStrings.get('profile_rooms')"),
    ("title: 'WiFi Profiles'", "title: AppStrings.get('profile_wifi_profiles')"),
    ("title: 'Personal Information'", "title: AppStrings.get('profile_personal_information')"),
    ("title: 'Share Devices'", "title: AppStrings.get('profile_share_devices')"),
    ("title: 'Shared with Me'", "title: AppStrings.get('profile_shared_with_me')"),
    ("title: 'Send Feedback'", "title: AppStrings.get('profile_send_feedback')"),
]

count = 0
for old, new in profile_fixes:
    if old in c:
        c = c.replace(old, new)
        count += 1

with open(fp, 'w') as f:
    f.write(c)
print(f'✅ Fixed {count} menu items in profile_screen.dart')

# ========== 4. Fix notifications_inbox_screen.dart ==========
fp = os.path.join(BASE, 'screens/notifications_inbox_screen.dart')
with open(fp, 'r') as f:
    c = f.read()

# Add import if needed
if "import '../l10n/app_strings.dart';" not in c:
    last_import = c.rfind("import '")
    end = c.index('\n', last_import) + 1
    c = c[:end] + "import '../l10n/app_strings.dart';\n" + c[end:]

# Fix title
c = c.replace("'Notifications',", "AppStrings.get('notifications_title'),")
# Fix Mark all read
c = c.replace("'Mark all read',", "AppStrings.get('notifications_mark_all_read'),")
c = c.replace("'Mark all read'", "AppStrings.get('notifications_mark_all_read')")

# Fix time ago
c = c.replace(
    "if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';",
    "if (diff.inMinutes < 60) return '${diff.inMinutes}${AppStrings.get(\"notifications_minutes_ago\")}';")
c = c.replace(
    "if (diff.inHours < 24) return '${diff.inHours}h ago';",
    "if (diff.inHours < 24) return '${diff.inHours}${AppStrings.get(\"notifications_hours_ago\")}';")
c = c.replace(
    "if (diff.inDays == 1) return 'Yesterday';",
    "if (diff.inDays == 1) return AppStrings.get('notifications_yesterday');")
c = c.replace(
    "if (diff.inDays < 7) return '${diff.inDays}d ago';",
    "if (diff.inDays < 7) return '${diff.inDays}${AppStrings.get(\"notifications_days_ago\")}';")

with open(fp, 'w') as f:
    f.write(c)
print('✅ Fixed notifications_inbox_screen.dart')

print('\n🎯 All screenshot issues fixed!')
