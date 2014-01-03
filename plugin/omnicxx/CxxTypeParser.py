#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os
import os.path
import re
import json

########## 硬编码设置, 用于快速测试 ##########
path = [os.path.expanduser('~/.videm/core'),
        os.path.expanduser('~/.vim/bundle/videm/autoload/omnicpp'),
        os.path.expanduser('~/.vim/autoload/omnicpp')]
sys.path.extend(path)
##########

from CppTokenizer import CxxToken
from ListReader import ListReader
from CppTokenizer import CxxTokenize

class TokensReader(ListReader):
    def __init__(self, tokens, null = CxxToken()):
        ListReader.__init__(self, tokens, null)

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

    def IsInvalid(self):
        return not self.IsValid()

    def IsError(self):
        return not self.IsValid()

    def Invalidate(self):
        '''重置这个实例的值, 使其无效化'''
        self.text = ''
        self.tmpl = []

    def ToEvalStr(self):
        return '{"text": "%s", "tmpl": %s}' % (self.text, self.tmpl)

    def __repr__(self):
        return self.ToEvalStr()

class CxxType(object):
    '''代表一个C++类型，保存足够的信息'''
    def __init__(self):
        # CxxUnitType 实例的列表
        self.typelist = []
        # 是否强制为全局作用域，如 ::A::B
        self._global = False

    @property
    def fullname(self):
        '''返回全名, 用于搜索 tags
        A<X, Y>::B::C -> A::B::C
        '''
        names = [i.text for i in self.typelist]
        if self._global:
            return '::' + '::'.join(names)
        else:
            return '::'.join(names)

    def IsValid(self):
        return bool(self.typelist)

    def IsInvalid(self):
        return not self.IsValid()

    def ToEvalStr(self):
        return '{"global": %s, "typelist": %s}' % (self._global, self.typelist)

    def __repr__(self):
        return self.ToEvalStr()

    def Invalidate(self):
        self.typelist = []
        self._global = False

def SkipToToken(tokrdr, text, collector = None):
    '''跳到指定的token, 成功时, tokrdr.curr 即为指定的 token'''
    while tokrdr.curr.IsValid():
        tok = tokrdr.curr

        if isinstance(collector, list):
            collector.append(tok)

        if tok.text == text:
            break

        tokrdr.Pop()

# 语法错误的话, 不吃任何token, 并由调用者检查并进一步处理
def CxxParseUnitType_Char(tokrdr):
    '''返回字符串'''
    result = ''
    curr_tok = tokrdr.Get()
    next_tok = tokrdr.curr

    if curr_tok.text == 'signed':
        if next_tok.text == 'char':
            result = 'signed char'
            tokrdr.Pop()
        else:
            # 语法错误, 回滚
            tokrdr.Put(curr_tok)
    elif curr_tok.text == 'unsigned':
        if next_tok.text == 'char':
            result = 'unsigned char'
            tokrdr.Pop()
        else:
            # 语法错误, 回滚
            tokrdr.Put(curr_tok)
    elif curr_tok.text == 'char':
        result = 'char'
    elif curr_tok.text == 'wchar_t':
        result = 'wchar_t'
    elif curr_tok.text == 'char16_t':
        result = 'char16_t'
    elif curr_tok.text == 'char32_t':
        result = 'char32_t'
    else:
        # 解析不出来的话, 也不要吃掉这个token
        tokrdr.Put(curr_tok)

    return result

def CxxParseUnitType_Float(tokrdr):
    '''
    float
    double
    long double
    '''
    result = ''

    if tokrdr.curr.text == 'float':
        result = 'float'
        tokrdr.Pop()
    elif tokrdr.curr.text == 'double':
        result = 'double'
        tokrdr.Pop()
    elif tokrdr.curr.text == 'long':
        tok = tokrdr.Pop()
        if tokrdr.curr.text == 'double':
            result = 'long double'
            tokrdr.Pop()
        else:
            # 语法错误, 回滚
            tokrdr.Put(tok)
    else:
        pass

    return result

