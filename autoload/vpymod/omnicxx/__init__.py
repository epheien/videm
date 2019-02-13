#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os
import os.path
import json
import re

import CxxParser

from TagsStorage.TagsManager import TagsManager

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
from CxxSemanticParser import GetComplInfo
from CxxSemanticParser import ResolveScopeStack
from CxxSemanticParser import ResolveComplInfo

from CxxKeyword import GetCxxKeywords

_DEBUG = False

def GetTagsMgr(dbfile):
    tagmgr = TagsManager()
    # 不一定打开成功
    if tagmgr.OpenDatabase(dbfile) != 0:
        return None
    return tagmgr

def GetScopeStack(buff, row, col):
    '''
    @buff:  是字符串的列表
    @row:   行, 从1开始
    @col:   列, 从1开始
    '''
    if isinstance(buff, str):
        # 强制转为字符串列表
        buff = buff.splitlines()
    contents = buff[: row-1]
    # NOTE: 按照vim的计算方式, 当前列不包括, 要取光标前的字符
    contents.append(buff[row-1][:col-1])
    return CxxParser.CxxGetScopeStack(contents)

def usage(cmd):
    print 'Usage:\n\t%s {dbfile} {file} {row} {col}' % cmd

def WordToVimComplItem(word, menu, kind, icase, extra_fields = {}):
    result = {}

    # 可以额外添加一些属性
    if extra_fields:
        result.update(extra_fields)

    # 添加必要的属性
    result['word']      = word
    #result['abbr']      = abbr
    result['menu']      = menu
    #result['info']      = ''
    result['kind']      = kind
    result['icase']     = int(bool(icase))
    result['dup']       = 0
    return result

def ToVimComplItem(tag, filter_kinds = set(), verbose = False):
    if tag['kind'] in filter_kinds:
        return {}
        return tag

    if tag['kind'] == 'f' and tag.has_key('class') and not tag.has_key('access'):
        # 如果此 tag 为类的成员函数, 类型为函数, 且没有访问控制信息, 跳过
        # 防止没有访问控制信息的类成员函数条目覆盖带访问控制信息的成员函数原型的
        return {}
        return tag

    # 添加访问控制信息
    access_mapping = {'public': '+','protected': '#','private': '-'}

    menu = ''
    menu += access_mapping.get(tag.get('access', ''), ' ')

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
    elif tag['kind'][0] == 'd' and tag.has_key('signature'):
        word += '()'
        abbr += '()'

    # 用于支持 calltips
    info = ''
    if tag.has_key('signature'):
        if tag.IsMacro():
            info = '%s%s' % (tag['path'], tag['signature'])
        else:
            info = '%s %s%s' % (tag.get('extra', ''), tag['path'], tag['signature'])

    # 添加必要的属性
    result              = {}
    result['word']      = word
    #result['abbr']      = abbr
    result['menu']      = menu
    # completeopt-=preview 无效, 没办法, 用 'extra' 代替
    #result['info']      = info
    result['kind']      = kind
    result['icase']     = 1
    result['dup']       = 0
    result['extra']      = info

    if verbose:
        result['fileid'] = tag['fileid']
        result['line'] = tag['line']
        result['path'] = tag['path']
        if tag.has_key('signature'):
            result['signature'] = tag['signature']

    return result

def main(argv):
    '''
    arg1: dbfile
    arg2: file
    arg3: row
    arg4: col
    '''
    if len(argv) < 5:
        usage(argv[0])
        return 1

    import pprint
    pp = pprint.PrettyPrinter(indent=4)

    icase = True
    opt = None

    dbfile = argv[1]
    file = argv[2]
    row = int(argv[3])
    col = int(argv[4])
    with open(file) as f:
        buff = f.read().splitlines()

    if _DEBUG:
        scope_stack = GetScopeStack(buff, row, col)
        obj = eval(repr(scope_stack))
        print '========== Scope Stack =========='
        print json.dumps(obj, sort_keys=True, indent=4)

        if not scope_stack:
            return 1

        tokens = CxxTokenize(scope_stack[-1].cusrstmt)
        print '========== Cursor Statement Tokens =========='
        print tokens

        print '========== Cursor Statement Complete Info =========='
        print GetComplInfo(tokens)

    retmsg = {}
    result = CodeComplete(file, buff, row, col, dbfile, retmsg=retmsg)
    print '========== Code Complete Result =========='
    pp.pprint(result)
    print '========== Code Complete Returned Messages =========='
    pp.pprint(retmsg)

def CodeComplete(file, buff, row, col, tagsdb = TagsManager(':memory:'),
                 **kwargs):
    '''返回补全结果, 返回结果应该为字典, 参考vim的complete-items的帮助信息
    @file:      当前补全的文件名, 暂时未用
    @buff:      缓冲区内容, 最好是字符串列表
    @row:       行
    @col:       列
    @tagsdb:    数据库文件或数据库实例
    @base:      base, 如果为 None, 则表示根据行和列来自动决定
    @icase:     ignore case
    @scase:     smart case
    @verbose:   会添加附加的信息到补全条目的字典中
    @opt:       选项, 暂未用到
    @retmsg:    反馈信息, 字典 {'error': <error message>, 'info': <information>}

    @pre_scopes:    强制首先搜索的 scopes, 仅在非成员补全时使用, 
                    用于支持额外的名空间信息的

    @return:    参考vim的complete-items的帮助信息
    '''
    base = kwargs.get('base', None)
    icase = kwargs.get('icase', True)
    scase = kwargs.get('scase', False)
    verbose = kwargs.get('verbose', False)
    opt = kwargs.get('opt', None)
    retmsg = kwargs.get('retmsg', {})
    pre_scopes = kwargs.get('pre_scopes', [])

    if isinstance(tagsdb, TagsManager):
        tagmgr = tagsdb
    else:
        tagmgr = GetTagsMgr(tagsdb)
    if not tagmgr:
        # 打开数据库失败, 返回一些错误信息给调用者
        retmsg['error'] = 'Failed to open tags database, abort'
        return []

