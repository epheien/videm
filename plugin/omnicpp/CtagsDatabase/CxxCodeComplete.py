#!/usr/bin/env python
# -*- coding:utf-8 -*-

'''C++ 的代码补全模块'''

# -*- DEPRECATED -*-
# 实现工作量太大，放弃了

# 嵌套层数限制
NEST_LIMIT = 20
# 展开 typedef 的缓存
ENABLE_TYPEDEF_CACHE = True

import sys
sys.path.append("omnicpp")

import re
import CppParser
import CxxHWParser
from TagsStorageSQLite import TagsStorageSQLite as TagsStorage
from TagEntry import TagEntry
from CppParser import CppScope, NSInfo
from CppParser import ParseVariableType
from CxxHWParser import CxxOmniInfo, CxxOmniScope, JoinTokensToString
from CxxHWParser import OmniInfo2Statement, TokenReader, CxxParseOmniInfo
from CppTokenizer import CxxTokenize, CxxToken

reFirstWord = re.compile(r'\b[a-zA-Z_]\w*\b')

class TypedefCache:
    '''类型定义缓存'''
    def __init__(self):
        self.di = {}

    def AddCache(self, scope, name, repl):
        if not self.di.has_key(scope):
            self.di[scope] = {}
        self.di[scope][name] = repl

    def HasCache(self, scope, name):
        if self.di.has_key(scope) and self.di[scope].has_key(name):
            return True
        else:
            return False

    def GetCache(self, scope, name):
        if self.HasCache(scope, name):
            return self.di[scope][name]
        else:
            return None

def ExpandNestedCxxMapping(key, di, ecptDict = {}):
    '''循环展开一个值，返回最终展开后的值(字符串)
    展开失败，返回 key'''
    global reFirstWord
    result = key
    if di.has_key(key):
        val = di[key]
        m = reFirstWord.search(val)
        if not m:
            return result
        w = m.group()
        if ecptDict.has_key(w): # 循环了，返回自身
            return w
        ecptDict[key] = ""
        w = ExpandNestedCxxMapping(w, di, ecptDict)
        result = reFirstWord.sub(w, val, 1)
        del ecptDict[key]
    return result

def ResolveNestedCxxMapping(di):
    '''用于处理 nsalias，也可以用于处理一般的嵌套映射
    x -> a::b
    会处理第一个单词 a，b 不会处理'''
    result = {}
    for k, v in di.iteritems():
        val = ExpandNestedCxxMapping(k, di)
        result[k] = val
    return result

def SimplifyScopeStack(scopeStack):
    '''简化 ScopeStack，返回(scope列表, 归并后的NSInfo)'''
    scopeList = []
    nsi = NSInfo()
    for scope in scopeStack:
        if scope.kind == "file":
            scopeList.append("<global>")
        else:
            scopeList.append(scope.name)
        nsi.usingns += scope.nsinfo.usingns
        nsi.using.update(scope.nsinfo.using)
        nsi.nsalias.update(scope.nsinfo.nsalias)

    nsi.nsalias = ResolveNestedCxxMapping(nsi.nsalias)
    nsi.using = ResolveNestedCxxMapping(nsi.using)

    return (scopeList, nsi)

def JoinScopes(scopes):
    '''tags 数据库的 scope 很不统一，这个很讨厌，通过这个函数来封装差异'''
    if len(scopes) == 0:
        return ""
    elif len(scopes) == 1:
        return scopes[0]
    else:
        if scopes[0] == "<global>":
            return "::".join(scopes[1:])
        else:
            return "::".join(scopes)

def SimpScopeStack2SearchScopes(simpScopeStack):
    '''把 simpScopeStack 转为搜索用的 searchScopes，
    用于 GetFirstMatchTag() 之类的函数'''
    result = []
    li = []
    for simpScope in simpScopeStack:
        li.append(simpScope)
        result.append(JoinScopes(li))
    return result


# kinds 可能的取值
# class
# macro
# enumerator
# function
# enum
# local
# member
# namespace
# prototype
# struct
# typedef
# union
# variable
# externvar
def GetFirstMatchTag(tagsStorage, searchScopes, name, *kinds):
    '''kinds 是全称
    返回 TagEntry'''
    result = None
    for scope in searchScopes:
        path = JoinScopes([scope, name])
        tags = tagsStorage.GetTagsByPath(path)
        if tags:
            if kinds:
                found = False
                for tag in tags:
                    if tag.GetKind() in kinds:
                        result = tag
                        found = True
                        break
                if found:
                    break
            else:
                # FIXME: 真的需要这么做吗？
                tag = tags[0]
                if tag.GetParent() == tag.GetName() \
                   or "~" + tag.GetParent() == tag.GetName() \
                   and (tag.IsFunction() or tag.IsPrototype()):
                    # 跳过构造和析构函数的 tag, 因为构造函数是不能继续补全的
                    # eg. A::A, A::~A
                    continue
                else:
                    result = tag
                    break

    return result

