#!/usr/bin/env python3
"""Fix ALL remaining English strings in add_scene_screen.dart"""
import re

# New keys
new_keys = {
    'scene_name_hint': ("Scene name (e.g., Movie Night)", "اسم السيناريو (مثال: وقت الفيلم)"),
    'scene_preview': ("Scene Preview", "معاينة السيناريو"),
    'scene_activation_time': ("Activation Time", "وقت التفعيل"),
    'scene_select_days': ("Select Days", "اختيار الأيام"),
    'scene_trigger_type': ("Trigger Type", "نوع المشغّل"),
    'scene_detecting_location': ("Detecting Location...", "جاري تحديد الموقع..."),
    'scene_update_location': ("Update Location", "تحديث الموقع"),
    'scene_use_current_location': ("Use Current Location", "استخدام الموقع الحالي"),
    'scene_select_devices': ("Select Devices", "اختيار الأجهزة"),
    'scene_configure_actions': ("Configure Device Actions", "إعداد إجراءات الأجهزة"),
    'scene_review': ("Review Scene", "مراجعة السيناريو"),
    'scene_basic_info': ("Basic Info", "المعلومات الأساسية"),
    'scene_name_label': ("Name", "الاسم"),
    'scene_select_time_error': ("Please select an activation time for time-based trigger", "يرجى اختيار وقت تفعيل للمشغّل المؤقت"),
    'scene_update_failed': ("Failed to update scene", "فشل تحديث السيناريو"),
    'scene_create_failed': ("Failed to create scene", "فشل إنشاء السيناريو"),
    'scene_location_disabled': ("Location services are disabled. Please enable them.", "خدمات الموقع معطّلة. يرجى تفعيلها."),
    'scene_location_denied': ("Location permissions are permanently denied. Please enable them in settings.", "أذونات الموقع مرفوضة بشكل دائم. يرجى تفعيلها من الإعدادات."),
    'repeat_weekdays': ("Monday to Friday", "الاثنين إلى الجمعة"),
}

# Add keys to app_strings.dart
filepath = 'lib/l10n/app_strings.dart'
with open(filepath, 'r') as f:
    content = f.read()

existing = set(re.findall(r"'([a-z_0-9]+)':", content))
en_entries = []
ar_entries = []
for key, (en, ar) in new_keys.items():
    if key in existing:
        # Update existing repeat_weekdays
        if key == 'repeat_weekdays':
            content = content.replace("'repeat_weekdays': 'Weekdays'", "'repeat_weekdays': 'Monday to Friday'")
        continue
    en_entries.append(f"      '{key}': '{en}',")
    ar_entries.append(f"      '{key}': '{ar}',")

if en_entries:
    en_start = content.index("'en': {"); bc = 0
    for i in range(en_start, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0: en_end = i; break
    ar_start = content.index("'ar': {"); bc = 0
    for i in range(ar_start, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0: ar_end = i; break
    content = content[:ar_end] + '\n' + '\n'.join(ar_entries) + '\n    ' + content[ar_end:]
    en_start2 = content.index("'en': {"); bc = 0
    for i in range(en_start2, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0: en_end2 = i; break
    content = content[:en_end2] + '\n' + '\n'.join(en_entries) + '\n    ' + content[en_end2:]

with open(filepath, 'w') as f:
    f.write(content)
print(f'Added {len(en_entries)} keys')

# Fix add_scene_screen.dart
fp = 'lib/screens/add_scene_screen.dart'
with open(fp, 'r') as f:
    c = f.read()

fixes = [
    ("hint: 'Scene name (e.g., Movie Night)'", "hint: AppStrings.get('scene_name_hint')"),
    ("'Scene Preview'", "AppStrings.get('scene_preview')"),
    ("'Activation Time'", "AppStrings.get('scene_activation_time')"),
    ("'Select Days'", "AppStrings.get('scene_select_days')"),
    ("'Trigger Type'", "AppStrings.get('scene_trigger_type')"),
    ("'Detecting Location...'", "AppStrings.get('scene_detecting_location')"),
    ("'Update Location'", "AppStrings.get('scene_update_location')"),
    ("'Use Current Location'", "AppStrings.get('scene_use_current_location')"),
    ("'Select Devices'", "AppStrings.get('scene_select_devices')"),
    ("'Configure Device Actions'", "AppStrings.get('scene_configure_actions')"),
    ("'Review Scene'", "AppStrings.get('scene_review')"),
    ("'Basic Info'", "AppStrings.get('scene_basic_info')"),
    ("'Please select an activation time for time-based trigger'", "AppStrings.get('scene_select_time_error')"),
    ("'Location services are disabled. Please enable them.'", "AppStrings.get('scene_location_disabled')"),
    ("'Location permissions are permanently denied. Please enable them in settings.'", "AppStrings.get('scene_location_denied')"),
]

count = 0
for old, new in fixes:
    if old in c:
        c = c.replace(old, new)
        count += 1

# Fix the summary Name: line
c = c.replace(
    "_buildSummarySection('Basic Info', ['Name: ${_nameController.text}'])",
    "_buildSummarySection(AppStrings.get('scene_basic_info'), ['${AppStrings.get('scene_name_label')}: ${_nameController.text}'])"
)

# Fix error messages with interpolation
c = c.replace(
    "'Failed to update scene: $e'",
    "'${AppStrings.get('scene_update_failed')}: $e'"
)
c = c.replace(
    "'Failed to create scene: $e'",
    "'${AppStrings.get('scene_create_failed')}: $e'"
)

# Fix Monday to Friday → Weekdays in the list
c = c.replace("'Monday to Friday',", "'Weekdays',")

# Remove const from Text widgets using AppStrings
c = re.sub(r'const\s+(Text\s*\(\s*AppStrings)', r'\1', c)

with open(fp, 'w') as f:
    f.write(c)
print(f'Fixed {count} strings in add_scene_screen.dart')
