#!/usr/bin/env python3
"""
Apply extracted localization strings to app_strings.dart and all screen files.
1. Merge arabic_fixes.json into localization_strings.json
2. Add all new keys to app_strings.dart (en + ar maps)
3. Replace hardcoded strings in each screen file with AppStrings.get() calls
"""

import json
import os
import re

BASE = '/root/.openclaw/workspace-hbot/lib'

def load_data():
    with open('/root/.openclaw/workspace-hbot/scripts/localization_strings.json') as f:
        strings = json.load(f)
    with open('/root/.openclaw/workspace-hbot/scripts/arabic_fixes.json') as f:
        fixes = json.load(f)
    
    # Apply Arabic fixes
    for key, ar_text in fixes.items():
        if key in strings:
            strings[key]['ar'] = ar_text
    
    # Check remaining [AR] fallbacks
    remaining = sum(1 for v in strings.values() if v['ar'].startswith('[AR]'))
    print(f'Total strings: {len(strings)}, Arabic fixes applied: {len(fixes)}, Remaining [AR]: {remaining}')
    
    return strings

def update_app_strings_dart(strings):
    """Add new keys to app_strings.dart"""
    filepath = os.path.join(BASE, 'l10n/app_strings.dart')
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Find the end of 'en' map (look for the pattern before 'ar' map)
    # The structure is: 'en': { ... }, 'ar': { ... }
    
    # Build new entries
    en_entries = []
    ar_entries = []
    
    # Get existing keys to avoid duplicates
    existing_keys = set(re.findall(r"'([a-z_0-9]+)':", content))
    
    added = 0
    for key, val in strings.items():
        if key in existing_keys:
            continue
        
        en_text = val['en'].replace("'", "\\'")
        ar_text = val['ar'].replace("'", "\\'")
        
        # Skip [AR] fallbacks — better to have English than broken Arabic
        if ar_text.startswith('[AR]'):
            ar_text = en_text  # Fallback to English
        
        en_entries.append(f"      '{key}': '{en_text}',")
        ar_entries.append(f"      '{key}': '{ar_text}',")
        added += 1
    
    if not en_entries:
        print('No new keys to add to app_strings.dart')
        return
    
    # Find insertion points
    # Strategy: find the last entry before the closing } of each map
    
    # Find 'en' map closing
    en_map_start = content.index("'en': {")
    # Find matching closing brace - count braces
    brace_count = 0
    en_map_end = -1
    for i in range(en_map_start, len(content)):
        if content[i] == '{':
            brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                en_map_end = i
                break
    
    # Find 'ar' map closing
    ar_map_start = content.index("'ar': {")
    brace_count = 0
    ar_map_end = -1
    for i in range(ar_map_start, len(content)):
        if content[i] == '{':
            brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                ar_map_end = i
                break
    
    # Insert before the closing }
    en_block = '\n' + '\n'.join(en_entries) + '\n'
    ar_block = '\n' + '\n'.join(ar_entries) + '\n'
    
    # Insert ar first (later position) then en (earlier position)
    # to keep indices valid
    content = content[:ar_map_end] + ar_block + '    ' + content[ar_map_end:]
    
    # Recalculate en_map_end since we inserted text
    # Actually, let's just find it again
    en_map_start2 = content.index("'en': {")
    brace_count = 0
    en_map_end2 = -1
    for i in range(en_map_start2, len(content)):
        if content[i] == '{':
            brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                en_map_end2 = i
                break
    
    content = content[:en_map_end2] + en_block + '    ' + content[en_map_end2:]
    
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f'✅ Added {added} new keys to app_strings.dart')