def GetCodeCompleteSearchScopes(tagsStorage, scopeStack, rawOmniInfo):
    '''代码补全接口
    tagsStorage 是 tags 仓库实例，理论上是 ITagsStorage 类型
    scopeStack 是当前代码上下文，是 CppParser.GetScopeStack() 的返回值
    rawOmniInfo 是当前要补全的语句，是 CxxOmniInfo 类型
    '''
    '''scopeStack 中的 nsinfo，先用名空间别名预处理所有的 usingns 和 using，
    展开的时候，优先选择 using 和 nsalias
    展开的时候，直接按字典查询 using 和 nsalias，直接替换'''
    pass
    # TODO: 从 omni 语句提取需要处理 typedef 的最短语句，现在暂时不处理
    simpScopeStack, simpNSInfo = SimplifyScopeStack(scopeStack)
    omniStmt = ResolveTypedef(tagsStorage, simpScopeStack, simpNSInfo,
                              OmniInfo2Statement(rawOmniInfo))
    omniInfo = CxxParseOmniInfo(omniStmt)
    searchScopes = SimpScopeStack2SearchScopes(simpScopeStack)
    omniss = omniInfo.omniss

    result = []

    if omniInfo.precast == "<global>":
        searchScopes = ["<global>"]
    elif omniInfo.precast == "this":
        try:
            searchScopes = [searchScopes[-2]] # 最后的肯定是成员函数
        except:
            return []
    elif omniInfo.precast != "":
        # 第一个元素不需要解析了，直接得出结果
        omniss[0].typeinfo = ParseVariableType(omniInfo.precast)
    else:
        pass

    currSimpSS = simpScopeStack[:] # 当前作用域栈

    # TODO
    for idx, omni in enumerate(omniss):
        if idx == 0:
            if omni.op == "::":
                tag = GetFirstMatchTag(tagsStorage, searchScopes, omni.text)
                if not tag: break
                currSimpSS = tag.GetScope().split("::")
            else: # omni.op == "." or omni.op == "->"
                if not omni.preops:
                    # 单变量
                    if not omni.typeinfo:
                        # 先解析变量
                        pass
                    tags = tagsStorage.GetTagsByPath(
                        omni.typeinfo.name + "::operator " + omni.op)
                    if not tags: break
                else:
                    # 函数或者 operator []
                    for preop in preops:
                        # TODO
                        pass
            continue

        # 非第一次

    print OmniInfo2Statement(omniInfo)
    return result

reDumpDecl = re.compile(r'typedef\s+([^;]+)\s+[a-zA-Z_]\w*;$')
reTrimTypedefWord = re.compile(r'\btypename\b|\btemplate\b')
def DumpDeclFromTypedefStmt(stmt):
    global reDumpDecl, reTrimTypedefWord
    m = reDumpDecl.match(stmt)
    if m:
        return reTrimTypedefWord.sub("", m.group(1))
    else:
        return ""

def ReplaceTypeMap(stmt, typeMap):
    '''根据 typeMap(字典)，替换 stmt 相应的类型
    是直接根据 typeMap 替换，所以 typeMap 要先自己处理完毕嵌套的情况'''
    toks = CxxTokenize(stmt)
    trd = TokenReader(toks)
    result = []
    curTok = CxxToken()
    while True:
        prevTok = curTok
        curTok = trd.GetToken()
        if not curTok.IsValid():
            break
        text = curTok.text
        if prevTok.IsOP() and prevTok.text == "::":
            pass
        elif curTok.IsWord():
            text = typeMap.get(curTok.text, curTok.text)
        result.append(text)
    return " ".join(result)

def SplitTemplate(template):
    '''把模板声明分割为列表'''
    nestLv = 0
    charlist = []
    result = []
    for c in template:
        charlist.append(c)
        if c == '<':
            if nestLv == 0: # 第一个左尖括号
                charlist.pop(0)
            nestLv += 1
        elif c == '>':
            nestLv -= 1
            if nestLv == 0: # 最后一个右尖括号
                charlist.pop(-1)
        elif c == ',' and nestLv == 1:
            charlist.pop(-1)
            result.append("".join(charlist).strip())
            del charlist[:]

        if nestLv == 0:
            result.append("".join(charlist).strip())
            break

    return result

