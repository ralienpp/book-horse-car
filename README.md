# Overview

A multi-language illustrated children's picture book, built entirely in LuaLaTeX.

## Languages

Romanian (ro), Russian (ru), English (en), German (de).

Romanian and Russian are the primary check pair - always build both to catch Cyrillic font issues early.

## Quick Start

```bash
# Build all four languages (A5, two-pass each)
make all

# Build only Romanian
make ro

# Build Romanian + Russian, then run verification
make verify

# Debug build with grid overlay (Romanian only)
make debug

# Create a booklet version after a basic version was compiled.
# For 2xA5 per A4: run the command below, print as duplex long-edge and just fold them.
# The output is in, e.g., `book-ro-booklet.pdf`
scripts/make-booklet.sh book-ro.pdf a4

# For 4xA6 per A4: run the command below, print as duplex SHORT-edge, cut horizontally, interleave the pages. The output is in, e.g.,: `book-ro-a6-booklet.pdf`
make booklet SHEET=a4 SIZE=a6
```

Output files land in the project root: `book-ro.pdf`, `book-ru.pdf`, `book-en.pdf`, `book-de.pdf`.

## Project Structure

```
.
├── main.tex                    # Full book content (22 pages)
├── main-dual.tex               # Dual-language edition
├── picturebook.sty             # LaTeX package - all macros, environments, config
├── picturebook-glossary.lua    # Glossary CSV parser and LaTeX emitter
├── Makefile                    # Build system
├── translations/
│   ├── ro.lua                  # Romanian (primary)
│   ├── ru.lua                  # Russian
│   ├── en.lua                  # English
│   ├── de.lua                  # German
│   └── glossary.csv            # Multilingual glossary (IPA + translations)
├── images/
│   ├── modern-city.jpeg        # Placeholder - modern city scene
│   └── horse-tram.jpeg         # Placeholder - horse tram era
├── scripts/
│   ├── verify.sh               # Post-build automated verification (12 checks)
│   ├── check-translations.lua  # Translation key completeness validator
│   ├── glossary-canonicalize.py # Sort, validate, sync glossary CSV
│   ├── glossary-ipa.py         # Fill in missing IPA transcriptions
│   ├── scale-pdf.sh            # Ghostscript-based ISO paper size scaling
│   ├── make-booklet.sh         # Booklet imposition for saddle-stitch printing
│   └── setup-fonts.sh          # Downloads optional fonts into fonts/
├── fonts/                      # Downloaded by setup-fonts.sh — not in git
├── story.txt                   # Original Romanian story text
└── spec.md                     # Full specification (R1–R15)
```

## Fonts

Font files are **not committed** to the repository. Run the setup script once after cloning:

```bash
bash scripts/setup-fonts.sh            # install all available fonts
bash scripts/setup-fonts.sh antykwa    # install one font only
bash scripts/setup-fonts.sh --list     # show what is available
```

| Font | License | Variants |
|------|---------|----------|
| Antykwa Toruńska | GUST Font License (free, open) | Regular, Light, Med, Cond |
| OpenDyslexic | SIL Open Font License 1.1 (free, open) | Regular, Bold, Italic, Bold-Italic |

To use a downloaded font, set `\bookfont` before loading the package in `main.tex`:

```latex
\def\bookfont{Antykwa Torunska}
\usepackage{picturebook}
```

Or set it permanently in `picturebook.sty` (line ~153):

```latex
\def\bookfont{Antykwa Torunska}
```

The font must be either installed system-wide (visible to `fc-list`) or placed in the `fonts/` subdirectory. For fonts in `fonts/`, `fontspec` finds them automatically because LuaLaTeX is run from the project root.

**Fonts requiring manual download** (non-redistributable — not handled by the script):

| Font | License | URL |
|------|---------|-----|
| Dyslexie | Commercial, proprietary | https://www.dyslexiefont.com |
| Lexie Readable | Freeware, no redistribution | https://www.k-type.com/fonts/lexie-readable |
| Sylexiad | Academic use only | http://www.robsfonts.com |

Place manually downloaded fonts in `fonts/<subfolder>/` — those paths are already in `.gitignore`.

