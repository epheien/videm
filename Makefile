
dirs := \
	common \
	lib \
	plugin \
	vim \
	wsp \

DESTDIR ?= $(shell readlink -f videm_files)
PYDIR	?= videm/core
VIMDIR	?= videm/vim
export DESTDIR
export PYDIR
export VIMDIR

all:

clean:

install: skel_dir
	@for d in $(dirs); do $(MAKE) $@ -C "$$d"; done

skel_dir:
	@mkdir -p $(DESTDIR)/$(PYDIR)
	@mkdir -p $(DESTDIR)/$(VIMDIR)
	@mkdir -p $(DESTDIR)/$(VIMDIR)/plugin
	@mkdir -p $(DESTDIR)/$(VIMDIR)/autoload
	@mkdir -p $(DESTDIR)/videm/{bin,config,lib}


.PHONY: all clean install skel_dir
