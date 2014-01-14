VIM_DESTDIR = $(DESTDIR)/autoload/omnicxx
VIDEM_PLUGIN_DIR = $(DESTDIR)/autoload/videm/plugin

all:

clean:

install:
	@mkdir -p $(VIM_DESTDIR)
	@cp omnicxx.vim $(VIDEM_PLUGIN_DIR)
	@cp complete.vim $(VIM_DESTDIR)
	@cd omnicxx && $(MAKE) $@

.PHONY: all clean install