def patch_screen_files(strings):
    """Replace hardcoded strings with AppStrings.get() in screen files"""
    # Group strings by screen file
    by_screen = {}
    for key, val in strings.items():
        screen = val['screen']
        if screen not in by_screen:
            by_screen[screen] = []
        by_screen[screen].append((key, val))
    
    total_replacements = 0
    
    for screen_path, entries in by_screen.items():
        filepath = os.path.join(BASE, screen_path)
        if not os.path.exists(filepath):
            continue
        
        with open(filepath, 'r') as f:
            content = f.read()
        
        original = content
        replacements = 0
        
        # Add import if not present
        if "import '../l10n/app_strings.dart'" not in content and "import '../l10n/app_strings.dart'" not in content:
            # For widgets, the import path is different
            if screen_path.startswith('widgets/'):
                import_line = "import '../l10n/app_strings.dart';\n"
            else:
                import_line = "import '../l10n/app_strings.dart';\n"
            
            # Insert after last import
            last_import = content.rfind("import '")
            if last_import >= 0:
                end_of_line = content.index('\n', last_import) + 1
                content = content[:end_of_line] + import_line + content[end_of_line:]
        
        # Sort entries by text length (longest first) to avoid partial replacements
        entries.sort(key=lambda x: len(x[1]['en']), reverse=True)
        
        for key, val in entries:
            en_text = val['en']
            
            # Pattern 1: Text('exact string')
            old1 = f"Text('{en_text}'"
            new1 = f"Text(AppStrings.get('{key}')"
            if old1 in content:
                content = content.replace(old1, new1, 1)
                # Remove const before this Text if present
                content = content.replace(f"const {new1}", new1)
                replacements += 1
                continue
            
            # Pattern 2: Text("exact string")  
            old2 = f'Text("{en_text}"'
            new2 = f"Text(AppStrings.get('{key}')"
            if old2 in content:
                content = content.replace(old2, new2, 1)
                content = content.replace(f"const {new2}", new2)
                replacements += 1
                continue
            
            # Pattern 3: content: Text('exact string')
            old3 = f"content: Text('{en_text}'"
            new3 = f"content: Text(AppStrings.get('{key}')"
            if old3 in content:
                content = content.replace(old3, new3, 1)
                content = content.replace(f"const {new3}", new3)
                replacements += 1
                continue
            
            # Pattern 4: content: const Text('exact string')
            old4 = f"content: const Text('{en_text}'"
            new4 = f"content: Text(AppStrings.get('{key}')"
            if old4 in content:
                content = content.replace(old4, new4, 1)
                replacements += 1
                continue
            
            # Pattern 5: title: Text('exact string') / title: const Text('exact string')
            old5a = f"title: const Text('{en_text}'"
            new5 = f"title: Text(AppStrings.get('{key}')"
            if old5a in content:
                content = content.replace(old5a, new5, 1)
                replacements += 1
                continue
            
            old5b = f"title: Text('{en_text}'"
            if old5b in content:
                content = content.replace(old5b, new5, 1)
                replacements += 1
                continue
            
            # Pattern 6: hintText/labelText: 'exact string'
            for prop in ['hintText', 'labelText', 'helperText', 'errorText', 'tooltip', 'semanticLabel', 'label']:
                old6 = f"{prop}: '{en_text}'"
                new6 = f"{prop}: AppStrings.get('{key}')"
                if old6 in content:
                    content = content.replace(old6, new6, 1)
                    replacements += 1
                    break
        
        if content != original:
            # Remove orphaned 'const' before SnackBar that now has non-const content
            # Pattern: const SnackBar( ... Text(AppStrings.get  → remove const
            content = re.sub(
                r'const\s+(SnackBar\s*\([^)]*Text\(AppStrings\.get)',
                r'\1',
                content
            )
            
            with open(filepath, 'w') as f:
                f.write(content)
            
            total_replacements += replacements
            print(f'  📝 {os.path.basename(screen_path)}: {replacements} replacements')
    
    print(f'\n✅ Total replacements across all files: {total_replacements}')

def main():
    strings = load_data()
    print('\n--- Updating app_strings.dart ---')
    update_app_strings_dart(strings)
    print('\n--- Patching screen files ---')
    patch_screen_files(strings)

if __name__ == '__main__':
    main()
