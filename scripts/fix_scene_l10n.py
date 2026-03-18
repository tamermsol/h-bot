#!/usr/bin/env python3
"""Fix remaining scene screen localization + add shared device labels"""
import re, os

# ---- 1. Add all new keys to app_strings.dart ----
new_keys = {
    # Repeat options (keep English as identifiers, display localized)
    'repeat_once_only': ('Once only', 'مرة واحدة'),
    'repeat_every_day': ('Every day', 'كل يوم'),
    'repeat_weekdays': ('Weekdays', 'أيام العمل'),
    'repeat_weekend': ('Weekend', 'عطلة نهاية الأسبوع'),
    'repeat_custom': ('Custom', 'مخصص'),
    'scene_repeat': ('Repeat', 'التكرار'),
    
    # Days
    'day_mon': ('Mon', 'اثن'),
    'day_tue': ('Tue', 'ثلا'),
    'day_wed': ('Wed', 'أرب'),
    'day_thu': ('Thu', 'خمي'),
    'day_fri': ('Fri', 'جمع'),
    'day_sat': ('Sat', 'سبت'),
    'day_sun': ('Sun', 'أحد'),
    
    # Location trigger
    'trigger_arrive': ('Arrive', 'وصول'),
    'trigger_leave': ('Leave', 'مغادرة'),
    'scene_location': ('Location', 'الموقع'),
    'scene_radius': ('Radius', 'نطاق'),
    'scene_trigger_distance': ('Scene will trigger when you are within this distance', 'سيتم تفعيل السيناريو عندما تكون ضمن هذه المسافة'),
    
    # Device step
    'scene_choose_devices': ('Choose which devices this scene will control', 'اختر الأجهزة التي سيتحكم بها هذا السيناريو'),
    'scene_set_actions': ('Set what each device should do when this scene is activated', 'حدّد ما يجب أن يفعله كل جهاز عند تفعيل هذا السيناريو'),
    'scene_no_devices_selected': ('No devices selected', 'لم يتم اختيار أجهزة'),
    'scene_go_back_select': ('Go back and select devices first', 'ارجع واختر الأجهزة أولاً'),
    'scene_no_room': ('No Room', 'بدون غرفة'),
    'scene_action': ('Action', 'الإجراء'),
    'scene_channels': ('Channels', 'القنوات'),
    'scene_no_actions': ('No actions available for this device type', 'لا توجد إجراءات متاحة لهذا النوع من الأجهزة'),
    
    # Review step  
    'scene_review_config': ('Review your scene configuration before creating', 'راجع إعدادات السيناريو قبل الإنشاء'),
    'scene_summary_trigger': ('Trigger', 'المشغّل'),
    'scene_summary_devices': ('Devices', 'الأجهزة'),
    
    # Success messages
    'scene_updated_success': ('Scene updated successfully!', 'تم تحديث السيناريو بنجاح!'),
    'scene_created_success': ('Scene created successfully!', 'تم إنشاء السيناريو بنجاح!'),
}

filepath = 'lib/l10n/app_strings.dart'
with open(filepath, 'r') as f:
    content = f.read()

existing = set(re.findall(r"'([a-z_0-9]+)':", content))
en_entries = []
ar_entries = []
for key, (en, ar) in new_keys.items():
    if key in existing:
        continue
    en_entries.append(f"      '{key}': '{en}',")
    ar_entries.append(f"      '{key}': '{ar}',")

