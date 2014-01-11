
pyfiles := \
    VIMClangCC.py \


vimfiles := \
    core.vim \


PY_TARGET_DIR = $(VIDEM_PYDIR)
VIM_TARGET_DIR = $(DESTDIR)/autoload/vimccc
VIDEM_PLUGIN_DIR = $(DESTDIR)/autoload/videm/plugin

all:

clean:

install:
	@mkdir -p $(PY_TARGET_DIR)
	@for d in $(pyfiles); do cp "$$d" $(PY_TARGET_DIR); done
	@mkdir -p $(VIM_TARGET_DIR)
	@for d in $(vimfiles); do cp "$$d" $(VIM_TARGET_DIR); done
	@mkdir -p $(DESTDIR)/plugin
	@cp vimccc_plugin.vim $(DESTDIR)/plugin
	@mkdir -p $(VIDEM_PLUGIN_DIR)
	@cp vimccc.vim $(VIDEM_PLUGIN_DIR)
	@cp -r clang $(PY_TARGET_DIR) 2>/dev/null


.PHONY: all clean install
