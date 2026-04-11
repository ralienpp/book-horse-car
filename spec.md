# Objective
Create a LaTeX template for writing illustrated children's picture books, with the possibility to easily translate the text to other languages.

The primary language of the text is Romanian.

The author is also the translator, they are familiar with Linux, LaTeX, Python, bash; and are willing to learn other technologies, if you recommend something as an excellent fit for this project.


# Requirements
R1. Book pages can have illustrations that take the entire space, leaving no margin or bleed.
R2. The default page size is A5, but the template must be easily adjustable to other sizes, e.g., B5, A5, A6.
R3. The book will be written in Romanian, Russian, English and German; and subsequently other languages might be added.
R4. The book must accommodate full spreads, i.e., an image spanning two pages side-by-side. The image will be cropped automatically, its left side will be on the left page, and the right side on the right page. Assume that the proportions of the image match those of the paper.
R4.1 Spreads must enforce correct parity;
R5. The book must accommodate single pages, i.e., an image that only takes one full page.
R6. The book will be printed as a booklet on a typical home printer that supports duplex printing. Booklet imposition will be handled by an external tool.
R7. There will also be full-prose pages that benefit from regular LaTeX features like line-breaks, paragraph breaks, etc. These pages will have regular margin sizes. An example of use - the book will have a section for parents, that provides background details about what the book is about, with footnotes, tables, etc.


## R8. Grid placement of text
There must be a possibility to specify exactly where on the page (that is fully covered by an image) the prose will be placed.

These coordinates will be specified in centimeters. When the varied formats are produced (e.g., A4, A6...), then these values will be shrunk proportionally from the A5 original.

The coordinate system originates in the top left corner.

There should be default values that place the text to the top of the page, leaving some side margins.

## R9. Debug mode to visualize grid
There must be a debug flag; when enabled, the resulting PDF will display a semi-transparent grid, to facilitate text placement.

The grid will have a step of 1 cm.

After every 5 steps, add a mini-overlay text that shows what the coordinates in that position are.

The debug visualization will also show information at the top of the page:
- Full spread left
- Full spread right
- Single page
- Single page padding
- ... others, that you think make sense


In addition, the debug mode will show red dotted lines at the border - which indicate the "safe space", i.e., the part that is guaranteed to be printed on most printers. The author will use these markers to ensure that all important elements of each page are within the safe area.

## R10. Optional halo behind text
In some cases the background picture might interfere with the readability of the text. In such cases, the text can be optionally overlaid on top of a semi-transparent "halo" box, to improve contrast.

The halo environment takes the following parameters:
- color; default=white
- opacity; default=0.6


## R11. Macros for simplifying the design and editing process
To make it easier to produce the book, several macros (or maybe environments?) are needed, at a minimum:

- `\singlepage`
	- takes the path to the image as a parameter
	- the x,y coordinates of where the text should go
	- the width of the text box
	- the text
- `\fullspread`
	- takes the path to the image as a parameter
	- the x,y coordinates of where the text should go
	- the width of the text box
	- the text for the left side (can be empty)
	- the text for the right side (can be empty)
- `\startprose` - to signal that I want to switch from "full image background with text" to regular LaTeX document flow.


## R12. There should be a possibility to specify a custom font
This can be a TTF or an equivalent format used in Linux.

## R13. There should be optional page numbers
The number will be at the bottom of the page. Optionally, it can be turned off (e.g., if we have a full spread image that needs to remain clean and have no overlays).

Optionally, one can say where to put the page number: bottom edge (left on left side, right on right side), or bottom center.

## R14. Images are loaded from the images/ directory
Assume images follow the aspect ratio of a full spread or that of a single page. 

## R15. Spreads must enforce correct parity
When necessary, add a filler page that has an orange background and a warning text that says "this page must be blank". This will serve as a visual signal that a revision is needed.

The author can then intentionally add a `\fillerpage` instruction, or add a `\singlepage` with custom content like "This page is intentionally left blank" or some decorative image.



## Additional details
- Booklet imposition, defined in R6, will be implemented via a separate script, which takes the regular PDF at the input and produces the booklet at the output.


# Technical decisions

## Engine: LuaLaTeX
The project uses LuaLaTeX exclusively. This provides:
- Native UTF-8 support (critical for Romanian diacritics and Cyrillic script)
- `fontspec` for TTF/OTF custom fonts
- Embedded Lua runtime for translation loading and computation

## Translation system: Lua tables
Translations are stored as Lua tables in `translations/<lang>.lua`. LuaLaTeX loads the appropriate file at compile time. A `\tr{key}` macro retrieves strings, with a visible fallback ("MISSING: key") for undefined keys.

