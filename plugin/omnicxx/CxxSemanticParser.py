#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os
import os.path
import json
import re

# 这个正则表达式经常要用
CXX_MEMBER_OP_RE = re.compile('^(\.|->|::)$')

########## 硬编码设置, 用于快速测试 ##########
path = [os.path.expanduser('~/.videm/core'),
        os.path.expanduser('~/.vim/bundle/videm/autoload/omnicpp'),
        os.path.expanduser('~/.vim/autoload/omnicpp')]
sys.path.extend(path)

# NOTE 不在 vim 环境下运行, 默认使用 "~/libCxxParser.so"
import CppParser

##########

# CPP_OP 作为 CPP_OPERATORPUNCTUATOR 的缩写
from CppTokenizer import CPP_EOF, CPP_KEYOWORD, CPP_WORD, C_COMMENT,        \
        C_UNFIN_COMMENT, CPP_COMMENT, CPP_STRING, CPP_CHAR, CPP_DIGIT,      \
        CPP_OPERATORPUNCTUATOR as CPP_OP
from CppTokenizer import CxxTokenize

from ListReader import ListReader
from CxxTypeParser import TokensReader
from CxxTypeParser import CxxType
from CxxTypeParser import CxxUnitType
from CxxTypeParser import CxxParseType
from CxxTypeParser import CxxParseTemplateList

class ComplScope(object):
    '''
    代码补全时每个scope的信息, 只有三种:
    * ->    成员变量, (成员)函数的返回值, 需要解析出具体的类型
    * .     成员变量, (成员)函数的返回值, 需要解析出具体的类型
    * ::    一个固定的类型, 无需解析类型, 可以称之为容器

    {
        'kind': <'container'|'variable'|'function'|'unknown'>
        'text': <name>    <- 必然是单元类型 eg. A<a,b,c>
        'tmpl': <template initialization list>
        'tag' : {}        <- 在解析的时候添加
        'type': {}        <- 在解析的时候添加
        'cast': <强制类型转换>
    }
    '''
    KIND_CONTAINER  = 0
    KIND_VARIABLE   = 1
    KIND_FUNCTION   = 2
    KIND_UNKNOWN    = 3

    kind_mapping = {
        KIND_CONTAINER  : 'KIND_CONTAINER',
        KIND_VARIABLE   : 'KIND_VARIABLE',
        KIND_FUNCTION   : 'KIND_FUNCTION',
        KIND_UNKNOWN    : 'KIND_UNKNOWN',
    }

    def __init__(self, name = '', kind = KIND_UNKNOWN):
        self.text = ''
        self.kind = type(self).KIND_UNKNOWN
        # 每个item是文本
        self.tmpl = []
        # CxxType
        self.type = None
        # CxxType
        self.cast = None

    def __repr__(self):
        return '{"text": "%s", "kind": "%s", "tmpl": %s, "type": %s, "cast": %s}' % (
            self.text, type(self).kind_mapping.get(self.kind),
            self.tmpl, self.type, self.cast)

class ComplInfo(object):
    def __init__(self):
        # ComplScope
        self.scopes = []
        # 如果最前面的有效 token 为 '::', 那么这个成员为 True
        # 最前面的 '::' 不算进 scopes 里面的类型里面, 
        # 单独算进这个变量处理起来更简单
        self._global = False
        # "new A::B", 用于标识, 有时候需要根据这个来获取calltips
        self.new_stmt = False

    def IsValid(self):
        return bool(self.scopes) or self._global

    def Invalidate(self):
        del self.scopes[:]
        self._global = False
        self.new_stmt = False

    def __repr__(self):
        return '{"global": %s, "new_stmt": %s, "scopes": %s}' % (
            self._global, self.new_stmt, self.scopes)

# 跳至指定的匹配，tokrdr 当前的 token 为 left 的下一个
# 返回结束时的嵌套层数, 调用着可检查此返回值来确定是否下一步动作
def SkipToMatch(tokrdr, left, right, collector = None):
    nestlv = 1
    while tokrdr.curr.IsValid():
        tok = tokrdr.Get()

        if isinstance(collector, list):
            collector.append(tok)

        if tok.text == left:
            nestlv += 1
        elif tok.text == right:
            nestlv -= 1

        if nestlv == 0:
            break

    return nestlv

class TypeInfo(object):
    '''代表一个C++类型，保存足够的信息, vim omnicpp 兼容形式'''
    def __init__(self):
        self.text = ''
        self.tmpl = []
        self.typelist = []

