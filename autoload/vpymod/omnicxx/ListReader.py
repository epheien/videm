#!/usr/bin/env python
# -*- coding: utf-8 -*-

class ListReader(object):
    def __init__(self, tokens, null = None):
        # 原料, 反转顺序是为了性能?
        self.__list = tokens[::-1]
        # 已经被弹出去的 token，用于支持 Prev()
        self.__popeds = []
        # 无效标识
        self.null = null

    @property
    def current(self):
        return self.Cur()

    @property
    def curr(self):
        return self.Cur()

    @property
    def next(self):
        return self.Next()

    @property
    def prev(self):
        return self.Prev()

    def Get(self):
        '''弹出一个token'''
        if not self.__list:
            self.__popeds.append(self.null)
            return self.null
        self.__popeds.append(self.__list[-1])
        return self.__list.pop(-1)

    def Pop(self):
        '''别名'''
        return self.Get()

    def Put(self, tok):
        '''压入一个token'''
        self.__list.append(tok)
        # 这个也要处理, 等于改变了一个
        if self.__popeds:
            self.__popeds.pop(-1)

    def Cur(self):
        '''当前token'''
        if self.__list:
            return self.__list[-1]
        return self.null

    def Next(self):
        if len(self.__list) >= 2:
            return self.__list[-2]
        return self.null

    def Prev(self):
        if len(self.__popeds) >= 1:
            return self.__popeds[-1]
        return self.null

    def Is(self, tok):
        return self.Cur() is tok

    def IsNull(self):
        return self.curr is self.null

def main(argv):
    pass

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret:
        sys.exit(ret)
