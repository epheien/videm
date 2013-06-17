" Vim Script
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2012-08-05
" Change:   2012-08-05

if !has('python')
    echoerr "[videm] Error: Required vim compiled with +python"
    finish
endif
if v:version < 703
    echoerr "[videm] Error: Required vim 7.3 or later"
    finish
endif

if exists('g:loaded_videm')
    finish
endif
let g:loaded_videm = 1

" 命令导出
command! -nargs=? -complete=file VidemOpen 
            \                           call videm#wsp#InitWorkspace('<args>')


" vim: fdm=marker fen et sts=4 fdl=1