reAssignExporDumper = re.compile(r'\b([a-zA-Z_]\w*)\s*=\s*([^;]+)')
def AssignExprDumper(expr):
    '''从等号表达式提取 key 和 value
    提取失败的话，返回 None，否则返回 (key, value)'''
    global reAssignExporDumper
    m = reAssignExporDumper.search(expr)
    if not m:
        return None
    else:
        return m.groups()

def TmplDeclList2Dict(tmplDeclList, tmplList = []):
    '''tmplDeclList 为 SplitTemplate() 的返回类型'''
    result = {}
    if not tmplList:
        for i in tmplDeclList:
            tmp = AssignExprDumper(i)
            if tmp:
                result[tmp[0]] = tmp[1]
            else:
                k = i.split()[-1]
                result[k] = k # 键和值一样
    else:
        for idx, val in enumerate(tmplDeclList):
            tmp = AssignExprDumper(val)
            if tmp:
                k = tmp[0]
                v = ReplaceTypeMap(tmp[1], result) # 默认参数要展开一下
            else:
                k = val.split()[-1]
                v = k # 键和值一样
            try:
                v = tmplList[idx]
            except:
                pass
            result[k] = v

    return result

def GetTemplateMap(tagsStorage, path, tmplList):
    '''tmplList 为模板初始化列表，例如 ["int", "char", "float"]
    tmplList 的类型如果有嵌套的话，不处理，所以最好就是外部先处理 tmplList 的嵌套
    返回字典，没有有效的映射的话，就返回空字典'''
    tags = tagsStorage.GetTagsByPath(path)
    result = {}
    if not tags:
        return {}
    for tag in tags:
        tmpl = tag.GetTemplate()
        if not tmpl:
            return {}
        result = TmplDeclList2Dict(SplitTemplate(tmpl), tmplList)
        break
    return result

# 这个函数主要还差嵌套模板类型替换的处理
def ResolveTypedef(tagsStorage, simpScopeStack, simpNSInfo,
                   stmt, nestLv = 0, cache = None, simpTemplate = None):
    '''展开语句 stmt 的 typedef，会嵌套展开

    simpScopeStack 是简化后的 scopeStack，元素是字符串
    simpTemplate 是 simpScopeStack 对应的模板，例如
    simpScopeStack = ["std", "map"]
    simpTemplate = [[], ["std::string", "int"]]

    simpNSInfo 只支持一级 NSInfo，在补全开始那里和全局 NSInfo，
    其他复杂的状况暂不支持，太麻烦了

    模板的处理比较麻烦，暂时使用最简单的处理，不支持嵌套的模板

    cache 是 TypedefCache 类型

    展开失败返回空字符串'''
    if nestLv >= NEST_LIMIT:
        return ""

    # 太麻烦了，模板参数，只支持最里层的作用域内展开，不支持嵌套情况
    tmplList = []
    try:
        tmplList = simpTemplate[-1]
    except:
        pass
    tmplTypeDict = GetTemplateMap(tagsStorage, JoinScopes(simpScopeStack),
                                  tmplList)

    toks = CxxTokenize(stmt)
    trd = TokenReader(toks)
    result = [] # 元素是字符串
    curTok = CxxToken()
    while True:
        prevTok = curTok
        curTok = trd.GetToken()
        if not curTok.IsValid():
            break
        text = curTok.text
        if prevTok.IsOP() and prevTok.text == "::":
            # 这个 token 不需要展开typedef
            pass
        elif curTok.IsWord():
            # 这个 token 需要展开typedef
            # A::B<C>::D
            # ^
            text = curTok.text
            if simpNSInfo.using.has_key(curTok.text):
                text = simpNSInfo.using[curTok.text]
            elif simpNSInfo.nsalias.has_key(curTok.text):
                text = simpNSInfo.nsalias[curTok.text]
            elif tmplTypeDict.has_key(curTok.text):
                text = tmplTypeDict[curTok.text]
            else: # 查找 typedef 的 tag
                # 在 simpScopeStack 中查找 text 的 typedef 对应的 tag，
                # 若能找到，替换 tag 中的 typedef 部分为 text
                tag = GetFirstMatchTag(tagsStorage,
                                       SimpScopeStack2SearchScopes(simpScopeStack),
                                       text, "typedef")
                if tag:
                    tempText = DumpDeclFromTypedefStmt(tag.GetText())
                    if tempText:
                        text = tempText
                        tempText = ResolveTypedef(tagsStorage, simpScopeStack,
                                                  simpNSInfo, text,
                                                  nestLv + 1, cache,
                                                  simpTemplate)
                        if tempText:
                            text = tempText
        result.append(text)

    return " ".join(result)

