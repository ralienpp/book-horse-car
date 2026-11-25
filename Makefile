LANGS        := ro en ru de es ta bn hi fa tr zh sq it sv
PDFS         := $(foreach lang,$(LANGS),book-$(lang).pdf)

# LuaLaTeX flags — never hang on interactive prompts
LATEXFLAGS   := -interaction=nonstopmode -halt-on-error

# Glossary: build without the glossary section when a language pair has no
# glossary data.  Usage:  make dual GLOSSARY=off
GLOSSARY     ?= on
ifeq ($(GLOSSARY),off)
  GLOSSARYFLAG := \def\bookglossaryoff{}
else
  GLOSSARYFLAG :=
endif

.PHONY: all $(LANGS) dual debug verify check-translations scale booklet clean

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
.SECONDEXPANSION:
book-dual-%.pdf: main-dual.tex picturebook.sty \
		translations/$$(word 1,$$(subst -, ,$$*)).lua \
		translations/$$(word 2,$$(subst -, ,$$*)).lua
	$(eval DUAL_P := $(word 1,$(subst -, ,$*)))
	$(eval DUAL_S := $(word 2,$(subst -, ,$*)))
	lualatex $(LATEXFLAGS) -jobname="book-dual-$*" "\def\booklang{$(DUAL_P)}\def\booklangsecondary{$(DUAL_S)}$(GLOSSARYFLAG)\input{main-dual}"

# Per-language PDF (single pass — all page placement is shipout-anchored)
book-%.pdf: main.tex picturebook.sty translations/%.lua
	lualatex $(LATEXFLAGS) -jobname="book-$*" "\def\booklang{$*}\input{main}"

# Debug build (Romanian only, with grid overlay)
debug:
	lualatex $(LATEXFLAGS) -jobname="book-ro-debug" "\PassOptionsToPackage{debug}{picturebook}\def\booklang{ro}\input{main}"

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
