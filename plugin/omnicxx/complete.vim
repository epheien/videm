" OmniCxx plugin for Videm
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-12-22
" Change:   2013-12-22

function! omnicxx#complete#BuffInit() "{{{2
    call s:InitPyIf()
    let icase = videm#settings#Get('.videm.cc.omnicxx.IgnoreCase')
    let slmode = videm#settings#Get('.videm.cc.omnicxx.ItemSelectMode')
    let trigchr = videm#settings#Get('.videm.cc.omnicxx.AutoTriggerCharCount')
    let omnifunc = 1
    call asynccompl#Register(icase, '\.\|>\|:',
            \                '[A-Za-z_0-9]', '[A-Za-z_]\w*$', trigchr,
            \                'CxxSearchStartColumn', 'CommonLaunchComplThread',
            \                'CommonFetchComplResult',
            \                omnifunc, slmode)
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

def OmniCxxArgsHook(row, col, base, icase, data):
    # 暂时没有这么高端要支持好几个未保存的文件, 只支持当前文件未保存即可
    args = {'file': vim.eval('expand("%:p")'),
            'buff': vim.current.buffer[:row], # 可以是列表或者字符串, 看需求
            'row': row,
            'col': col,
            'base': base,
            'icase': icase,
            'dbfile': os.path.expanduser('~/dbfile.vltags'), # 数据库文件名
            'opts': ''}
    return args

def OmniCxxCompleteHook(acthread, args, data):
    '''这个函数在后台线程运行, 只能根据传入参数来进行操作'''
    file = args.get('file')
    buff = args.get('buff') # 只保证到row行, row行后的内存可能不存在
    row = args.get('row')
    col = args.get('col')
    base = args.get('base')
    icase = args.get('icase')
    dbfile = args.get('dbfile') # 数据库文件, 跨线程需要新建数据库连接实例
    opts = args.get('opts')

    result = None

    acthread.CommonLock()
    # TODO 这里开始根据参数来获取补全结果
    # result = xxxxx(file, row, col, base, icase, dbfile, opts)
    result = ['abc', 'xyz', 'ABC', 'XYZ']
    acthread.CommonUnlock()

    return result

PYTHON_EOF
endfunction
"}}}

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
