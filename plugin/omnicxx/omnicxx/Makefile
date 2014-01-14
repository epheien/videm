files := $(wildcard *.py)

THIS_DESTDIR = $(VPYMOD_DIR)/omnicxx

all:

clean:

install:
	@mkdir -p $(THIS_DESTDIR)
	@for d in $(files); do cp "$$d" $(THIS_DESTDIR); done
	@cd TagsStorage && $(MAKE) $@

.PHONY: all clean install
