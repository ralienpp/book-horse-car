#!/usr/bin/env bash
# ============================================================
#  make-booklet.sh — Produce a saddle-stitched booklet PDF
#                    ready for duplex printing.
#
#  Takes a page-sized PDF (e.g. A5) and imposes it 2-up in
#  booklet signature order on a larger sheet (e.g. A4).
#
#  When the sheet is exactly one ISO step above the content
#  (A5→A4, A6→A5, B6→B5, etc.), this is a single pdfbook2
#  call — the simple case.
#
#  When the sheet is two or more steps above (e.g. A6 content
#  on A4 sheets), the booklet spread is smaller than the sheet.
#  In that case the script centers the spread on the sheet and
#  adds crop marks so you can trim after printing.
#
#  Usage:
#    bash scripts/make-booklet.sh <input.pdf> <sheet-size> [output.pdf]
#    bash scripts/make-booklet.sh --help
#
#  Examples:
#    # A5 book → A4 booklet (simple case)
#    bash scripts/make-booklet.sh book-ro.pdf a4
#
#    # A6 book → A4 booklet (center + crop marks)
#    bash scripts/make-booklet.sh book-ro-a6.pdf a4
#
#    # A5 book → A3 booklet (center + crop marks)
#    bash scripts/make-booklet.sh book-ro.pdf a3
#
#  Requires: pdfbook2, pdfjam, pdfinfo, gs (Ghostscript)
# ============================================================

set -euo pipefail

# ---- ISO sizes: name → "width_pt height_pt" (portrait) -----
declare -A ISO_W ISO_H ISO_LATEX
ISO_W[a6]=298   ; ISO_H[a6]=420  ; ISO_LATEX[a6]="a6paper"
ISO_W[b6]=354   ; ISO_H[b6]=499  ; ISO_LATEX[b6]="b6paper"
ISO_W[a5]=420   ; ISO_H[a5]=595  ; ISO_LATEX[a5]="a5paper"
ISO_W[b5]=499   ; ISO_H[b5]=709  ; ISO_LATEX[b5]="b5paper"
ISO_W[a4]=595   ; ISO_H[a4]=842  ; ISO_LATEX[a4]="a4paper"
ISO_W[b4]=709   ; ISO_H[b4]=1001 ; ISO_LATEX[b4]="b4paper"
ISO_W[a3]=842   ; ISO_H[a3]=1191 ; ISO_LATEX[a3]="a3paper"

# Ordered list for "one step up" lookups
SIZE_ORDER=(a6 b6 a5 b5 a4 b4 a3)

# ---- Helpers ------------------------------------------------
die() { echo "ERROR: $1" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  make-booklet.sh <input.pdf> <sheet-size> [output.pdf]
  make-booklet.sh --help

Arguments:
  input.pdf     Source PDF (any ISO page size)
  sheet-size    Paper you will print on: a6, b6, a5, b5, a4, b4, a3
  output.pdf    Optional output path (default: <input>-booklet.pdf)

The script auto-detects the input page size and chooses the
appropriate pipeline:

  • Direct fit: content is exactly half the sheet (e.g. A5 on A4).
    → Simple 2-up booklet imposition via pdfbook2.

  • Indirect fit: content is smaller than half the sheet
    (e.g. A6 on A4). → Booklet imposed on the natural sheet,
    then centered on the target sheet with crop marks.

Requires: pdfbook2, pdfjam, pdfinfo
EOF
  exit 0
}

# Detect input page size name from PDF dimensions.
# Returns the ISO size name or "unknown".
detect_size() {
  local pdf="$1"
  local info
  info=$(pdfinfo "$pdf" 2>/dev/null) || die "Cannot read $pdf"
  local w h
  w=$(echo "$info" | grep "Page size:" | grep -oP '[\d.]+' | head -1)
  h=$(echo "$info" | grep "Page size:" | grep -oP '[\d.]+' | head -2 | tail -1)
  # Round to nearest integer for matching
  w=$(printf "%.0f" "$w")
  h=$(printf "%.0f" "$h")

  for name in "${SIZE_ORDER[@]}"; do
    local nw="${ISO_W[$name]}"
    local nh="${ISO_H[$name]}"
    # Allow ±3pt tolerance; check both portrait and landscape
    if (( (w >= nw-3 && w <= nw+3) && (h >= nh-3 && h <= nh+3) )) || \
       (( (w >= nh-3 && w <= nh+3) && (h >= nw-3 && h <= nw+3) )); then
      echo "$name"
      return
    fi
  done
  echo "unknown"
}

# Find the natural booklet sheet for a given content size.
# Two pages of size X side-by-side = one step up in ISO.
# A6 → A5, B6 → B5, A5 → A4, B5 → B4, A4 → A3.
natural_sheet() {
  local content="$1"
  case "$content" in
    a6) echo "a5" ;;
    b6) echo "b5" ;;
    a5) echo "a4" ;;
    b5) echo "b4" ;;
    a4) echo "a3" ;;
    *) echo "" ;;
  esac
}