def GetComplInfo(tokens):
    # 需要语法解析, 实在是太麻烦了
    '''
    获取全能补全请求前的语句的 ComplInfo
        case01. A::B C::D::|
        case02. A::B()->C().|
        case03. A::B().C->|
        case04. A->B().|
        case05. A->B.|
        case06. Z Y = ((A*)B)->C.|
        case07. (A*)B()->C.|
        case08. static_cast<A*>(B)->C.|
        case09. A(B.C()->|)

        case10. ::A->|
        case11. A(::B.|)
        case12. (A**)::B.|
    '''
    rdr = TokensReader(tokens[::-1])
    #while rdr.curr.IsValid():
        #print rdr.Pop()

    # 初始状态, 可能不用
    STATE_INIT = 0
    # 期待操作符号 '->', '.', '::'
    STATE_EXPECT_OP = 1
    # 期待单词
    STATE_EXPECT_WORD = 2

    state = STATE_INIT

    global CXX_MEMBER_OP_RE

    result = ComplInfo()

    # 用于模拟 C 语言的 for(; x; y) 语句
    __first_enter = True
    while rdr.curr.IsValid():
        if not __first_enter:
            # 消耗一个token
            rdr.Pop()
        __first_enter = False

        if rdr.curr.kind == CPP_OP and CXX_MEMBER_OP_RE.match(rdr.curr.text):
        # 这是个成员操作符 '->', '.', '::'
            if state == STATE_INIT:
                # 初始状态遇到操作符, 补全开始, 光标前没有输入单词
                state = STATE_EXPECT_WORD
            elif state == STATE_EXPECT_OP:
                state = STATE_EXPECT_WORD
            elif state == STATE_EXPECT_WORD:
                # 语法错误
                result.Invalidate()
                break
            else:
                pass
            # endif

        elif rdr.curr.kind == CPP_WORD:
            if state == STATE_INIT:
                # 这是base, 这里不考虑base的问题, 继续
                pass
            elif state == STATE_EXPECT_OP:
                # 期望操作符, 遇到单词
                # 结束.
                # eg A::B C::|
                #       ^
                break
            elif state == STATE_EXPECT_WORD:
                # 成功获取一个单词
                compl_scope = ComplScope()
                compl_scope.text = rdr.curr.text
                # 无法根据上一个字符来判断类型, 因为 ::A 的 A 可能是变量
                # 根据下一个字符来判断: prev -> right
                if rdr.prev.text == '::':
                    compl_scope.kind = ComplScope.KIND_CONTAINER
                elif rdr.prev.text == '->' or rdr.prev.text == '.' \
                        or rdr.prev.text == '[':
                    compl_scope.kind = ComplScope.KIND_VARIABLE
                else:
                    # unknown
                    pass

                result.scopes.insert(0, compl_scope)
                state = STATE_EXPECT_OP
            else:
                # 忽略
                pass

        elif rdr.curr.kind == CPP_KEYOWORD and rdr.curr.text == 'this':
            if state == STATE_INIT:
                # 这是base, 忽略
                state = STATE_EXPECT_OP
            elif state == STATE_EXPECT_OP:
                # 期待操作符, 即上一个是单词, 显然语法错误
                result.Invalidate()
                break
            elif state == STATE_EXPECT_WORD:
                # 期待单词遇到 this, 肯定是 this-> 之类的
                right = rdr.prev
                #if right.text != '->': # 现在是不做指针或者结构的区别的
                    #result.Invalidate()
                    #break
                # 特殊变量 'this'
                compl_scope = ComplScope()
                compl_scope.text = 'this'
                compl_scope.kind = type(compl_scope).KIND_VARIABLE
                result.scopes.insert(0, compl_scope)
                break
            else:
                pass
            # endif

            #if state == STATE_INIT:
            #    pass
            #elif state == STATE_EXPECT_OP:
            #    pass
            #elif state == STATE_EXPECT_WORD:
            #    pass
            #else:
            #    pass
            ## endif

        elif rdr.curr.kind == CPP_OP and rdr.curr.text == ')':
            if state == STATE_INIT:
                # 括号后是无法补全的
                result.Invalidate()
                break
            elif state == STATE_EXPECT_OP:
                # 期待操作符, 遇到右括号
                # 必定是一个 postcast, 结束
                # 无须处理, 直接完成
                # eg. (A*)B->|
                #        ^
                break
            elif state == STATE_EXPECT_WORD:
                # 期待单词
                # 遇到右括号
                # 可能是 precast 或者 postcast 或者是一个函数
                # precast:
                #   ((A*)B.b)->C.|
                #           ^|
                #   ((A*)B.b())->C.|
                #            ^|
                #   static_cast<A *>(B.b())->C.|
                #                        ^|
                #   
                # postcast:
                #   (A)::B.|
                #     ^|
                #
                # function:
                #   func<T>(0).|
                #            ^|
                # 
                save_prev = rdr.prev
                rdr.Pop()
                colltoks = []
                SkipToMatch(rdr, ')', '(', colltoks)
                # tmprdr 是正常顺序, 最后的 '(' 字符不要
                if colltoks:
                    colltoks.pop(-1)
                colltoks.reverse()
                tmprdr = TokensReader(colltoks)

                '''
                C++形式的cast:
                    dynamic_cast < type-id > ( expression )
                    static_cast < type-id > ( expression )
                    reinterpret_cast < type-id > ( expression )
                    const_cast < type-id > ( expression )
                '''

                # 处理模板
                #   Func<T>(0)
                #         ^
                tmpltoks = []
                if rdr.curr.text == '>':
                    tmpltoks.append(rdr.Pop())
                    if SkipToMatch(rdr, '>', '<', tmpltoks) != 0:
                        result.Invalidate()
                        break
                    # 需要反转
                    tmpltoks.reverse()

                if rdr.curr.kind == CPP_WORD:
                    # 确定是函数
                    compl_scope = ComplScope()
                    compl_scope.kind = ComplScope.KIND_FUNCTION
                    compl_scope.text = rdr.curr.text
                    if tmpltoks:
                        compl_scope.tmpl = CxxParseTemplateList(TokensReader(tmpltoks))
                    result.scopes.insert(0, compl_scope)
                    state = STATE_EXPECT_OP
                elif rdr.curr.kind == CPP_KEYOWORD and \
                        rdr.curr.text == 'dynamic_cast' or \
                        rdr.curr.text == 'static_cast' or \
                        rdr.curr.text == 'reinterpret_cast' or \
                        rdr.curr.text == 'const_cast':
                    # C++ 形式的 precast
                    if not tmpltoks:
                        # 语法错误
                        result.Invalidate()
                        break
                    compl_scope = ComplScope()
                    compl_scope.kind = ComplScope.KIND_VARIABLE
                    compl_scope.text = '<CODE>'
                    # 解析的时候不要前后的尖括号
                    tmpltoks = tmpltoks[1:-1]
                    tmpltoks_reader = TokensReader(tmpltoks)
                    cxx_type = CxxParseType(tmpltoks_reader)
                    compl_scope.cast = cxx_type
                    result.scopes.insert(0, compl_scope)
                    break
                elif tmprdr.curr.text == '(':
                    # C 形式的 precast
                    #   ((A*)B.b)->C.|
                    #           ^|
                    compl_scope = ComplScope()
                    compl_scope.kind = ComplScope.KIND_VARIABLE
                    compl_scope.text = '<CODE>' # 无需名字

                    # 既然是 precast 那么这里可以直接获取结果并结束
                    tmprdr.Pop()
                    colltoks = []
                    SkipToMatch(tmprdr, '(', ')', colltoks)
                    # 不要最后的 ')'
                    if colltoks:
                        colltoks.pop(-1)
                    # 这里就可以解析类型了
                    cxx_type = CxxParseType(TokensReader(colltoks))
                    # cxx_type 可能是无效的, 由外部检查
                    compl_scope.cast = cxx_type
                    result.scopes.insert(0, compl_scope)
                    break
                elif rdr.prev.kind == CPP_OP and rdr.prev.text == '::':
                    # postcast
                    # eg. (A**)::B.|
                    #         |^^
                    if result.scopes:
                        compl_scope = result.scopes[0]
                    else:
                        compl_scope = ComplScope()
                    if not compl_scope.type:
                        # 这种情况下, compl_scope 肯定可以分析处理type的, 
                        # 如果没有那肯定是语法错误
                        result.Invalidate()
                        break
                    compl_scope.type._global = True
                    break
                else:
                    #  (A**)::B.
                    # ^
                    if save_prev.text == '::':
                        result._global = True
                    else:
                        result.Invalidate()

                    break
            else:
                pass

        elif rdr.curr.kind == CPP_OP and rdr.curr.text == ']':
            # 处理数组下标
            # eg. A[B][C[D]].|
            # 暂不支持数组下标补全, 现在全忽略掉 
            if state == STATE_INIT:
                result.Invalidate()
                break
            elif state == STATE_EXPECT_OP:
                result.Invalidate()
                break
            elif state == STATE_EXPECT_WORD:
                # 跳过所有连续的 [][][]
                brk = False
                while rdr.curr.kind == CPP_OP and rdr.curr.text == ']':
                    rdr.Pop()
                    if SkipToMatch(rdr, ']', '[') != 0:
                        # 中括号不匹配, 肯定语法错误吧
                        result.Invalidate()
                        brk = True
                        break
                if brk:
                    break
                # NOTE: 当前指向下一个token, 如果这时候continue的话, 这个token
                #       将错误检查, 因为每次循环后固定获取下一个token, 所以要
                #       put一个token
                rdr.Put(rdr.prev)
            else:
                result.Invalidate()
                break
            # endif

        elif rdr.curr.kind == CPP_OP and rdr.curr.text == '>':
            # 处理模板实例化
            # eg. A<B, C>::|
            if state == STATE_INIT:
                result.Invalidate()
                break
            elif state == STATE_EXPECT_OP:
                # eg. if (1 > A.|)
                break
            elif state == STATE_EXPECT_WORD:
                # eg. A<B, C>::
                #           ^
                # eg. if (a > ::A.
                #           ^
                # 跳到匹配的 '<'
                right = rdr.prev
                tmpltoks = [rdr.Pop()]
                if SkipToMatch(rdr, '>', '<', tmpltoks) != 0:
                    # eg. if (a > ::A.
                    if right.text == '::':
                        result._global = True
                    break
                tmpltoks.reverse()
                # 分析模板
                tmpl = CxxParseTemplateList(TokensReader(tmpltoks))
                # 继续往前分析, 因为现在的状况基本是已确定的(?)
                # 前面必须是一个函数或者容器
                if not rdr.curr.kind == CPP_WORD and \
                   not rdr.curr.kind == CPP_KEYOWORD and \
                   right.text != '::': # 无此语法: A<B>.
                    # 貌似必然是语法错误, 因为没见过这种语法: {op}<>
                    result.Invalidate()
                    break
                compl_scope = ComplScope()
                compl_scope.text = rdr.curr.text
                compl_scope.tmpl = tmpl
                # 上面已经检查过了, 这里可用于调试
                if right.text == '::':
                    compl_scope.kind = ComplScope.KIND_CONTAINER
                result.scopes.insert(0, compl_scope)
                state = STATE_EXPECT_OP
            else:
                result.Invalidate()
                break
            # endif

        else:
        # 遇到了其他字符, 结束. 前面判断的结果多数情况下是有用
            right = rdr.prev
            if right.kind == CPP_OP and right.text == '::':
                # 期待单词时遇到其他字符, 并且之前的是 '::', 那么这是 <global>
                if state == STATE_EXPECT_WORD:
                    result._global = True

            if rdr.curr.kind == CPP_KEYOWORD and rdr.curr.text == 'new':
                result.new_stmt = True

            break

        # endif

    # endwhile

    # eg. ::A->|
    if state == STATE_EXPECT_WORD and rdr.prev.text == '::':
        result._global = True

    return result