# ============================================================================
# 补全预分析
# ============================================================================
    scope_stack = GetScopeStack(buff, row, col)
    #obj = eval(repr(scope_stack))
    #print json.dumps(obj, sort_keys=True, indent=4)

    if not scope_stack:
        return []

    tokens = CxxTokenize(scope_stack[-1].cusrstmt)
    #print tokens

    this_base = ''
    if tokens and (tokens[-1].IsKeyword() or tokens[-1].IsWord()):
        # 补全之前的 token 为单词的话, 作为 base 并弹出
        this_base = tokens.pop(-1).text

    # 需要的话, 重置 base
    if base is None:
        base = this_base

    # "::", "->", "." 之后的补全(无论 base 是否为空字符)定义为成员补全
    member_complete = False

    # "::" 作用域补全, 用于与 "->" 和 "." 补全区分
    scope_complete = False

    member_complete_re = re.compile('^(\.|->|::)$')

    if tokens:
        if tokens[-1].IsOP() and member_complete_re.match(tokens[-1].text):
            member_complete = True
            if tokens[-1].text == '::':
                scope_complete = True
        elif base:
            # 如果最后的 token 不是有效的补全开始 token, 那么这时有 base 的话
            # 还是可以继续的, 否则就是无效的补全请求了
            pass
        else:
            # 上面的分支做了简单的语法检查, 进入这个分支的话就不能补全了
            retmsg['info'] = 'Invalid code complete request'
            return []

# ============================================================================
# 补全分析开始
# ============================================================================
    tags = []

    if not member_complete:
    # 非成员请求, 直接在本作用域内搜索即可
        scope_info = ResolveScopeStack(scope_stack)
        #scope_info.Print()
        search_scopes = scope_info.container + scope_info._global + scope_info.function
        # 添加 pre_scopes 到最前面
        search_scopes[:0] = pre_scopes
        # 获取tags
        tags = tagmgr.GetOrderedTagsByScopesAndName(search_scopes, base)
    else:
    # 成员补全, 相当复杂
        compl_info = GetComplInfo(tokens)
        if not compl_info.scopes and compl_info._global and not base:
            # 禁用全局全符号补全, 因为太多了
            retmsg['info'] = 'complete global symbols with empty base is not allowed'
            return []
        search_scopes = ResolveComplInfo(scope_stack, compl_info, tagmgr)
        tags = tagmgr.GetOrderedTagsByScopesAndName(search_scopes, base)

    if member_complete and not tags:
        retmsg['info'] = 'tags not found'
        return []
# ============================================================================
# 这之后的是转换结果
# ============================================================================
    result = []
    base_re = None
    if base:
        if scase and re.search('[A-Z]', base):
            icase = 0
        try:
            # 模式全部转为16进制, 那就不需要任何转义了
            patstr = ''.join(["\\x%2x" % ord(c) for c in base])
            if icase:
                base_re = re.compile(patstr, re.I)
            else:
                base_re = re.compile(patstr)
        except:
            retmsg['error'] = 're complete error: %s' % base
            return []

    if not member_complete:
        # 先添加关键词
        cxxkw = GetCxxKeywords()
        if base:
            result += [WordToVimComplItem(var, '', 'k', icase) for var in cxxkw
                       if base_re.match(var)]
        else:
            result += [WordToVimComplItem(var, '', 'k', icase) for var in cxxkw]

        # 再添加局部变量
        visible_vars = {}
        # NOTE: 现在的变量解析不够准确, 只需要添加最里层的变量就够用了
        if scope_stack[-1].kind != 'file':
            visible_vars.update(scope_stack[-1].vars)
            for name, info in visible_vars.iteritems():
                if base and not base_re.match(name):
                    continue
                di = {}
                if verbose:
                    # 附加信息
                    di['fileid'] = 0            # 0 代表在本文件中
                    di['line'] = info['line']
                result.append(WordToVimComplItem(name, '', 'v', icase, di))

    filter_kinds = set()
    if member_complete and not scope_complete:
        filter_kinds.add('t')
        filter_kinds.add('s')
        filter_kinds.add('c')

    # 再添加 tags
    if base:
        for tag in tags:
            if not base_re.match(tag['name']):
                continue
            item = ToVimComplItem(tag, filter_kinds, verbose)
            if not item:
                continue
            result.append(item)
    else:
        for tag in tags:
            item = ToVimComplItem(tag, filter_kinds, verbose)
            if not item:
                continue
            result.append(item)

    if tags:
        #print 'fetch tags', len(tags)
        #print json.dumps(result, sort_keys=True, indent=4)
        pass

    return result

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret is None:
        ret = 0
    sys.exit(ret)
