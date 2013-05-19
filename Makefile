
dirs := \
	common \
	lib \
	plugin \
	vim \
	wsp \


DESTDIR		?= $(shell readlink -f videm_files)
VIDEMDIR	?= $(DESTDIR)/dotvidem
PYDIR		?= $(VIDEMDIR)/core
VIMDIR		?= $(DESTDIR)/videm
export DESTDIR
export VIDEMDIR
export PYDIR
export VIMDIR

all:

clean:

install: skel_dir
	@for d in $(dirs); do $(MAKE) $@ -C "$$d"; done
# clean '.svn'
	@find $(DESTDIR) -depth -name '.svn' -exec rm -rf {} \;

skel_dir:
	@mkdir -p $(PYDIR)
	@mkdir -p $(VIMDIR)
	@mkdir -p $(VIMDIR)/plugin
	@mkdir -p $(VIMDIR)/autoload
	@mkdir -p $(VIDEMDIR)/bin
	@mkdir -p $(VIDEMDIR)/config
	@mkdir -p $(VIDEMDIR)/lib


.PHONY: all clean install skel_dir
