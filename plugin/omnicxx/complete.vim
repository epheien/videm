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

    exec 'nnoremap <silent> <buffer> '.videm#settings#Get('.videm.cc.omnicxx.GotoDeclKey')
            \ .' :call omnicxx#complete#GotoDeclaration()<CR>'

    exec 'nnoremap <silent> <buffer> '.videm#settings#Get('.videm.cc.omnicxx.GotoImplKey')
            \ .' :call omnicxx#complete#GotoImplementation()<CR>'
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
function! omnicxx#complete#RequestCalltips(data) "{{{2
    let use_cache = s:calltips_from_cache
    let s:calltips_from_cache = 0

    " <<< 普通情况，请求 calltips >>>
    " 确定函数括号开始的位置
    let lOrigCursor = getpos('.')
    let lStartPos = searchpairpos('(', '', ')', 'nWb',
            \ 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"')
    " 考虑刚好在括号内，加 'c' 参数
    let lEndPos = searchpairpos('(', '', ')', 'nWc',
            \ 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"')
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
        call vlcalltips#UnkeepCursor()
    else
        " 找到了函数名，开始全能补全
        let compl_result = omnicxx#complete#CodeComplete(nRow, nCol, sFuncName)
        call vlcalltips#KeepCursor()
    endif

    " 根据 sFuncName 和 compl_result 提取 calltips
    let lCalltips = s:GetCalltips(compl_result, sFuncName)

    " just for test
    "call add(lCalltips, 'int printf(const char *fmt, ...)')
    "call add(lCalltips, 'int printf(const char *fmt, int a, int b)')

    call setpos('.', lOrigCursor)
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
function! omnicxx#complete#CodeComplete(row, col, base, ...) "{{{2
    let row = a:row
    let col = a:col
    let base = a:base
    let verbose = get(a:000, 0, 0)
    let icase = videm#settings#Get('.videm.cc.omnicxx.IgnoreCase')
    let scase = videm#settings#Get('.videm.cc.omnicxx.SmartCase')
    let dbfile = videm#plugin#omnicxx#GetWspDbfile()
    py vim.command("let result = %s" % ToVimEval(
            \       OmniCxxCodeCompleteX(buff=vim.current.buffer[:int(vim.eval("row"))],
            \                            row=int(vim.eval("row")),
            \                            col=int(vim.eval("col")),
            \                            icase=int(vim.eval("col")),
            \                            scase=int(vim.eval("col")),
            \                            verbose=int(vim.eval("verbose")),
            \                            base=vim.eval("base"),
            \                            dbfile=vim.eval("dbfile"))))
    return result
endfunction
"}}}
function! s:GetGotoItems() "{{{2
    let sWord = expand('<cword>')
    let lOrigPos = getpos('.')
    let sLine = getline('.')
    let save_ic = &ignorecase
    set noignorecase

    if col('.') == 1 || (col('.') > 1 && sLine[col('.')-2] =~# '\W')
        if sLine[col('.')-1] ==# '~'
        " 为了支持光标放到 '~' 位置的析构函数. eg. class A { |~A(); }
            " 右移一格
            call cursor(line('.'), col('.') + 1)
        endif

        " 光标在第一列或者光标前面是空格或者 '~'
        " 右移一格
        call cursor(line('.'), col('.') + 1)
    endif
    let lTags = omnicxx#complete#CodeComplete(line('.'), col('.'), sWord, 1)
    " 进一步过滤, 因为 base 匹配不是完整匹配
    call filter(lTags, 'substitute(v:val["word"], "()", "", "") ==# sWord')

    if empty(lTags)
        call setpos('.', lOrigPos)
        let &ignorecase = save_ic
        return []
    endif

    call setpos('.', lOrigPos)
    let &ignorecase = save_ic

    return lTags
endfunction
"}}}
function! s:ExpandItemsFileid(items) "{{{2
    let items = a:items
    let fidmap = {}
    call filter(items, 'has_key(v:val, "fileid")')
    for item in items
        if item['fileid'] == 0
            " 0 代表本文件
            let item['file'] = expand('%:p')
            let fidmap[0] = item['file']
            continue
        endif

        if has_key(fidmap, item['fileid'])
            let item['file'] = fidmap[item['fileid']]
            continue
        endif

        py vim.command("let fname = %s" % ToVimEval(
                \ videm_cc_omnicxx.tagmgr.GetFileByFileid(
                \       vim.eval('item["fileid"]'))))

        if empty(fname)
            " 这一定是一个bug
            echo 'BUG: Can not resolve fileid'
            echo item
            call getchar()
            continue
        endif

        let item['file'] = fname
        let fidmap[item['fileid']] = fname
    endfor
    return items
endfunction
"}}}2
" 生成带编号菜单选择列表
" NOTE: 第一项(即li[0])不会添加编号
function! s:GenerateMenuList(li) "{{{2
    let li = a:li
    let nLen = len(li)
    let lResult = []

    if nLen > 0
        call add(lResult, li[0])
        let l = len(string(nLen -1))
        let n = 1
        for str in li[1:]
            call add(lResult, printf('%*d. %s', l, n, str))
            let n += 1
        endfor
    endif

    return lResult
endfunction
"}}}
function! s:GotoItemPosition(items) "{{{2
    let items = a:items
    if empty(items)
        return []
    endif

    let result = s:ExpandItemsFileid(items)
    if empty(result)
        return []
    endif

    " 先检查是否 static 的符号，如果是的话直接跳转就好了
    if len(items) > 1
        let fname = resolve(expand('%:p'))
        for item in items
            if vlutils#IsWindowsOS()
                if resolve(item.file) ==? fname
                    let result = [item]
                    break
                endif
            else
                if resolve(item.file) ==# fname
                    let result = [item]
                    break
                endif
            endif
        endfor
    endif

    if len(result) > 1
        " 弹出选择菜单
        let li = []
        for d in result
            call add(li, printf("%s, %s:%s",
                    \           d.path . get(d, 'signature', ''),
                    \           d.file,
                    \           d.line))
        endfor
        let idx = inputlist(s:GenerateMenuList(['Please select:'] + li)) - 1
        if idx >= 0 && idx < len(result)
            let item = result[idx]
        else
            " 错误, 返回调试信息
            return result
        endif
    else
        let item = result[0]
    endif

    let sSymbol = substitute(item.word, '()$', '', '')
    let sFileName = item.file
    let sLineNr = item.line

    " 开始跳转
    if bufnr(sFileName) == bufnr('%')
        " 跳转的是同一个缓冲区, 仅跳至指定的行号
        normal! m'
        exec sLineNr
    else
        let sCmd = printf('e +%s %s', sLineNr, fnameescape(sFileName))
        exec sCmd
    endif

    let sSearchFlag = 'cW'
    let sSymbol = '\<'.sSymbol.'\>'
    call search('\C\V'.sSymbol, sSearchFlag, line('.'))
endfunction
"}}}
" TODO
function! omnicxx#complete#GotoDeclaration() "{{{2
    echo 'Sorry, this is not implemented.'
endfunction
"}}}
function! omnicxx#complete#GotoImplementation() "{{{2
    let items = s:GetGotoItems()
    if empty(items)
        return []
    endif

    if items[0].kind[0] ==# 'p' || items[0].kind[0] ==# 'f'
    " 请求跳转到函数的实现处
        " 剔除 items 里面类型为 'p' 的项目
        call filter(items, 'v:val["kind"][0] !=# "p"')
    else
    " 请求跳转到数据结构的实现处
        " 剔除纯声明式的数据结构。eg. struct a;
        call filter(items, 'v:val["kind"][0] !=# "x"')
    endif

    call s:GotoItemPosition(items)
    return items
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

def OmniCxxCodeCompleteX(**kwargs):
    '''简单的封装以易于使用'''
    return OmniCxxCompleteHook(AsyncComplThread(None, {}), kwargs)

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
    verbose = args.get('verbose')
    dbfile = args.get('dbfile') # 数据库文件, 跨线程需要新建数据库连接实例
    opts = args.get('opts')

    result = None

    acthread.CommonLock()
    # just for test
    #result = ['abc', 'xyz', 'ABC', 'XYZ']
    retmsg = {}
    # 这里开始根据参数来获取补全结果
    result = OmniCxxCodeComplete(file, buff, row, col, dbfile, base=base,
                                 icase=icase, scase=scase, verbose=verbose,
                                 retmsg=retmsg)
    acthread.CommonUnlock()

    return result

PYTHON_EOF
endfunction
"}}}

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
