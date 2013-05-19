#!/usr/bin/env python
# -*- coding:utf-8 -*-

from clang import cindex
import sys, os.path


def main():
    if len(sys.argv) < 4:
        print "Usage: %s filename line column" % sys.argv[0]
        return

    sFileName = sys.argv[1]
    nLine = int(sys.argv[2])
    nColumn = int(sys.argv[3])
    lArgs = sys.argv[4:]

    with open(sFileName, 'rb') as f:
        contents = f.read()

    #unsavedFile = (sFileName, '#include <string>\n#include <vector>\n' + contents)
    #print unsavedFile[1]
    unsavedFiles = []

    if os.path.splitext(sFileName)[1] == '.h':
        print 'enter'
        #sFileName += 'pp'
        unsavedFiles = [(sFileName, contents)]

    flags = 0
    flags |= cindex.TranslationUnit.DetailedPreprocessingRecord
    flags |= cindex.TranslationUnit.NestedMacroExpansions
    index = cindex.Index.create()
    tu = index.parse(sFileName, lArgs, unsavedFiles, flags)
    #ccrs = tu.codeComplete(sFileName, nLine, nColumn)

    # FIXME: sFileName 文件不存在的时候，会抛出 AssertionError
    cursor = tu.getCursor(
        tu.getLocation(tu.getFile(sFileName), nLine, nColumn))

    for idx in range(len(tu.diagnostics)):
        print tu.diagnostics[idx]
    print '=' * 40

    print cursor.displayname, '->', cursor.spelling
    #print cursor.type.kind # FIXME: 这里可能会导致段错误，
                            # 原因是 clang_getCursorType() 的参数的内容为空时
                            # （不是空参数，而是空内容），直接段错误
    print cursor.kind

    # 寻找声明
    declCursor = cursor.get_referenced()
    if declCursor:

        li = []
        li.insert(0, declCursor.spelling)
        parent = declCursor.get_semantic_parent()
        while parent:
            print parent.kind
            li.insert(0, parent.spelling)
            #print '::' + parent.spelling
            parent = parent.get_semantic_parent()
        print 'Path: %s' % '::'.join(li)

        #print "Declaration location:",
        print declCursor.displayname, '->', declCursor.spelling, ':',
        print declCursor.location
    else:
        print "Declaration not found"

    # 寻找定义
    defiCursor = cursor.get_definition()
    if defiCursor:
        #print "Definition location:",
        print defiCursor.displayname, '->', defiCursor.spelling, ':',
        print defiCursor.location
    else:
        print "Definition not found"

if __name__ == '__main__':
    main()