class ScopeInfo(object):
    '''
    NOTE: 理论上可能会有嵌套名空间的情况, 但是为了简化, 不允许使用嵌套名空间
        eg.
            using namespace A;
            using namespace B;
            A::B::C <-> C
    '''
    def __init__(self):
        # 函数作用域, 一般只用名空间信息
        self.function = []
        # 容器的作用域列表, 包括名空间信息
        self.container = []
        # 全局(文件)的作用域列表, 包括名空间信息
        # 因为 global 是 python 的关键词, 所以用这个错别字
        self._global = []

    def Print(self):
        print 'function: %s' % self.function
        print 'container: %s' % self.container
        print 'global: %s' % self._global

class CxxScope(object):
    '''ExpandScopeStack() 返回用, 合并的 CppScope'''
    def __init__(self):
        self.kind = 'unknown'
        self.name = ''
        self.scopes = []

def CookScopeStack(tagmgr, scope_stack):
    '''处理 scope, 展开里面所有的必要项, 然后需要的时候直接提取'''
    # TODO
    pass

def ExpandScopeStack(tagmgr, scope_stack):
    '''
    scope_stack 始终是很有用的原始信息, 只有在有需要的时候按需提取信息即可

    分析 scope_stack 中的名空间信息
    * 自动添加默认的 '<global>' 搜索域
    * 自动添加类和其所有基类的路径作为搜索域

    * 要展开 typedef
    * 要展开 inherits

    @return:    展开后的数段搜索域

    ['file', 'container', 'container', 'function', 'function', 'container']
    ->
    [
        {'kind': 'file',       'scopes': [...]},
        {'kind': 'container',  'scopes': [...]},
        {'kind': 'function',   'scopes': [...]},
        {'kind': 'container',  'scopes': [...]},
    ]
    '''
    # 名空间别名: {'abc': 'std'}
    nsalias = {}
    # using 声明: {'cout': 'std::out', 'cin': 'std::cin'}
    usingdecl = {}
    # using namespace
    usingns = []

    result = []

    # 逆序
    srdr = ListReader(scope_stack[::-1])
    while srdr.curr:
        nsalias.update(srdr.curr.nsinfo.nsalias)
        usingdecl.update(srdr.curr.nsinfo.using)
        usingns.extend(srdr.curr.nsinfo.usingns)

        if srdr.curr.kind == 'file':
            cxx_scope = CxxScope()
            cxx_scope.kind = 'file'
            cxx_scope.scopes.extend(srdr.curr.nsinfo.usingns)
            cxx_scope.scopes.append('<global>')
            result.append(cxx_scope)
            # 理论上必定完成
            break
        elif srdr.curr.kind == 'container':
            pending_scopes = []
            # 处理连续的 container
            tmp_search_scopes = []
            while srdr.curr:
                tmp_search_scopes.extend(srdr.curr.nsinfo.usingns)
                pending_scopes.append(srdr.curr.name)
                srdr.Pop()
            # 顺序
            for idx, scope in enumerate(pending_scopes[::-1]):
                # 处理嵌套类
                # eg.
                # void A::B::C::D()
                # {
                #     |
                # }
                # ['A', 'B', 'C'] -> ['A', 'A::B', 'A::B::C']
                # ['A', 'A::B', 'A::B::C'] 中的每个元素也必须展开其基类
                cls = '::'.join(pending_scopes[: idx+1])
                # TODO: 需要展开每个类的基类作为需要搜索的作用域
                epdcls = [cls]

                # 添加到最前面
                tmp_search_scopes[:0] = epdcls
            # endfor
            cxx_scope = CxxScope()
            cxx_scope.kind = 'container'
            cxx_scope.scopes.extend(tmp_search_scopes)
            result.append(cxx_scope)
            # 自己处理的, 直接 continue
            continue
        elif srdr.curr.kind == 'function':
            cxx_scope = CxxScope()
            # 处理连续的 function
            while srdr.curr:
                cxx_scope.scopes.extend(srdr.curr.nsinfo.usingns)
                srdr.Pop()
            cxx_scope.kind = 'function'
            result.append(cxx_scope)
            # 自己处理的, 直接 continue
            continue
        else:
            pass
        # endif

        srdr.Pop()
    # endwhile

    return result

