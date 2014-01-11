
files := $(wildcard *.vim)

TARGET_DIR = $(DESTDIR)/autoload/videm/plugin

all:

clean:

install:
	@mkdir -p $(TARGET_DIR)
	@for d in $(files); do cp "$$d" $(TARGET_DIR); done


.PHONY: all clean install
