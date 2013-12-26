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

import CppTokenizer
from VimTagsManager import VimTagsManager

# CPP_OP 作为 CPP_OPERATORPUNCTUATOR 的缩写
from CppTokenizer import CPP_EOF, CPP_KEYOWORD, CPP_WORD, C_COMMENT,        \
        C_UNFIN_COMMENT, CPP_COMMENT, CPP_STRING, CPP_CHAR, CPP_DIGIT,      \
        CPP_OPERATORPUNCTUATOR as CPP_OP

class ListReader(object):
    def __init__(self, tokens, null = None):
        # 原料, 反转顺序是为了性能?
        self.__list = tokens[::-1]
        # 已经被弹出去的 token，用于支持 Prev()
        self.__popeds = []
        # 无效标识
        self.null = None

    @property
    def current(self):
        return self.Cur()

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

class ComplScope(object):
    '''
    代码补全时每个scope的信息, 只有三种:
    * ->    成员变量, (成员)函数的返回值, 需要解析出具体的类型
    * .     成员变量, (成员)函数的返回值, 需要解析出具体的类型
    * ::    一个固定的类型, 无需解析类型, 可以称之为容器

    {
        'kind': <'container'|'variable'|'function'|'unknown'>
        'name': <name>    <- 必然是单元类型 eg. A<a,b,c>
        'tmpl' : <template initialization list>
        'tag' : {}        <- 在解析的时候添加
        'typeinfo': {}    <- 在解析的时候添加
        'cast': <强制类型转换>
    }
    '''
    KIND_CONTAINER  = 0
    KIND_VARIABLE   = 1
    KIND_FUNCTION   = 2
    KIND_UNKNOWN    = 3

    def __init__(self):
        self.name = ''
        self.kind = KIND_UNKNOWN
        self.tmpl = []
        self.typeinfo = None

class ComplInfo(object):
    def __init__(self):
        self.scopes = []
        # this | <global> | {precast type}
        #self.cast = ''

# 跳至指定的匹配，tokrdr 当前的 token 为 left 的下一个
def SkipToMatch(tokrdr, left, right, collector = None):
    nestlv = 1
    while tokrdr.current:
        tok = tokrdr.Get()

        if isinstance(collector, list):
            collector.append(tok)

        if tok.text == left:
            nestlv += 1
        elif tok.text == right:
            nestlv -= 1

        if nestlv == 0:
            break

class CxxUnitType(object):
    '''单元类型, 如:
    A a;
    A<B, <C<D> > a;

    像 A::B::C 就是由三个单元类型构成
    '''
    def __init__(self):
        # 文本
        self.text = ''
        # 模板
        self.tmpl = []

    def IsValid(self):
        return bool(self.text)

    def IsError(self):
        return not self.IsValid()

class CxxType(object):
    '''代表一个C++类型，保存足够的信息'''
    def __init__(self):
        # CxxUnitType 实例的列表
        self.typelist = []
        # 是否强制为全局作用域，如 ::A::B
        self._global = False

    def IsValid(self):
        return bool(self.typelist)

class TypeInfo(object):
    '''代表一个C++类型，保存足够的信息, vim omnicpp 兼容形式'''
    def __init__(self):
        self.name = ''
        self.tmpl = []
        self.typelist = []

def ParseTypeInfo(tokrdr):
    '''
    从一条语句中获取变量信息, 无法判断是否非法声明
    尽量使传进来的参数是单个语句而不是多个语句
    Return: 若解释失败，返回无有效内容的 TypeInfo
    eg1. const MyClass&
    eg2. const map < int, int >&
    eg3. MyNs::MyClass
    eg4. ::MyClass**
    eg5. MyClass a, *b = NULL, c[1] = {};
    eg6. A<B>::C::D<E<Z>, F>::G g;
    eg7. hello(MyClass1 a, MyClass2* b
    eg8. Label: A a;
    TODO: eg9. A (*a)[10];
    '''
    pass

