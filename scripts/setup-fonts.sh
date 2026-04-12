#!/usr/bin/env bash
# ============================================================
#  setup-fonts.sh — Download optional fonts into fonts/
#
#  Fonts are NOT committed to the repository. Run this script
#  once after cloning, or whenever you want to use a new font.
#
#  Usage:
#    bash scripts/setup-fonts.sh            # install all fonts
#    bash scripts/setup-fonts.sh antykwa    # install one font
#    bash scripts/setup-fonts.sh --list     # show available fonts
#
#  After running, use a font in main.tex:
#    \def\bookfont{Antykwa Torunska}
#    \usepackage{picturebook}
#
#  Or set it permanently in picturebook.sty:
#    \def\bookfont{Antykwa Torunska}
#
#  License notes:
#    Antykwa Torunska  GUST Font License (free, open)
#    OpenDyslexic      SIL Open Font License 1.1 (free, open)
# ============================================================

set -euo pipefail

FONTS_DIR="$(cd "$(dirname "$0")/.." && pwd)/fonts"
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

die()  { echo "ERROR: $1" >&2; exit 1; }
info() { echo "  $1"; }
ok()   { echo "  [ok] $1"; }
skip() { echo "  [skip] $1 — already installed"; }

# ============================================================
#  Font definitions
# ============================================================

install_antykwa() {
  local dest="$FONTS_DIR/antykwa"
  local marker="$dest/AntykwaTorunska-Regular.otf"
  [ -f "$marker" ] && { skip "Antykwa Torunska"; return; }

  echo "Installing Antykwa Torunska (GUST Font License)..."
  mkdir -p "$dest"
  local tmp="$TMPDIR_BASE/antt"
  mkdir -p "$tmp"

  info "Downloading from CTAN..."
  curl -fsSL "https://ftp.fau.de/ctan/fonts/antt.zip" -o "$tmp/antt.zip" \
    || die "Download failed. Check your internet connection."

  info "Unpacking..."
  unzip -q "$tmp/antt.zip" "antt/fonts/opentype/public/antt/*.otf" -d "$tmp"
  cp "$tmp/antt/fonts/opentype/public/antt/"*.otf "$dest/"

  local count
  count=$(ls "$dest/"*.otf 2>/dev/null | wc -l)
  ok "Antykwa Torunska — $count OTF files in fonts/antykwa/"
  echo ""
  echo "     Variants available:"
  echo "       Regular:  \\def\\bookfont{Antykwa Torunska}"
  echo "       Light:    \\def\\bookfont{Antykwa Torunska Light}"
  echo "       Medium:   \\def\\bookfont{Antykwa Torunska Med}"
  echo "       Cond:     \\def\\bookfont{Antykwa Torunska Cond}"
}

install_opendyslexic() {
  local dest="$FONTS_DIR/opendyslexic"
  local marker="$dest/OpenDyslexic-Regular.otf"
  [ -f "$marker" ] && { skip "OpenDyslexic"; return; }

  echo "Installing OpenDyslexic (SIL Open Font License 1.1)..."
  mkdir -p "$dest"
  local tmp="$TMPDIR_BASE/opendyslexic"
  mkdir -p "$tmp"

  info "Downloading from GitHub..."
  curl -fsSL \
    "https://github.com/antijingoist/opendyslexic/releases/download/v0.91.12/opendyslexic-0.910.12-rc2-2019.10.17.zip" \
    -o "$tmp/opendyslexic.zip" \
    || die "Download failed. Check your internet connection."

  info "Unpacking..."
  unzip -q "$tmp/opendyslexic.zip" "*.otf" -d "$tmp"
  chmod u+r "$tmp/"*.otf
  cp "$tmp/"*.otf "$dest/"

  local count
  count=$(ls "$dest/"*.otf 2>/dev/null | wc -l)
  ok "OpenDyslexic — $count OTF files in fonts/opendyslexic/"
  echo ""
  echo "     Usage: \\def\\bookfont{OpenDyslexic}"
}

# ============================================================
#  Fonts that cannot be downloaded automatically
# ============================================================

note_manual_fonts() {
  echo ""
  echo "Fonts requiring manual download (check license before use):"
  echo ""
  echo "  Dyslexie Font     — commercial, proprietary"
  echo "    https://www.dyslexiefont.com"
  echo "    Place .otf/.ttf files in fonts/dyslexie/"
  echo ""
  echo "  Lexie Readable    — freeware, no redistribution"
  echo "    https://www.k-type.com/fonts/lexie-readable"
  echo "    Place .otf/.ttf files in fonts/lexie/"
  echo ""
  echo "  Sylexiad          — academic use only"
  echo "    http://www.robsfonts.com"
  echo "    Place .otf/.ttf files in fonts/sylexiad/"
  echo ""
  echo "  For any manually placed font, use it with:"
  echo "    \\def\\bookfont{Font Family Name}"
  echo "    \\def\\bookfontpath{fonts/subfolder/}"
}

# ============================================================
#  Argument parsing
# ============================================================

list_fonts() {
  echo "Available fonts:"
  echo ""
  echo "  antykwa       Antykwa Torunska  (GUST Font License)"
  echo "  opendyslexic  OpenDyslexic      (SIL Open Font License 1.1)"
  echo ""
  echo "Run without arguments to install all of the above."
}

case "${1:-all}" in
  --list|-l)
    list_fonts
    ;;
  all)
    echo "=== Setting up fonts ==="
    echo ""
    install_antykwa
    echo ""
    install_opendyslexic
    note_manual_fonts
    echo ""
    echo "=== Done ==="
    ;;
  antykwa)
    install_antykwa
    ;;
  opendyslexic)
    install_opendyslexic
    ;;
  *)
    die "Unknown font '$1'. Run with --list to see options."
    ;;
esac
