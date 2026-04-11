#!/usr/bin/env bash
# ============================================================
#  verify.sh — Post-build automated verification
#
#  Usage:  bash scripts/verify.sh
#
#  Expects book-ro.pdf and book-ru.pdf to exist in the current directory.
#  Exit code 0 = all checks pass.
#  Exit code 1 = at least one check failed.
# ============================================================

set -euo pipefail

PASS=0
FAIL=0
WARN=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN + 1)); }

echo "=== Verification: book-ro.pdf and book-ru.pdf ==="
echo ""

# ----------------------------------------------------------
#  Check that PDFs exist
# ----------------------------------------------------------
for pdf in book-ro.pdf book-ru.pdf; do
  if [ ! -f "$pdf" ]; then
    fail "$pdf does not exist"
    echo ""
    echo "RESULT: FAIL (missing PDFs)"
    exit 1
  fi
done
pass "Both PDFs exist"

# ----------------------------------------------------------
#  Check page size (A5 = 148 x 210 mm)
# ----------------------------------------------------------
for pdf in book-ro.pdf book-ru.pdf; do
  size=$(pdfinfo "$pdf" 2>/dev/null | grep "Page size:" | head -1)
  # pdfinfo reports in points: 419.528 x 595.276 pts (A5)
  w=$(echo "$size" | grep -oP '[\d.]+' | head -1)
  h=$(echo "$size" | grep -oP '[\d.]+' | head -2 | tail -1)
  # Allow ±1pt tolerance
  w_ok=$(echo "$w > 418 && $w < 421" | bc -l)
  h_ok=$(echo "$h > 594 && $h < 597" | bc -l)
  if [ "$w_ok" = "1" ] && [ "$h_ok" = "1" ]; then
    pass "$pdf page size is A5 (${w} x ${h} pts)"
  else
    fail "$pdf page size is NOT A5 (got ${w} x ${h} pts)"
  fi
done

# ----------------------------------------------------------
#  Check page count consistency (ro and ru should have same count)
# ----------------------------------------------------------
pages_ro=$(pdfinfo book-ro.pdf 2>/dev/null | grep "Pages:" | awk '{print $2}')
pages_ru=$(pdfinfo book-ru.pdf 2>/dev/null | grep "Pages:" | awk '{print $2}')
if [ "$pages_ro" = "$pages_ru" ]; then
  pass "Page counts match: ro=$pages_ro, ru=$pages_ru"
else
  warn "Page counts differ: ro=$pages_ro, ru=$pages_ru (may be OK if text lengths differ)"
fi

# ----------------------------------------------------------
#  Check for overfull hboxes in log files
# ----------------------------------------------------------
for lang in ro ru; do
  logfile="book-${lang}.log"
  if [ -f "$logfile" ]; then
    count=$(grep -c "Overfull \\\\hbox" "$logfile" 2>/dev/null || true)
    if [ "$count" = "0" ] || [ -z "$count" ]; then
      pass "book-${lang}: No overfull hboxes"
    else
      warn "book-${lang}: $count overfull hbox warnings"
    fi
  else
    warn "book-${lang}.log not found — skipping hbox check"
  fi
done

# ----------------------------------------------------------
#  Check for missing images in log files
# ----------------------------------------------------------
for lang in ro ru; do
  logfile="book-${lang}.log"
  if [ -f "$logfile" ]; then
    missing=$(grep -ci "file.*not found\|could not find image" "$logfile" 2>/dev/null || true)
    if [ "$missing" = "0" ] || [ -z "$missing" ]; then
      pass "book-${lang}: No missing images"
    else
      fail "book-${lang}: $missing missing image(s) in log"
    fi
  fi
done

# ----------------------------------------------------------
#  Check for MISSING translation keys in PDF text
# ----------------------------------------------------------
for lang in ro ru; do
  pdf="book-${lang}.pdf"
  text=$(pdftotext "$pdf" - 2>/dev/null || echo "")
  count=$(echo "$text" | grep -c "MISSING:" 2>/dev/null || true)
  if [ "$count" = "0" ] || [ -z "$count" ]; then
    pass "book-${lang}: No missing translation keys"
  else
    fail "book-${lang}: Found $count 'MISSING:' markers in PDF text"
    echo "$text" | grep "MISSING:" | head -5 | sed 's/^/         /'
  fi
done

# ----------------------------------------------------------
#  Cyrillic integrity check (Russian PDF)
# ----------------------------------------------------------
ru_text=$(pdftotext book-ru.pdf - 2>/dev/null || echo "")
# Check for at least some Cyrillic characters (Unicode range \u0400-\u04FF)
cyrillic_count=$(echo "$ru_text" | grep -cP '[\x{0400}-\x{04FF}]' 2>/dev/null || true)
if [ "$cyrillic_count" -gt 0 ] 2>/dev/null; then
  pass "book-ru: Cyrillic text present ($cyrillic_count lines with Cyrillic)"
else
  fail "book-ru: No Cyrillic text found — possible font/encoding issue"
fi

# ----------------------------------------------------------
#  Full-bleed check: verify edge pixels are not white
#  (Renders first illustrated page to PNG, checks edges)
# ----------------------------------------------------------
for lang in ro; do
  pdf="book-${lang}.pdf"
  tmpdir=$(mktemp -d)
  # Render page 1 at 72 DPI
  pdftoppm -f 1 -l 1 -r 72 -png "$pdf" "$tmpdir/page" 2>/dev/null
  png=$(ls "$tmpdir"/page-*.png 2>/dev/null | head -1)
  if [ -f "$png" ]; then
    # Get image dimensions
    dims=$(identify -format "%w %h" "$png" 2>/dev/null)
    w=$(echo "$dims" | awk '{print $1}')
    h=$(echo "$dims" | awk '{print $2}')
    # Check if the top-left pixel is white (or very close to white)
    # A full-bleed page should NOT have white edges
    tl_color=$(convert "$png" -crop 1x1+0+0 -format "%[fx:mean]" info: 2>/dev/null || echo "unknown")
    tr_color=$(convert "$png" -crop "1x1+$((w-1))+0" -format "%[fx:mean]" info: 2>/dev/null || echo "unknown")
    bl_color=$(convert "$png" -crop "1x1+0+$((h-1))" -format "%[fx:mean]" info: 2>/dev/null || echo "unknown")
    br_color=$(convert "$png" -crop "1x1+$((w-1))+$((h-1))" -format "%[fx:mean]" info: 2>/dev/null || echo "unknown")

    all_white=true
    for c in "$tl_color" "$tr_color" "$bl_color" "$br_color"; do
      if [ "$c" != "unknown" ]; then
        is_white=$(echo "$c > 0.98" | bc -l 2>/dev/null || echo "0")
        if [ "$is_white" != "1" ]; then
          all_white=false
        fi
      fi
    done

    if [ "$all_white" = "false" ]; then
      pass "book-${lang} p.1: Full-bleed confirmed (edge pixels are not all white)"
    else
      warn "book-${lang} p.1: Edge pixels are white — may indicate missing full-bleed"
    fi
  else
    warn "Could not render $pdf page 1 to PNG for bleed check"
  fi
  rm -rf "$tmpdir"
done

# ----------------------------------------------------------
#  Summary
# ----------------------------------------------------------
echo ""
echo "=== Summary ==="
echo "  Passed:   $PASS"
echo "  Failed:   $FAIL"
echo "  Warnings: $WARN"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "RESULT: FAIL"
  exit 1
else
  echo "RESULT: PASS"
  exit 0
fi