def ResolveScopeStack(scope_stack):
    '''
    分析 scope_stack 中的名空间信息, 并作为搜索域来进行归类
    * 自动添加默认的 '<global>' 搜索域
    * 自动添加类和其所有基类的路径作为搜索域
    '''
    result = ScopeInfo()

    # 名空间别名: {'abc': 'std'}
    nsalias = {}
    # using 声明: {'cout': 'std::out', 'cin': 'std::cin'}
    usingdecl = {}
    # using namespace
    usingns = []

    # 需要返回的搜索作用域
    global_scopes = []

    # 容器类型的 scope
    container_scopes = []

    # 需要进一步解析的 scope
    pending_scopes = []

    function_scopes = []

    # NOTE: 这里作了一个重要的假设
    # scope_stack 的元素的顺序必然是如此的
    #   ['file', 'container', 'container', ..., 'function']
    #   ['file', 'container', 'container', ...]
    # 即必然以 'file' 开始, 并且之后的是连续的 'container', 最后可能是 'function'
    # 并且假定 'function' 不能嵌套
    # TODO: 需要支持任何顺序的情况('file'开始无法改变)

    for scope in scope_stack:
        # NOTE: 原来的逻辑是在 else 分支不进行此操作, 一般来说如果传入参数
        #       正确的话, 不存在任何问题
        nsalias.update(scope.nsinfo.nsalias)
        usingdecl.update(scope.nsinfo.using)
        usingns.extend(scope.nsinfo.usingns)

        if scope.kind == 'file':
            global_scopes.extend(scope.nsinfo.usingns)
            # 把 <global> 放最后，虽然理论上当有名字二义性的时候是编译错误
            # 但是在模糊模式里面，要把全局搜索域放到最后
            global_scopes.append('<global>')
        elif scope.kind == 'container':
            pending_scopes.append(scope.name)
            container_scopes.extend(scope.nsinfo.usingns)
        elif scope.kind == 'function':
            function_scopes.extend(scope.nsinfo.usingns)
        elif scope.kind == 'other':
            # TODO: 添加到更合适的地方
            function_scopes.extend(scope.nsinfo.usingns)
        else:
            pass
        # endif

    # endfor

    for idx, scope in enumerate(pending_scopes):
        # 处理嵌套类
        # eg.
        # void A::B::C::D()
        # {
        #     |
        # }
        # ['A', 'B', 'C'] -> ['A', 'A::B', 'A::B::C']
        # ['A', 'A::B', 'A::B::C'] 中的每个元素也必须展开其基类
        cls = '::'.join(pending_scopes[: idx+1])
        # TODO: 需要展开每个类的基类作为需要搜索的作用域
        epdcls = [cls]

        # 添加到最前面, 原来的逻辑
        container_scopes[:0] = epdcls
    # endfor

    result.function = function_scopes
    result.container = container_scopes
    result._global = global_scopes

    return result

