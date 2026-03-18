#!/usr/bin/env python3
"""
Extract ALL remaining hardcoded English strings from lib/ screens and widgets.
Covers: Text('...'), hintText, labelText, title, content, tooltip, SnackBar messages, etc.
Skips strings already using AppStrings.get().
"""

import re
import os
import json

BASE = '/root/.openclaw/workspace-hbot/lib'
DIRS = ['screens', 'widgets']

# Skip these files (debug/internal only)
SKIP_FILES = {'mqtt_debug_sheet.dart'}

# Skip strings that are clearly not user-facing
SKIP_PATTERNS = [
    r'^[a-z_]+$',          # snake_case identifiers
    r'^\$',                # variable interpolation
    r'^https?://',         # URLs
    r'^package:',          # imports
    r'^[0-9.]+$',         # numbers
    r'^#[0-9a-fA-F]+$',   # hex colors
    r'^[A-Z_]+$',         # ALL_CAPS constants
    r'^\w+\.\w+',         # dot notation (e.g., "device.name")
    r'^POWER',            # MQTT commands
    r'^Shutter',          # MQTT commands 
    r'^mqtt',             # MQTT stuff
    r'^supabase',         # internal
]

def should_skip(text):
    text = text.strip()
    if len(text) < 2:
        return True
    if text.startswith('$') or text.startswith('{'):
        return True
    for pat in SKIP_PATTERNS:
        if re.match(pat, text):
            return True
    return False

def make_key(screen_name, text):
    """Generate a key from screen name and text"""
    # Clean screen name
    base = screen_name.replace('_screen.dart', '').replace('_widget.dart', '').replace('.dart', '')
    
    # Clean text for key
    clean = re.sub(r'[^a-zA-Z0-9\s]', '', text.lower())
    words = clean.split()[:8]  # Max 8 words
    key_suffix = '_'.join(words)
    
    return f"{base}_{key_suffix}"

def extract_from_file(filepath, screen_name):
    with open(filepath, 'r') as f:
        content = f.read()
    
    strings = {}
    
    # Pattern 1: Text('...')  or Text("...")
    for m in re.finditer(r"""(?:const\s+)?Text\(\s*['"]([^'"]+)['"]\s*[,)]""", content):
        text = m.group(1)
        if 'AppStrings.get' in content[max(0,m.start()-20):m.start()]:
            continue
        if should_skip(text):
            continue
        key = make_key(screen_name, text)
        strings[key] = {'en': text, 'screen': os.path.relpath(filepath, BASE)}
    
    # Pattern 2: hintText: '...' or hintText: "..."
    for prop in ['hintText', 'labelText', 'helperText', 'errorText', 'tooltip', 'semanticLabel']:
        for m in re.finditer(rf"""{prop}:\s*['"]([^'"]+)['"]""", content):
            text = m.group(1)
            if should_skip(text):
                continue
            key = make_key(screen_name, text)
            strings[key] = {'en': text, 'screen': os.path.relpath(filepath, BASE), 'prop': prop}
    
    # Pattern 3: title: Text('...') or title: const Text('...')
    for m in re.finditer(r"""title:\s*(?:const\s+)?Text\(\s*['"]([^'"]+)['"]""", content):
        text = m.group(1)
        if should_skip(text):
            continue
        key = make_key(screen_name, text)
        strings[key] = {'en': text, 'screen': os.path.relpath(filepath, BASE)}
    
    # Pattern 4: content: Text('...')
    for m in re.finditer(r"""content:\s*(?:const\s+)?Text\(\s*['"]([^'"]+)['"]""", content):
        text = m.group(1)
        if should_skip(text):
            continue
        key = make_key(screen_name, text)
        strings[key] = {'en': text, 'screen': os.path.relpath(filepath, BASE)}
    
    # Pattern 5: label: '...' (for form fields, buttons)
    for m in re.finditer(r"""label:\s*['"]([^'"]+)['"]""", content):
        text = m.group(1)
        if should_skip(text):
            continue
        key = make_key(screen_name, text)
        strings[key] = {'en': text, 'screen': os.path.relpath(filepath, BASE)}
    
    # Pattern 6: SnackBar(content: Text('...'))
    for m in re.finditer(r"""SnackBar\s*\(\s*content:\s*(?:const\s+)?Text\(\s*['"]([^'"]+)['"]""", content):
        text = m.group(1)
        if should_skip(text):
            continue
        key = make_key(screen_name, text)
        strings[key] = {'en': text, 'screen': os.path.relpath(filepath, BASE)}
    
    # Pattern 7: Tab(text: '...')
    for m in re.finditer(r"""Tab\s*\(\s*text:\s*['"]([^'"]+)['"]""", content):
        text = m.group(1)
        if should_skip(text):
            continue
        key = make_key(screen_name, text)
        strings[key] = {'en': text, 'screen': os.path.relpath(filepath, BASE)}
    
    # Deduplicate - skip if already using AppStrings
    filtered = {}
    for key, val in strings.items():
        if f"AppStrings.get('{key}')" not in content:
            # Check the string isn't already localized
            en = val['en']
            if f"AppStrings.get(" not in content or f"'{en}'" in content or f'"{en}"' in content:
                filtered[key] = val
    
    return filtered

def main():
    all_strings = {}
    
    for d in DIRS:
        dirpath = os.path.join(BASE, d)
        if not os.path.exists(dirpath):
            continue
        for fname in sorted(os.listdir(dirpath)):
            if not fname.endswith('.dart'):
                continue
            if fname in SKIP_FILES:
                continue
            filepath = os.path.join(dirpath, fname)
            extracted = extract_from_file(filepath, fname)
            
            # Avoid duplicate keys
            for key, val in extracted.items():
                orig_key = key
                i = 2
                while key in all_strings and all_strings[key]['en'] != val['en']:
                    key = f"{orig_key}_{i}"
                    i += 1
                all_strings[key] = val
    
    # Write output
    outpath = '/root/.openclaw/workspace-hbot/scripts/remaining_strings.json'
    with open(outpath, 'w') as f:
        json.dump(all_strings, f, indent=2, ensure_ascii=False)
    
    # Stats
    by_file = {}
    for key, val in all_strings.items():
        s = val['screen']
        by_file[s] = by_file.get(s, 0) + 1
    
    print(f'Total remaining strings: {len(all_strings)}')
    for f, c in sorted(by_file.items(), key=lambda x: -x[1]):
        print(f'  {os.path.basename(f)}: {c}')

if __name__ == '__main__':
    main()
