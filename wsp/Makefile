
files := $(wildcard *.py)


all:

clean:

install:
	@for d in $(files); do cp "$$d" $(DESTDIR)/$(PYDIR)/; done
	@cp videm.vim $(DESTDIR)/$(VIMDIR)/plugin
	@mkdir -p $(DESTDIR)/$(VIMDIR)/autoload/videm
	@cp wsp.vim wsp.py $(DESTDIR)/$(VIMDIR)/autoload/videm


.PHONY: all clean install