# 解析 unsigned | signed 之后的 int 声明
def _ParseInt(tokrdr):
    result = 'int'

    if tokrdr.curr.text == 'short':    # short
        tokrdr.Pop()
        if tokrdr.curr.text == 'int':
            tokrdr.Pop()
        result = 'short int'
    elif tokrdr.curr.text == 'long':   # long | long long
        tokrdr.Pop()
        result = 'long'
        if tokrdr.curr.text == 'long':
            result += ' long'
            tokrdr.Pop()
        if tokrdr.curr.text == 'int':
            tokrdr.Pop()
        result += ' int'
    elif tokrdr.curr.text == 'int':
        tokrdr.Pop()
        result = 'int'
    else:
        result = 'int'

    return result

def CxxParseUnitType_Int(tokrdr):
    '''
    左侧为标准类型
    signed short int        (short | short int | signed short | signed short int)
    unsigned short int      (unsigned short | unsigned short int)
    signed int              (int | signed | signed int)
    unsigned int            (unsigned | unsigned int)
    signed long int         (long | long int | signed long | signed long int)
    unsigned long int       (unsigned long | unsigned long int)
    signed long long int    (long long | long long int | signed long long | signed long long int)
    unsigned long long int  (unsigned long long | unsigned long long int)
    '''
    result = ''

    if tokrdr.curr.text == 'signed' or tokrdr.curr.text == 'unsigned':
        result = tokrdr.curr.text + ' '
        tokrdr.Pop()
        result += _ParseInt(tokrdr)
    elif tokrdr.curr.text == 'int':
        result = 'signed int'
        tokrdr.Pop()
    elif tokrdr.curr.text == 'short':
        tokrdr.Pop()
        if tokrdr.curr.text == 'signed':
            # short signed [int]
            result = 'signed short int'
            tokrdr.Pop()
        elif tokrdr.curr.text == 'unsigned':
            # short unsigned [int]
            result = 'unsigned short int'
            tokrdr.Pop()
        else:
            # 省略写法
            result = 'signed short int'

        if tokrdr.curr.text == 'int':
            tokrdr.Pop()
    elif tokrdr.curr.text == 'long':
        result += 'long'
        tokrdr.Pop()

        if tokrdr.curr.text == 'long':
            # long long [[signed|unsigned] int]
            result += ' long'
            tokrdr.Pop()

        if tokrdr.curr.text == 'signed':
            result = 'signed ' + result
            tokrdr.Pop()
        elif tokrdr.curr.text == 'unsigned':
            result = 'unsigned ' + result
            tokrdr.Pop()
        else:
            result = 'signed ' + result

        if tokrdr.curr.text == 'int':
            tokrdr.Pop()

        result += ' int'
    else:
        # 解析失败, 什么都不做
        pass

    return result

