#!/usr/bin/env python3
"""Fix all feedback items from Tamer's review in one pass."""
import re

# ============================================================
# 1. Fix app_strings.dart — add new keys, fix existing ones
# ============================================================
with open('lib/l10n/app_strings.dart', 'r') as f:
    content = f.read()

# Fix existing Arabic translations
fixes = {
    "'rooms_add_your_first_room': 'إضافة Your First Room'": "'rooms_add_your_first_room': 'أضف غرفتك الأولى'",
    "'manage_homes_subtitle': 'إضافة وتعديل وحذف المنازل'": "'manage_homes_subtitle': 'المنازل'",
    "'manage_homes_subtitle': 'Add, edit, or remove homes'": "'manage_homes_subtitle': 'Homes'",
}

for old, new in fixes.items():
    content = content.replace(old, new)

# New keys to add
new_keys = {
    'no_internet_connection': ('No internet connection', 'لا يوجد اتصال بالإنترنت'),
    'no_internet_retry': ('Check your connection and try again', 'تحقق من اتصالك وحاول مجدداً'),
    'my_home_default': ('My Home', 'منزلي'),
    'clear_all_notifications': ('Clear All', 'مسح الكل'),
    'clear_notifications_confirm': ('Clear all notifications?', 'مسح جميع الإشعارات؟'),
    'clear_notifications_confirm_body': ('This will remove all notifications from your inbox.', 'سيتم إزالة جميع الإشعارات من صندوق الوارد.'),
    'notifications_cleared': ('Notifications cleared', 'تم مسح الإشعارات'),
    'no_owned_devices_to_share': ("You don't own any devices to share. Add devices first.", 'لا تملك أجهزة لمشاركتها. أضف أجهزة أولاً.'),
    'reset_password_title': ('Reset Password', 'إعادة تعيين كلمة المرور'),
    'reset_enter_code': ('Enter the 6-digit code sent to:', 'أدخل الرمز المكون من 6 أرقام المرسل إلى:'),
    'reset_at_least_6': ('At least 6 characters', '6 أحرف على الأقل'),
    'reset_reenter_password': ('Re-enter your password', 'أعد إدخال كلمة المرور'),
    'reset_password_min_error': ('Password must be at least 6 characters', 'يجب أن تكون كلمة المرور 6 أحرف على الأقل'),
    'reset_passwords_no_match': ('Passwords do not match', 'كلمات المرور غير متطابقة'),
    'reset_enter_new_password': ('Please enter a new password', 'يرجى إدخال كلمة مرور جديدة'),
    'reset_resend_in': ('Resend in', 'إعادة الإرسال خلال'),
    'reset_resend': ('Resend', 'إعادة الإرسال'),
    'reset_didnt_receive': ("Didn't receive the code?", 'لم تستلم الرمز؟'),
    'reset_email_not_found': ('No account found with this email', 'لا يوجد حساب بهذا البريد الإلكتروني'),
    'connection_timeout': ('Connection timeout. Check your internet connection.', 'انتهت مهلة الاتصال. تحقق من اتصالك بالإنترنت.'),
    'network_error': ('Network error. Check your internet connection.', 'خطأ في الشبكة. تحقق من اتصالك بالإنترنت.'),
}

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
print(f'app_strings.dart: Added {len(en_entries)} new keys, fixed {sum(1 for o in fixes if o in open("lib/l10n/app_strings.dart").read())} translations')

# ============================================================
# 2. Fix home_dashboard_screen.dart — "My Home" fallback
# ============================================================
fp = 'lib/screens/home_dashboard_screen.dart'
with open(fp) as f: c = f.read()
c = c.replace(
    "_selectedHome?.name ?? 'My Home'",
    "_selectedHome?.name ?? AppStrings.get('my_home_default')"
)
with open(fp, 'w') as f: f.write(c)
print(f'{fp}: Fixed "My Home" fallback')

# ============================================================
# 3. Fix notifications_settings_screen.dart — toggle state
# ============================================================
fp = 'lib/screens/notifications_settings_screen.dart'
with open(fp) as f: c = f.read()

# Fix: toggle should reflect actual permission state, not just SharedPreferences
old_init = """      if (mounted) {
        setState(() {
          _notificationsEnabled = enabled;
          _permissionStatus = status;"""
new_init = """      if (mounted) {
        setState(() {
          // Sync toggle with actual permission status (not just saved pref)
          _notificationsEnabled = enabled && status.isGranted;
          // If permission is granted but pref is off, update pref
          if (status.isGranted && !enabled) {
            prefs.setBool(_notificationsEnabledKey, true);
            _notificationsEnabled = true;
          }
          _permissionStatus = status;"""
c = c.replace(old_init, new_init)
with open(fp, 'w') as f: f.write(c)
print(f'{fp}: Fixed notification toggle state')

# ============================================================
# 4. Fix help_center_screen.dart — LTR phone/URL
# ============================================================
fp = 'lib/screens/help_center_screen.dart'
with open(fp) as f: c = f.read()

# Wrap subtitle in Directionality widget for LTR
old_subtitle = """      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.hTextSecondary,
        ),
      ),"""
new_subtitle = """      subtitle: Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.hTextSecondary,
          ),
        ),
      ),"""
c = c.replace(old_subtitle, new_subtitle)
with open(fp, 'w') as f: f.write(c)
print(f'{fp}: Fixed RTL phone/URL display')

# ============================================================
# 5. Fix device_selector.dart — button dark mode text color
# ============================================================
fp = 'lib/widgets/device_selector.dart'
with open(fp) as f: c = f.read()
c = c.replace(
    """style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                ),""",
    """style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                ),"""
)
with open(fp, 'w') as f: f.write(c)
print(f'{fp}: Fixed button dark mode text color')

