" OmniCxx plugin for Videm
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-12-22
" Change:   2014-01-26

" !0 - 从 s:cache_ccresult 直接提取 calltips, 无须重新请求一次代码补全
let s:calltips_from_cache = 0

" 返回 0 表示不触发补全
function! omnicxx#complete#ManualPopupCheck(char) "{{{2
    " NOTE: char 为即将输入的字符
    if col('.') < 2
        return 0
    endif

    let prev_char = getline('.')[col('.')-2 : col('.')-2]
    if a:char ==# ':' && prev_char !=# ':'
        return 0
    elseif a:char ==# '>' && prev_char !=# '-'
        return 0
    endif
    return 1
endfunction
"}}}
function! s:StartQucikCalltips() "{{{2
    let sLine = getline('.')
    let nCol = col('.')
    if sLine[nCol-3:] =~# '^()'
        normal! h
    endif
    let s:calltips_from_cache = 1
    call vlcalltips#Start()
    return ''
endfunction
"}}}
function! s:InitKeymap() "{{{2
    call vlcalltips#InitBuffKeymap()
    if videm#settings#Get('.videm.cc.omnicxx.ReturnToCalltips')
        inoremap <silent> <expr> <buffer> <CR> pumvisible() ? 
                \"\<C-y>\<C-r>=<SID>StartQucikCalltips()\<Cr>" : 
                \"\<CR>"
    endif
endfunction
"}}}
function! s:GetCalltips(items, funcname) "{{{2
    let items = a:items
    let funcname = a:funcname

    " NOTE: 使用了 item['extra'] 域, 这个是不标准的用法, 理论上用 'info'
    "       比较好, 但是貌似 vim 有 BUG, 用 'info' 会强制打开预览窗口, 很烦
    let lCalltips = []
    for item in items
        if item.word ==# funcname.'()'
            " 如果声明和定义分开, 只取声明的 tag
            " ctags 中, 解析类方法定义的时候是没有访问控制信息的
            " 1. 原型
            " 2. C 中的函数(kind == 'f', !has_key(tag, 'class'))
            " 3. C++ 中的内联成员函数
            if item.kind ==# 'p' || item.kind ==# 'f'
                    "\ || (item.kind ==# 'f' && item.menu =~# '^[-#+]')
                if has_key(item, 'extra')
                    call add(lCalltips, item.extra)
                endif
            elseif item.kind ==# 'd'
                " 处理函数形式的宏
                if has_key(item, 'extra') && !empty(item.extra)
                    call add(lCalltips, item.extra)
                endif
            endif
        endif
    endfor

    return lCalltips
endfunction
"}}}
" TODO 支持 calltips
function! omnicxx#complete#RequestCalltips(data) "{{{2
    let use_cache = s:calltips_from_cache
    let s:calltips_from_cache = 0

    " <<< 普通情况，请求 calltips >>>
    " 确定函数括号开始的位置
    let lOrigCursor = getpos('.')
    let lStartPos = searchpairpos('(', '', ')', 'nWb', 
            \'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"')
    " 考虑刚好在括号内，加 'c' 参数
    let lEndPos = searchpairpos('(', '', ')', 'nWc', 
            \'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"')
    let lCurPos = lOrigCursor[1:2]

    " 不在括号内
    if lStartPos ==# [0, 0]
        return []
    endif

    " 获取函数名称和名称开始的列，只能处理 '(' "与函数名称同行的情况，
    " 允许之间有空格
    let sStartLine = getline(lStartPos[0])
    let sFuncName = matchstr(sStartLine[: lStartPos[1]-1], '\~\?\w\+\ze\s*($')
    let nFuncStartIdx = match(sStartLine[: lStartPos[1]-1], '\~\?\w\+\ze\s*($')

    if empty(sFuncName)
        return []
    endif

    " 补全时，行号要加上前置字符串所占的行数，否则位置就会错误
    let nRow = lStartPos[0]
    let nCol = nFuncStartIdx + 1

    let lCalltips = []

    if use_cache
        " 直接使用最近的结果
        let compl_result = asynccompl#GetLatestResult()
    else
        " 找到了函数名，开始全能补全
        let sFileName = expand("%:p")
        " TODO sFileName, nRow, nCol, sFuncName
        let compl_result = []
    endif

    " TODO 根据 sFuncName 和 compl_result 提取 calltips
    let lCalltips = s:GetCalltips(compl_result, sFuncName)

    " just for test
    "call add(lCalltips, 'int printf(const char *fmt, ...)')
    "call add(lCalltips, 'int printf(const char *fmt, int a, int b)')

    call setpos('.', lOrigCursor)
    call vlcalltips#KeepCursor()
    return lCalltips