# 解析成功的话, tokrdr.curr 指向下一个需要解析的 token
def CxxParseUnitType(tokrdr):
    '''
    获取单元类型
    Character
     signed char
     unsigned char
     char
     wchar_t
     char16_t(C++11)
     char32_t(C++11)
    
    Integer
     short int (short | short int | signed short | signed short int)
     unsigned short int (unsigned short | unsigned short int)
     int (int | signed | signed int)
     unsigned int (unsigned | unsigned int)
     long int (long | long int | signed long | signed long int)
     unsigned long int (unsigned long | unsigned long int)
     long long int (long long | long long int | signed long long | signed long long int)
     unsigned long long int (unsigned long long | unsigned long long int)
    
    Floating
     float
     double
     long double
    
    Bool
     bool
    
    Special
     void
    '''
    unit_type = CxxUnitType()

    if tokrdr.curr.IsKeyword():
        if tokrdr.curr.text == 'unsigned' or tokrdr.curr.text == 'signed':
            if tokrdr.next.text == 'char':
                unit_type.text = CxxParseUnitType_Char(tokrdr)
            else:
                # 返回空字符串的话就是语法错误
                unit_type.text = CxxParseUnitType_Int(tokrdr)

        elif tokrdr.curr.text == 'long':
            if tokrdr.next.text == 'double':
                unit_type.text = CxxParseUnitType_Float(tokrdr)
            else:
                unit_type.text = CxxParseUnitType_Int(tokrdr)

        elif tokrdr.curr.text == 'int' or tokrdr.curr.text == 'short':
            unit_type.text = CxxParseUnitType_Int(tokrdr)

        elif tokrdr.curr.text == 'char' or tokrdr.curr.text == 'wchar_t' or \
                tokrdr.curr.text == 'char16_t' or tokrdr.curr.text == 'char32_t':
            unit_type.text = CxxParseUnitType_Char(tokrdr)

        elif tokrdr.curr.text == 'float' or tokrdr.curr.text == 'double':
            unit_type.text = CxxParseUnitType_Float(tokrdr)

        elif tokrdr.curr.text == 'bool':
            unit_type.text = 'bool'
            # 吃掉这个token
            tokrdr.Pop()

        elif tokrdr.curr.text == 'void':
            unit_type.text = 'void'
            # 吃掉这个token
            tokrdr.Pop()

        else:
            # TODO: 又是关键词又不是基础类型？语法错误只要返回错误并且不操作即可
            #SkipToToken(tokrdr, ';')
            pass

    elif tokrdr.curr.IsWord():
        # A<X<Y>, Z> a;
        unit_type.text = tokrdr.curr.text
        # 令 curr 指向下一个 token
        tokrdr.Pop()
        if tokrdr.curr.text == '<':
            # 收集模板
            tokrdr.Pop()
            nestlv = 1
            text = ''
            __first_enter = True
            while tokrdr.curr.IsValid():
                if not __first_enter:
                    tokrdr.Pop()
                __first_enter = False

                if tokrdr.curr.text == '<':
                    nestlv += 1
                elif tokrdr.curr.text == '>':
                    nestlv -= 1
                    if nestlv == 0:
                        unit_type.tmpl.append(text)
                        # 完毕
                        tokrdr.Pop()
                        break
                elif tokrdr.curr.text == ',':
                    if nestlv == 1:
                        unit_type.tmpl.append(text)
                        text = ''
                        continue

                # 收集字符
                if nestlv >= 1:
                    if text:
                        text += ' ' + tokrdr.curr.text
                    else:
                        text += tokrdr.curr.text
            # endwhile

            if nestlv != 0:
                # FIXME: 这里语法错误并且把所有字符吃掉了, 理论上需要恢复,
                #        这里直接返回错误算了
                unit_type.Invalidate()
        else:
            # 其他字符就不解析了
            pass

    else:
        # TODO: 这个暂时不知道是什么状况, 不处理
        pass

    # endif

    return unit_type

def CxxParseTemplateList(tokrdr):
    '''解析模板列表, 解析时需要包括两端的尖括号
        <A, B<C>, D>
    '''
    result = []
    if tokrdr.curr.text != '<':
        return []

    tokrdr.Pop()

    nestlv = 1
    text = ''
    __first_enter = True
    while tokrdr.curr.IsValid():
        if not __first_enter:
            tokrdr.Pop()
        __first_enter = False

        if tokrdr.curr.text == '<':
            nestlv += 1
        elif tokrdr.curr.text == '>':
            nestlv -= 1
            if nestlv == 0:
                result.append(text)
                # 完毕
                tokrdr.Pop()
                break
        elif tokrdr.curr.text == ',':
            if nestlv == 1:
                result.append(text)
                text = ''
                continue

        # 收集字符
        if nestlv >= 1:
            if text:
                text += ' ' + tokrdr.curr.text
            else:
                text += tokrdr.curr.text
    # endwhile

    if nestlv != 0:
        # FIXME: 这里语法错误并且把所有字符吃掉了, 理论上需要恢复,
        #        这里直接返回错误算了
        return []

    return result

def CxxParseType(arg):
    if isinstance(arg, TokensReader):
        tokrdr = arg
    elif isinstance(arg, str):
        tokrdr = TokensReader(CxxTokenize(arg))
    elif isinstance(arg, list):
        tokrdr = TokensReader(arg)
    else:
        raise StandardError('Invalid argument')
        

    cxx_type = CxxType()