To see all fonts currently available on your system (usable without any setup):

```bash
fc-list --format="%{family}\n" | sort -u
```

## Makefile Targets

| Target               | Description                                            |
|----------------------|--------------------------------------------------------|
| `make all`           | Build all four languages (two LuaLaTeX passes each)    |
| `make ro`            | Build Romanian only                                    |
| `make ru`            | Build Russian only                                     |
| `make debug`         | Debug build - Romanian with grid overlay enabled       |
| `make verify`        | Build ro + ru, then run `scripts/verify.sh`            |
| `make check-translations` | Check all translation files for missing keys      |
| `make scale SIZE=b5` | Scale all `book-*.pdf` files to a target paper size    |
| `make booklet SHEET=a4` | Create A4 booklets from A5 content (direct fit)     |
| `make booklet SHEET=a4 SIZE=a6` | Scale to A6, then create A4 booklets with crop marks |
| `make clean`         | Remove all generated files (PDF, aux, log, etc.)       |

### Variables

- `SIZE` - Target paper size for scaling. Default: `b5`. Values: `a6`, `b6`, `a5`, `b5`, `a4`, `a3`.
- `SHEET` - Physical sheet size for booklet printing. Default: `a4`.

## picturebook.sty Reference

### Package Options

```latex
\usepackage[debug,pagenumbers]{picturebook}
```

| Option        | Description                                                   |
|---------------|---------------------------------------------------------------|
| `debug`       | Show 1cm grid, coordinate labels, safe-area box, page labels  |
| `pagenumbers` | Enable page numbers (default off)                             |

Debug mode can also be activated at compile time without editing the source:

```bash
lualatex "\def\debugmode{1}\input{main}"
```

### Paper Size

Canonical authoring size is **A5**. Other sizes are produced by scaling the finished PDF via Ghostscript, not by re-rendering.

### Coordinate System

**Top-left origin**, X increases right, Y increases down. All positions specified in **centimeters**.

### Macros

#### `\singlepage{image}{x}{y}{width}{content}`

Full-bleed single page. The image fills the entire page. A text block is placed at `(x, y)` cm from the top-left corner with the given width in cm.

```latex
\singlepage{images/modern-city.jpeg}{1}{15}{12.8}{%
    \begin{halo}
        \tr{p03_growing_cities}
    \end{halo}
}
```

#### `\fullspread{image}{Lx}{Ly}{Lw}{L-content}{Rx}{Ry}{Rw}{R-content}`

Double-page spread. A single image spans two pages using a clip+anchor technique. Left-page text is placed at `(Lx, Ly)` with width `Lw`; right-page at `(Rx, Ry)` with width `Rw`. Either content block can be empty (`{}`).

**Parity enforcement**: The left page of a spread must be even. If the current page is odd when `\fullspread` is called, an auto-filler page is inserted.

```latex
\fullspread{images/horse-tram.jpeg}%
    {1}{1}{12.8}{% left page
        \begin{halo}
            \tr{p01_modern_city}
        \end{halo}
    }%
    {1}{1}{12.8}{% right page
        \begin{halo}
            \tr{p02_horse_tram}
        \end{halo}
    }
```

#### `\startprose`

Switches to 20mm margins for prose/text-heavy sections. No `\endprose` is needed - calling `\singlepage` or `\fullspread` resets back to full-bleed mode.

#### `\fillerpage`

Inserts an intentional blank/decorative filler page. Useful for padding page count or adjusting parity.

#### `\tr{key}`

Retrieves a translated string from the active language's Lua table. If the key is missing, renders **MISSING: key** in red.

#### Page Number Controls

| Macro                        | Description                                      |
|------------------------------|--------------------------------------------------|
| `\pagenumberson`             | Enable page numbers from this point forward       |
| `\pagenumbersoff`            | Disable page numbers from this point forward      |
| `\pagenumberstyle{sides}`    | Page numbers on outer edges (left/right)          |
| `\pagenumberstyle{center}`   | Page numbers centered at the bottom               |

Page numbers render as TikZ overlays with a semi-transparent white background, so they work over full-bleed images.

### Environments

#### `halo`

Semi-transparent rounded box for readable text over images.

