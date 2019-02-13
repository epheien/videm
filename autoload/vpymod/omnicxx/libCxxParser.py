#!/usr/bin/env python
# -*- coding:utf-8 -*-

from ctypes import *
import os.path

def GetCharPStr(charp):
    i = 0
    l = []
    while charp[i] != '\0':
        l.append(charp[i])
        i += 1
    return ''.join(l)

def GetLibCxxParser():
    '''通过 sys.argv[1] 传递库路径'''
    import platform
    OSName = platform.system()
    try:
        import vim
        import sys
        # TODO 需要优雅的方式
        library = vim.eval("videm#settings#Get('.videm.cc.omnicxx.LibCxxParserPath')")
        return CDLL(library)
    except:
        return CDLL(os.path.expanduser("~/libCxxParser.so"))

libCxxParser = GetLibCxxParser()

CxxHWParser_Create = libCxxParser.CxxHWParser_Create
CxxHWParser_Create.restype = c_void_p
CxxHWParser_Create.argtypes = [c_char_p]

CxxHWParser_Destroy = libCxxParser.CxxHWParser_Destroy
CxxHWParser_Destroy.argtypes = [c_void_p]

CxxOmniCpp_Create = libCxxParser.CxxOmniCpp_Create
CxxOmniCpp_Create.restype = c_void_p
CxxOmniCpp_Create.argtypes = [c_void_p, c_char_p]

CxxOmniCpp_Destroy = libCxxParser.CxxOmniCpp_Destroy
CxxOmniCpp_Destroy.argtypes = [c_void_p]

CxxOmniCpp_GetSearchScopes = libCxxParser.CxxOmniCpp_GetSearchScopes
CxxOmniCpp_GetSearchScopes.restype = c_char_p
CxxOmniCpp_GetSearchScopes.argtypes = [c_void_p]

_GetScopeStack = libCxxParser.GetScopeStack
_GetScopeStack.restype = POINTER(c_char)
_GetScopeStack.argtypes = [c_char_p]

CxxParser_GetVersion = libCxxParser.CxxParser_GetVersion
CxxParser_GetVersion.restype = c_int
CxxParser_GetVersion.argtypes = []

#pParser = CxxHWParser_Create("test");
#print pParser

#pResult = CxxOmniCpp_Create(pParser, "hello");
#print pResult

#print CxxOmniCpp_GetSearchScopes(pResult)

#CxxOmniCpp_Destroy(pResult);
#pResult = None
#CxxHWParser_Destroy(pParser)
#pParser = None

def GetScopeStack(buff):
    '''buff必须是字符串'''
    assert isinstance(buff, str)
    return GetCharPStr(_GetScopeStack(buff))

if __name__ == "__main__":
    import sys
    import json
    print 'CxxParser version: %d' % CxxParser_GetVersion()
    if not sys.argv[1:]:
        print "usage: %s {file} [line]" % sys.argv[0]
        sys.exit(1)

    line = 1000000
    if sys.argv[1:]:
        fn = sys.argv[1]
        if sys.argv[2:]:
            line = int(sys.argv[2])

    f = open(fn)
    allLines = f.readlines()
    f.close()
    lines = ''.join(allLines[: line])
    #print lines
    print json.dumps(json.loads(GetScopeStack(lines)), sort_keys=True, indent=4)
