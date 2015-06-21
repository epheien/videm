" Async Complete plugin for vim 7.3.196 or later
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-12-13
" Change:   2015-06-21

" 这个插件暂时只支持 ASCII 码的补全, 其他的都不支持

if get(s:, 'loaded', 0)
    finish
endif
let s:loaded = 1

if !has('python')
    echohl ErrorMsg
    echomsg 'asynccompl need Vim compiled with +python feature'
    echohl None
    finish
endif
if !exists('##InsertCharPre')
    echohl ErrorMsg
    echomsg 'Vim does not support InsertCharPre autocmd,'
    echomsg 'so asynccompl plugin will not work'
    echomsg 'Please update your Vim to version 7.3.196 or later'
    echohl None
    finish
endif

" 版本号 1001 -> 1.001
let s:version = "0.100"

" 全局使用 - 正向选择全部
" 仅某些类型使用
"       - 正向选择(优先)
"       - 反向选择
let g:asynccompl_autostart_filetype =
        \ get(g:, 'asynccompl_autostart_filetype', ['all'])
let g:asynccompl_autostop_filetype =
        \ get(g:, 'asynccompl_autostop_filetype', [])

let s:sfile = expand('<sfile>')
function! s:InitKeywordsComplete() "{{{2
    " 防止重复初始化
    if exists('#AsyncCompl#InsertCharPre#<buffer>')
        return
    endif

    if index(g:asynccompl_autostart_filetype, 'all') >= 0 || empty(&ft)
        " nothing to be done
    elseif index(g:asynccompl_autostart_filetype, &ft) >= 0
        " nothing to be done
    elseif index(g:asynccompl_autostop_filetype, &ft) >= 0
        return
    else
        return
    endif

    call s:InitPyIf()
    let config = {}
    let config.auto_popup_pattern = '\k'
    let config.auto_popup_base_pattern = '\k\+$'
    "let config.auto_popup_char_count = 2
    "let config.item_select_mode = 2
    "let config.SearchStartColumnHook = 'CommonSearchStartColumn'
    "let config.LaunchComplThreadHook = 'CommonLaunchComplThread'
    "let config.FetchComplResultHook = 'CommonFetchComplResult'
    call asynccompl#Register(config)
    " NOTE: 暂时只能做到这种程度了, 因为python无法模拟vim的'\<'正则,
    "       用'\b'会有副作用, 正确的搜索模式应该是 '\<\k\k\+'
    py __kw_pat = ''.join(iskconv.Conv2PattList(vim.eval('&iskeyword'), ascii_only=1)[0])
    py __kw_pat = '(?<![%s])[%s]{2,}' % (__kw_pat, __kw_pat)
    "py print __kw_pat
    py CommonCompleteHookRegister(CurrFileKeywordsComplete,
            \                     re.compile(__kw_pat))
    py CommonCompleteArgsHookRegister(CurrFileKeywordsCompleteArgs, None)
    py del __kw_pat
    call asynccompl#BuffInit()

    command! -nargs=0 AsyncComplBuffInit call asynccompl#BuffInit()
    command! -nargs=0 AsyncComplBuffExit call asynccompl#BuffExit()
endfunction
"}}}

let s:init_pyif = 0
function! s:InitPyIf() "{{{2
    if s:init_pyif
        return
    endif
    let s:init_pyif = 1

    call vpymod#driver#Init()
python << PYTHON_EOF
import re
import vim
import sys
import os.path

import iskconv

def CurrFileKeywordsComplete(acthread, args):
    '''补全当前文件的关键词, 类似于 <C-x><C-n>'''
    text = args.get('text', '')
    base = args.get('base', '')
    icase = args.get('icase', 0)
    scase = args.get('scase', 0)
    kw_re = args.get('priv', re.compile(''))
    raw_result = GetCurBufKws(base, icase, scase, text, kw_re)
    if scase and re.search('[A-Z]', base):
        icase = 0
    # 转为字典, 否则不支持icase
    return [{'word': i, 'icase': icase} for i in raw_result]

def CurrFileKeywordsCompleteArgs(kwargs):
    args = {
        'text'  : '\n'.join(vim.current.buffer),
        'file'  : vim.eval('expand("%:p")'),
        'row'   : kwargs['row'],
        'col'   : kwargs['col'],
        'base'  : kwargs['base'],
        'icase' : kwargs['icase'],
        'scase' : kwargs['scase'],
    }
    #print args
    return args

PYTHON_EOF
endfunction
"}}}

augroup AsyncComplStart
    autocmd!
    autocmd BufNewFile,BufReadPost * call <SID>InitKeywordsComplete()
augroup END

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
