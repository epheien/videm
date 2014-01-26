#!/usr/bin/env python
# -*- encoding:utf-8 -*-

import re
import json
from Misc import Obj2Dict, Dict2Obj

CKinds = {
    'c': "class",     
    'd': "macro",     
    'e': "enumerator",
    'f': "function",  
    'g': "enum",      
    'l': "local",     
    'm': "member",    
    'n': "namespace", 
    'p': "prototype", 
    's': "struct",    
    't': "typedef",   
    'u': "union",     
    'v': "variable",  
    'x': "externvar", 
}

RevCKinds = {
    "class"     : 'c',
    "macro"     : 'd',
    "enumerator": 'e',
    "function"  : 'f',
    "enum"      : 'g',
    "local"     : 'l',
    "member"    : 'm',
    "namespace" : 'n',
    "prototype" : 'p',
    "struct"    : 's',
    "typedef"   : 't',
    "union"     : 'u',
    "variable"  : 'v',
    "externvar" : 'x',
}

def ToFullKind(kind):
    if len(kind) > 1:
        return kind
    return CKinds.get(kind, '')
def ToFullKinds(kinds):
    return [ToFullKind(kind) for kind in kinds]

def ToAbbrKind(kind):
    if len(kind) == 1:
        return kind
    return RevCKinds.get(kind, '')
def ToAbbrKinds(kinds):
    return [ToAbbrKind(kind) for kind in kinds]

ACCESS_MAPPING = {
    'public'    : '+',
    'protected' : '#',
    'private'   : '-',
}

ACCESS_RMAPPING = {
    '+': 'public',
    '#': 'protected',
    '-': 'private',
}

def ToAbbrAccess(access):
    if len(access) == 1:
        return access
    return ACCESS_MAPPING.get(access, '')
def ToFullAccess(access):
    if len(access) > 1:
        return access
    return ACCESS_RMAPPING.get(access, '')
    

reMacroSig = r'^\s*#\s*define\s*[a-zA-Z_]\w*(\(.*?\))' # 包括括号
patMacroSig = re.compile(reMacroSig)
def GetMacroSignature(srcLine):
    global patMacroSig
    m = patMacroSig.match(srcLine)
    if m:
        return m.group(1)
    else:
        return ''

def GenPath(scope, name):
    if scope == '<global>':
        return name
    return '%s::%s' % (scope, name)

def SplitPath(path):
    '''把 path 分割成 scope 和 name'''
    if not path:
        return ['', '']
    scope, sep, name = path.rpartition('::')
    if not scope:
        scope = '<global>'
    return [scope, name]

