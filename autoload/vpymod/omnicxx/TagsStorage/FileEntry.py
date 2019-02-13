#!/usr/bin/env python
# -*- encoding:utf-8 -*-

class FileEntry:
    def __init__(self):
        self.id = -1
        self.file = ''
        # 最近 parse 的时间, 单位是秒
        self.tagtime = 0