def ExpandUsingAndNSAlias(text):
    ''''''
    # TODO
    return text

def FilterDuplicate(li):
    s = set()
    result = []
    for item in li:
        if item in s:
            continue
        s.add(item)
        result.append(item)
    return result

def _ToCxxType(di):
    '''libCxxParser.so 导出的 type 转为 CxxType 实例'''
    '''
    "pPrvtData": {
        "line": 4, 
        "type": {
            "types": [
                {
                    "name": "CxxLexPrvtData", 
                    "til": []
                }
            ]
        }
    }
    '''
    cxx_type = CxxType()
    for t in di.get('type').get('types'):
        unit_type = CxxUnitType()
        unit_type.text = t['name']
        unit_type.tmpl = t['til']
        cxx_type.typelist.append(unit_type)
    # TODO: _global 成员貌似没法初始化, 因为 libCxxParser.so 没有导出它
    return cxx_type

def ResolveLocalDecl(scope_stack, variable_name):
    for scope in scope_stack[::-1]:
        if scope.vars.has_key(variable_name):
            return _ToCxxType(scope.vars.get(variable_name))
    return None

def ResolveFirstVariable(tagmgr, scope_stack, search_scopes, variable_name):
    '''解析第一个变量
    search_scopes 应该从 scope_stack 中提取'''
    cxx_type = ResolveLocalDecl(scope_stack, variable_name)
    if cxx_type:
        # TODO: 展开 using 和名空间别名
        return cxx_type

    # 没有在局部作用域到找到此变量的声明
    # 在作用域栈中搜索
    tag = GetFirstMatchTag(tagmgr, search_scopes, variable_name)
    # TODO: 从 tag 中获取变量声明, 然后解析出 CxxType
    cxx_type = CxxParseType(tag.get('text', ''))
    if tag.has_key('class'):
        # 变量是类中的成员, 需要解析模版
        # TODO
        pass
    return cxx_type

