" OmniCxx plugin for Videm
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-12-22
" Change:   2013-12-22

if get(s:, 'loaded', 0)
    finish
endif
let s:loaded = 1

" import library
let s:os = vlutils#os

let s:enable = 0

" 备用，暂时还没有起作用
let s:OmniCxxSettings = {
    \ '.videm.cc.omnicxx.Enable'                : 0,
    \ '.videm.cc.omnicxx.IgnoreCase'            : &ignorecase,
    \ '.videm.cc.omnicxx.EnableSyntaxTest'      : 1,
    \ '.videm.cc.omnicxx.ReturnToCalltips'      : 1,
    \ '.videm.cc.omnicxx.ItemSelectMode'        : 2,
    \ '.videm.cc.omnicxx.GotoDeclKey'           : '<C-p>',
    \ '.videm.cc.omnicxx.GotoImplKey'           : '<C-]>',
    \ '.videm.cc.omnicxx.AutoTriggerCharCount'  : 2,
    \ '.videm.cc.omnicxx.UseLibCxxParser'       : 0,
    \ '.videm.cc.omnicxx.InclAllCondCmplBrch'   : 1,
    \ '.videm.cc.omnicxx.LibCxxParserPath'      : s:os.path.join(g:VidemDir,
    \                                                   '/lib/libCxxParser.so'),
\ }

function! s:InitSettings() "{{{2
    if vlutils#IsWindowsOS() &&
            \ !videm#settings#Has('.videm.cc.omnicxx.LibCxxParserPath')
        call videm#settings#Set('.videm.cc.omnicxx.LibCxxParserPath',
                \           s:os.path.join(g:VidemDir, 'lib\libCxxParser.dll'))
    endif
    call videm#settings#Init(s:OmniCxxSettings)
endfunction
"}}}
function! s:InstallCommands() "{{{2
endfunction
"}}}
function! s:UninstallCommands() "{{{2
endfunction
"}}}
function! videm#plugin#omnicxx#HasEnabled() "{{{2
    return s:enable
endfunction
"}}}
function! videm#plugin#omnicxx#Enable() "{{{2
    if s:enable
        return
    endif
    call s:InitPyIf()
    " 命令
    call s:InstallCommands()
    " 自动命令
    augroup VidemCCOmniCxx
        autocmd!
        autocmd! FileType c,cpp call omnicxx#complete#BuffInit()
        "autocmd! BufWritePost * call <SID>AsyncParseCurrentFile()
        "autocmd! VimLeave     * call <SID>Autocmd_Quit()
    augroup END
    let s:enable = 1
endfunction
"}}}
function! videm#plugin#omnicxx#Disable() "{{{2
    if !s:enable
        return
    endif
    " 删除命令
    call s:UninstallCommands()
    " 删除自动命令
    augroup VidemCCOmniCxx
        autocmd!
    augroup END
    augroup! VidemCCOmniCxx
    let s:enable = 0
endfunction
"}}}
function! videm#plugin#omnicxx#Init() "{{{2
    call s:InitSettings()
    call videm#settings#RegisterHook('videm#plugin#omnicxx#SettingsHook', 0, 0)
    if videm#settings#Get('.videm.cc.omnicxx.Enable', 0)
        call videm#plugin#omnicxx#Enable()
    endif
endfunction
"}}}
function! videm#plugin#omnicxx#Exit() "{{{2
    " 暂不支持插件卸载
endfunction
"}}}
function! videm#plugin#omnicxx#SettingsHook(event, data, priv) "{{{2
    let event = a:event
    let opt = a:data['opt']
    let val = a:data['val']
    if event ==# 'set'
        if opt ==# '.videm.cc.omnicxx.Enable'
            if val
                call videm#plugin#omnicxx#Enable()
            else
                call videm#plugin#omnicxx#Disable()
            endif
        endif
    endif
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
import os.path
PYTHON_EOF
endfunction
"}}}

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
