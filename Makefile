LANGS        := ro en ru de es ta bn hi fa tr zh sq it sv
PDFS         := $(foreach lang,$(LANGS),book-$(lang).pdf)

# Extra latexmk flags, e.g.:  make ro LATEXMKFLAGS=-gg   (force rebuild)
LATEXMKFLAGS ?=

# Glossary: build without the glossary section when a language pair has no
# glossary data.  Usage:  make dual GLOSSARY=off
GLOSSARY     ?= on
ifeq ($(GLOSSARY),off)
  GLOSSARYFLAG := \def\bookglossaryoff{}
else
  GLOSSARYFLAG :=
endif

# Rebuilding is decided by latexmk, not make (it tracks images too, which
# make prerequisites cannot see), so the PDF targets must always run their
# recipe. They hang off FORCE for that: .PHONY does NOT work here because
# GNU make >= 4.4 ignores pattern-rule recipes for phony targets.
.PHONY: all $(LANGS) dual debug verify check-translations scale booklet clean FORCE
FORCE:

# Build all languages
all: $(PDFS)

# Quick builds: one target per language (derived from LANGS)
$(foreach lang,$(LANGS),$(eval $(lang): book-$(lang).pdf))

# Dual-language edition (stacked: primary on top, secondary below).
# Defaults to Romanian primary / English secondary; override on the
# command line, e.g.:  make dual DUAL_PRIMARY=en DUAL_SECONDARY=ro
# Output is book-dual-<primary>-<secondary>.pdf, so each language pair is
# cached independently and switching the parameters always rebuilds the
# correct file.
DUAL_PRIMARY   ?= ro
DUAL_SECONDARY ?= en
dual: book-dual-$(DUAL_PRIMARY)-$(DUAL_SECONDARY).pdf

# All builds delegate to latexmk (see .latexmkrc): it tracks every input —
# sources, style, translations AND images — so the rules always run and
# latexmk itself no-ops when nothing relevant changed.

book-dual-%.pdf: FORCE
	$(eval DUAL_P := $(word 1,$(subst -, ,$*)))
	$(eval DUAL_S := $(word 2,$(subst -, ,$*)))
	latexmk $(LATEXMKFLAGS) -jobname="book-dual-$*" -e '$$lualatex = q/lualatex -interaction=nonstopmode -halt-on-error %O "\def\booklang{$(DUAL_P)}\def\booklangsecondary{$(DUAL_S)}$(GLOSSARYFLAG)\input{main-dual}"/' main-dual.tex

# Per-language PDF.
book-%.pdf: FORCE
	latexmk $(LATEXMKFLAGS) -jobname="book-$*" -e '$$lualatex = q/lualatex -interaction=nonstopmode -halt-on-error %O "\def\booklang{$*}\input{main}"/' main.tex

# Debug build (Romanian only, with grid overlay)
debug:
	latexmk $(LATEXMKFLAGS) -jobname="book-ro-debug" -e '$$lualatex = q/lualatex -interaction=nonstopmode -halt-on-error %O "\PassOptionsToPackage{debug}{picturebook}\def\booklang{ro}\input{main}"/' main.tex

# Run automated verification
verify: book-ro.pdf book-ru.pdf
	bash scripts/verify.sh

# Check translation key completeness
check-translations:
	texlua scripts/check-translations.lua translations/

# Scale all book PDFs to a target paper size.
# Usage: make scale SIZE=b5
#        make scale SIZE=a4
SIZE ?= b5
scale: $(PDFS)
	bash scripts/scale-pdf.sh --all $(SIZE)

# Create booklets for all languages, ready for duplex printing.
# Usage: make booklet SHEET=a4        (A5 content → A4 booklet)
#        make booklet SHEET=a4 SIZE=a6 (A6 content → A4 booklet)
SHEET ?= a4
booklet: $(PDFS)
ifdef SIZE
	@echo "=== Scaling to $(SIZE), then creating $(SHEET) booklets ==="
	@for pdf in $(PDFS); do \
		base=$${pdf%.pdf}; \
		bash scripts/scale-pdf.sh "$$pdf" $(SIZE) "$${base}-$(SIZE).pdf"; \
		bash scripts/make-booklet.sh "$${base}-$(SIZE).pdf" $(SHEET) "$${base}-$(SIZE)-booklet.pdf"; \
	done
else
	@echo "=== Creating $(SHEET) booklets ==="
	@for pdf in $(PDFS); do \
		base=$${pdf%.pdf}; \
		bash scripts/make-booklet.sh "$$pdf" $(SHEET) "$${base}-booklet.pdf"; \
	done
endif

clean:
	rm -f *.aux *.log *.fls *.fdb_latexmk *.xdv *.synctex.gz *.out *.pdf