def GetBotLevelSearchScopesFromTag(tag, cxx_type = CxxType()):
    '''
    解析 tag 的 typeref 和 inherits, 从而获取底层搜索域
    可选参数为 TypeInfo, 作为输出, 会修改, 用于类型为模版类的情形
    Return: 与 tag.path 同作用域的 scope 列表
    NOTE1: dTag 和 可选参数都可能修改而作为输出
    NOTE2: 仅解析出最邻近的搜索域, 不展开次邻近等的搜索域, 主要作为搜索成员用
    NOTE3: 仅需修改派生类的类型信息作为输出,
           因为基类的类型定义会在模版解析(ResolveTemplate())的时候处理,
           模版解析时仅需要派生类的标签和类型信息
    '''
    return _GetBotLevelSearchScopesFromTag(tag, cxx_type)

def _GetBotLevelSearchScopesFromTag(tag, cxx_type):
    # TODO
    search_scopes = []
    return []

def ExpandSearchScopesFromScope(scope):
    '''
    把一个作用域展开为所有可能搜索的作用域路径
    eg. A::B::C -> ['A::B::C', 'A::B', 'A', '<global>']
    '''
    if not scope:
        return []

    if scope == '<global>':
        return ['<global>']

    result = ['<global>']
    for idx, scope in enumerate(scope.split('::')):
        if idx == 0:
            result.insert(0, scope)
        else:
            result.insert(0, '%s::%s' % (result[0], scope))
    return result

'''
= 类作用域中的名字查找 =
(1) 首先, 在使用该名字的块中查找名字的声明. 只考虑在该项使用之前声明的名字
(2) 如果找不到该名字, 则在包围的作用域中查找.

    == 类成员声明的名字查找 ==
    * 检查出现在名字使用之前的类成员的声明
    * 如果第1步查找不成功, 则检查包含类定义的作用域中出现的声明以及出现在类定义
      之前的声明.

    == 类成员定义中的名字查找 ==
    * 首先检查成员函数局部作用域中的声明
    * 如果在成员函数中找不到该名字的声明, 则检查对所有类成员的声明
    * 如果在类中找不到该名字的声明, 则检查在此成员函数定义之前的作用域中出现的声明
'''

def ResolveComplInfo(scope_stack, compl_info, tagmgr = None):
    '''
    解析补全请求
        递归解析补全请求的补全 scope
        返回用于获取 tags 的 search_scopes
        NOTE: 不支持嵌套定义的模版类, 也不打算支持, 因诸多原因.
        基本算法:
        1) 预处理第一个非容器成员(变量, 函数), 使第一个成员变为容器
        2) 处理 MemberStack 时, 第一个是变量或者函数或者经过类型替换后, 重头开始
        3) 解析变量和函数的时候, 需要搜索变量和函数的 path 中的每段 scope
        4) 每解析一次都要检查是否存在类型替换
        5) 重复 2), 3), 4)

    @return:    返回搜索作用域列表, 直接用于获取补全的tags'''
    if not scope_stack or not compl_info.IsValid():
        return []

    if not compl_info.scopes and compl_info._global:
        # 最简单的情况: ::|
        return ['<global>']

    scope_info = ResolveScopeStack(scope_stack)
    # 逆序, 这个作为返回值, 一直修改
    search_scopes = scope_info.function + scope_info.container + scope_info._global
    compl_scopes = compl_info.scopes

