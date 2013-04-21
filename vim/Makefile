
dirs := \
	autoload \


all:

clean:

install:
	@cp -r $(dirs) $(DESTDIR)/$(VIMDIR)/
# clean '.svn'
	@find $(DESTDIR) -depth -name '.svn' -exec rm -rf {} \;


.PHONY: all clean install