Benefits over `\newcommand`-based `.tex` files:
- Multi-line text works naturally via Lua `[[ ]]` long strings (no `%` hacks)
- Structural validation is trivial (a script can diff key sets across all language files)
- Adding a language = copying a file and translating values
- Comments are supported; no LaTeX escaping issues

## Paper size scaling via pdfpages
The canonical authoring size is A5. Other sizes (A6, B5, etc.) are produced by scaling the finished A5 PDF via the `pdfpages` package, rather than re-rendering at different geometry. This guarantees that font sizes, coordinates, and line breaks scale proportionally with zero rework.

## Package architecture
All macros, environments, and configuration live in `picturebook.sty`. The main document (`main.tex`) contains only book content. This separates the template engine from authoring.

## Switching between illustration and prose modes
`\startprose` switches to standard LaTeX margins for prose sections. There is no `\endprose`; calling `\singlepage` or `\fullspread` implicitly resets to full-bleed mode.

## Coordinate system (R8)
Origin is top-left corner of the page. X increases rightward, Y increases downward. Units are centimeters. These coordinates are authored for A5 and scale proportionally when other sizes are produced via pdfpages.


# File structure

```
book-horse-car/
  picturebook.sty           -- Reusable LaTeX package (all macros, envs, config)
  main.tex                  -- Book content (uses picturebook.sty)
  translations/
    ro.lua                  -- Romanian (primary language)
    en.lua                  -- English
    ru.lua                  -- Russian
    de.lua                  -- German
  images/                   -- All illustrations
  fonts/                    -- Optional custom fonts (TTF/OTF)
  Makefile                  -- Build targets: all, ro, ru, debug, verify, clean
  scripts/
    verify.sh               -- Post-build automated verification
    check-translations.lua  -- Pre-build translation key validation
  spec.md
  story.txt
  old/                      -- Previous prototype (kept for reference)
```


# Implementation workflow

## Agentic AI loop
This will be implemented through the use of agentic AI, in an iterative form. The agent works in a build-verify-fix loop and iterates autonomously, only requesting human input for visual/aesthetic judgments or genuine spec ambiguities.

### The loop

1. **EDIT** - modify `.sty`, `.tex`, `.lua`, or build files
2. **BUILD** - `make ro ru` (always both Romanian and Russian to catch Latin/Cyrillic issues early)
3. **CHECK** - if compilation failed, parse the `.log` file, fix the error, go to step 2
4. **VERIFY** - `make verify` runs automated checks (see below)
5. **If checks fail** - fix and go to step 2
6. **If checks pass** - proceed to the next feature or report completion

### Build flags
LuaLaTeX is invoked with `-interaction=nonstopmode -halt-on-error` to prevent hanging on interactive prompts (critical for agentic use).

### Automated verification (`scripts/verify.sh`)
The verification script produces a machine-readable exit code (0 = pass) and a human-readable summary. It checks:

- **Page size**: `pdfinfo` confirms MediaBox matches A5 (148x210mm)
- **Page count**: matches expected number of pages
- **Full-bleed correctness**: render pages to PNG via `pdftoppm`, check edge pixels for unexpected white borders
- **Spread parity**: parse debug labels or page structure to confirm left=even, right=odd
- **No overfull hboxes**: grep the `.log` for "Overfull \\hbox"
- **No missing images**: grep the `.log` for "File not found"
- **No missing translation keys**: extract PDF text via `pdftotext`, grep for "MISSING:"
- **Cyrillic integrity**: for `ru` builds, verify that Cyrillic text is present in the PDF text layer (catches font fallback / encoding failures)

### Translation validation (`scripts/check-translations.lua`)
A standalone Lua script that loads all `translations/*.lua` files, computes the union of all keys, and reports any file missing a key. Runs as a pre-build step.

### Primary check pair: Romanian + Russian
Romanian is the primary language with the most content. Russian is the secondary check because Cyrillic script exercises different font coverage, encoding, and hyphenation paths. If both `ro` and `ru` build and verify cleanly, the Latin-script languages (`en`, `de`) are very likely correct. All four languages are built as a final validation step.

### When human input is required
- **Visual aesthetics**: "Does this spread look right?" - agent renders PNGs and asks
- **Content/translation accuracy**: structural completeness is checked automatically, but linguistic correctness is the author's domain
- **Spec ambiguities**: agent asks rather than guessing

### Incremental development
Features are implemented one at a time, each with its own build-verify cycle:
1. Minimal compiling document (geometry + one `\singlepage`)
2. Full spread support
3. Debug grid overlay
4. Halo environment
5. Prose mode
6. Translation system
7. Page numbers
8. Parity enforcement + filler pages
9. Full book content
10. All-language build + final verification