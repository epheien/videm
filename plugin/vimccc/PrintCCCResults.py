#!/usr/bin/env python
# -*- coding:utf-8 -*-

from clang import cindex
import sys, os.path

def GetQuickFixItem(diagnostic):
  # Some diagnostics have no file, e.g. "too many errors emitted, stopping now"
    if diagnostic.location.file:
        sFileName = diagnostic.location.file.name
    else:
        sFileName = ""

    if diagnostic.severity == diagnostic.Ignored:
        sType = 'I'
    elif diagnostic.severity == diagnostic.Note:
        sType = 'I'
    elif diagnostic.severity == diagnostic.Warning:
        sType = 'W'
    elif diagnostic.severity == diagnostic.Error:
        sType = 'E'
    elif diagnostic.severity == diagnostic.Fatal:
        sType = 'E'
    else:
        return None

    #return dict{'bufnr': int(vim.eval("bufnr('" + sFileName + "', 1)")),
    return {'filename': os.path.normpath(sFileName),
            'lnum': diagnostic.location.line,
            'col': diagnostic.location.column,
            'text': diagnostic.spelling,
            'type': sType}

def main():
    if len(sys.argv) < 4:
        print "Usage: %s filename line column" % sys.argv[0]
        return

    sFileName = sys.argv[1]
    nLine = int(sys.argv[2])
    nColumn = int(sys.argv[3])

    index = cindex.Index.create()
    tu = index.parse(sFileName)
    ccrs = tu.codeComplete(sFileName, nLine, nColumn)
    for ccr in ccrs.results:
        print '%s: %s' % (ccr.kind, ccr)

    for idx in range(len(ccrs.diagnostics)):
        print ccrs.diagnostics[idx]

    print filter(None, map(GetQuickFixItem, tu.diagnostics))

if __name__ == '__main__':
    main()