class TagEntry():
    def __init__(self):
        '''
        与数据库保持一致

        file    未定

        text    不再需要
        pattern 不再需要
        parent  不再需要保存, 直接从 scope 提取
        path    不再需要保存, 直接根据 scope 和 name 合并生成即可

        kind    保存缩写
        '''
        self.id = -1                # unused

        self.name = ''              # Tag name (short name, excluding any scope 
                                    # names)
        self.file = ''              # File this tag is found
        self.fileid = 0             # 对应 FILES 表的 id
        self.line = -1              # Line number
        #self.text = ''              # code text

        #self.pattern = ''           # A pattern that can be used to locate the 
                                    # tag in the file

        self.kind = '?'     # Member, function, class, typedef etc.
        #self.parent = ''            # Direct parent
        #self.path = ''              # Tag full path
        self.scope = ''             # Scope

        # 对于 typedef, 存储原型
        # 对于 struct 和 class, 存储模板和特化信息
        # 对于 function, 存储声明和模板
        # 对于 variable, 存储声明
        # 上述存储模板信息的时候, 如果存在模板特化, 则要把文本存储到符号">"为止
        self.extra = ''

        self.exts = {}              # Additional extension fields

    def __getitem__(self, key):
        if hasattr(self, key):
            return getattr(self, key)
        return self.exts.get(key)

    def __setitem__(self, key, val):
        if hasattr(self, key):
            setattr(self, key, val)
        else:
            self.exts[key] = val

    def get(self, key, default = None):
        if hasattr(self, key):
            return getattr(self, key, default)
        return self.exts.get(key, default)

    def has_key(self, key):
        if hasattr(self, key):
            return True
        return self.exts.has_key(key)

    def ToDict(self):
        return Obj2Dict(self)

    def ToJson(self):
        return json.dumps(self.ToDict(), sort_keys=True, indent=4)

    def FromDict(self, d):
        Dict2Obj(self, d)

    def Create(self, name, fname, line, text, kind, exts, pattern = ''):
        '''
        @kind:  全称
        '''
        self.SetId(-1)
        self.SetName(name)
        self.SetFile(fname)
        self.SetLine(line)
        if kind:
            self.SetKind(kind)
        self.exts = exts

        extra = ''

        if kind == 'typedef':
            # TODO: typedef 多个的时候会有些问题
            if exts.has_key('typeref'):
                kind, sep, ident = exts['typeref'].partition(':')
                extra = '%s %s' % (kind, ident)
            else:
                extra = re.sub(r'typedef\s+|\s+[a-zA-Z_]\w*\s*;\s*$', '', text)
        elif kind == 'struct' or kind == 'class':
            # 先清掉继承语句, 因为这些语句可能有尖括号
            temp = re.sub(r':.+$', '', text)
            m = re.search(r'\btemplate\s*<.*>', temp)
            if m:
                extra = m.group()
        elif kind == 'function' or kind == 'prototype':
            '''
            A<B>::C & func(void) {}
            template<> A<B>::C *** func (void) {}
            template<class T> A<B>::C *** func <X, Y> (void) {}
            '''
            m = re.search(r'([^(]+)\(', text)
            if m:
                extra = re.sub(r'\s*[a-zA-Z_]\w*$', '', m.group(1).strip())
        elif kind == 'variable' or kind == 'externvar' or kind == 'member':
            # TODO: 数组形式未能解决, 很复杂, 暂时无法完善处理, 全部存起来
            if exts.has_key('typeref'):
                # 从这个域解析
                # typeref:struct:ss    } ***p, *x;
                kind, sep, ident = exts['typeref'].partition(':')
                extra = '%s %s %s' % (kind, ident, re.sub(r'^\s*}\s*', '', text))
            else:
                extra = text
        else:
            pass

        self.extra = extra

        # Check if we can get full name (including path)
        # 添加 parent_kind 属性, 以保证不丢失信息
        scope = ''
        if self.GetExtField('class'):
            self.SetParentKind('class')
            scope = self.GetExtField('class')
        elif self.GetExtField('struct'):
            self.SetParentKind('struct')
            scope = self.GetExtField('struct')
        elif self.GetExtField('namespace'):
            self.SetParentKind('namespace')
            scope = self.GetExtField('namespace')
        elif self.GetExtField('union'):
            self.SetParentKind('union')
            scope = self.GetExtField('union')
        elif self.GetExtField('enum'):
            self.SetParentKind('enum')
            # enumerator 的 scope 和 path 要退一级
            scope = '::'.join(self.GetExtField('enum').split('::')[:-1])
        else:
            pass

        if not scope:
            scope = '<global>'
        self.SetScope(scope)

        if kind == 'macro':
            sig = GetMacroSignature(pattern[2:-2])
            if sig:
                self.SetSignature(sig)

    def FromLine(self, strLine):
        strLine = strLine
        line = -1
        text = ''
        exts = {}

        # get the token name
        partStrList = strLine.partition('\t')
        name = partStrList[0]
        strLine = partStrList[2]

        # get the file name
        partStrList = strLine.partition('\t')
        fileName = partStrList[0]
        strLine = partStrList[2]

        # here we can get two options:
        # pattern followed by ;"
        # or
        # line number followed by ;"
        partStrList = strLine.partition(';"\t')
        if not partStrList[1]:
            # invalid pattern found
            return

        if strLine.startswith('/^'):
            # regular expression pattern found
            pattern = partStrList[0]
            strLine = '\t' + partStrList[2]
        else:
            # line number pattern found, this is usually the case when
            # dealing with macros in C++
            pattern = partStrList[0].strip()
            strLine = '\t' + partStrList[2]
            line = int(pattern)

        # next is the kind of the token
        if strLine.startswith('\t'):
            strLine = strLine.lstrip('\t')

        partStrList = strLine.partition('\t')
        kind = partStrList[0]
        strLine = partStrList[2]

        if strLine:
            for i in strLine.split('\t'):
                key = i.partition(':')[0].strip()
                val = i.partition(':')[2].strip()

                if key == 'line' and val:
                    line = int(val)
                elif key == 'text': # 不把 text 放到扩展域里面
                    text = val
                else:
                    exts[key] = val

        # 真的需要?
        #kind = kind.strip()
        #name = name.strip()
        #fileName = fileName.strip()
        #pattern = pattern.strip()

        if kind == 'enumerator':
            # enums are specials, they are not really a scope so they should 
            # appear when I type: enumName::
            # they should be member of their parent 
            # (which can be <global>, or class)
            # but we want to know the "enum" type they belong to, 
            # so save that in typeref,
            # then patch the enum field to lift the enumerator into the 
            # enclosing scope.
            # watch out for anonymous enums -- leave their typeref field blank.
            if exts.has_key('enum'):
                typeref = exts['enum']
                # comment on 2012-05-17
                #exts['enum'] = \
                        #exts['enum'].rpartition(':')[0].rpartition(':')[0]
                if not typeref.rpartition(':')[2].startswith('__anon'):
                    # watch out for anonymous enums
                    # just leave their typeref field blank.
                    exts['typeref'] = 'enum:%s' % typeref

        self.Create(name, fileName, line, text, kind, exts, pattern)

    def IsValid(self):
        return self.kind != '?'

    @property
    def parent(self):
        return self.scope.split('::')[-1]

    @property
    def path(self):
        return GenPath(self.scope, self.name)

    def GetExtra(self):
        return self.extra

    def IsContainer(self):
        return self.GetAbbrKind() in set(['c', 's', 'u', 'n'])

    def IsCtor(self):
        '''构造函数'''
        return self.GetAbbrKind() in set(['f', 'p']) and self.parent == self.name

    def IsConstructor(self):
        '''构造函数'''
        return self.IsCtor()

    def IsDtor(self):
        '''析构函数'''
        return self.GetAbbrKind() in set(['f', 'p']) and self.name.startswith('~')

    def IsDestructor(self):
        '''析构函数'''
        return self.IsDtor()

    def IsMethod(self):
        '''Return true of the this tag is a function or prototype'''
        return self.IsPrototype() or self.IsFunction()

    def IsFunction(self):
        return self.GetKind() == 'function'

    def IsPrototype(self):
        return self.GetKind() == 'prototype'

    def IsMacro(self):
        return self.GetKind() == 'macro'

    def IsClass(self):
        return self.GetKind() == 'class'

    def IsStruct(self):
        return self.GetKind() == 'struct'

    def IsScopeGlobal(self):
        return not self.GetScope() or self.GetScope() == '<global>'

    def IsTypedef(self):
        return self.GetKind() == 'typedef'


    #------------------------------------------
    # Operations
    #------------------------------------------
    def GetId(self):
        return self.id
    def SetId(self, id):
        self.id = id

    def GetName(self):
        return self.name
    def SetName(self, name):
        self.name = name

    def GetPath(self):
        return GenPath(self.scope, self.name)

    def GetFile(self):
        return self.file
    def SetFile(self, file):
        self.file = file

    def GetLine(self):
        return self.line
    def SetLine(self, line):
        self.line = line

    def SetKind(self, kind):
        self.kind = ToAbbrKind(kind)
    def GetKind(self):
        return self.GetFullKind()
    def GetAbbrKind(self):
        return self.kind
    def GetFullKind(self):
        return ToFullKind(self.kind)

    def GetParentKind(self):
        return ToFullKind(self.GetExtField('parent_kind'))
    def GetAbbrParentKind(self):
        return ToAbbrKind(self.GetExtField('parent_kind'))
    def SetParentKind(self, parent_kind):
        self.exts['parent_kind'] = ToAbbrKind(parent_kind)

    def GetAbbrAccess(self):
        return ToAbbrAccess(self.GetExtField("access"))
    def GetAccess(self):
        return self.GetExtField("access")
    def SetAccess(self, access):
        self.exts["access"] = access

    def GetSignature(self):
        return self.GetExtField("signature")
    def SetSignature(self, sig):
        self.exts["signature"] = sig

    def SetInherits(self, inherits):
        self.exts["inherits"] = inherits
    def GetInherits(self):
        return self.GetInheritsAsString()

    def GetTyperef(self):
        return self.GetExtField("typeref")
    def SetTyperef(self, typeref):
        self.exts["typeref"] = typeref

    def GetInheritsAsString(self):
        return self.GetExtField('inherits')

    def GetInheritsAsArrayNoTemplates(self):
        '''返回清除了模版信息的继承字段的列表'''
        inherits = self.GetInheritsAsString()
        parent = ''
        parentsArr = []

        # 清楚所有尖括号内的字符串
        depth = 0
        for ch in inherits:
            if ch == '<':
                if depth == 0 and parent:
                    parentsArr.append(parent.strip())
                    parent = ''
                depth += 1
            elif ch == '>':
                depth -= 1
            elif ch == ',':
                if depth == 0 and parent:
                    parentsArr.append(parent.strip())
                    parent = ''
            else:
                if depth == 0:
                    parent += ch

        if parent:
            parentsArr.append(parent.strip())

        return parentsArr

    def GetInheritsAsArrayWithTemplates(self):
        inherits = self.GetInheritsAsString()
        parent = ''
        parentsArr = []

        depth = 0
        for ch in inherits:
            if ch == '<':
                depth += 1
                parent += ch
            elif ch == '>':
                depth -= 1
                parent += ch
            elif ch == ',':
                if depth == 0 and parent:
                    parentsArr.append(parent.strip())
                    parent = ''
                elif depth != 0:
                    parent += ch
            else:
                parent += ch

        if parent:
            parentsArr.append(parent.strip())

        return parentsArr

    def GetReturn(self):
        return self.GetExtField('return')
    def SetReturn(self, retVal):
        self.exts["return"] = retVal

    def GetScope(self):
        return self.scope
    def SetScope(self, scope):
        self.scope = scope

    def Key(self):
        '''Generate a Key for this tag based on its attributes

        Return tag key'''
        # 键值为 [原型/宏:]path:signature
        key = ''
        if self.GetKind() == 'prototype' or self.GetKind() == 'macro':
            key += self.GetKind() + ': '

        key += self.GetPath() + self.GetSignature()
        return key

    def TypeFromTyperef(self):
        '''Return the actual type as described in the 'typeref' field

        return real name or wxEmptyString'''
        typeref = self.GetTyperef()
        if typeref:
            name = typeref.partition(':')[0]
            return name
        else:
            return ''

    # ------------------------------------------
    #  Extenstion fields
    # ------------------------------------------
    def GetExtField(self, extField, default = ''):
        return self.exts.get(extField, default)

    # ------------------------------------------
    #  Misc
    # ------------------------------------------
    def Print(self):
        '''顺序基本与数据库的一致'''
        print '=' * 40
        print 'Name:\t\t' + self.GetName()
        print 'File:\t\t' + self.GetFile()
        print 'Line:\t\t' + str(self.GetLine())
        print 'Kind:\t\t' + self.GetKind()
        print 'Scope:\t\t' + self.GetScope()
        print 'Path:\t\t' + self.GetPath()
        print 'Extra:\t\t' + self.GetExtra()
        print '---- Ext Fields ----'
        for k, v in self.exts.iteritems():
            if k == 'parent_kind':
                v = ToFullKind(v)
            print k + ':\t\t' + v
        print '-' * 40

    def UpdatePath(self, scope):
        '''Update the path with full path (e.g. namespace::class)'''
        pass

