
files := $(wildcard *.py)


all:

clean:

install:
	@for d in $(files); do cp "$$d" $(DESTDIR)/$(PYDIR)/; done


.PHONY: all clean install
