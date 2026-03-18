#!/usr/bin/env python3
"""Fix batch 3: Alexa sheet, help center, and any other remaining strings"""
import re, os

BASE = 'lib'

# New keys
new_keys = {
    # Alexa sheet
    'alexa_link_title': ('Link H-Bot with Alexa', 'ربط H-Bot مع Alexa'),
    'alexa_step_1': ('Open the Amazon Alexa app', 'افتح تطبيق Amazon Alexa'),
    'alexa_step_2': ('Tap "More" → "Skills & Games"', 'اضغط على "المزيد" ← "المهارات والألعاب"'),
    'alexa_step_3': ('Search for "H-Bot"', 'ابحث عن "H-Bot"'),
    'alexa_step_4': ('Tap "Enable to Use" and link your account', 'اضغط على "تمكين للاستخدام" واربط حسابك'),
    
    # Help center
    'help_were_here_to_help': ("We\\'re here to help", 'نحن هنا لمساعدتك'),
    'help_get_in_touch': ('Get in touch with us through any of the following channels', 'تواصل معنا عبر أي من القنوات التالية'),
    'help_contact_information': ('Contact Information', 'معلومات الاتصال'),
    'help_website': ('Website', 'الموقع الإلكتروني'),
    'help_email': ('Email', 'البريد الإلكتروني'),
    'help_phone': ('Phone', 'الهاتف'),
    'help_whatsapp': ('WhatsApp', 'WhatsApp'),
    'help_response_time': ('We typically respond within 24 hours during business days.', 'نستجيب عادةً خلال 24 ساعة في أيام العمل.'),
}

# Add to app_strings.dart
filepath = os.path.join(BASE, 'l10n/app_strings.dart')
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
    with open(filepath, 'w') as f:
        f.write(content)
    print(f'Added {len(en_entries)} keys to app_strings.dart')

# Fix profile_screen.dart - Alexa sheet
fp = os.path.join(BASE, 'screens/profile_screen.dart')
with open(fp, 'r') as f:
    c = f.read()

alexa_fixes = [
    ("'Link H-Bot with Alexa'", "AppStrings.get('alexa_link_title')"),
    ("'Open the Amazon Alexa app'", "AppStrings.get('alexa_step_1')"),
    ("'Tap \"More\" → \"Skills & Games\"'", "AppStrings.get('alexa_step_2')"),
    ("'Search for \"H-Bot\"'", "AppStrings.get('alexa_step_3')"),
    ("'Tap \"Enable to Use\" and link your account'", "AppStrings.get('alexa_step_4')"),
]
count = 0
for old, new in alexa_fixes:
    if old in c:
        c = c.replace(old, new)
        count += 1

with open(fp, 'w') as f:
    f.write(c)
print(f'Fixed {count} Alexa strings in profile_screen.dart')

# Fix help_center_screen.dart
fp = os.path.join(BASE, 'screens/help_center_screen.dart')
with open(fp, 'r') as f:
    c = f.read()

if "import '../l10n/app_strings.dart';" not in c:
    last_import = c.rfind("import '")
    end = c.index('\n', last_import) + 1
    c = c[:end] + "import '../l10n/app_strings.dart';\n" + c[end:]

help_fixes = [
    ("'We\\'re here to help'", "AppStrings.get('help_were_here_to_help')"),
    ("'Get in touch with us through any of the following channels'", "AppStrings.get('help_get_in_touch')"),
    ("'Contact Information'", "AppStrings.get('help_contact_information')"),
    ("title: 'Website'", "title: AppStrings.get('help_website')"),
    ("title: 'Email'", "title: AppStrings.get('help_email')"),
    ("title: 'Phone'", "title: AppStrings.get('help_phone')"),
    ("title: 'WhatsApp'", "title: AppStrings.get('help_whatsapp')"),
    ("'We typically respond within 24 hours during business days.'", "AppStrings.get('help_response_time')"),
]
count = 0
for old, new in help_fixes:
    if old in c:
        c = c.replace(old, new)
        count += 1

# Remove const from widgets now using AppStrings
c = re.sub(r'const\s+(Text\s*\(\s*AppStrings)', r'\1', c)

with open(fp, 'w') as f:
    f.write(c)
print(f'Fixed {count} strings in help_center_screen.dart')
