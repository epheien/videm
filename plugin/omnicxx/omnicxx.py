#!/usr/bin/env python
# -*- coding: utf-8 -*-

from VimTagsManager import VimTagsManager

def GetTagsMgr(dbfile):
    tagmgr = VimTagsManager()
    # 不一定打开成功
    if not tagmgr.OpenDatabase(dbfile):
        return None
    return tagmgr

def Error(msg):
    print msg

def main(argv):
    '''
    arg1: dbfile
    arg2: file
    arg3: row
    arg4: col
    arg5: base
    '''
    if len(argv) < 6:
        usage(argv[0])
        return 1

    icase = True
    opt = None

    dbfile = argv[1]
    file = argv[2]
    row = int(argv[3])
    col = int(argv[4])
    base = argv[5]
    with open(file) as f:
        buff = f.read()

    print CodeComplete(file, buff, row, col, base, icase, dbfile, opt)

def CodeComplete(file, buff, row, col, base, icase, dbfile, opt):
    '''返回补全结果, 返回结果应该为字典, 参考vim的complete-items的帮助信息'''
    result = []
    tagmgr = GetTagsMgr(dbfile)
    if not tagmgr:
        # NOTE 打开数据库失败, 要返回一些错误信息给调用者
        Error('Failed to open tags database, abort')
        return []

    # TODO 材料准备完毕, 开始分析补全!

    return result

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret is None:
        ret = 0
    sys.exit(ret)
