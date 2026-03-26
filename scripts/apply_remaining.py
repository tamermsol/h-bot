#!/usr/bin/env python3
"""
Apply remaining localization strings (batch 2).
1. Add new keys to app_strings.dart (en + ar)
2. Replace hardcoded strings in screen/widget files with AppStrings.get() calls
"""

import json
import os
import re

BASE = '/root/.openclaw/workspace-hbot/lib'

def load_data():
    with open('/root/.openclaw/workspace-hbot/scripts/remaining_strings.json') as f:
        strings = json.load(f)
    with open('/root/.openclaw/workspace-hbot/scripts/remaining_arabic.json') as f:
        arabic = json.load(f)
    
    # Merge Arabic
    for key in strings:
        if key in arabic:
            strings[key]['ar'] = arabic[key]
        else:
            strings[key]['ar'] = strings[key]['en']  # Fallback
    
    print(f'Total strings: {len(strings)}, Arabic available: {len(arabic)}')
    return strings

def has_interpolation(text):
    """Check if text contains Dart string interpolation"""
    return bool(re.search(r'(?<!\\)\$[a-zA-Z_{]', text))

def update_app_strings_dart(strings):
    filepath = os.path.join(BASE, 'l10n/app_strings.dart')
    with open(filepath, 'r') as f:
        content = f.read()
    
    existing_keys = set(re.findall(r"'([a-z_0-9]+)':", content))
    
    en_entries = []
    ar_entries = []
    skipped_interp = 0
    added = 0
    
    for key, val in strings.items():
        if key in existing_keys:
            continue
        
        en_text = val['en']
        ar_text = val.get('ar', en_text)
        
        # Skip strings with interpolation
        if has_interpolation(en_text):
            skipped_interp += 1
            continue
        
        # Escape single quotes
        en_escaped = en_text.replace("'", "\\'")
        ar_escaped = ar_text.replace("'", "\\'")
        
        en_entries.append(f"      '{key}': '{en_escaped}',")
        ar_entries.append(f"      '{key}': '{ar_escaped}',")
        added += 1
    
    if not en_entries:
        print('No new keys to add')
        return set()
    
    # Find 'en' map closing brace
    en_map_start = content.index("'en': {")
    brace_count = 0
    en_map_end = -1
    for i in range(en_map_start, len(content)):
        if content[i] == '{': brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                en_map_end = i
                break
    
    # Find 'ar' map closing brace
    ar_map_start = content.index("'ar': {")
    brace_count = 0
    ar_map_end = -1
    for i in range(ar_map_start, len(content)):
        if content[i] == '{': brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                ar_map_end = i
                break
    
    en_block = '\n' + '\n'.join(en_entries) + '\n'
    ar_block = '\n' + '\n'.join(ar_entries) + '\n'
    
    # Insert ar first (later position) then en
    content = content[:ar_map_end] + ar_block + '    ' + content[ar_map_end:]
    
    # Recalc en_map_end
    en_map_start2 = content.index("'en': {")
    brace_count = 0
    for i in range(en_map_start2, len(content)):
        if content[i] == '{': brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                en_map_end2 = i
                break
    
    content = content[:en_map_end2] + en_block + '    ' + content[en_map_end2:]
    
    with open(filepath, 'w') as f:
        f.write(content)
    
    added_keys = set(strings.keys()) - existing_keys
    print(f'✅ Added {added} keys to app_strings.dart (skipped {skipped_interp} with interpolation)')
    return added_keys

def patch_screen_files(strings, added_keys):
    by_screen = {}
    for key, val in strings.items():
        if has_interpolation(val['en']):
            continue
        screen = val['screen']
        if screen not in by_screen:
            by_screen[screen] = []
        by_screen[screen].append((key, val))
    
    total = 0
    
    for screen_path, entries in by_screen.items():
        filepath = os.path.join(BASE, screen_path)
        if not os.path.exists(filepath):
            continue
        
        with open(filepath, 'r') as f:
            content = f.read()
        
        original = content
        
        # Add import if not present
        import_str = "import '../l10n/app_strings.dart';"
        if import_str not in content:
            last_import = content.rfind("import '")
            if last_import >= 0:
                end_of_line = content.index('\n', last_import) + 1
                content = content[:end_of_line] + import_str + '\n' + content[end_of_line:]
        
        # Sort by text length (longest first)
        entries.sort(key=lambda x: len(x[1]['en']), reverse=True)
        
        replacements = 0
        for key, val in entries:
            en = val['en']
            replacement = f"AppStrings.get('{key}')"
            
            # Skip if already replaced
            if replacement in content:
                continue
            
            replaced = False
            
            # Try various patterns
            patterns = [
                # const Text('...')
                (f"const Text('{en}'", f"Text({replacement}"),
                (f'const Text("{en}"', f"Text({replacement})"),
                # Text('...')
                (f"Text('{en}'", f"Text({replacement}"),
                (f'Text("{en}"', f"Text({replacement}"),
                # title: const Text('...')
                (f"title: const Text('{en}'", f"title: Text({replacement}"),
                (f"title: Text('{en}'", f"title: Text({replacement}"),
                # content: const Text('...')
                (f"content: const Text('{en}'", f"content: Text({replacement}"),
                (f"content: Text('{en}'", f"content: Text({replacement}"),
                # child: const Text('...')
                (f"child: const Text('{en}'", f"child: Text({replacement}"),
                (f"child: Text('{en}'", f"child: Text({replacement}"),
            ]
            
            for old, new in patterns:
                if old in content:
                    content = content.replace(old, new, 1)
                    replaced = True
                    replacements += 1
                    break
            
            if not replaced:
                # Try property patterns
                for prop in ['hintText', 'labelText', 'helperText', 'errorText', 'tooltip', 'semanticLabel', 'label', 'text']:
                    old_prop = f"{prop}: '{en}'"
                    new_prop = f"{prop}: {replacement}"
                    if old_prop in content:
                        content = content.replace(old_prop, new_prop, 1)
                        replaced = True
                        replacements += 1
                        break
                    # Double quotes
                    old_prop2 = f'{prop}: "{en}"'
                    if old_prop2 in content:
                        content = content.replace(old_prop2, new_prop, 1)
                        replaced = True
                        replacements += 1
                        break
        
        if content != original:
            # Fix const issues: remove const before widgets that now have AppStrings.get
            # Pattern: const SomeWidget(...AppStrings.get...)
            content = re.sub(
                r'const\s+(SnackBar\s*\([^)]*AppStrings\.get)',
                r'\1', content
            )
            content = re.sub(
                r'const\s+(Text\s*\(\s*AppStrings\.get)',
                r'\1', content
            )
            # const InputDecoration with AppStrings
            content = re.sub(
                r'const\s+(InputDecoration\s*\([^)]*AppStrings\.get)',
                r'\1', content, flags=re.DOTALL
            )
            
            with open(filepath, 'w') as f:
                f.write(content)
            
            total += replacements
            print(f'  📝 {os.path.basename(screen_path)}: {replacements}')
    
    print(f'\n✅ Total: {total} replacements')

def main():
    strings = load_data()
    print('\n--- Updating app_strings.dart ---')
    added = update_app_strings_dart(strings)
    print('\n--- Patching files ---')
    patch_screen_files(strings, added)

if __name__ == '__main__':
    main()