# ============================================================================
# 这段例程是跳过 ['::'] [nested_name_specifier] type_name 前的所有东东
# ============================================================================
    '''
    // 跳过以下产生式
    /* 
       friend
       typedef
       constexpr

       const
       volatile

       storage_class_specifier:
        auto            Removed in C++0x
        register
        static
        thread_local    C++0x
        extern
        mutable

       function_specifier:
        inline
        virtual
        explicit
    */
    '''
    words = ['friend', 'typedef', 'constexpr', 'const', 'volatile',
             'auto', 'register', 'static', 'thread_local', 'extern', 'mutable',
             'inline', 'virtual', 'explicit']
    words_re = re.compile('(^%s$)' % '$)|(^'.join(words))

    # 跳过上面那些关键词
    while True:
        if words_re.match(tokrdr.curr.text):
            tokrdr.Pop()
        break

    '''
    type_specifier: 
                    trailing_type_specifier
                    class_specifier
                    enum_specifier
    '''
    # enum_specifier
    if tokrdr.curr.text == 'enum':
        tokrdr.Pop()
        if tokrdr.curr.text == 'class' or tokrdr.curr.text == 'struct':
            tokrdr.Pop()
    # class_specifier
    elif tokrdr.curr.text == 'class' or tokrdr.curr.text == 'struct' or \
            tokrdr.curr.text == 'union':
        tokrdr.Pop()
    # trailing_type_specifier
    else:
        '''
        trailing_type_specifier:
         simple_type_specifier
         elaborated_type_specifier
         typename_specifier
         cv_qualifier
        '''
        # cv_qualifier
        if tokrdr.curr.text == 'const' or tokrdr.curr.text == 'volatile':
            tokrdr.Pop()
        # typename_specifier
        elif tokrdr.curr.text == 'typename':
            tokrdr.Pop()
        # elaborated_type_specifier
        elif tokrdr.curr.text == 'class' or tokrdr.curr.text == 'struct' or \
                tokrdr.curr.text == 'union' or tokrdr.curr.text == 'enum':
            tokrdr.Pop()
        else:
            # simple_type_specifier
            pass

# ============================================================================
    if tokrdr.curr.text == '::':
        cxx_type._global = True
        tokrdr.Pop()

    while tokrdr.curr.IsValid():
        unit_type = CxxParseUnitType(tokrdr)
        if unit_type.IsInvalid():
            cxx_type.Invalidate()
            break

        cxx_type.typelist.append(unit_type)
        # 不是 "::" 的话，直接结束
        if tokrdr.curr.text != '::':
            break
        # 扔掉 '::'
        tokrdr.Pop()

    return cxx_type

def unit_test_int():
    cases = [
        ["short",               "signed short int"],
        ["short int",           "signed short int"],
        ["signed short",        "signed short int"],
        ["signed short int",    "signed short int"],
        ["short signed",        "signed short int"],
        ["short signed int",    "signed short int"],

        ["unsigned short",      "unsigned short int"],
        ["unsigned short int",  "unsigned short int"],
        ["short unsigned",      "unsigned short int"],
        ["short unsigned int",  "unsigned short int"],

        ["int",         "signed int"],
        ["signed",      "signed int"],
        ["signed int",  "signed int"],

        ["unsigned",        "unsigned int"],
        ["unsigned int",    "unsigned int"],

        ["long",            "signed long int"],
        ["long int",        "signed long int"],
        ["signed long",     "signed long int"],
        ["signed long int", "signed long int"],
        ["long signed",     "signed long int"],
        ["long signed int", "signed long int"],

        ["unsigned long",       "unsigned long int"],
        ["unsigned long int",   "unsigned long int"],
        ["long unsigned",       "unsigned long int"],
        ["long unsigned int",   "unsigned long int"],

        ["long long",               "signed long long int"],
        ["long long int",           "signed long long int"],
        ["signed long long",        "signed long long int"],
        ["signed long long int",    "signed long long int"],
        ["long long signed",        "signed long long int"],
        ["long long signed int",    "signed long long int"],

        ["unsigned long long",      "unsigned long long int"],
        ["unsigned long long int",  "unsigned long long int"],
        ["long long unsigned",      "unsigned long long int"],
        ["long long unsigned int",  "unsigned long long int"],
    ]

    for origin, result in cases:
        tokrdr = TokensReader(CxxTokenize(origin))
        try:
            tmp = CxxParseUnitType_Int(tokrdr)
            assert tmp == result
        except AssertionError:
            print origin, '->', tmp, '!=', result

        try:
            assert tokrdr.IsNull()
        except AssertionError:
            print 'tokrdr is not null:', origin

        tokrdr = TokensReader(CxxTokenize(origin))
        unit_type = CxxParseUnitType(tokrdr)
        assert unit_type.text == result
        assert not unit_type.tmpl

