#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os
import os.path

__dir__ = os.path.dirname(os.path.abspath(__file__))

sys.path.append(os.path.dirname(__dir__))
import omnicxx

from omnicxx import GetTagsMgr
from omnicxx import CodeComplete

def _ToList(compl_items):
    li = []
    for item in compl_items:
        li.append(item['word'])
    return li

def test00(tagmgr):
    assert tagmgr.GetTagsByPath('A::B')
    fname = os.path.join(__dir__, 'test00.cpp')
    with open(fname) as f:
        buff = f.read().splitlines()
    retmsg = {}
    #print _ToList(CodeComplete(fname, buff, 61, 8, tagmgr))
    #print retmsg
    #print _ToList(CodeComplete(fname, buff, 61, 6, tagmgr, retmsg=retmsg))
    #print retmsg
    #print _ToList(CodeComplete(fname, buff, 21, 1, tagmgr, retmsg=retmsg))
    #print retmsg

    cases = [
        #([79, 18], []),

        ([4, 24], ['a', 'af()']),
        ([61, 6], []),
        ([61, 24], []),
        #([70, 27],[])
        ([79, 18], []),
        ([83, 25], []),
        ([84, 44], []),
        ([90, 19], []),
        ([91, 21], []),
        ([96, 10], []),
        ([97, 8], []),
        ([99, 5], []),
    ]

    for pos, result in cases:
        row = pos[0]
        col = pos[1]
        print '=' * 40
        print buff[row-1][: col-1].strip()
        retmsg = {}
        li = _ToList(CodeComplete(fname, buff, row, col, tagmgr, retmsg=retmsg))
        print li
        if result:
            try:
                assert li == result
            except:
                print li, '!=', result
                raise
        print 'retmsg:', retmsg

def test01(tagmgr):
    '''test.cpp 的测试用例'''
    #print tagmgr
    assert tagmgr.GetTagsByPath('main')
    assert tagmgr.GetTagsByPath('INT')

def test02(tagmgr):
    pass

def main(argv):
    files = []
    for item in os.listdir(__dir__):
        fname = os.path.join(__dir__, item)
        if not os.path.isfile(fname):
            continue
        if os.path.splitext(fname)[1] in set(['.c', '.cpp', '.h', '.hpp', '.cxx']):
            files.append(fname)

    tagmgr = GetTagsMgr(':memory:')
    #tagmgr = GetTagsMgr('test.db')

    for fname in files:
        if not os.path.basename(fname).startswith('test'):
            continue
        tagmgr.RecreateDatabase()
        tagmgr.ParseFiles([fname])
        name = os.path.splitext(os.path.basename(fname))[0]
        eval('%s(tagmgr)' % name)

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret is None:
        ret = 0
    sys.exit(ret)