```latex
\begin{halo}[color=white, opacity=0.6]
    Text content here.
\end{halo}
```

| Parameter | Default | Description                        |
|-----------|---------|------------------------------------|
| `color`   | `white` | Background color                   |
| `opacity` | `0.6`   | Background opacity (0 = invisible) |

Built on `tcolorbox`. Works correctly inside `textblock*` positioning.

## Translation System

Translations are Lua tables in `translations/<lang>.lua`. Each file returns a table mapping string keys to translated values:

```lua
return {
  polyglossia_lang = "romanian",
  title    = "Calul, Cacatul și Mașina",
  subtitle = "O poveste despre cum orașele rezolvă problemele",
  p01_modern_city = "Orașele noastre nu arătau întotdeauna așa.",
  -- ... 26 keys total
}
```

The `polyglossia_lang` key sets the Polyglossia language for proper hyphenation and typographic rules.

### Adding a New Language

1. Copy an existing translation file: `cp translations/en.lua translations/fr.lua`
2. Translate all values (keep the keys identical).
3. Set `polyglossia_lang` to the correct Polyglossia language name.
4. Add `fr` to the `LANGS` variable in the Makefile.
5. Run `make check-translations` to verify key completeness.

### Checking Translations

```bash
# Via Makefile
make check-translations

# Directly
texlua scripts/check-translations.lua translations/
```

Validates that all `.lua` files in the translations directory define the same set of keys. Exits with code 1 if any file is missing a key.

## Glossary

The dual-language edition includes a glossary of vocabulary from the source language with IPA transcriptions and translations. The glossary is stored as a single CSV file at `translations/glossary.csv` and rendered at compile time by `picturebook-glossary.lua`.

### CSV Schema

```csv
src,prefix,word,ipa,dst,meaning
de,die,Straße,ʃtraːsə,en,"street, road"
de,die,Straße,ʃtraːsə,ro,"stradă, drum"
de,,aber,ˈaːbɐ,en,but
```

| Column   | Description |
|----------|-------------|
| `src`    | Source language code |
| `prefix` | Display prefix (e.g. `der`/`die`/`das` for German nouns). Ignored for sorting. |
| `word`   | The vocabulary word |
| `ipa`    | IPA transcription (Unicode). Can be left empty; propagated from other rows with same `(src, word)`. |
| `dst`    | Target language code |
| `meaning`| Translation in the target language |

Sorting is by `(src, word, dst)`, alphabetical, ignoring the prefix column.

### For Translators

Edit `translations/glossary.csv` in any spreadsheet application (Excel, Google Sheets, LibreOffice). Fill in the `meaning` column for your target language. The `prefix` and `ipa` columns can be left empty — they are propagated automatically from other rows for the same word.

### Building the Glossary

The glossary is rendered automatically by `\printglossary` in `main-dual.tex`. It reads the CSV at compile time, filters by the active `(src, dst)` language pair, and emits a compact dictionary-style layout. If no data exists for a language pair, the glossary section is simply empty.

To build a language pair without the glossary section, pass `GLOSSARY=off`:

```bash
make dual GLOSSARY=off
# or, without make:
lualatex -interaction=nonstopmode "\def\booklang{de}\def\booklangsecondary{tr}\def\bookglossaryoff{}\input{main-dual}"
```

### Maintainer Workflow

```bash
# 1. Sort and validate the glossary
python3 scripts/glossary-canonicalize.py translations/glossary.csv

# 2. Sync new vocabulary from a translation file (requires spaCy)
python3 scripts/glossary-canonicalize.py translations/glossary.csv \
    --sync translations/de.lua --dst en,ro

# 3. Fill in missing IPA transcriptions (requires ipa-dict data)
python3 scripts/glossary-ipa.py

# 4. Build the book
make dual
```

### Dependencies for Glossary Tooling

These are only needed for the maintainer scripts, not for building the book.

