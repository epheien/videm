#!/usr/bin/env python
# -*- coding:utf-8 -*-

import sys
import re
import json

import CppTokenizer

# 必须在这个作用域 import libCxxParser，否则 sys.argv 无法用于传参数给 libCxxParser
# 外部可能不需要使用 libCxxParser，这时候，libCxxParser 很可能会在 import 的时候出错
# 外部如果不需要使用 libCxxParser 的时候，不应该调用 CxxGetScopeStack，否则会出错
try:
    import libCxxParser
except:
    print 'Failed to import libCxxParser, libCxxParser not found?'
    #raise

def EscStr(string, chars):
    '''用 '\\' 转义指定字符'''
    result = ''
    for char in string:
        if char in chars:
            # 转义之
            result += '\\' + char
        else:
            result += char
    return result

# Scope 数据结构
# {
# 'kind':       <'file'|'container'|'function'|'other'>, 
# 'name':       <scope name>, 
# 'nsinfo':     <NSInfo>, 
# 'includes':   [<header1>, <header2>, ...]
# }
#
# NSInfo 字典
# {
# 'nsalias': {}     <- namespace alias
# 'using': {}       <- using 语句，{"string": "std::strng"}
# 'usingns': []     <- using namespace
# }
# ScopeStack 数据结构
# [<scope1>, <scope2>, ...]
class CppScope(object):
    '''Cpp 中一个作用域的数据结构'''
    def __init__(self):
        self.kind = ''
        self.name = ''
        self.nsinfo = NSInfo()
        self.includes = [] # 这个暂不支持
        self.vars = {} # 变量字典
                       # {'name': {"line": 10, "type": {"types": [<types>]]}}, ...}
        self.stmt = '' # 'file' 类型为空
        self.cusrstmt = '' # 光标前的未完成的语句

    def IsFile(self):
        return self.kind == 'file'

    def IsCtnr(self):
        '''是否容器'''
        return self.kind == 'container'

    def IsFunc(self):
        '''是否函数'''
        return self.kind == 'function'

    def ToEvalStr(self):
        nsinfoEvalStr = '{}'
        s = '{"stmt": "%s", "kind": "%s", "name": "%s", '\
                '"nsinfo": %s, "vars": %s, "cusrstmt": "%s", "includes": []}' \
                % (EscStr(self.stmt, '"\\'),
                   self.kind, self.name, self.nsinfo.ToEvalStr(),
                   json.dumps(self.vars), EscStr(self.cusrstmt, '"\\'))
        return s

    def __repr__(self):
        return self.ToEvalStr()

    def Print(self):
        print self.ToEvalStr()

class NSInfo(object):
    '''名空间信息'''
    def __init__(self):
        '''using 的时候，不需要考虑 usingns 了，是绝对路径'''
        self.usingns = []   # using namespace std;
        self.using = {}     # using std::string;
        self.nsalias = {}   # namespace s = std;

    def AddUsingNamespace(self, nsName):
        self.usingns.append(nsName)

    def AddUsing(self, usingStr):
        if usingStr:
            self.using[usingStr.split('::')[-1]] = usingStr

    def AddNamespaceAlias(self, s1, s2):
        if s1: # vim 不允许空字符串为键值
            self.nsalias[s1] = s2

    def ToEvalStr(self):
        s = '{"usingns": %s, "using": %s, "nsalias": %s}' \
                % (json.dumps(self.usingns),
                   json.dumps(self.using),
                   json.dumps(self.nsalias))
        return s

    def __repr__(self):
        return self.ToEvalStr()

def CxxGetScopeStack(lines):
    '''使用 libCxxParser.so 的版本, 这里作简单的转换'''
    if isinstance(lines, list):
        li = eval(libCxxParser.GetScopeStack('\n'.join(lines)))
    else:
        li = eval(libCxxParser.GetScopeStack(lines))
    #print li
    scopeStack = []
    for idx, rawScope in enumerate(li):
        #print rawScope["stmt"]
        if idx == 0:
            # 第一个 scope 直接用即可
            cxxnsinfo = rawScope["nsinfo"]
            tmpScope = CppScope()
            tmpScope.kind = "file"
            tmpScope.nsinfo.usingns = cxxnsinfo["usingns"]
            tmpScope.nsinfo.using = cxxnsinfo["using"]
            tmpScope.nsinfo.nsalias = cxxnsinfo["nsalias"]
            tmpScope.vars = rawScope["vars"]
            tmpScope.cusrstmt = rawScope["cusrstmt"] # added on 2012-07-04
            scopeStack.append(tmpScope)
            continue
        scopes = ParseScopes(rawScope["stmt"], null2other=True)
        if scopes:
            cxxnsinfo = rawScope["nsinfo"]
            scopes[-1].nsinfo.usingns = cxxnsinfo["usingns"]
            scopes[-1].nsinfo.using = cxxnsinfo["using"]
            scopes[-1].nsinfo.nsalias = cxxnsinfo["nsalias"]
            scopes[-1].vars = rawScope["vars"]
            scopes[-1].cusrstmt = rawScope["cusrstmt"] # added on 2012-07-04
        scopeStack.extend(scopes)
    #print '=' * 20, 'scope stack'
    #PrintList(scopeStack)
    return scopeStack

def PrintList(li):
    for i in li:
        print i

# 使用 libCxxParser
GetScopeStack = CxxGetScopeStack

def main():
    pass

if __name__ == '__main__':
    main()
