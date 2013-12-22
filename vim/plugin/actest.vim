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
function! CommonSearchStartColumn() "{{{2
    let row = line('.')
    let col = col('.')

    " 光标在第一列, 不能补全
    if col <= 1
        return -1
    endif

    let cursor_prechar = getline('.')[col-2 : col-2]

    " 光标前的字符不是关键字, 不能补全
    if cursor_prechar !~# '\k'
        return -1
    endif

    " NOTE: 光标下的字符应该不算在内
    let [srow, scol] = searchpos('\<\k', 'bn', row)

    let start_column = scol

    return start_column
endfunction
"}}}

function! InitKeywordsComplete() "{{{2
    if exists('#AsyncCompl#InsertCharPre#<buffer>')
        return
    endif

    call s:InitPyIf()
    call asynccompl#Register(1, '', '\k', '\k\+$', 2,
            \               'CommonSearchStartColumn', 'CommonLaunchComplThread',
            \               'CommonFetchComplResult')
    " NOTE: 暂时只能做到这种程度了, 因为python无法模拟vim的'\<'正则,
    "       用'\b'会有副作用, 正确的搜索模式应该是 '\<\k\k\+'
    py __kw_pat = ''.join(iskconv.Conv2PattList(vim.eval('&iskeyword'), 1)[0])
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
