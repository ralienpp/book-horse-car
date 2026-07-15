#!/usr/bin/env python3
"""Generate or fill in IPA transcriptions in the glossary CSV.

Reads translations/glossary.csv, looks up IPA for words that are missing it,
and writes the result back.

IPA sources (tried in order):
  1. ipa-dict lookup (open-source pronunciation dictionary)
  2. Epitran transliteration (rule-based, if installed)
  3. Left empty (translator can fill manually)

Usage:
  python3 glossary-ipa.py [--ipa-dict-dir /path/to/ipa-dict/data]

Dependencies:
  - ipa-dict data files (required): https://github.com/open-dict-data/ipa-dict
  - epitran (optional): pip install epitran
"""

import argparse
import csv
import os
import sys
from collections import defaultdict

# Map language codes to ipa-dict filenames and epitran codes
LANG_CONFIG = {
    'de': {'ipa_dict': 'de.txt',       'epitran': 'deu-Latn'},
    'en': {'ipa_dict': 'en_US.txt',    'epitran': 'eng-Latn'},
    'ro': {'ipa_dict': 'ro.txt',       'epitran': 'ron-Latn'},
    'es': {'ipa_dict': 'es_ES.txt',    'epitran': 'spa-Latn'},
    'fa': {'ipa_dict': 'fa.txt',       'epitran': None},
    'zh': {'ipa_dict': 'zh_hans.txt',  'epitran': None},
    'ru': {'ipa_dict': None,           'epitran': 'rus-Cyrl'},
    'tr': {'ipa_dict': None,           'epitran': 'tur-Latn'},
    'hi': {'ipa_dict': None,           'epitran': 'hin-Deva'},
    'bn': {'ipa_dict': None,           'epitran': 'ben-Beng'},
    'ta': {'ipa_dict': None,           'epitran': 'tam-Taml'},
}


def load_ipa_dict(filepath):
    """Load ipa-dict TSV into a word -> IPA lookup."""
    word_ipa = {}
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            parts = line.rstrip('\n').split('\t', 1)
            if len(parts) != 2:
                continue
            word, ipa_part = parts
            ipa_part = ipa_part.strip()
            # Take first reading if multiple
            if ',' in ipa_part:
                ipa_part = ipa_part.split(',')[0].strip()
            # Strip surrounding slashes
            if ipa_part.startswith('/') and ipa_part.endswith('/'):
                ipa_part = ipa_part[1:-1]
            if ipa_part:
                word_ipa[word.lower()] = ipa_part
    return word_ipa


def main():
    parser = argparse.ArgumentParser(
        description='Fill in missing IPA transcriptions in the glossary CSV.')
    parser.add_argument('--csv', default='translations/glossary.csv',
                        help='Path to glossary CSV (default: translations/glossary.csv)')
    parser.add_argument('--ipa-dict-dir', default=None,
                        help='Path to ipa-dict data directory')
    args = parser.parse_args()

    # Find ipa-dict data directory
    ipa_dict_dir = args.ipa_dict_dir
    if not ipa_dict_dir:
        # Try common locations
        candidates = [
            os.path.expanduser('~/ipa-dict/data'),
            '/usr/share/ipa-dict/data',
            os.path.join(os.path.dirname(__file__), '..', 'ipa-dict', 'data'),
        ]
        for c in candidates:
            if os.path.isdir(c):
                ipa_dict_dir = c
                break

    if not ipa_dict_dir or not os.path.isdir(ipa_dict_dir):
        print("WARNING: ipa-dict data directory not found. "
              "Use --ipa-dict-dir to specify.", file=sys.stderr)
        ipa_dict_dir = None

    # Try loading epitran
    epitran_module = None
    try:
        import epitran
        epitran_module = epitran
    except ImportError:
        print("NOTE: epitran not installed, dictionary lookup only.", file=sys.stderr)

    # Read glossary
    rows = []
    with open(args.csv, 'r', encoding='utf-8', newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)

    # Find which (src, word) pairs need IPA
    needs_ipa = set()
    has_ipa = {}
    for row in rows:
        key = (row['src'], row['word'].lower())
        if row['ipa']:
            has_ipa[key] = row['ipa']
        else:
            needs_ipa.add(key)

    # Remove pairs that already have IPA somewhere
    needs_ipa -= set(has_ipa.keys())

    if not needs_ipa:
        print("All entries already have IPA transcriptions.", file=sys.stderr)
        return

    print(f"Need IPA for {len(needs_ipa)} (src, word) pairs", file=sys.stderr)

    # Group by source language
    by_lang = defaultdict(set)
    for src, word in needs_ipa:
        by_lang[src].add(word)

    # Look up IPA for each language
    found_ipa = {}  # (src, word) -> ipa
    for lang, words in by_lang.items():
        cfg = LANG_CONFIG.get(lang)
        if not cfg:
            print(f"  {lang}: no IPA config, skipping {len(words)} words", file=sys.stderr)
            continue

        dict_found = 0
        epi_found = 0

        # Try ipa-dict
        ipa_dict = {}
        if ipa_dict_dir and cfg['ipa_dict']:
            dict_path = os.path.join(ipa_dict_dir, cfg['ipa_dict'])
            if os.path.exists(dict_path):
                ipa_dict = load_ipa_dict(dict_path)
                print(f"  {lang}: loaded {len(ipa_dict)} entries from ipa-dict", file=sys.stderr)

        # Try epitran
        epi = None
        if epitran_module and cfg.get('epitran'):
            try:
                epi = epitran_module.Epitran(cfg['epitran'])
                epi.transliterate('test')  # verify it works
                print(f"  {lang}: epitran ({cfg['epitran']}) ready as fallback", file=sys.stderr)
            except Exception as e:
                epi = None
                print(f"  {lang}: epitran unavailable: {e}", file=sys.stderr)

        for word in words:
            ipa = ipa_dict.get(word.lower())
            if ipa:
                dict_found += 1
                found_ipa[(lang, word)] = ipa
            elif epi:
                try:
                    ipa = epi.transliterate(word)
                    if ipa:
                        epi_found += 1
                        found_ipa[(lang, word)] = ipa
                except Exception:
                    pass

        missing = len(words) - dict_found - epi_found
        print(f"  {lang}: {dict_found} from dict, {epi_found} from epitran, "
              f"{missing} still missing", file=sys.stderr)

    # Apply found IPA back to rows
    updated = 0
    for row in rows:
        if not row['ipa']:
            key = (row['src'], row['word'])
            ipa = found_ipa.get(key)
            if not ipa:
                # Try case-insensitive
                key_lower = (row['src'], row['word'].lower())
                ipa = found_ipa.get(key_lower)
            if ipa:
                row['ipa'] = ipa
                updated += 1

    # Write back
    with open(args.csv, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['src', 'prefix', 'word', 'ipa', 'dst', 'meaning'])
        writer.writeheader()
        for row in rows:
            writer.writerow(row)

    print(f"Updated {updated} rows with IPA transcriptions", file=sys.stderr)


if __name__ == '__main__':
    main()
