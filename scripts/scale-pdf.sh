#!/usr/bin/env bash
# ============================================================
#  scale-pdf.sh — Scale a PDF from its native size to a target
#                 ISO paper size using Ghostscript.
#
#  Designed for the picturebook project: the canonical authoring
#  size is A5; this script produces B6, B5, A4, etc. variants
#  by uniformly scaling the finished PDF.
#
#  Usage:
#    bash scripts/scale-pdf.sh <input.pdf> <size> [output.pdf]
#    bash scripts/scale-pdf.sh --all <size>
#    bash scripts/scale-pdf.sh --list
#
#  Examples:
#    bash scripts/scale-pdf.sh book-ro.pdf b5
#    bash scripts/scale-pdf.sh book-ro.pdf a4 output/ro-a4.pdf
#    bash scripts/scale-pdf.sh --all b5          # scales all book-*.pdf
#    bash scripts/scale-pdf.sh --list             # show supported sizes
#
#  Supported sizes:
#    a6, b6, a5, b5, a4, a3
#
#  The output filename defaults to <basename>-<size>.pdf in the
#  same directory as the input.
# ============================================================

set -euo pipefail

# ---- ISO paper sizes in points (1mm = 2.83465pt) -----------
# Width × Height in points, portrait orientation.
declare -A SIZES
SIZES[a6]="298 420"
SIZES[b6]="354 499"
SIZES[a5]="420 595"
SIZES[b5]="499 709"
SIZES[a4]="595 842"
SIZES[a3]="842 1191"

# ---- Helpers ------------------------------------------------
usage() {
  cat <<'EOF'
Usage:
  scale-pdf.sh <input.pdf> <size> [output.pdf]
  scale-pdf.sh --all <size>
  scale-pdf.sh --list

Arguments:
  input.pdf    Source PDF (e.g. book-ro.pdf)
  size         Target ISO paper size: a6, b6, a5, b5, a4, a3
  output.pdf   Optional output path (default: <input>-<size>.pdf)

Flags:
  --all <size>   Scale every book-*.pdf in the current directory
  --list         List supported paper sizes and exit
  --help, -h     Show this help
EOF
  exit 0
}

list_sizes() {
  echo "Supported ISO paper sizes:"
  echo ""
  printf "  %-6s %s\n" "Name" "Dimensions"
  printf "  %-6s %s\n" "----" "----------"
  for name in a6 b6 a5 b5 a4 a3; do
    read -r w h <<< "${SIZES[$name]}"
    # Convert points back to mm for display
    w_mm=$(echo "scale=0; $w / 2.83465" | bc)
    h_mm=$(echo "scale=0; $h / 2.83465" | bc)
    printf "  %-6s %s × %s mm  (%s × %s pt)\n" "$name" "$w_mm" "$h_mm" "$w" "$h"
  done
  exit 0
}

die() { echo "ERROR: $1" >&2; exit 1; }

scale_one() {
  local input="$1"
  local size="$2"
  local output="$3"

  [ -f "$input" ] || die "Input file not found: $input"

  read -r w h <<< "${SIZES[$size]}"

  echo "  $input -> $output  (${size^^}: ${w}×${h} pt)"

  gs -sDEVICE=pdfwrite \
     -dFIXEDMEDIA \
     -dPDFFitPage \
     -dDEVICEWIDTHPOINTS="$w" \
     -dDEVICEHEIGHTPOINTS="$h" \
     -dCompatibilityLevel=1.5 \
     -dNOPAUSE -dBATCH -dQUIET \
     -sOutputFile="$output" \
     "$input" 2>&1

  # Verify output was created
  if [ -f "$output" ]; then
    local pages
    pages=$(pdfinfo "$output" 2>/dev/null | grep "Pages:" | awk '{print $2}')
    echo "    OK — $pages pages"
  else
    die "Ghostscript failed to produce $output"
  fi
}

# ---- Argument parsing ---------------------------------------
[ $# -eq 0 ] && usage

case "$1" in
  -h|--help)
    usage
    ;;
  --list)
    list_sizes
    ;;
  --all)
    [ $# -ge 2 ] || die "--all requires a size argument (e.g. --all b5)"
    size="${2,,}"  # lowercase
    [ -n "${SIZES[$size]+x}" ] || die "Unknown size '$size'. Use --list to see options."

    files=( book-*.pdf )
    [ -e "${files[0]}" ] || die "No book-*.pdf files found in current directory."

    echo "Scaling ${#files[@]} file(s) to ${size^^}:"
    for f in "${files[@]}"; do
      # Skip files that already have a size suffix (e.g. book-ro-b5.pdf)
      base="${f%.pdf}"
      # Check if it already ends with a known size
      skip=false
      for s in "${!SIZES[@]}"; do
        if [[ "$base" == *"-$s" ]]; then
          skip=true
          break
        fi
      done
      if $skip; then
        echo "  $f  (skipped — already a scaled variant)"
        continue
      fi

      output="${base}-${size}.pdf"
      scale_one "$f" "$size" "$output"
    done
    echo ""
    echo "Done."
    ;;
  *)
    # Single file mode: scale-pdf.sh <input> <size> [output]
    [ $# -ge 2 ] || die "Expected: scale-pdf.sh <input.pdf> <size> [output.pdf]"
    input="$1"
    size="${2,,}"  # lowercase
    [ -n "${SIZES[$size]+x}" ] || die "Unknown size '$size'. Use --list to see options."

    if [ $# -ge 3 ]; then
      output="$3"
    else
      base="${input%.pdf}"
      output="${base}-${size}.pdf"
    fi

    echo "Scaling to ${size^^}:"
    scale_one "$input" "$size" "$output"
    echo ""
    echo "Done."
    ;;
esac