# ============================================================================
# 需要先处理掉第一个scope是变量和函数的情况, 往后就好处理了
# 都要展开名空间
# ============================================================================
    compl_scope = compl_scopes[0]
    if compl_scope.kind == compl_scope.KIND_CONTAINER:
        # 开始的时候的容器需要展开名空间信息
        temp_name = ExpandUsingAndNSAlias(compl_scope.text)
        if temp_name != compl_scope.text:
            # 展开了 using, 需要重建 typeinfo
            # eg.
            # using A::B;
            # B<C,D> b;
            #
            # Origin:   B<C,D>
            # Reuslt:   A::B<C,D>
            code = temp_name
            if compl_scope.tmpl:
                code += '< %s >' % ', '.join(compl_scope.tmpl)
            cxx_type = CxxParseType(code)
            # 更新
            compl_scope.type = cxx_type
    elif compl_scope.kind == compl_scope.KIND_VARIABLE and not compl_scope.cast:
        if compl_scope.text == 'this':
            # 'this' 变量是特殊的, 并且理论上只会出现在开始处
            if len(scope_stack) < 2 and scope_stack[-2].kind != 'container':
                # 上上个 scope 必须是容器, 否则就是语法错误
                return []
            search_name = scope_stack[-2].name
            # TODO: 常规的情况下, 直接搜索, 通用情况下, 需要考虑作用域关系
            search_scopes = scope_info._global # 暂时如此
            tag = GetFirstMatchTag(tagmgr, search_scopes, search_name)
            if not tag:
                return []
            #compl_scope.type = CxxParseType(tag['path'])
            # TODO: this 的搜索范围仅限于它的类以及所有基类
            #search_scopes = ExpandSearchScopesFromScope(tag['path'])
            #search_scopes = ExpandClassScopes(tag['path'])
            search_scopes = [tag['path']]
            # 这里自己处理掉这个 scope
            compl_scopes.pop(0)
        else:
            cxx_type = ResolveFirstVariable(tagmgr, scope_stack,
                                            search_scopes, compl_scope.text)
            tag = None
            if not cxx_type.IsValid():
                # 再尝试搜索 tag
                tag = GetFirstMatchTag(tagmgr, search_scopes, compl_scope.text)
                if not tag:
                    return []

            compl_scope.type = cxx_type
            if tag:
                search_scopes = ExpandSearchScopesFromScope(tag['scope'])

            if len(cxx_type.typelist) > 1:
                # 复合类型的变量, 需要解析, 因为这时的 cxx_type 可能无法搜索到 tag
                # TODO
                pass
    elif compl_scope.kind == compl_scope.KIND_FUNCTION and not compl_scope.cast:
        tag = GetFirstMatchTag(tagmgr, search_scopes, compl_scope.text)
        if not tag:
            return []
        cxx_type = CxxParseType(tag.get('text', ''))
        if not cxx_type.IsValid():
            return []
        # 更新
        compl_scope.type = cxx_type
        # 修正搜索范围
        search_scopes = ExpandSearchScopesFromScope(tag['path'])
    elif compl_scope.kind == compl_scope.KIND_UNKNOWN:
        # 暂时不支持 KIND_UNKNOWN 的解析
        return []
