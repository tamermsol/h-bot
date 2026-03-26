#!/usr/bin/env python3
"""
Extract all hardcoded English strings from unlocalized Flutter screens,
generate Arabic translations, and produce patched files.

Strategy:
1. Parse each screen file for hardcoded strings in Text(), SnackBar, hints, labels, etc.
2. Generate keys based on screen name + context
3. Output new entries for app_strings.dart
4. Output patched screen files with AppStrings.get() calls
"""

import re
import os
import json

BASE = '/root/.openclaw/workspace-hbot/lib'

# Screens that need full localization (not yet using AppStrings)
SCREENS_TO_LOCALIZE = [
    'screens/activity_log_screen.dart',
    'screens/add_device_flow_screen.dart',
    'screens/add_timer_screen.dart',
    'screens/devices_screen.dart',
    'screens/device_timers_screen.dart',
    'screens/feedback_screen.dart',
    'screens/help_center_screen.dart',
    'screens/homes_screen.dart',
    'screens/multi_device_share_screen.dart',
    'screens/notifications_inbox_screen.dart',
    'screens/notifications_settings_screen.dart',
    'screens/profile_edit_screen.dart',
    'screens/reset_password_screen.dart',
    'screens/rooms_screen.dart',
    'screens/scan_device_qr_screen.dart',
    'screens/shared_devices_screen.dart',
    'screens/share_device_screen.dart',
    'screens/shutter_calibration_screen.dart',
    'screens/shutter_manual_calibration_screen.dart',
    'screens/wifi_profile_screen.dart',
]

# Widgets to localize
WIDGETS_TO_LOCALIZE = [
    'widgets/device_selector.dart',
    'widgets/shutter_control_widget.dart',
    'widgets/room_icon_picker.dart',
    'widgets/background_image_picker.dart',
]

