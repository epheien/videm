
dirs := \
	common \
	lib \
	plugin \
	vim \
	wsp \

DESTDIR ?= $(shell readlink -f videm_files)
PYDIR	?= videm/python
VIMDIR	?= videm/vim
export DESTDIR
export PYDIR
export VIMDIR

all:

clean:

install:
	@mkdir -p $(DESTDIR)/$(PYDIR)
	@mkdir -p $(DESTDIR)/$(VIMDIR)
	@for d in $(dirs); do $(MAKE) $@ -C "$$d"; done


.PHONY: all clean install
