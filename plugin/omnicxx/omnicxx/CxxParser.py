#!/usr/bin/env python
# -*- coding:utf-8 -*-

import sys
import re
import json
import traceback

import CppTokenizer

# 必须在这个作用域 import libCxxParser，否则 sys.argv 无法用于传参数给 libCxxParser
# 外部可能不需要使用 libCxxParser，这时候，libCxxParser 很可能会在 import 的时候出错
# 外部如果不需要使用 libCxxParser 的时候，不应该调用 CxxGetScopeStack，否则会出错
try:
    import libCxxParser
except:
    print 'Failed to import libCxxParser, libCxxParser not found?'
    traceback.print_exc()
    #raise

from CppTokenizer import CPP_KEYOWORD
from CppTokenizer import CPP_WORD
from CppTokenizer import C_COMMENT
from CppTokenizer import C_UNFIN_COMMENT
from CppTokenizer import CPP_COMMENT
from CppTokenizer import CPP_STRING
from CppTokenizer import CPP_CHAR
from CppTokenizer import CPP_DIGIT
from CppTokenizer import CPP_OPERATORPUNCTUATOR

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

def CppTokenize(s):
    '''必须把换行换成空格，方便正则处理'''
    return CppTokenizer.CppTokenize(s.replace('\n', ' '))

class TokensReader:
    def __init__(self, tokens):
        '''tokens 必须是列表'''
        self.__tokens = tokens
        self.tokens = self.__tokens[::-1] # 副本，翻转顺序
        self.popeds = [] # 已经被弹出去的 token，用于支持 PrevToken()

    def GetToken(self):
        '''获取下一个 token，若到尾部，返回 None'''
        if self.tokens:
            tok = self.tokens.pop(-1)
            self.popeds.append(tok)
            return tok
        else:
            # popeds 数据结构也要加上这个，以便统一处理
            if self.popeds and not self.popeds[-1] is None:
                self.popeds.append(None)
            return None

    def UngetToken(self, token):
        '''反推 token，外部负责 token 的正确性'''
        self.tokens.append(token)
        if self.popeds:
            self.popeds.pop(-1)

    def PeekToken(self):
        if self.tokens:
            return self.tokens[-1]
        else:
            return None

    def PrevToken(self):
        if len(self.popeds) >= 2:
            return self.popeds[-2]
        else:
            return None

    def GetOrigTokens(self):
        return self.__tokens

