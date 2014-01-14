VIM_DESTDIR = $(DESTDIR)/autoload/omnicxx
VIDEM_PLUGIN_DIR = $(DESTDIR)/autoload/videm/plugin

all:

clean:

install:
	@mkdir -p $(VIM_DESTDIR)
	@-cp -r omnicxx/ $(VPYMOD_DIR)
	@cp omnicxx.vim $(VIDEM_PLUGIN_DIR)
	@cp complete.vim $(VIM_DESTDIR)

.PHONY: all clean install
