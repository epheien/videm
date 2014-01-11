
dirs := \
	autoload \


all:

clean:

install:
	@# 忽略错误是因为 cp -r 会把 .svn 的内容也复制, 并且会复制失败
	@-cp -r $(dirs) $(DESTDIR)/ 2>/dev/null

.PHONY: all clean install
