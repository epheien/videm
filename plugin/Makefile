dirs := \
	cscope \
	gtags \
	omnicpp \
	pyclewn \
	vimccc \

all:

clean:

install:
	@for d in $(dirs); do $(MAKE) $@ -C "$$d"; done

.PHONY: all clean install
