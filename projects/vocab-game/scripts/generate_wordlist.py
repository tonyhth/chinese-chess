#!/usr/bin/env python3
"""Convert wordlist.md to wordlist.json for VocabGame."""
import json
import re
import sys

def parse_wordlist(md_path):
    with open(md_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    words = []
    seen_ids = set()
    
    # Match table rows: | number | word | meaning |
    for line in content.split('\n'):
        m = re.match(r'\s*\|\s*(\d+)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|', line)
        if m:
            wid = int(m.group(1))
            text = m.group(2).strip()
            meaning = m.group(3).strip()
            
            # Skip duplicate IDs (keep first occurrence)
            if wid in seen_ids:
                continue
            seen_ids.add(wid)
            
            # Assign to group (1-25): first 24 groups of 15, last group 16
            if wid <= 360:
                group = ((wid - 1) // 15) + 1
            else:
                group = 25
            
            words.append({
                "id": wid,
                "text": text,
                "meaning": meaning,
                "group": group
            })
    
    return words

def main():
    md_path = sys.argv[1] if len(sys.argv) > 1 else '../data/wordlist.md'
    json_path = sys.argv[2] if len(sys.argv) > 2 else '../VocabGame/Resources/Data/wordlist.json'
    
    words = parse_wordlist(md_path)
    
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    
    print(f"Generated {len(words)} words to {json_path}")

if __name__ == '__main__':
    main()