# Comprehensive Arabic translations dictionary
TRANSLATIONS = {
    # Common actions
    'Save': 'حفظ',
    'Cancel': 'إلغاء',
    'Delete': 'حذف',
    'Edit': 'تعديل',
    'Add': 'إضافة',
    'Create': 'إنشاء',
    'Update': 'تحديث',
    'Close': 'إغلاق',
    'Done': 'تم',
    'OK': 'حسناً',
    'Yes': 'نعم',
    'No': 'لا',
    'Confirm': 'تأكيد',
    'Submit': 'إرسال',
    'Retry': 'إعادة المحاولة',
    'Back': 'رجوع',
    'Next': 'التالي',
    'Skip': 'تخطي',
    'Search': 'بحث',
    'Loading': 'جارٍ التحميل',
    'Error': 'خطأ',
    'Success': 'نجاح',
    'Warning': 'تحذير',
    'Info': 'معلومات',
    'Settings': 'الإعدادات',
    'Refresh': 'تحديث',
    'Share': 'مشاركة',
    'Copy': 'نسخ',
    'Scan': 'مسح',
    'Select': 'اختيار',
    'Remove': 'إزالة',
    'Rename': 'إعادة تسمية',
    'Reset': 'إعادة تعيين',
    'Continue': 'متابعة',
    'Start': 'بدء',
    'Stop': 'إيقاف',
    'Open': 'فتح',
    'Send': 'إرسال',

    # Navigation / Sections
    'Home': 'الرئيسية',
    'Dashboard': 'لوحة التحكم',
    'Devices': 'الأجهزة',
    'Rooms': 'الغرف',
    'Scenes': 'المشاهد',
    'Profile': 'الملف الشخصي',
    'Notifications': 'الإشعارات',
    'Activity Log': 'سجل النشاط',
    'Help Center': 'مركز المساعدة',
    'Feedback': 'ملاحظات',

    # Device types
    'Switch': 'مفتاح',
    'Shutter': 'مصراع',
    'Dimmer': 'ديمر',
    'Relay': 'ريليه',
    'Sensor': 'مستشعر',
    'Light': 'ضوء',
    'Lighting': 'الإضاءة',
    'Climate': 'المناخ',
    'Shutters': 'المصاريع',
    'Other': 'أخرى',
    'All': 'الكل',

    # Status
    'Online': 'متصل',
    'Offline': 'غير متصل',
    'Connected': 'متصل',
    'Disconnected': 'غير متصل',
    'Active': 'نشط',
    'Inactive': 'غير نشط',
    'Enabled': 'مفعّل',
    'Disabled': 'معطّل',
    'On': 'تشغيل',
    'Off': 'إيقاف',

    # Time
    'Timer': 'مؤقت',
    'Schedule': 'جدول',
    'Daily': 'يومياً',
    'Weekly': 'أسبوعياً',
    'Once': 'مرة واحدة',
    'Repeat': 'تكرار',
    'Duration': 'المدة',
    'Time': 'الوقت',
    'Date': 'التاريخ',

    # Sharing
    'Shared': 'مشترك',
    'Shared with Me': 'مشترك معي',
    'Share Device': 'مشاركة الجهاز',
    'Owner': 'المالك',
    'Permission': 'الصلاحية',
    'Control': 'تحكم',
    'View Only': 'عرض فقط',
    'Can Control': 'يمكنه التحكم',
    'QR Code': 'رمز QR',

    # Home
    'My Home': 'منزلي',
    'My Homes': 'منازلي',
    'Home Name': 'اسم المنزل',
    'Create New Home': 'إنشاء منزل جديد',
    'Delete Home': 'حذف المنزل',
    'Edit Home': 'تعديل المنزل',

    # Room
    'Room Name': 'اسم الغرفة',
    'Create New Room': 'إنشاء غرفة جديدة',
    'Delete Room': 'حذف الغرفة',
    'No Room': 'بدون غرفة',
    'Unknown Room': 'غرفة غير معروفة',

    # Notifications
    'Notification Settings': 'إعدادات الإشعارات',
    'Push Notifications': 'الإشعارات الفورية',
    'No notifications': 'لا توجد إشعارات',
    'Mark all as read': 'تحديد الكل كمقروء',

    # Calibration
    'Calibration': 'المعايرة',
    'Calibrate': 'معايرة',
    'Position': 'الموضع',
    'Open Position': 'وضع الفتح',
    'Close Position': 'وضع الإغلاق',
    'Manual Calibration': 'المعايرة اليدوية',

    # Wi-Fi
    'Wi-Fi Profile': 'ملف Wi-Fi',
    'SSID': 'SSID',
    'Password': 'كلمة المرور',
    'Network': 'الشبكة',
    'Connect': 'اتصال',

    # Common phrases
    'No devices found': 'لم يتم العثور على أجهزة',
    'No rooms found': 'لم يتم العثور على غرف',
    'No homes found': 'لم يتم العثور على منازل',
    'Are you sure?': 'هل أنت متأكد؟',
    'This action cannot be undone': 'لا يمكن التراجع عن هذا الإجراء',
    'Something went wrong': 'حدث خطأ ما',
    'Please try again': 'يرجى المحاولة مرة أخرى',
    'Successfully': 'بنجاح',
    'Failed to': 'فشل في',
    'Please enter': 'يرجى إدخال',
    'Required field': 'حقل مطلوب',
    'Unknown': 'غير معروف',
    'Unknown Device': 'جهاز غير معروف',
    'Not available': 'غير متوفر',
    'No data': 'لا توجد بيانات',
}

def extract_strings_from_file(filepath):
    """Extract hardcoded English strings from a Dart file."""
    with open(filepath, 'r') as f:
        content = f.read()
        lines = content.split('\n')
    
    strings_found = []
    
    for i, line in enumerate(lines):
        stripped = line.strip()
        
        # Skip comments, imports, debugPrint
        if stripped.startswith('//') or stripped.startswith('import') or 'debugPrint' in stripped:
            continue
        if 'AppStrings.get' in stripped:
            continue
            
        # Find Text('...') and Text("...")
        for match in re.finditer(r'''Text\(\s*['"]([^'"]+)['"]\s*''', line):
            text = match.group(1)
            if _is_translatable(text):
                strings_found.append({
                    'line': i + 1,
                    'text': text,
                    'context': 'Text',
                    'full_match': match.group(0),
                })
        
        # Find hintText: '...' and labelText: '...'
        for match in re.finditer(r'''(hintText|labelText|helperText|errorText|counterText|prefixText|suffixText|semanticLabel|tooltip):\s*['"]([^'"]+)['"]''', line):
            text = match.group(2)
            if _is_translatable(text):
                strings_found.append({
                    'line': i + 1,
                    'text': text,
                    'context': match.group(1),
                    'full_match': match.group(0),
                })
        
        # Find title: Text('...')
        for match in re.finditer(r'''title:\s*(?:const\s+)?Text\(\s*['"]([^'"]+)['"]\s*''', line):
            text = match.group(1)
            if _is_translatable(text):
                strings_found.append({
                    'line': i + 1,
                    'text': text,
                    'context': 'title',
                    'full_match': match.group(0),
                })
        
        # Find content: Text('...')
        for match in re.finditer(r'''content:\s*(?:const\s+)?Text\(\s*['"]([^'"]+)['"]\s*''', line):
            text = match.group(1)
            if _is_translatable(text):
                strings_found.append({
                    'line': i + 1,
                    'text': text,
                    'context': 'content',
                    'full_match': match.group(0),
                })

        # Find label: '...' (for form fields, buttons)
        for match in re.finditer(r'''label:\s*['"]([^'"]+)['"]''', line):
            text = match.group(1)
            if _is_translatable(text):
                strings_found.append({
                    'line': i + 1,
                    'text': text,
                    'context': 'label',
                    'full_match': match.group(0),
                })
    
    return strings_found


