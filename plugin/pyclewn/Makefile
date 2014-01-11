VIDEM_PLUGIN_DIR = $(DESTDIR)/autoload/videm/plugin

all:

clean:

install:
	@-cp -r pyclewn/bin $(VIDEM_DIR) 2>/dev/null
	@-cp -r pyclewn/pyclewn $(VIDEM_DIR) 2>/dev/null
	@-cp -r pyclewn/vim/* $(DESTDIR) 2>/dev/null
	@mkdir -p $(VIDEM_PLUGIN_DIR)
	@cp pyclewn.vim $(VIDEM_PLUGIN_DIR)
	@mkdir -p $(VIDEM_DIR)/doc
	@mv $(DESTDIR)/doc/vpyclewn.txt $(VIDEM_DIR)/doc


.PHONY: all clean install
