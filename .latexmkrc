# latexmk configuration for the picture-book build.
#
# The Makefile delegates every build to latexmk, which decides whether a
# rebuild is needed by tracking ALL inputs — sources, style, translations,
# AND images (via -recorder/.fls and content digests). A plain Make rule
# cannot see image changes; latexmk can, so don't duplicate the decision.
#
# Manual use (defaults: Romanian, jobname from the tex file):
#   latexmk main.tex
#   latexmk -gg main.tex        # force full rebuild

$pdf_mode = 4;                       # 4 = lualatex (5 would be xelatex!)
$recorder = 1;                       # .fls file list -> images are tracked
$lualatex = 'lualatex -interaction=nonstopmode -halt-on-error %O %S';

# Language selection is injected per job by the Makefile with -e, e.g.:
#   latexmk -jobname=book-de -e '$lualatex = q/lualatex ... "\def\booklang{de}\input{main}"/' main.tex