def GetCompleteInfo(tokens):
    # 需要语法解析, 实在是太麻烦了
    '''
" 获取全能补全请求前的语句的 OmniScopeStack
" 以下情况一律先清理所有不必要的括号, 清理 [], 把 C++ 的 cast 转为 C 形式
" case01. A::B C::D::|
" case02. A::B()->C().|    orig: A::B::C(" a(\")z ", '(').|
" case03. A::B().C->|
" case04. A->B().|
" case05. A->B.|
" case06. Z Y = ((A*)B)->C.|
" case07. (A*)B()->C.|
" case08. static_cast<A*>(B)->C.|      -> 处理成标准 C 的形式 ((A*)B)->C.|
" case09. A(B.C()->|)
"
" case10. ::A->|
" case11. A(::B.|)
" case12. (A**)::B.|
"
" Return: OmniInfo
" OmniInfo
" {
" 'omniss': <OmniSS>
" 'precast': <this|<global>|precast>
" }
"
" 列表 OmniSS, 每个条目为 OmniScope
" 'tmpl' 一般在 'kind' 为 'container' 时才有效
" OmniScope
" {
" 'kind': <'container'|'variable'|'function'|'cast'|'unknown'>
" 'name': <name>    <- 必然是单元类型 eg. A<a,b,c>
" 'tmpl' : <template initialization list>
" 'tag' : {}        <- 在解析的时候添加
" 'typeinfo': {}    <- 在解析的时候添加
" }
"
" 如 case3, [{'kind': 'container', 'name': 'A'},
"            {'kind': 'function', 'name': 'B'},
"            {'kind': 'variable', 'name': 'C'}]
" 如 case6, [{'kind': 'variable', 'name': 'B'},
"            {'kind': 'variable', 'name': 'C'}]
"
" 判断 cast 的开始: 1. )单词, 2. )(
" 判断 precast: 从 )( 匹配的结束位置寻找匹配的 ), 如果匹配的 ')' 右边也为 ')'
" 判断 postcast: 从 )( 匹配的结束位置寻找匹配的 ), 如果匹配的 ')' 右边不为 ')'
" TODO: 
" 1. A<B>::C<D, E>::F g; g.|
" 2. A<B>::C<D, E>::F.g.| (g 为静态变量)
"
" 1 的方法, 需要记住整条路径每个作用域的 tmpl
" 2 的方法, OmniInfo 增加 tmpl 域
    '''
    rdr = ListReader(tokens[::-1])
    while rdr.current:
        print rdr.Get()

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
    while True:
        if not __first_enter:
            # 消耗一个token
            rdr.Get()
        __first_enter = False

        if not rdr.current:
            break

        tok = rdr.current
        if tok.kind == CPP_OP and CXX_MEMBER_OP_RE.match(tok.text):
        # 这是个成员操作符 '->', '.', '::'
            if state == STATE_INIT:
                # 初始状态遇到操作符, 补全开始, 光标前没有输入单词
                state = STATE_EXPECT_WORD
            elif state == STATE_EXPECT_OP:
                state = STATE_EXPECT_WORD
            elif state == STATE_EXPECT_WORD:
                # 语法错误
                print 'Syntax Error:', tok.text
                result = ComplInfo()
                break
            else:
                pass
            # endif

        elif tok.kind == CPP_WORD:
            if state == STATE_INIT:
                # 这是base, 这里不考虑base的问题, 继续
                pass
            elif state == STATE_EXPECT_OP:
                # 期望操作符, 遇到单词
                # 结束. eg A::B C::|
                #             ^
                break
            elif state == STATE_EXPECT_WORD:
                # 成功获取一个单词
                compl_scope = ComplScope()
                compl_scope.name = tok.text
                prev_tok = rdr.Prev()
                if prev_tok:
                    if prev_tok.text == '::':
                        compl_scope.kind = ComplScope.KIND_CONTAINER
                    elif prev_tok.text == '->' or prev_tok.text == '.':
                        compl_scope.kind = ComplScope.KIND_VARIABLE
                    else:
                        # unknown
                        pass
                result.scopes.insert(0, compl_scope)
                else:
                    # unknown
                    pass

                state = STATE_EXPECT_OP
            else:
                # 忽略
                pass


        elif tok.kind == CPP_KEYOWORD and tok.text == 'this':
            # TODO: 未想好如何处理
            if state == STATE_INIT:
                # 直接
                pass
            elif state == STATE_EXPECT_OP:
                pass
            elif state == STATE_EXPECT_WORD:
                pass
            else:
                pass
            # endif

            if state == STATE_INIT:
                pass
            elif state == STATE_EXPECT_OP:
                pass
            elif state == STATE_EXPECT_WORD:
                pass
            else:
                pass
            # endif

        elif tok.kind == CPP_OP and tok.text == ')':
            if state == STATE_INIT:
                pass
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
                #   func(0).|
                #         ^|
                # 
                rdr.Get()
                colltoks = []
                SkipToMatch(rdr, ')', '(', colltoks)
                tmprdr = ListReader(colltoks[::-1])
                if rdr.current and rdr.current.kind == CPP_WORD:
                    # 确定是函数
                    # TODO: Func<T>(0)
                    #             ^
                    compl_scope = ComplScope()
                    compl_scope.kind = ComplScope.KIND_FUNCTION
                    compl_scope.name = rdr.Next().text
                    result.scopes.insert(0, compl_scope)
                    state = STATE_EXPECT_OP
                elif tmprdr.current and tmprdr.current.text == '(':
                    # C 形式的 precast
                    compl_scope = ComplScope()
                    compl_scope.kind = ComplScope.KIND_VARIABLE
                    compl_scope.text = '<CODE>' # 无需名字
                    result.scopes.insert(0, compl_scope)

                    # 既然是 precast 那么这里可以直接获取结果并结束
                    tmprdr.Get()
                    colltoks = []
                    SkipToMatch(tmprdr, '(', ')', colltoks)
                    # 不要最后的 ')'
                    if colltoks:
                        colltoks.pop(-1)
                    # 这里就可以解析类型了
                    # TODO
            else:
                pass

        else:
            pass

        # endif

    # endwhile

        # TODO

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