# TODO: "class Z::A"
def ParseScopes(stmt, null2other = False):
    '''返回 Scope 列表，每个项目是 CppScope 对象
    对于每个 CppScope 对象，只填写 kind 和 name 字段'''
    trd = TokensReader(CppTokenize(stmt))
    scopes = []

    # 如果语句为空的话，视为一个无名作用域，有时候需要
    if trd.PeekToken() is None and null2other:
        newScope = CppScope()
        newScope.kind = 'other'
        scopes.append(newScope)
        return scopes

    # GO
    SCOPTTYPE_COMMON = 0
    SCOPETYPE_CONTAINER = 1
    SCOPETYPE_SCOPE = 2
    SCOPETYPE_FUNCTION = 3
    scopeType = SCOPTTYPE_COMMON # 0 表示无名块类型
    while True:
        # 首先查找能确定类别的关键字符
        # 0. 无名块(if, while, etc.)
        # 1. 容器类别 'namespace|class|struct|union'. eg. class A
        # 2. 作用域类别 '::'. eg. A B::C::D(E)
        # 3. 函数类别 '('. eg. A B(C)
        curToken = trd.GetToken()
        if curToken is None:
            break

        if curToken.kind == CPP_KEYOWORD \
           and curToken.value in set(['namespace', 'class', 'struct', 'union']):
            # 容器类别
            # 取最后的 cppWord, 因为经常在名字前有修饰宏
            # eg. class WXDLLIMPEXP_SDK BuilderGnuMake;
            while True:
                curToken = trd.GetToken()
                if curToken is None or curToken.kind != CPP_WORD:
                    break
            prevTok = trd.PrevToken()
            scopeType = SCOPETYPE_CONTAINER
            newScope = CppScope()
            newScope.kind = 'container'
            newScope.name = prevTok.value

            # 也可能是函数，例如: 'struct tm * A::B::C(void *p)'
            needRestart = False
            # added on 2012-07-04
            tmpToks = [] # 用来恢复的
            # 不是这样的时候才需要继续检查 'struct xx {'
            if not trd.PeekToken() is None and trd.PeekToken().value != '{':
                while True: # 检查是否函数，方法是检查后面是否有 '('
                    curToken = trd.GetToken()
                    if curToken is None:
                        break
                    tmpToks.append(curToken)
                    if curToken.kind == CPP_OPERATORPUNCTUATOR \
                       and curToken.value == '(':
                        needRestart = True
                        # 恢复
                        for t in tmpToks[::-1]:
                            trd.UngetToken(t)
                        break
                # added on 2012-07-04 -*- END -*-

            if needRestart:
                continue
            else:
                scopes.append(newScope)
                # OK
                break
        elif curToken.kind == CPP_KEYOWORD and curToken.value == 'else':
            if not trd.PeekToken() is None and trd.PeekToken().value == 'if':
                # 也可能是 else if {
                pass
            else:
                # else 条件语句
                newScope = CppScope()
                newScope.kind = 'other'
                newScope.name = curToken.value
                scopes.append(newScope)
                # OK
                break
        elif curToken.kind == CPP_KEYOWORD and curToken.value == 'extern':
            # 忽略 'extern "C" {'
            peekTok = trd.PeekToken()
            if peekTok is None:
                break
            if peekTok.kind == CPP_STRING \
               or peekTok.kind == CPP_OPERATORPUNCTUATOR:
                break
        elif curToken.kind == CPP_OPERATORPUNCTUATOR and curToken.value == '::':
            scopeType = SCOPETYPE_SCOPE
            # FIXME: 不能处理释构函数 eg. A::~A()
            # 现在会把析构函数解析为构造函数
            # 由于现在基于 ctags 的 parser, 会无视函数作用域,
            # 所以暂时工作正常
            prevTok = trd.PrevToken()
            tempScopes = []
            if not prevTok is None:
                newScope = CppScope()
                newScope.kind = 'container'
                newScope.name = trd.PrevToken().value
                tempScopes.append(newScope)
            # 继续分析
            # 方法都是遇到操作符('::', '(')后确定前一个 token 的类别
            needRestart = False
            # 连续单词数，若大于 1，重新开始
            serialWordCount = 0
            while True:
                curToken = trd.GetToken()
                if curToken is None:
                    break
                if curToken.kind == CPP_OPERATORPUNCTUATOR \
                   and curToken.value == '(':
                    newScope = CppScope()
                    newScope.kind = 'function'
                    prevTok = trd.PrevToken()
                    if prevTok.kind == CPP_KEYOWORD:
                        newScope.kind = 'other'
                    newScope.name = prevTok.value
                    tempScopes.append(newScope)
                    # 到了函数参数或条件判断位置, 已经完成
                    break
                elif curToken.kind == CPP_OPERATORPUNCTUATOR \
                        and curToken.value == '::':
                    serialWordCount = 0
                    newScope = CppScope()
                    newScope.kind = 'container'
                    newScope.name = trd.PrevToken().value
                    tempScopes.append(newScope)
                elif curToken.kind == CPP_KEYOWORD or curToken.kind == CPP_WORD:
                    serialWordCount += 1
                    if serialWordCount > 1: # 连续的单词，如 std::a func()
                        needRestart = True
                        trd.UngetToken(curToken)
                        break
            if needRestart:
                # 例如: std::string func() {
                pass
            else:
                # OK
                scopes.extend(tempScopes)
                break
        elif curToken.kind == CPP_OPERATORPUNCTUATOR and curToken.value == '(':
            # 函数或条件类型
            scopeType = SCOPETYPE_FUNCTION
            prevTok = trd.PrevToken()
            if not prevTok is None:
                newScope = CppScope()
                newScope.kind = 'function'
                if prevTok.kind == CPP_KEYOWORD:
                    newScope.kind = 'other'
                newScope.name = prevTok.value
                scopes.append(newScope)
                # OK
                break
        else:
            if trd.PeekToken() is None:
                # 到达最后但是还不能确定为上面的其中一种
                # 应该是一个无名块, 视为 other 类型
                newScope = CppScope()
                newScope.kind = 'other'
                newScope.name = curToken.value
                scopes.append(newScope)
    # while END
    return scopes

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
