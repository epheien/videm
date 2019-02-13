" Add python modules in this directory to sys.path
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-12-15
" Change:   2013-12-15

if !has('python3')
    finish
endif

let s:sfile = expand('<sfile>')
let s:init = 0
function vpymod#driver#Init()
    if s:init
        return
    endif
    let s:init = 1

    pyx import sys
    pyx import os.path
    pyx import vim
    pyx sys.path.append(os.path.dirname(vim.eval('s:sfile')))
endfunction

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