def _is_translatable(text):
    """Check if a string should be translated."""
    # Skip very short strings, pure technical strings, URLs, etc.
    if len(text) < 2:
        return False
    if text.startswith('http') or text.startswith('/'):
        return False
    if text.startswith('#') or text.startswith('0x'):
        return False
    # Skip strings that are just variable names or codes
    if re.match(r'^[a-z_]+$', text):
        return False
    if re.match(r'^[A-Z_]+$', text):
        return False
    # Skip icon/asset references
    if 'assets/' in text or '.png' in text or '.svg' in text:
        return False
    # Must contain at least one letter
    if not re.search(r'[a-zA-Z]', text):
        return False
    return True


def generate_key(screen_name, text, context):
    """Generate a unique key for a string."""
    prefix = screen_name.replace('_screen', '').replace('_widget', '')
    # Clean the text to make a key
    key = text.lower()
    key = re.sub(r'[^a-z0-9\s]', '', key)
    key = re.sub(r'\s+', '_', key.strip())
    key = key[:40]  # Limit length
    return f'{prefix}_{key}'


def translate(text):
    """Translate English to Arabic using our dictionary + patterns."""
    # Direct match
    if text in TRANSLATIONS:
        return TRANSLATIONS[text]
    
    # Try case-insensitive
    for en, ar in TRANSLATIONS.items():
        if text.lower() == en.lower():
            return ar
    
    # Pattern-based translations
    result = text
    
    # "Failed to X: $e" patterns
    m = re.match(r'Failed to (.+?)(?::\s*\$\w+)?$', text)
    if m:
        action = m.group(1).lower()
        action_ar = _translate_action(action)
        return f'فشل في {action_ar}'
    
    # "X successfully!" patterns
    m = re.match(r'(.+?)\s+(?:created|updated|deleted|saved|removed)\s+successfully!?$', text, re.I)
    if m:
        return f'تم بنجاح'
    
    # "Please enter X" patterns
    m = re.match(r'Please enter (?:a |an |the )?(.+)', text, re.I)
    if m:
        return f'يرجى إدخال {_translate_noun(m.group(1))}'
    
    # "No X found" patterns
    m = re.match(r'No (.+?) found', text, re.I)
    if m:
        return f'لم يتم العثور على {_translate_noun(m.group(1))}'
    
    # "Are you sure you want to X?" patterns
    m = re.match(r'Are you sure you want to (.+?)\??', text, re.I)
    if m:
        return f'هل أنت متأكد أنك تريد {_translate_action(m.group(1))}؟'
    
    # "X deleted" patterns
    m = re.match(r'(.+?) deleted', text, re.I)
    if m:
        return f'تم حذف {_translate_noun(m.group(1))}'
    
    # "X created" patterns  
    m = re.match(r'(.+?) created', text, re.I)
    if m:
        return f'تم إنشاء {_translate_noun(m.group(1))}'

    # "Add X" patterns
    m = re.match(r'Add (?:a |an |new )?(.+)', text, re.I)
    if m:
        return f'إضافة {_translate_noun(m.group(1))}'
    
    # "Delete X" patterns
    m = re.match(r'Delete (?:this )?(.+)', text, re.I)
    if m:
        return f'حذف {_translate_noun(m.group(1))}'
    
    # "Edit X" patterns
    m = re.match(r'Edit (?:this )?(.+)', text, re.I)
    if m:
        return f'تعديل {_translate_noun(m.group(1))}'
    
    # Fallback: return English with Arabic marker
    return f'[AR] {text}'


