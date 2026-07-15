#!/usr/bin/env python3
"""Canonicalize the glossary CSV: sort, validate, optionally sync with source.

Usage:
  python3 glossary-canonicalize.py glossary.csv
  python3 glossary-canonicalize.py glossary.csv --sync translations/de.lua

Without --sync: sorts and validates existing data.
With --sync: also extracts new words from the Lua file and adds them with empty
meanings (ready for translators to fill in). Requires spaCy.
"""

import argparse
import csv
import os
import re
import sys
from collections import defaultdict


def read_glossary(path):
    """Read the glossary CSV, return list of row dicts."""
    rows = []
    with open(path, 'r', encoding='utf-8', newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
    return rows


def write_glossary(path, rows):
    """Write rows back to the glossary CSV, sorted canonically."""
    # Sort by (src, word, dst) -- prefix is ignored for sorting
    rows.sort(key=lambda r: (r['src'], r['word'].lower(), r['dst']))

    with open(path, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['src', 'prefix', 'word', 'ipa', 'dst', 'meaning'])
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def validate_ipa(rows):
    """Check that IPA is consistent for the same (src, word) pair."""
    ipa_map = defaultdict(set)
    for row in rows:
        if row['ipa']:
            ipa_map[(row['src'], row['word'])].add(row['ipa'])

    issues = []
    for key, ipas in ipa_map.items():
        if len(ipas) > 1:
            issues.append(f"  {key[0]}/{key[1]}: {ipas}")

    if issues:
        print("WARNING: Inconsistent IPA values:", file=sys.stderr)
        for issue in issues:
            print(issue, file=sys.stderr)
    else:
        print("IPA consistency: OK", file=sys.stderr)


def propagate_ipa(rows):
    """Fill in missing IPA and prefix from other rows with the same (src, word)."""
    ipa_map = {}
    prefix_map = {}
    for row in rows:
        key = (row['src'], row['word'])
        if row['ipa'] and key not in ipa_map:
            ipa_map[key] = row['ipa']
        if row.get('prefix') and key not in prefix_map:
            prefix_map[key] = row['prefix']

    filled_ipa = 0
    filled_prefix = 0
    for row in rows:
        key = (row['src'], row['word'])
        if not row['ipa'] and key in ipa_map:
            row['ipa'] = ipa_map[key]
            filled_ipa += 1
        if not row.get('prefix') and key in prefix_map:
            row['prefix'] = prefix_map[key]
            filled_prefix += 1

    if filled_ipa:
        print(f"Propagated IPA to {filled_ipa} rows", file=sys.stderr)
    if filled_prefix:
        print(f"Propagated prefix to {filled_prefix} rows", file=sys.stderr)


def extract_lua_strings(text):
    """Extract string values from a Lua table file."""
    strings = []
    i = 0
    n = len(text)

    while i < n:
        if text[i] == '"':
            i += 1
            chars = []
            while i < n:
                if text[i] == '\\':
                    i += 1
                    if i < n:
                        chars.append(text[i])
                elif text[i] == '"':
                    break
                else:
                    chars.append(text[i])
                i += 1
            strings.append(''.join(chars))
            i += 1
        elif text[i:i + 2] == '[[':
            j = i + 2
            while j < n and text[j] == '=':
                j += 1
            equals_count = j - (i + 2)
            start = j
            i = start
            while i < n:
                if text[i] == ']':
                    k = i + 1
                    eq = 0
                    while k < n and text[k] == '=':
                        eq += 1
                        k += 1
                    if eq == equals_count and k < n and text[k] == ']':
                        strings.append(text[start:i])
                        i = k + 1
                        break
                i += 1
        else:
            i += 1

    return strings


def sync_with_source(rows, lua_path, src_lang, dst_langs):
    """Extract words from Lua source and add missing ones to the glossary.

    Requires spaCy for lemmatization.
    """
    try:
        import spacy
    except ImportError:
        print("ERROR: spaCy required for --sync. Install with: pip install spacy", file=sys.stderr)
        sys.exit(1)

    MODELS = {
        "en": "en_core_web_sm",
        "de": "de_core_news_sm",
        "es": "es_core_news_sm",
        "ro": "ro_core_news_sm",
        "ru": "ru_core_news_sm",
    }

    if src_lang not in MODELS:
        print(f"WARNING: No spaCy model for '{src_lang}', using blank pipeline", file=sys.stderr)
        nlp = spacy.blank(src_lang)
    else:
        nlp = spacy.load(MODELS[src_lang])

    with open(lua_path, 'r', encoding='utf-8') as f:
        text = f.read()

    strings = extract_lua_strings(text)
    combined = ' '.join(strings)
    doc = nlp(combined)

    # Extract lemmatized vocabulary
    vocab = set()
    for token in doc:
        if token.is_space or token.is_punct:
            continue
        lemma = token.lemma_.strip().lower()
        if len(lemma) < 2:
            continue
        if re.match(r'^\\', lemma):
            continue
        if not re.search(r'[^\W\d_]', lemma, re.UNICODE):
            continue
        vocab.add(lemma)

    # Find words already in glossary for this src_lang
    existing = set()
    for row in rows:
        if row['src'] == src_lang:
            existing.add(row['word'])

    # Add new words
    new_words = vocab - existing
    added = 0
    for word in sorted(new_words):
        for dst in dst_langs:
            rows.append({
                'src': src_lang,
                'prefix': '',
                'word': word,
                'ipa': '',
                'dst': dst,
                'meaning': '',
            })
            added += 1

    if added:
        print(f"Added {added} new rows ({len(new_words)} words × {len(dst_langs)} languages)", file=sys.stderr)
    else:
        print("No new words found", file=sys.stderr)

    # Report words in glossary but not in source
    removed_candidates = existing - vocab
    if removed_candidates:
        print(f"NOTE: {len(removed_candidates)} words in glossary but not in source:", file=sys.stderr)
        for w in sorted(removed_candidates)[:10]:
            print(f"  {w}", file=sys.stderr)
        if len(removed_candidates) > 10:
            print(f"  ... and {len(removed_candidates) - 10} more", file=sys.stderr)
        print("  (These are NOT auto-removed. Review and delete manually if needed.)", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description='Canonicalize the glossary CSV.')
    parser.add_argument('csv', help='Path to glossary.csv')
    parser.add_argument('--sync', metavar='LUA_FILE',
                        help='Sync vocabulary from a Lua translation file (requires spaCy)')
    parser.add_argument('--src', default=None,
                        help='Source language code (auto-detected from --sync filename if omitted)')
    parser.add_argument('--dst', default='en,ro',
                        help='Comma-separated destination languages for new entries (default: en,ro)')
    args = parser.parse_args()

    if not os.path.exists(args.csv):
        print(f"Error: {args.csv} not found", file=sys.stderr)
        sys.exit(1)

    rows = read_glossary(args.csv)
    print(f"Loaded {len(rows)} rows from {args.csv}", file=sys.stderr)

    if args.sync:
        src_lang = args.src or os.path.splitext(os.path.basename(args.sync))[0]
        dst_langs = [l.strip() for l in args.dst.split(',')]
        sync_with_source(rows, args.sync, src_lang, dst_langs)

    validate_ipa(rows)
    propagate_ipa(rows)
    write_glossary(args.csv, rows)

    print(f"Wrote {len(rows)} rows to {args.csv}", file=sys.stderr)


if __name__ == '__main__':
    main()
