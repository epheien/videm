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
    " 注册回调
    py VidemWorkspace.RegDelNodePostHook(DelNodePostHook, 0, videm_cc_omnicxx)
    py VidemWorkspace.RegRnmNodePostHook(RnmNodePostHook, 0, videm_cc_omnicxx)
    py VidemWorkspace.wsp_ntf.Register(VidemWspOmniCxxHook, 0, videm_cc_omnicxx)
    " 自动命令
    augroup VidemCCOmniCxx
        autocmd!
        autocmd! FileType c,cpp call omnicxx#complete#BuffInit()
        "autocmd! BufWritePost * call <SID>AsyncParseCurrentFile()
        "autocmd! VimLeave     * call <SID>Autocmd_Quit()
    augroup END
    " 安装videm菜单项目
    py OmniCxxWMenuAction()
    let s:enable = 1
endfunction
"}}}
function! videm#plugin#omnicxx#Disable() "{{{2
    if !s:enable
        return
    endif
    " 删除命令
    call s:UninstallCommands()
    " 删除回调
    py VidemWorkspace.UnregDelNodePostHook(DelNodePostHook, 0)
    py VidemWorkspace.UnregRnmNodePostHook(RnmNodePostHook, 0)
    py VidemWorkspace.wsp_ntf.Unregister(VidemWspOmniCxxHook, 0)
    " 删除自动命令
    augroup VidemCCOmniCxx
        autocmd!
    augroup END
    augroup! VidemCCOmniCxx
    " 删除videm菜单项目
    py OmniCxxWMenuAction(remove=True)
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
from omnicxx.TagsStorage.TagsManager import TagsManager
from omnicxx.VimOmniCxx import VimOmniCxx
import Misc

# 全局变量
videm_cc_omnicxx = VimOmniCxx(TagsManager())

def DelNodePostHook(wsp, nodepath, nodetype, files, ins):
    ins.tagmgr.DeleteTagsByFiles(files, True)
    ins.tagmgr.DeleteFileEntries(files, True)

def RnmNodePostHook(wsp, nodepath, nodetype, oldfile, newfile, ins):
    if nodetype == VidemWorkspace.NT_FILE:
        ins.tagmgr.UpdateFilesFile(oldfile, newfile)

def VidemWspOmniCxxHook(event, wsp, ins):
    #print 'Enter VidemWspOmniCxxHook():', event, wsp, ins
    if event == 'open_post':
        dbfile = os.path.splitext(wsp.VLWIns.fileName)[0] + '.vtags'
        if ins.tagmgr.OpenDatabase(dbfile) != 0:
            print 'Failed to open tags database:', dbfile
        # 更新额外的搜索域
        #vim.command("let g:omnicxx_PrependSearchScopes = %s" %
        #            ToVimEval(wsp.VLWSettings.GetUsingNamespace()))
    elif event == 'close_post':
        ins.tagmgr.CloseDatabase()

    return Notifier.OK

def OmniCxxMenuWHook(wsp, choice, ins):
    if   choice == 'Parse Workspace (Full, Async)':
        ins.ParseWorkspace(wsp, async=True, full=True)
    elif choice == 'Parse Workspace (Quick, Async)':
        ins.ParseWorkspace(wsp, async=True, full=False)
    elif choice == 'Parse Workspace (Full)':
        ins.ParseWorkspace(wsp, async=False, full=True)
    elif choice == 'Parse Workspace (Quick)':
        ins.ParseWorkspace(wsp, async=False, full=False)
    elif choice == 'Parse Workspace (Full, Shallow)':
        ins.ParseWorkspace(wsp, async=False, full=True, deep=False)
    elif choice == 'Parse Workspace (Quick, Shallow)':
        ins.ParseWorkspace(wsp, async=False, full=False, deep=False)

def OmniCxxWMenuAction(remove=False):
    # 菜单动作，只添加工作区菜单
    li = [
        '-Sep_OmniCxx-',
        'Parse Workspace (Full, Async)',
        'Parse Workspace (Quick, Async)',
        #'Parse Workspace (Full)',
        #'Parse Workspace (Quick)',
        'Parse Workspace (Full, Shallow)',
        'Parse Workspace (Quick, Shallow)',
    ]

    if remove:
        for item in li:
            VidemWorkspace.RemoveWMenu(item)
    else:
        idx = VidemWorkspace.popupMenuW.index('-Sep_Symdb-')
        for item in li:
            VidemWorkspace.InsertWMenu(idx, item, OmniCxxMenuWHook,
                                       videm_cc_omnicxx)
            idx += 1

PYTHON_EOF
endfunction
"}}}
" 需要等待后台线程完成
function! s:Autocmd_Quit() "{{{2
    while 1
        py vim.command('let nCnt = %d' % Misc.GetBgThdCnt())
        if nCnt != 0
            redraw
            let sMsg = printf(
                        \"There %s %d running background thread%s, " 
                        \. "please wait...", 
                        \nCnt == 1 ? 'is' : 'are', nCnt, nCnt > 1 ? 's' : '')
            call vlutils#EchoWarnMsg(sMsg)
        else
            break
        endif
        sleep 500m
    endwhile
endfunction
"}}}

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
