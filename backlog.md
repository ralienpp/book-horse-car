# Backlog

Deferred ideas from the repo review (Nov 2026). Not urgent, worth remembering.

- **"This book belongs to" page** — classic children's-book page; a few lines
  with `\singlepage` + a translation key.
- **Colophon / imprint page** — edition, year, ISBN + barcode space, license
  text, printer. Needed once an ISBN is registered.
- **Explicit trim/bleed option** (e.g. `bleed=3mm` in picturebook.sty: paper =
  A5 + 2x bleed, full-bleed images grow automatically, safe area = trim box).
  Current workflow designs pages with the implicit assumption that edges get
  cut (debug red safe-area line). Only needed when a print shop physically
  trims full-bleed pages; home printing never trims.
- **`dyslexic` package option** (letter spacing + leading + optional font).
  Deferred: no convincing peer-reviewed evidence for dyslexic fonts as such;
  letter spacing and leading are the parts with support.
- **QR codes** stay as committed PDFs: they are hand-customized (logo overlaid
  on the QR dots). The `qrcode` package cannot reproduce these.
- **PDF/A-3**: deliberately skipped — embedding the source contradicts the
  plan to keep sources private / sell an enhanced PDF; PDF/A-3 does not
  require source embedding anyway.
- **Hyphenation and leading**: deliberately left as-is (author decision).