- [ipa-dict](https://github.com/open-dict-data/ipa-dict) — pronunciation dictionary (clone to `~/ipa-dict`)
- [epitran](https://pypi.org/project/epitran/) — rule-based IPA transliteration fallback (optional)
- [spaCy](https://spacy.io/) — lemmatization for vocabulary extraction (optional, for `--sync`)

## Scripts

### scripts/verify.sh

Post-build automated verification. Runs 12 checks against `book-ro.pdf` and `book-ru.pdf`:

1. Both PDFs exist
2. Page size is A5 (419.5 x 595.3 pts, +/-1pt tolerance)
3. Page count consistency between ro and ru
4. No overfull hboxes in log files
5. No missing images in log files
6. No `MISSING:` translation markers in PDF text (ro)
7. No `MISSING:` translation markers in PDF text (ru)
8. Cyrillic text present in Russian PDF
9. Full-bleed check - edge pixels of page 1 are not white

```bash
bash scripts/verify.sh
# Exit code 0 = all checks pass
# Exit code 1 = at least one check failed
```

### scripts/scale-pdf.sh

Scales a finished PDF to a different ISO paper size using Ghostscript.

```bash
# Single file
bash scripts/scale-pdf.sh book-ro.pdf b5
bash scripts/scale-pdf.sh book-ro.pdf a4 output/ro-a4.pdf

# Batch mode - scale all book-*.pdf
bash scripts/scale-pdf.sh --all b5

# List supported sizes
bash scripts/scale-pdf.sh --list
```

| Argument       | Description                                        |
|----------------|----------------------------------------------------|
| `input.pdf`    | Source PDF                                          |
| `size`         | Target: `a6`, `b6`, `a5`, `b5`, `a4`, `a3`        |
| `output.pdf`   | Optional output path (default: `<input>-<size>.pdf`)|
| `--all <size>` | Scale every `book-*.pdf` in the current directory   |
| `--list`       | Show supported sizes with dimensions                |

### scripts/make-booklet.sh

Produces a saddle-stitched booklet PDF ready for duplex printing. Auto-detects whether direct or indirect fit is needed.

```bash
# A5 content → A4 booklet (direct fit)
bash scripts/make-booklet.sh book-ro.pdf a4

# A6 content → A4 booklet (indirect fit with crop marks)
bash scripts/make-booklet.sh book-ro-a6.pdf a4

# A5 content → A3 booklet (indirect fit with crop marks)
bash scripts/make-booklet.sh book-ro.pdf a3
```

| Argument       | Description                                           |
|----------------|-------------------------------------------------------|
| `input.pdf`    | Source PDF (any ISO page size)                         |
| `sheet-size`   | Paper to print on: `a6`, `b6`, `a5`, `b5`, `a4`, `b4`, `a3` |
| `output.pdf`   | Optional output path (default: `<input>-booklet.pdf`) |

**Direct fit**: Content is exactly half the sheet (e.g. A5 on A4). Simple 2-up imposition via `pdfbook2`.

**Indirect fit**: Content is smaller than half the sheet (e.g. A6 on A4). The booklet is first imposed on its natural sheet, then centered on the target sheet with TikZ crop marks and a dashed fold line.

Printing instructions are printed to stdout after generation.

### scripts/check-translations.lua

See [Checking Translations](#checking-translations) above.

### scripts/glossary-canonicalize.py

Sorts and validates `translations/glossary.csv`. Optionally syncs vocabulary from a Lua translation file (requires spaCy).

```bash
# Sort and validate existing data
python3 scripts/glossary-canonicalize.py translations/glossary.csv

# Sync new words from a translation file (requires spaCy)
python3 scripts/glossary-canonicalize.py translations/glossary.csv --sync translations/de.lua
```

### scripts/glossary-ipa.py

Fills in missing IPA transcriptions in `translations/glossary.csv`. Uses ipa-dict lookup with optional Epitran fallback.

```bash
python3 scripts/glossary-ipa.py
python3 scripts/glossary-ipa.py --ipa-dict-dir /path/to/ipa-dict/data
```

### scripts/setup-fonts.sh

See [Fonts](#fonts) above.

## Dependencies

```bash
sudo apt install \
  texlive-latex-base \
  texlive-latex-extra \
  texlive-luatex \
  texlive-extra-utils \
  texlive-fonts-extra \
  poppler-utils \
  ghostscript \
  imagemagick \
  bc
```