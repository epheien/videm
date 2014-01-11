
dirs := \
	common \
	lib \
	plugin \
	vim \
	wsp \

# 打包基础目录
DESTDIR		?= $(shell readlink -f "videm")
# _videm
VIDEM_DIR	?= $(DESTDIR)/_videm
# _videm/core
VIDEM_PYDIR	?= $(VIDEM_DIR)/core
# autoload/vpymod, 公共的 py 库
VPYMOD_DIR	?= $(DESTDIR)/autoload/vpymod
export DESTDIR
export VIDEM_DIR
export VIDEM_PYDIR
export VPYMOD_DIR

all:
	@echo "Please run pkg.sh to make a package"

clean:

install: skel_dir
	@for d in $(dirs); do $(MAKE) $@ -C "$$d"; done
# clean '.svn'
	@find $(DESTDIR) -depth -name '.svn' -exec rm -rf {} \;
# clean '.*.swp'
	@find $(DESTDIR) -name '.*.swp' -exec rm -f {} \;
# help doc
	@cp videm.txt $(DESTDIR)/doc

skel_dir:
	@mkdir -p $(DESTDIR)
	@mkdir -p $(DESTDIR)/plugin
	@mkdir -p $(DESTDIR)/autoload
	@mkdir -p $(DESTDIR)/doc
	@mkdir -p $(VIDEM_DIR)
	@mkdir -p $(VIDEM_DIR)/bin
	@mkdir -p $(VIDEM_DIR)/config
	@mkdir -p $(VIDEM_DIR)/lib
	@mkdir -p $(VIDEM_PYDIR)
	@mkdir -p $(VPYMOD_DIR)

.PHONY: all clean install skel_dir