def UnitTest():
        assert DumpDeclFromTypedefStmt("typedef typename _Alloc::template rebind<value_type>::other _Pair_alloc_type;") == " _Alloc:: rebind<value_type>::other"
        di = {"_Key": "std::string", "_Tp": "int"}
        assert ReplaceTypeMap("std::less<_Key>", di) == "std :: less < std::string >"
        assert ReplaceTypeMap("std::allocator<std::pair<const _Key, _Tp> >", di) \
                == "std :: allocator < std :: pair < const std::string , int > >"
        assert SplitTemplate("<typename _Key, typename _Tp, typename _Compare = std::less<_Key>, typename _Alloc = std::allocator<std::pair<const _Key, _Tp> > >") \
                == ['typename _Key', 'typename _Tp',
                    'typename _Compare = std::less<_Key>',
                    'typename _Alloc = std::allocator<std::pair<const _Key, _Tp> >']
        assert AssignExprDumper("typename _Alloc = std::allocator<std::pair<const _Key, _Tp> >") \
                == ('_Alloc', 'std::allocator<std::pair<const _Key, _Tp> >')
        assert TmplDeclList2Dict(['typename _Key', 'typename _Tp',
                    'typename _Compare = std::less<_Key>',
                    'typename _Alloc = std::allocator<std::pair<const _Key, _Tp> >']) \
                == {'_Key': '_Key', '_Tp': '_Tp', '_Compare': 'std::less<_Key>',
                    '_Alloc': 'std::allocator<std::pair<const _Key, _Tp> >'}
        assert TmplDeclList2Dict(['typename _Key', 'typename _Tp',
                    'typename _Compare = std::less<_Key>',
                    'typename _Alloc = std::allocator<std::pair<const _Key, _Tp> >'],
                                ["std::string", "int", "test"]) \
                == {'_Key': 'std::string', '_Tp': 'int', '_Compare': 'test',
                    '_Alloc': 'std :: allocator < std :: pair < const std::string , int > >'}
        assert ExpandNestedCxxMapping("a", {"a": "b::x", "b": "c::y", "c": "yy"}) \
                == "yy::y::x"
        assert ExpandNestedCxxMapping("a", {"a": "b", "b": "c", "c": "a"}) \
                == "a"
        assert ResolveNestedCxxMapping({"a": "b::x", "b": "c::y", "c": "yy"}) \
                == {'a': 'yy::y::x', 'c': 'yy', 'b': 'yy::y'}

def test():
    UnitTest()
    dbfile = "Test_CxxParser.vltags"
    tagdb = TagsStorage()
    tagdb.OpenDatabase(dbfile)
    assert tagdb.db
    #print JoinScopes(["<global>"])
    #print JoinScopes(["<global>", "std", "map"])
    #print SimpScopeStack2SearchScopes(["<global>", "std", "map"])
    #print SimpScopeStack2SearchScopes(["std", "map"])
    searchScopes = SimpScopeStack2SearchScopes(["<global>", "std"])
    tag = GetFirstMatchTag(tagdb, searchScopes, "map", "class")
    tag = GetFirstMatchTag(tagdb, searchScopes, "string", "typedef")
    print GetTemplateMap(tagdb, "std::map", ["std::string", "int", "compare"])
    #tag = tagdb.GetTagsByPath("std::map")[0]
    if tag:
        pass
        #tag.Print()
        #print DumpDeclFromTypedefStmt(tag.GetText())
        #print DumpDeclFromTypedefStmt("typedef typename _Alloc::template rebind<value_type>::other _Pair_alloc_type;")
    nsi = NSInfo()
    nsi.using["map"] = "std::map";
    nsi.usingns.append("std");

    # scopeStack 有 "<global>" 表示需要搜索 <global> 作用域
    print ResolveTypedef(tagdb, ["<global>", "main"], nsi,
                         "map<String, int>::iterator")

    print ResolveTypedef(tagdb, ["std", "map"], NSInfo(), "iterator", simpTemplate = [[], ["std::strng", "int"]])

    import sys
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
    lines = allLines[: line]
    scopeStack = CppParser.GetScopeStack(lines)
    print scopeStack
    #print SimplifyScopeStack(scopeStack)
    print GetCodeCompleteSearchScopes(tagdb, scopeStack,
                                      CxxParseOmniInfo(scopeStack[-1].cusrstmt))

    cases = [
        "map<String, int>::iterator",
    ]
    for case in cases:
        pass
        #print ResolveTypedef(tagdb, scopeStack, case)


if __name__ == "__main__":
    test()