if en_entries:
    # Find end of en block
    en_start = content.index("'en': {")
    bc = 0
    for i in range(en_start, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0: en_end = i; break
    # Find end of ar block
    ar_start = content.index("'ar': {")
    bc = 0
    for i in range(ar_start, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0: ar_end = i; break
    
    ar_block = '\n' + '\n'.join(ar_entries) + '\n    '
    content = content[:ar_end] + ar_block + content[ar_end:]
    
    en_start2 = content.index("'en': {")
    bc = 0
    for i in range(en_start2, len(content)):
        if content[i] == '{': bc += 1
        elif content[i] == '}':
            bc -= 1
            if bc == 0: en_end2 = i; break
    en_block = '\n' + '\n'.join(en_entries) + '\n    '
    content = content[:en_end2] + en_block + content[en_end2:]
    
    with open(filepath, 'w') as f:
        f.write(content)
    print(f'Added {len(en_entries)} keys to app_strings.dart')
else:
    print('No new keys needed')

# ---- 2. Fix add_scene_screen.dart ----
fp = 'lib/screens/add_scene_screen.dart'
with open(fp, 'r') as f:
    c = f.read()

# Fix repeat option display - need a helper function
# The repeat options list is used as identifiers. We display them via _getRepeatDisplayName
# Add display name helper after _getTriggerDescription
insert_after = "  String _getTriggerDescription(String trigger) {"
# Actually, let's use a simpler approach - add a _getRepeatDisplayName method
# and replace display uses

replacements = [
    # Repeat label
    ("'Repeat'", "AppStrings.get('scene_repeat')"),
    # Location
    ("'Location'", "AppStrings.get('scene_location')"),
    # Radius
    ("'Radius'", "AppStrings.get('scene_radius')"),
    # Distance text
    ("'Scene will trigger when you are within this distance'", "AppStrings.get('scene_trigger_distance')"),
    # Device step
    ("'Choose which devices this scene will control'", "AppStrings.get('scene_choose_devices')"),
    ("'Set what each device should do when this scene is activated'", "AppStrings.get('scene_set_actions')"),
    ("'No devices selected'", "AppStrings.get('scene_no_devices_selected')"),
    ("'Go back and select devices first'", "AppStrings.get('scene_go_back_select')"),
    ("'No Room'", "AppStrings.get('scene_no_room')"),
    ("'Action'", "AppStrings.get('scene_action')"),
    ("'Channels'", "AppStrings.get('scene_channels')"),
    ("'No actions available for this device type'", "AppStrings.get('scene_no_actions')"),
    # Review step
    ("'Review your scene configuration before creating'", "AppStrings.get('scene_review_config')"),
    # Day chips
    ("_buildDayChip('Mon', 1)", "_buildDayChip(AppStrings.get('day_mon'), 1)"),
    ("_buildDayChip('Tue', 2)", "_buildDayChip(AppStrings.get('day_tue'), 2)"),
    ("_buildDayChip('Wed', 3)", "_buildDayChip(AppStrings.get('day_wed'), 3)"),
    ("_buildDayChip('Thu', 4)", "_buildDayChip(AppStrings.get('day_thu'), 4)"),
    ("_buildDayChip('Fri', 5)", "_buildDayChip(AppStrings.get('day_fri'), 5)"),
    ("_buildDayChip('Sat', 6)", "_buildDayChip(AppStrings.get('day_sat'), 6)"),
    ("_buildDayChip('Sun', 7)", "_buildDayChip(AppStrings.get('day_sun'), 7)"),
]

count = 0
for old, new in replacements:
    if old in c:
        c = c.replace(old, new)
        count += 1

# Fix 'arrive' / 'leave' display labels (these may be identifiers, need to check)
# These are used as trigger type values AND display text
# Let's replace display instances only
c = c.replace("'arrive',\n", "AppStrings.get('trigger_arrive'),\n", 1)
c = c.replace("'leave',\n", "AppStrings.get('trigger_leave'),\n", 1)

# Fix summary section labels
c = c.replace("_buildSummarySection('Trigger',", "_buildSummarySection(AppStrings.get('scene_summary_trigger'),")
c = c.replace("_buildSummarySection('Devices',", "_buildSummarySection(AppStrings.get('scene_summary_devices'),")

# Fix repeat display name in _getRepeatDescription
# Replace the return strings for repeat options
c = c.replace("return 'Every day';", "return AppStrings.get('repeat_every_day');")
c = c.replace("return 'Weekend';", "return AppStrings.get('repeat_weekend');")
c = c.replace("return 'Once only';", "return AppStrings.get('repeat_once_only');")
c = c.replace("return 'Custom';", "return AppStrings.get('repeat_custom');")

# Fix success messages - use simpler localized versions
c = c.replace(
    """'Scene "\${_nameController.text.trim()}" updated with \${_deviceActions.length} device action\${_deviceActions.length != 1 ? 's' : ''}!'""",
    "AppStrings.get('scene_updated_success')"
)
c = c.replace(
    """'Scene "\${_nameController.text.trim()}" created with \${_deviceActions.length} device action\${_deviceActions.length != 1 ? 's' : ''}!'""",
    "AppStrings.get('scene_created_success')"
)

# Remove const from widgets that now use AppStrings
c = re.sub(r'const\s+(Text\s*\(\s*AppStrings)', r'\1', c)

with open(fp, 'w') as f:
    f.write(c)
print(f'Fixed {count} string replacements in add_scene_screen.dart')