def GetTagsMgr(dbfile):
    tagmgr = VimTagsManager()
    # 不一定打开成功
    if not tagmgr.OpenDatabase(dbfile):
        return None
    return tagmgr

def GetScopeStack(buff, row, col):
    '''
    @buff:  是字符串的列表
    @row:   行, 从1开始
    @col:   列, 从1开始
    '''
    contents = buff[: row-1]
    # NOTE: 按照vim的计算方式, 当前列不包括, 要取光标前的字符
    contents.append(buff[row-1][:col-1])
    return CppParser.CxxGetScopeStack(contents)

def Error(msg):
    print msg

def usage(cmd):
    print 'Usage:\n\t%s {dbfile} {file} {row} {col} {base}' % cmd

def ResolveScopeStack(scope_stack):
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

def ToVimComplItem(tag, filter_kinds = set()):
    if tag['kind'] in filter_kinds:
        return {}
        return tag

    if tag['kind'] == 'f' and tag.has_key('class') and not tag.has_key('access'):
        # 如国此 tag 为类的成员函数, 类型为函数, 且没有访问控制信息, 跳过
        # 防止没有访问控制信息的类成员函数条目覆盖带访问控制信息的成员函数原型的
        return {}
        return tag

    # 添加访问控制信息
    access_mapping = {'public': '+','protected': '#','private': '-'}

    menu = ''
    if tag.has_key('access'):
        menu += access_mapping.get(tag['access'], ' ')

    menu += ' ' + tag['parent']

    name = tag['name']
    word = name
    abbr = name
    kind = tag['kind']

    # 如果是函数的话, 添加括号 "()"
    if tag['kind'][0] in set(['f', 'p']):
        word += '()'
        abbr += '()'
    # 把函数形式的宏视为函数
    elif tag['kind'][0] == 'd':
        # TODO
        pass

    # 添加必要的属性
    result              = {}
    result['word']      = word
    #result['abbr']      = abbr
    result['menu']      = menu
    #result['info']      = ''
    result['kind']      = kind
    result['icase']     = 1
    result['dup']       = 0

    return result

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
        buff = f.read().splitlines()

    scope_stack = GetScopeStack(buff, row, col)
    obj = eval(repr(scope_stack))
    #print json.dumps(obj, sort_keys=True, indent=4)

    if not scope_stack:
        return 1

    tokens = CppTokenizer.CxxTokenize(scope_stack[-1].cusrstmt)
    print tokens

    print GetCompleteInfo(tokens)

    # "::", "->", "." 之后的补全(无论 base 是否为空字符)定义为成员补全
    member_complete = False

    # "::" 作用域补全, 用于与 "->" 和 "." 补全区分
    scope_complete = False

    real_base = ''

    member_complete_re = re.compile('^(\.|->|::)$')

    if tokens:
        if tokens[-1].kind == CPP_OP and member_complete_re.match(tokens[-1].text):
            member_complete = True
        elif tokens[-1].kind == CPP_KEYOWORD or tokens[-1].kind == CPP_WORD:
            real_base = tokens[-1]
            if len(tokens) >= 2 and member_complete_re.match(tokens[-2].text):
                member_complete = True
                if tokens[-2].text == '::':
                    scope_complete = True
                # endif
            # endif
        else:
            # TODO: 进入这个分支的话不能补全
            pass

    tagmgr = GetTagsMgr(dbfile)
    tags = []

    if member_complete:
        scope_info = ResolveScopeStack(scope_stack)
        scope_info.Print()
        search_scopes = scope_info.container + scope_info._global + scope_info.function
        # TODO 获取tags
        tags = tagmgr.GetOrderedTagsByScopesAndName(search_scopes, real_base)
    else:
        pass

    if tags:
        print 'fetch tags', len(tags)
        print json.dumps([ToVimComplItem(tag) for tag in tags[:10]],
                         sort_keys=True, indent=4)

    print CodeComplete(file, buff, row, col, base, icase, dbfile, opt)

def CodeComplete(file, buff, row, col, base, icase, dbfile, opt):
    '''返回补全结果, 返回结果应该为字典, 参考vim的complete-items的帮助信息'''
    result = []
    tagmgr = GetTagsMgr(dbfile)
    if not tagmgr:
        # NOTE: 打开数据库失败, 要返回一些错误信息给调用者
        Error('Failed to open tags database, abort')
        return []

    # Just for test
    assert tagmgr.GetTagsByPath('CxxTokenReader')

    # TODO: 材料准备完毕, 开始分析补全!

    return result

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret is None:
        ret = 0
    sys.exit(ret)
