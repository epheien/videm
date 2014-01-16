" OmniCxx plugin for Videm
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-12-22
" Change:   2014-01-12

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
function! omnicxx#complete#BuffInit() "{{{2
    call s:InitPyIf()
    let config = {}
    let config.manu_popup_pattern = '\.\|>\|:'
    let config.auto_popup_pattern = '[A-Za-z_0-9]'
    let config.auto_popup_base_pattern = '[A-Za-z_]\w*$'
    let config.ignorecase = videm#settings#Get('.videm.cc.omnicxx.IgnoreCase')
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
    call asynccompl#BuffInit()
endfunction
"}}}
function! omnicxx#complete#BuffExit() "{{{2
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
    dbfile = args.get('dbfile') # 数据库文件, 跨线程需要新建数据库连接实例
    opts = args.get('opts')

    result = None

    acthread.CommonLock()
    # just for test
    result = ['abc', 'xyz', 'ABC', 'XYZ']
    retmsg = {}
    # 这里开始根据参数来获取补全结果
    result = OmniCxxCodeComplete(file, buff, row, col, dbfile, retmsg=retmsg)
    acthread.CommonUnlock()

    return result

PYTHON_EOF
endfunction
"}}}

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
