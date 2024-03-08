export EMACS ?= $(shell which emacs)

ELFILES = dape-cortex-debug.el
ELCFILES = $(addsuffix .elc, $(basename $(ELFILES)))

all: $(ELCFILES)

dape.el:
	@curl "https://raw.githubusercontent.com/svaante/dape/master/dape.el" > dape.el

%.elc: %.el dape.el
	@echo Compiling $<
	@${EMACS} -Q \
	          -batch \
                  -no-site-file \
                  -L . \
                  --eval="(package-install-file \"dape.el\")" \
                  -f batch-byte-compile $<
clean:
	@rm -f *.elc
