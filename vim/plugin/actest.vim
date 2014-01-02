" Async Complete Test
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-12-13
" Change:   2013-12-22

" 这个插件暂时只支持 ASCII 码的补全, 其他的都不支持

if get(s:, 'loaded', 0)
    finish
endif
let s:loaded = 1

let s:sfile = expand('<sfile>')
function! InitKeywordsComplete() "{{{2
    if exists('#AsyncCompl#InsertCharPre#<buffer>')
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
endfunction
"}}}

let s:init_pyif = 0
function! s:InitPyIf() "{{{2
    if s:init_pyif
        return
    endif
    let s:init_pyif = 1
python << PYTHON_EOF
import re
import vim
import sys
import os.path

sys.path.append(os.path.dirname(vim.eval("s:sfile")))

import iskconv

def CurrFileKeywordsComplete(acthread, args, data):
    '''补全当前文件的关键词, 类似于 <C-x><C-n>'''
    kw_re = data
    base = args.get('base', '')
    text = args.get('text', '')
    icase = args.get('icase', False)
    raw_result = GetCurBufKws(base, icase, text, kw_re)
    # 转为字典, 否则不支持icase
    return [{'word': i, 'icase': icase} for i in raw_result]

def CurrFileKeywordsCompleteArgs(row, col, base, icase, data):
    args = {'text': '\n'.join(vim.current.buffer),
            'file': vim.eval('expand("%:p")'),
            'hello': 'world',
            'row': row,
            'col': col,
            'base': base,
            'icase': icase}
    #print args
    return args
    
PYTHON_EOF
endfunction
"}}}

call vpymod#driver#Init()
autocmd BufNewFile,BufReadPost * call InitKeywordsComplete()

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