def unit_test_char():
    cases = [
        "signed char",
        "unsigned char",
        "char",
        "wchar_t",
        "char16_t",
        "char32_t",
    ]

    for origin in cases:
        result = origin
        tokrdr = TokensReader(CxxTokenize(origin))
        tmp = CxxParseUnitType_Char(tokrdr)
        assert tmp == result
        assert tokrdr.IsNull()

        tokrdr = TokensReader(CxxTokenize(origin))
        unit_type = CxxParseUnitType(tokrdr)
        assert unit_type.text == result
        assert not unit_type.tmpl

def unit_test_float():
    cases = [
        "float",
        "double",
        "long double",
    ]

    for origin in cases:
        result = origin
        tokrdr = TokensReader(CxxTokenize(origin))
        tmp = CxxParseUnitType_Float(tokrdr)
        assert tmp == result
        try:
            assert tokrdr.IsNull()
        except AssertionError:
            print 'AssertionError:', origin

        tokrdr = TokensReader(CxxTokenize(origin))
        unit_type = CxxParseUnitType(tokrdr)
        assert unit_type.text == result
        assert not unit_type.tmpl

def unit_test_unittype():
    cases = [
        # origin, result, tokrdr.curr.text
        ['A<X<Y>, Z> a;', ['A', ['X < Y >', 'Z']], 'a'],
        ['A< X <Y<x, y> >, Z >', ['A', ['X < Y < x , y > >', 'Z']], ''],
    ]

    for origin, result, end in cases:
        tokrdr = TokensReader(CxxTokenize(origin))
        unit_type = CxxParseUnitType(tokrdr)
        #print unit_type
        try:
            assert unit_type.text == result[0]
            assert unit_type.tmpl == result[1]
            assert tokrdr.curr.text == end
        except:
            print 'origin:', origin
            print 'unit_type:', unit_type
            print 'tokrdr.curr:', tokrdr.curr
            raise

def unit_test_type():
    cases = [
        'const MyClass&',
        'const map < int, int >&',
        'MyNs::MyClass',
        '::MyClass**',
        'MyClass a, *b = NULL, c[1] = {};',
        'A<B>::C::D<E<Z>, F>::G g;',
        #'hello(MyClass1 a, MyClass2* b',
        #'Label: A a;',
    ]

    # cases 对应的结果
    results = [
        # global, typelist = [[text, tmpl], ...], end
        [False, [{'text': 'MyClass'}], '&'],
        [False, [{'text': 'map', 'tmpl': ['int', 'int']}], '&'],
        [False, [{'text': 'MyNs'}, {'text': 'MyClass'}], ''],
        [True,  [{'text': 'MyClass'}], '*'],
        [False, [{'text': 'MyClass'}], 'a'],
        [False, [{'text': 'A', 'tmpl': ['B']},
                 {'text': 'C'},
                 {'text': 'D', 'tmpl': ['E < Z >', 'F']},
                 {'text': 'G'}],
         'g'],
        #[False, [{}], ''],
        #[False, [{}], ''],
        #[False, [{}], ''],
    ]


    for idx, origin in enumerate(cases):
        result = results[idx]
        tokrdr = TokensReader(CxxTokenize(origin))
        cxx_type = CxxParseType(tokrdr)
        #print '=' * 40
        #print origin
        #print json.dumps(eval(repr(cxx_type)), sort_keys=True, indent=4)
        #print tokrdr.curr
        try:
            assert cxx_type._global == result[0]
            for i, t in enumerate(cxx_type.typelist):
                assert t.text == result[1][i].get('text')
                assert t.tmpl == result[1][i].get('tmpl', [])
            assert tokrdr.curr.text == result[2]
        except:
            print 'origin:', origin
            print 'cxx_type:', cxx_type
            print 'tokrdr.curr:', tokrdr.curr
            raise

def main(argv):
    unit_test_int()
    unit_test_char()
    unit_test_float()
    unit_test_unittype()
    unit_test_type()

    cxx_type = CxxParseType('A<X, Y>::B::C')
    assert cxx_type.fullname == 'A::B::C'

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret:
        sys.exit(ret)