endfunction
"}}}
" NOTE: 只能操作当前缓冲区, 因为 imap 无法操作其他缓冲区
function! omnicxx#complete#BuffInit() "{{{2
    call s:InitPyIf()
    let config = {}
    let config.manu_popup_pattern = '\.\|>\|:'
    let config.auto_popup_pattern = '[A-Za-z_0-9]'
    let config.auto_popup_base_pattern = '[A-Za-z_]\w*$'
    let config.ignorecase = videm#settings#Get('.videm.cc.omnicxx.IgnoreCase')
    let config.smartcase = videm#settings#Get('.videm.cc.omnicxx.SmartCase')
    let config.item_select_mode =
            \ videm#settings#Get('.videm.cc.omnicxx.ItemSelectMode')
    let config.auto_popup_char_count =
            \ videm#settings#Get('.videm.cc.omnicxx.AutoTriggerCharCount')
    let config.omnifunc = 1
    let config.SearchStartColumnHook = 'CxxSearchStartColumn'
    let config.ManualPopupCheck = 'omnicxx#complete#ManualPopupCheck'
    call asynccompl#Register(config)
    py CommonCompleteHookRegister(OmniCxxCompleteHook, None)
    py CommonCompleteArgsHookRegister(OmniCxxArgsHook, None)
    if asynccompl#BuffInit() != 0
        return -1
    endif

    " 一些键位绑定
    call s:InitKeymap()
    " 初始化函数参数提示服务
    call vlcalltips#Register('omnicxx#complete#RequestCalltips', 0)
endfunction
"}}}
function! omnicxx#complete#BuffExit() "{{{2
    call vlcalltips#Unregister('omnicxx#complete#RequestCalltips')
endfunction
"}}}
let s:initpy = 0
function! s:InitPyIf() "{{{2
    if s:initpy
        return
    endif
    let s:initpy = 1
python << PYTHON_EOF
import sys
import vim
import os
import os.path
import re
from omnicxx import CodeComplete as OmniCxxCodeComplete

def OmniCxxArgsHook(kwargs):
    dbfile = vim.eval('videm#plugin#omnicxx#GetWspDbfile()')
    # 暂时没有这么高端要支持好几个未保存的文件, 只支持当前文件未保存即可
    args = {
        'file'  : vim.eval('expand("%:p")'),
        # 可以是列表或者字符串, 看需求
        'buff'  : vim.current.buffer[:kwargs['row']],
        'row'   : kwargs['row'],
        'col'   : kwargs['col'],
        'base'  : kwargs['base'],
        'icase' : kwargs['icase'],
        'scase' : kwargs['scase'],
        # 数据库文件名
        'dbfile': dbfile,
        'opts'  : '',
    }
    return args

def OmniCxxCompleteHook(acthread, args):
    '''这个函数在后台线程运行, 只能根据传入参数来进行操作'''
    file = args.get('file')
    buff = args.get('buff') # 只保证到row行, row行后的内容可能不存在
    row = args.get('row')
    col = args.get('col')
    base = args.get('base')
    icase = args.get('icase')
    scase = args.get('scase')
    dbfile = args.get('dbfile') # 数据库文件, 跨线程需要新建数据库连接实例
    opts = args.get('opts')

    result = None

    acthread.CommonLock()
    # just for test
    result = ['abc', 'xyz', 'ABC', 'XYZ']
    retmsg = {}
    # 这里开始根据参数来获取补全结果
    result = OmniCxxCodeComplete(file, buff, row, col, dbfile, base=base,
                                 icase=icase, scase=scase, retmsg=retmsg)
    acthread.CommonUnlock()

    return result

PYTHON_EOF
endfunction
"}}}

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
