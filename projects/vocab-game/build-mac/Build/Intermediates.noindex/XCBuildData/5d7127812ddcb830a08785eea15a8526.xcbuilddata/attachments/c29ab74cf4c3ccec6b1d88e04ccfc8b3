#!/bin/sh
cd "$PROJECT_DIR/scripts"
if [ ! -f "../VocabGame/Resources/Data/wordlist.json" ] || [ "../data/wordlist.md" -nt "../VocabGame/Resources/Data/wordlist.json" ]; then
  python3 generate_wordlist.py ../data/wordlist.md ../VocabGame/Resources/Data/wordlist.json
fi