def _translate_action(action):
    actions = {
        'load': 'التحميل',
        'save': 'الحفظ',
        'delete': 'الحذف',
        'create': 'الإنشاء',
        'update': 'التحديث',
        'share': 'المشاركة',
        'send': 'الإرسال',
        'connect': 'الاتصال',
        'disconnect': 'قطع الاتصال',
        'calibrate': 'المعايرة',
        'scan': 'المسح',
        'add': 'الإضافة',
        'remove': 'الإزالة',
        'rename': 'إعادة التسمية',
        'reset': 'إعادة التعيين',
        'submit': 'الإرسال',
        'fetch': 'الجلب',
    }
    for en, ar in actions.items():
        if en in action.lower():
            return ar
    return action


def _translate_noun(noun):
    nouns = {
        'home': 'المنزل',
        'homes': 'المنازل',
        'room': 'الغرفة',
        'rooms': 'الغرف',
        'device': 'الجهاز',
        'devices': 'الأجهزة',
        'scene': 'المشهد',
        'scenes': 'المشاهد',
        'timer': 'المؤقت',
        'timers': 'المؤقتات',
        'notification': 'الإشعار',
        'notifications': 'الإشعارات',
        'name': 'الاسم',
        'password': 'كلمة المرور',
        'email': 'البريد الإلكتروني',
        'feedback': 'الملاحظات',
        'profile': 'الملف الشخصي',
        'data': 'البيانات',
        'shutter': 'المصراع',
        'channel': 'القناة',
        'network': 'الشبكة',
        'home name': 'اسم المنزل',
        'room name': 'اسم الغرفة',
        'device name': 'اسم الجهاز',
    }
    lower = noun.lower().strip()
    if lower in nouns:
        return nouns[lower]
    return noun


def main():
    all_files = SCREENS_TO_LOCALIZE + WIDGETS_TO_LOCALIZE
    all_strings = {}  # key -> {en, ar, screen, line}
    
    for rel_path in all_files:
        filepath = os.path.join(BASE, rel_path)
        if not os.path.exists(filepath):
            print(f'⚠️  Not found: {rel_path}')
            continue
        
        screen_name = os.path.basename(rel_path).replace('.dart', '')
        strings = extract_strings_from_file(filepath)
        
        print(f'📄 {screen_name}: {len(strings)} strings found')
        
        for s in strings:
            key = generate_key(screen_name, s['text'], s['context'])
            # Avoid duplicates
            if key in all_strings:
                # Append number
                i = 2
                while f'{key}_{i}' in all_strings:
                    i += 1
                key = f'{key}_{i}'
            
            ar_text = translate(s['text'])
            all_strings[key] = {
                'en': s['text'],
                'ar': ar_text,
                'screen': rel_path,
                'line': s['line'],
            }
    
    # Output results
    print(f'\n📊 Total new strings: {len(all_strings)}')
    
    # Count [AR] fallbacks
    fallbacks = sum(1 for v in all_strings.values() if v['ar'].startswith('[AR]'))
    print(f'⚠️  Strings needing manual Arabic: {fallbacks}')
    
    # Write to JSON for inspection
    output_path = '/root/.openclaw/workspace-hbot/scripts/localization_strings.json'
    with open(output_path, 'w') as f:
        json.dump(all_strings, f, indent=2, ensure_ascii=False)
    print(f'\n✅ Written to {output_path}')
    
    # Generate dart code for app_strings.dart additions
    dart_path = '/root/.openclaw/workspace-hbot/scripts/new_strings.dart'
    with open(dart_path, 'w') as f:
        f.write("// NEW KEYS TO ADD TO 'en' MAP:\n")
        for key, val in all_strings.items():
            en = val['en'].replace("'", "\\'")
            f.write(f"      '{key}': '{en}',\n")
        
        f.write("\n// NEW KEYS TO ADD TO 'ar' MAP:\n")
        for key, val in all_strings.items():
            ar = val['ar'].replace("'", "\\'")
            f.write(f"      '{key}': '{ar}',\n")
    
    print(f'✅ Dart snippets written to {dart_path}')


if __name__ == '__main__':
    main()