# ---- Argument parsing ---------------------------------------
[ $# -eq 0 ] && usage
[ "$1" = "--help" ] || [ "$1" = "-h" ] && usage

input="$1"
[ -f "$input" ] || die "File not found: $input"

[ $# -ge 2 ] || die "Missing sheet-size argument. Use --help for usage."
sheet="${2,,}"
[ -n "${ISO_W[$sheet]+x}" ] || die "Unknown sheet size '$sheet'. Supported: ${SIZE_ORDER[*]}"

if [ $# -ge 3 ]; then
  output="$3"
else
  base="${input%.pdf}"
  output="${base}-booklet.pdf"
fi

# ---- Detect input size and plan pipeline --------------------
content_size=$(detect_size "$input")
[ "$content_size" = "unknown" ] && die "Cannot detect page size of $input. Is it a standard ISO size?"

natural=$(natural_sheet "$content_size")
[ -z "$natural" ] && die "No known booklet sheet for content size '$content_size'."

echo "Input:         $input ($content_size)"
echo "Sheet:         $sheet"
echo "Natural sheet: $natural (2× $content_size side-by-side)"
echo ""

# Check that the sheet is at least as large as the natural sheet
sheet_area=$(( ISO_W[$sheet] * ISO_H[$sheet] ))
natural_area=$(( ISO_W[$natural] * ISO_H[$natural] ))
(( sheet_area >= natural_area )) || die "Sheet $sheet is too small for $content_size content. Need at least $natural."

# ---- Create temp directory ----------------------------------
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# ---- Step 1: Impose booklet on natural sheet ----------------
echo "Step 1: Imposing booklet on ${natural} sheet..."
booklet_tmp="$tmpdir/booklet-${natural}.pdf"
pdfbook2 --paper="${ISO_LATEX[$natural]}" --no-crop \
  -o 0 -i 0 -t 0 -b 0 \
  "$input" 2>/dev/null

# pdfbook2 writes to <input-basename>-book.pdf in the input's directory
pdfbook2_output="${input%.pdf}-book.pdf"
[ -f "$pdfbook2_output" ] || die "pdfbook2 did not produce expected output ($pdfbook2_output)"
mv "$pdfbook2_output" "$booklet_tmp"

booklet_pages=$(pdfinfo "$booklet_tmp" 2>/dev/null | grep "Pages:" | awk '{print $2}')
echo "  → $booklet_tmp ($booklet_pages sides)"

# ---- Step 2: If natural sheet == target sheet, we're done ---
if [ "$natural" = "$sheet" ]; then
  echo ""
  echo "Direct fit — no centering needed."
  cp "$booklet_tmp" "$output"
  echo ""
  echo "Output: $output"
  echo "  Pages: $booklet_pages"
  echo "  Size:  $(pdfinfo "$output" | grep 'Page size:')"
  echo ""
  echo "Print duplex (long-edge), fold, staple."
  exit 0
fi

# ---- Step 2b: ISO-doubling — stack two spreads 1×2 on sheet --
# If 2 × area(natural) ≈ area(sheet) (within 3%), the natural booklet
# spread (landscape) fits exactly twice on the sheet (portrait).
# Use pdfjam --nup 1x2 so the printer gets the right size directly.
two_natural=$(( 2 * natural_area ))
# Check |2*natural - sheet| / sheet < 3%
diff=$(( two_natural - sheet_area ))
[ $diff -lt 0 ] && diff=$(( -diff ))
threshold=$(( sheet_area * 3 / 100 ))
if (( diff <= threshold )); then
  echo ""
  echo "ISO-doubling fit — stacking two spreads 1×2 on ${sheet} (portrait)..."

  # pdfbook2 output: pages come in duplex pairs [front, back] per booklet sheet.
  # For short-edge duplex on portrait A4, flipping over the top edge swaps
  # top/bottom halves. So to get correct front/back per strip after cutting:
  #   A4 front: top=p1(front-of-sheet1), bottom=p3(front-of-sheet2)
  #   A4 back:  top=p4(back-of-sheet2),  bottom=p2(back-of-sheet1)
  # → reorder every group of 4 from [a,b,c,d] to [a,c,d,b] before nup.
  n_pages="$booklet_pages"
  page_order=""
  i=1
  while (( i <= n_pages )); do
    remaining=$(( n_pages - i + 1 ))
    if (( remaining >= 4 )); then
      a=$i; b=$((i+1)); c=$((i+2)); d=$((i+3))
      page_order="${page_order:+$page_order,}$a,$c,$d,$b"
    else
      # Partial group at end — emit as-is
      for (( j=i; j<=n_pages; j++ )); do
        page_order="${page_order:+$page_order,}$j"
      done
    fi
    i=$((i+4))
  done

  pdfjam --nup 1x2 --paper "${ISO_LATEX[$sheet]}" --no-landscape \
    --delta "0 0" --frame false \
    "$booklet_tmp" "$page_order" \
    --outfile "$output" 2>/dev/null
  [ -f "$output" ] || die "pdfjam failed to produce $output"
  out_pages=$(pdfinfo "$output" 2>/dev/null | grep "Pages:" | awk '{print $2}')
  out_size=$(pdfinfo "$output" 2>/dev/null | grep "Page size:")
  echo "  → $output"
  echo ""
  echo "Output: $output"
  echo "  Pages: $out_pages"
  echo "  Size:  $out_size"
  echo ""
  echo "Print duplex (short-edge). Cut horizontally. Fold each strip. Stack and staple."
  exit 0
fi

# ---- Step 3: Center on larger sheet with crop marks ---------
echo ""
echo "Step 2: Centering on ${sheet} sheet with crop marks..."

# The booklet spread is in landscape orientation of the natural sheet.
# We need to place it centered on the target sheet (also landscape).
#
# We use pdfjam with a TikZ preamble that draws crop marks at the
# corners of the content area.

# Content dimensions (the booklet spread = natural sheet in landscape)
cw="${ISO_H[$natural]}"  # landscape: width = portrait height
ch="${ISO_W[$natural]}"  # landscape: height = portrait width

# Sheet dimensions (landscape)
sw="${ISO_H[$sheet]}"
sh="${ISO_W[$sheet]}"

# Offsets from sheet edge to content edge (in pt)
ox=$(( (sw - cw) / 2 ))
oy=$(( (sh - ch) / 2 ))

# Crop mark length and offset from content edge
CM=20   # length in pt
GAP=3   # gap between mark and content edge in pt

# TikZ preamble that draws crop marks on every page.
# Coordinates are relative to the page (0,0 = bottom-left).
read -r -d '' PREAMBLE << 'TIKZEOF' || true
\usepackage{tikz}
\usepackage{everypage}
\AddEverypageHook{%
  \begin{tikzpicture}[remember picture, overlay]
    % --- crop marks at the four corners of the content area ---
    % Bottom-left
    \draw[black, thin] ([xshift=OXpt, yshift=OYpt-GAPpt]current page.south west)
      -- ++(0,-CMpt);
    \draw[black, thin] ([xshift=OXpt-GAPpt, yshift=OYpt]current page.south west)
      -- ++(-CMpt,0);
    % Bottom-right
    \draw[black, thin] ([xshift=-OXpt, yshift=OYpt-GAPpt]current page.south east)
      -- ++(0,-CMpt);
    \draw[black, thin] ([xshift=-OXpt+GAPpt, yshift=OYpt]current page.south east)
      -- ++(CMpt,0);
    % Top-left
    \draw[black, thin] ([xshift=OXpt, yshift=-OYpt+GAPpt]current page.north west)
      -- ++(0,CMpt);
    \draw[black, thin] ([xshift=OXpt-GAPpt, yshift=-OYpt]current page.north west)
      -- ++(-CMpt,0);
    % Top-right
    \draw[black, thin] ([xshift=-OXpt, yshift=-OYpt+GAPpt]current page.north east)
      -- ++(0,CMpt);
    \draw[black, thin] ([xshift=-OXpt+GAPpt, yshift=-OYpt]current page.north east)
      -- ++(CMpt,0);
    % --- fold line (dashed, at center of content) ---
    \draw[gray, densely dashed, thin]
      ([xshift=OXpt+CWHALFpt, yshift=OYpt-GAPpt]current page.south west)
      -- ++(0,-CMpt);
    \draw[gray, densely dashed, thin]
      ([xshift=OXpt+CWHALFpt, yshift=-OYpt+GAPpt]current page.north west)
      -- ++(0,CMpt);
  \end{tikzpicture}%
}
TIKZEOF

# Substitute values into the preamble
cw_half=$(( cw / 2 ))
PREAMBLE="${PREAMBLE//OX/$ox}"
PREAMBLE="${PREAMBLE//OY/$oy}"
PREAMBLE="${PREAMBLE//GAP/$GAP}"
PREAMBLE="${PREAMBLE//CM/$CM}"
PREAMBLE="${PREAMBLE//CWHALF/$cw_half}"

pdfjam --paper "${ISO_LATEX[$sheet]}" --landscape \
  --preamble "$PREAMBLE" \
  "$booklet_tmp" \
  --outfile "$output" 2>/dev/null

[ -f "$output" ] || die "pdfjam failed to produce $output"

out_pages=$(pdfinfo "$output" 2>/dev/null | grep "Pages:" | awk '{print $2}')
out_size=$(pdfinfo "$output" 2>/dev/null | grep "Page size:")

echo "  → $output"
echo ""
echo "Output: $output"
echo "  Pages: $out_pages"
echo "  Size:  $out_size"
echo ""
echo "Print duplex (long-edge). Cut along crop marks. Fold at dashed line. Staple."
