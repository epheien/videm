VIDEM_PLUGIN_DIR = $(VIMDIR)/autoload/videm/plugin

all:

clean:

install:
	@-cp -r pyclewn/bin $(VIDEMDIR) 2>/dev/null
	@-cp -r pyclewn/pyclewn $(VIDEMDIR) 2>/dev/null
	@-cp -r pyclewn/vim/* $(VIMDIR) 2>/dev/null
	@mkdir -p $(VIDEM_PLUGIN_DIR)
	@cp pyclewn.vim $(VIDEM_PLUGIN_DIR)
	@mkdir -p $(VIDEMDIR)/doc
	@mv $(VIMDIR)/doc/vpyclewn.txt $(VIDEMDIR)/doc


.PHONY: all clean install
