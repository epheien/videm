" Vim clang code completion plugin
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-05-25
" Change:   2013-05-25

if exists("g:loaded_VIMCCC")
    finish
endif
let g:loaded_VIMCCC = 1

" NOTE: 放到 autoload 的任何地方都产生不了异常，只能放到 plugin 目录 (BUG?!)
" 检查是否支持 noexpand 选项
let s:__temp = &completeopt
let s:has_noexpand = 1
let g:VIMCCC_Has_noexpand = 1
try
    set completeopt+=noexpand
catch /.*/
    let g:VIMCCC_Has_noexpand = 0
endtry
let &completeopt = s:__temp
unlet s:__temp

command! -nargs=0 -bar VIMCCCInitForcibly call vimccc#core#InitForcibly()

if exists('g:VIMCCC_Enable') && g:VIMCCC_Enable
    call vimccc#core#InitEarly()
endif

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