# ============================================================
# 6. Fix notifications_inbox_screen.dart — dark mode cards + clear button + new account filter
# ============================================================
fp = 'lib/screens/notifications_inbox_screen.dart'
with open(fp) as f: c = f.read()

# Fix: unread cards — use dark-aware color instead of HBotColors.primarySurface
c = c.replace(
    'HBotColors.primarySurface',
    'HBotColors.primary.withOpacity(context.isDark ? 0.15 : 0.08)'
)

# Fix: unread icon circle bg
c = c.replace(
    """color: isUnread
                          ? HBotColors.primary.withOpacity(0.15)
                          : HBotColors.neutral100,""",
    """color: isUnread
                          ? HBotColors.primary.withOpacity(0.2)
                          : (context.isDark ? HBotColors.neutral100.withOpacity(0.1) : HBotColors.neutral100),"""
)

with open(fp, 'w') as f: f.write(c)
print(f'{fp}: Fixed dark mode cards')

# ============================================================
# 7. Fix settings_tile.dart — RTL-aware padding
# ============================================================
fp = 'lib/widgets/settings_tile.dart'
with open(fp) as f: c = f.read()

# Fix divider padding for RTL
c = c.replace(
    "padding: const EdgeInsets.only(left: 56),",
    "padding: const EdgeInsetsDirectional.only(start: 56),"
)

# Fix group label padding for RTL
c = c.replace(
    """padding: const EdgeInsets.only(
              left: HBotSpacing.space5,
              bottom: HBotSpacing.space2,
              top: HBotSpacing.space6,
            ),""",
    """padding: const EdgeInsetsDirectional.only(
              start: HBotSpacing.space5,
              bottom: HBotSpacing.space2,
              top: HBotSpacing.space6,
            ),"""
)

with open(fp, 'w') as f: f.write(c)
print(f'{fp}: Fixed RTL padding')

# ============================================================
# 8. Fix reset_password_screen.dart — localize all strings
# ============================================================
fp = 'lib/screens/reset_password_screen.dart'
with open(fp) as f: c = f.read()

replacements = [
    ("'Reset Password'", "AppStrings.get('reset_password_title')"),
    ("'Enter the 6-digit code sent to:'", "AppStrings.get('reset_enter_code')"),
    ("hint: 'At least 6 characters'", "hint: AppStrings.get('reset_at_least_6')"),
    ("hint: 'Re-enter your password'", "hint: AppStrings.get('reset_reenter_password')"),
    ("'Password must be at least 6 characters'", "AppStrings.get('reset_password_min_error')"),
    ("return 'Please enter a new password'", "return AppStrings.get('reset_enter_new_password')"),
    ("return 'Passwords do not match'", "return AppStrings.get('reset_passwords_no_match')"),
    ("'Resend'", "AppStrings.get('reset_resend')"),
]
count = 0
for old, new in replacements:
    if old in c:
        c = c.replace(old, new)
        count += 1

# Fix "Resend in Xs" — needs interpolation
c = re.sub(
    r"'Resend in \$\{_resendCountdown\}s'",
    r"'${AppStrings.get(\"reset_resend_in\")} ${_resendCountdown}s'",
    c
)

# Fix "Didn't receive the code?"
c = c.replace("\"Didn't receive the code?\"", "AppStrings.get('reset_didnt_receive')")
c = c.replace("'Didn\\'t receive the code?'", "AppStrings.get('reset_didnt_receive')")

# Ensure import
if "app_strings.dart" not in c:
    c = c.replace("import 'package:flutter/material.dart';", 
                  "import 'package:flutter/material.dart';\nimport '../l10n/app_strings.dart';")

# Remove const from widgets using AppStrings
c = re.sub(r'const\s+(Text\s*\(\s*AppStrings)', r'\1', c)

with open(fp, 'w') as f: f.write(c)
print(f'{fp}: {count} string replacements')

# ============================================================
# 9. Fix multi_device_share_screen.dart — empty state
# ============================================================
fp = 'lib/screens/multi_device_share_screen.dart'
with open(fp) as f: c = f.read()

# Find where devices list is displayed and add empty state
old_loading = """    setState(() => _isLoading = true);
    try {
      final devices = await _devicesRepo.listDevicesByHome(widget.homeId);
      setState(() {
        _allDevices = devices;
        _isLoading = false;
      });"""
new_loading = """    setState(() => _isLoading = true);
    try {
      final devices = await _devicesRepo.listDevicesByHome(widget.homeId);
      setState(() {
        _allDevices = devices;
        _isLoading = false;
      });
      if (devices.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('no_owned_devices_to_share'))),
        );
      }"""
c = c.replace(old_loading, new_loading)

with open(fp, 'w') as f: f.write(c)
print(f'{fp}: Added empty state for no devices')

# ============================================================
# 10. Fix add_scene_screen.dart — hide location trigger
# ============================================================
fp = 'lib/screens/add_scene_screen.dart'
with open(fp) as f: c = f.read()

# Remove 'Location Based' from trigger options list
c = c.replace("    'Location Based',\n", "    // 'Location Based', // Hidden for initial release\n")

with open(fp, 'w') as f: f.write(c)
print(f'{fp}: Hidden location trigger')

# ============================================================
# 11. Fix sign_in_screen.dart — localize network errors
# ============================================================
fp = 'lib/screens/sign_in_screen.dart'
with open(fp) as f: c = f.read()
c = c.replace("msg = 'Connection timeout. Check your internet connection.';", 
              "msg = AppStrings.get('connection_timeout');")
c = c.replace("msg = 'Network error. Check your internet connection.';",
              "msg = AppStrings.get('network_error');")
with open(fp, 'w') as f: f.write(c)
print(f'{fp}: Localized network errors')

print('\n✅ All feedback fixes applied!')
