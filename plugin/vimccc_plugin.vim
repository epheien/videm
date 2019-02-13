" Vim clang code completion plugin
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-05-25
" Change:   2013-05-25

if exists("g:loaded_VIMCCC")
    finish
endif
let g:loaded_VIMCCC = 1

command! -nargs=0 -bar VIMCCCInitForcibly call vimccc#core#InitForcibly()

if exists('g:VIMCCC_Enable') && g:VIMCCC_Enable
    call vimccc#core#InitEarly()
endif

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