# ----------------------------------------------------------------------------

    # 每次解析变量的 TypeInfo 时, 应该添加此变量的作用域到此类型的搜索域
    # eg.
    # namespace A
    # {
    #     class B {
    #     };
    #
    #     class C {
    #         D d;
    #     };
    # }
    # d 变量的 CxxType {'text': 'B', 'tmpl': []}
    # 搜索变量 D 时需要添加 d 的 scope 的所有可能情况, A::C::d -> ['A::C', 'A']
    # 即一个符号的上下文作用域

    # 补全开始位置的搜索 scopes, 有时候需要使用
    origin_search_scopes = search_scopes[:]

    # 是否需要考虑 using 指令
    expand_using = True

    for idx, compl_scope in enumerate(compl_scopes):
        # 每轮需要搜索的名字
        search_name = compl_scope.text

        if compl_scope.kind == compl_scope.KIND_UNKNOWN:
            # 解析失败了
            search_scopes = []
            break
        elif compl_scope.kind == compl_scope.KIND_CONTAINER:
            pass
        elif compl_scope.kind == compl_scope.KIND_VARIABLE:
            name = compl_scope.text
            if compl_scope.type:
                name = compl_scope.type.fullname
            elif compl_scope.cast:
                name = compl_scope.cast.fullname
            tag = GetFirstMatchTag(tagmgr, search_scopes, name)
            if not tag:
                search_scopes = []
                break
            if compl_scope.cast:
                cxx_type = compl_scope.cast
            else:
                cxx_type = CxxParseType(tag.get('text', ''))
            if not cxx_type.IsValid():
                search_scopes = []
                break
            compl_scope.type = cxx_type
            search_scopes = ExpandSearchScopesFromScope(tag['path'])
            search_name = cxx_type.fullname
        elif compl_scope.kind == compl_scope.KIND_FUNCTION:
            tag = GetFirstMatchTag(tagmgr, search_scopes, compl_scope.text)
            if not tag:
                search_scopes = []
                break
            if compl_scope.cast:
                cxx_type = compl_scope.cast
            else:
                cxx_type = CxxParseType(tag.get('text', ''))
            if not cxx_type.IsValid():
                search_scopes = []
                break
            compl_scope.type = cxx_type
            search_scopes = ExpandSearchScopesFromScope(tag['scope'])
            search_name = cxx_type.fullname
        else:
            pass
        # endif

        search_scopes = FilterDuplicate(search_scopes)

        ### 之后就是根据上面解析出来的 CxxType 来更新搜索范围, 用于下一个的解析

        # 根据已经获取到的 search_scopes 搜索目标 tag
        tag = GetFirstMatchTag(tagmgr, search_scopes, search_name)
        if not tag:
            # 处理匿名容器, 因为匿名容器是不存在对应的 tag 的
            # 所以如果有需要的时候, 手动构造匿名容器的 tag, 然后继续
            # TODO: 貌似vlctags2没有这个问题了? 待确认
            search_scopes = []
            break

        # TODO: 处理 tag 的 typedef

        #compl_scope.tag = tag

        # 好了, 已经获取到 tag 了, 现在需要解析 tag 生成 CxxType(typeinfo)
        # TODO: 暂时这样处理, 往后再改
        #compl_scope.type = CxxParseType(tag['path'])

        search_scopes = [tag['path']]

    return search_scopes

def Error(msg):
    print msg

def unit_test_GetComplInfo():
    cases = [
        # test
        #"dynamic_cast<A<Z, Y, X> *>(B.b())->C.",

        # general
        "A::B C::D::",
        "A::B()->C().",
        "A::B().C->",
        "A->B().",
        "A->B.",
        "Z Y = ((A*)B)->C.",
        "(A*)B()->C.",
        "static_cast<A*>(B)->C.",
        "A(B.C()->",
        "(A**)::B.",
        "B<X,Y>(Z)->",
        "A<B>::C<D, E>::F.g.",
        "A(B.C()->",
        "A(::B.C()->",

        # global
        "::A->",
        "A(::B.",

        # precast
        "((A*)B.b)->C.",
        "((A*)B.b())->C.",
        "dynamic_cast<A<Z, Y, X> *>(B.b())->C.",

        # 数组
        "A[B][C[D]].",

        # 模板实例化
        "A<B, C>::",

        # 终结
        "if (a > ::A.",

        # this
        "if ( this->a.",

        # new
        "A::B *pa = new A::",

        # last
        "dynamic_cast<A<Z, Y, X> *>((O*)B.b())->C.",
    ]
    
    for origin in cases:
        tokens = CxxTokenize(origin)
        #print tokens
        print '=' * 40
        print origin
        #print tokens
        compl_info = GetComplInfo(tokens)
        print compl_info
        #print json.dumps(eval(repr(compl_info)), sort_keys=True, indent=4)

def GenPath(scope, name):
    if scope == '<global>':
        return name
    return '%s::%s' % (scope, name)

def TagIsCtor(tag):
    '''判断是否构造函数的tag'''
    if tag['parent'] == tag['name'] and tag['kind'] in ['f', 'p']:
        return True
    return False

def TagIsDtor(tag):
    '''判断是否析构函数的tag'''
    if '~'+tag['parent'] == tag['name'] and tag['kind'] in ['f', 'p']:
        return True
    return False

def GetFirstMatchTag(tagmgr, search_scopes, name, kinds = set()):
    '''
    @kinds: kind缩写的集合, 非空的时候, 只有tag的kind在此集合中才会不被忽略
    '''
    result = {}

    for scope in search_scopes:
        path = GenPath(scope, name)
        tags = tagmgr.GetTagsByPath(path)
        if not tags:
            continue

        if kinds:
            found = False
            for tag in tags:
                if tag.kind in kinds:
                    result = tag
                    found = True
                    break
            if found:
                break
        else:
            tag = tags[0]
            if TagIsCtor(tag) or TagIsDtor(tag):
                # 跳过构造和析构函数的 tag, 因为构造函数是不能继续补全的
                # eg. A::A, A::~A
                continue
            else:
                result = tag
                break

    return result

def main(argv):
    unit_test_GetComplInfo()

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret is None:
        ret = 0
    sys.exit(ret)