if __name__ == '__main__':
    import sys
    import os.path
    for fname in sys.argv[1:]:
        if not os.path.exists(fname):
            print '%s not found' % fname
            continue
        with open(fname) as f:
            for line in f:
                if line.startswith('!'):
                    continue
                print line,
                entry = TagEntry()
                entry.FromLine(line)
                entry.Print()
    if sys.argv[1:]:
        sys.exit(0)

    assert GetMacroSignature('#define MIN(x, y) x < y ? x : y') == '(x, y)'
    entry = TagEntry()
    lines = [
        'ab\tmain.c\t/^  ab,$/;"\tenumerator\tline:12\tenum:abc\ttext:ab',
        'xy\tmain.c\t/^  int xy;$/;"\tmember\tline:16\tstruct:xyz\taccess:public\ttext:int xy;',
        'ldiv_t\t/usr/include/stdlib.h\t110;"\ttypedef\tline:110\ttyperef:struct:__anon3_stdlib_h\ttext:} ldiv_t;',
        'i\ttmp.txt\t22;"\tmember\tline:22\tstruct:ss\taccess:public\ttext:int i;',
    ]
    for line in lines:
        entry.FromLine(line)
        entry.Print()

    tag = TagEntry()
    assert tag['kind'] == '?'
    tag['abc'] = 'xyz'
    tag['kind'] = 'xxx'
    assert tag['abc'] == 'xyz'
    assert tag.kind == 'xxx'
    assert tag['kind'] == 'xxx'
    assert tag.get('kind') == 'xxx'
    assert tag.get('abc') == 'xyz'
    assert tag.exts['abc'] == 'xyz'
    assert tag.get('xyz') is None
    assert tag.get('xyz', 'abc') == 'abc'
