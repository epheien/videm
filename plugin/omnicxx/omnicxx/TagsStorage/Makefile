files := $(wildcard *.py)

THIS_DESTDIR = $(VPYMOD_DIR)/omnicxx/TagsStorage

all:

clean:

install:
	@mkdir -p $(THIS_DESTDIR)
# 排除掉软链接, 一般软链接仅供测试用而已
	@for f in $(files); do		\
	    [ -L "$$f" ] && continue;	\
	    cp "$$f" $(THIS_DESTDIR);	\
	done

.PHONY: all clean install
