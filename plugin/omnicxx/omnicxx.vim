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
function! s:SID() "获取脚本 ID {{{2
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
let s:sid = s:SID()

function! s:GetSFuncRef(sFuncName) " 获取局部于脚本的函数的引用 {{{2
    let sFuncName = a:sFuncName =~ '^s:' ? a:sFuncName[2:] : a:sFuncName
    return function('<SNR>'.s:sid.'_'.sFuncName)
endfunction
"}}}

if vlutils#IsWindowsOS()
    let s:libname = 'libCxxParser.dll'
else
    let s:libname = 'libCxxParser.so'
endif

" 备用，暂时还没有起作用
let s:OmniCxxSettings = {
    \ '.videm.cc.omnicxx.Enable'                : 0,
    \ '.videm.cc.omnicxx.IgnoreCase'            : &ignorecase,
    \ '.videm.cc.omnicxx.SmartCase'             : &smartcase,
    \ '.videm.cc.omnicxx.EnableSyntaxTest'      : 1,
    \ '.videm.cc.omnicxx.ReturnToCalltips'      : 1,
    \ '.videm.cc.omnicxx.ItemSelectMode'        : 2,
    \ '.videm.cc.omnicxx.GotoDeclKey'           : '<C-p>',
    \ '.videm.cc.omnicxx.GotoImplKey'           : '<C-]>',
    \ '.videm.cc.omnicxx.AutoTriggerCharCount'  : 2,
    \ '.videm.cc.omnicxx.InclAllCondCmplBrch'   : 1,
    \ '.videm.cc.omnicxx.LibCxxParserPath'      : s:os.path.join(g:VidemDir,
    \                                                       'lib', s:libname),
\ }

unlet s:libname

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
    command! -nargs=0 -bar VOmniCxxParseCurrFile
            \                           call <SID>AsyncParseCurrentFile(0, 0)
    command! -nargs=0 -bar VOmniCxxParseCurrFileDeep
            \                           call <SID>AsyncParseCurrentFile(0, 1)
    command! -nargs=0 -bar VOmniCxxTagsSetttings    call <SID>TagsSettings()
endfunction
"}}}
function! s:InstallMenus() "{{{2
    anoremenu <silent> 200 &Videm.OmniCxx\ Tags\ Settings\.\.\. 
            \ :call <SID>TagsSettings()<CR>
endfunction
"}}}
function! s:UninstallCommands() "{{{2
    delcommand VOmniCxxParseCurrFile
    delcommand VOmniCxxParseCurrFileDeep
    delcommand VOmniCxxTagsSetttings
endfunction
"}}}
function! s:UninstallMenus() "{{{2
    aunmenu &Videm.OmniCxx\ Tags\ Settings\.\.\.
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
    " 菜单
    call s:InstallMenus()
    " 注册回调
    py VidemWorkspace.RegDelNodePostHook(DelNodePostHook, 0, videm_cc_omnicxx)
    py VidemWorkspace.RegRnmNodePostHook(RnmNodePostHook, 0, videm_cc_omnicxx)
    py VidemWorkspace.wsp_ntf.Register(VidemWspOmniCxxHook, 0, videm_cc_omnicxx)
    " 自动命令
    augroup VidemCCOmniCxx
        autocmd!
        autocmd! FileType c,cpp call omnicxx#complete#BuffInit()
        autocmd! BufWritePost * call <SID>AsyncParseCurrentFile(1, 1)
        autocmd! VimLeave     * call <SID>Autocmd_Quit()
    augroup END
    " 安装videm菜单项目
    py OmniCxxWMenuAction()
    " 工作区设置
    call VidemWspSetCreateHookRegister('videm#plugin#omnicxx#WspSetHook',
            \                          0, s:ctls)
    " 执行一次hook动作
    py if ws.IsOpen(): VidemWspOmniCxxHook('open_post', ws, videm_cc_omnicxx)
    let s:enable = 1
endfunction
"}}}
function! videm#plugin#omnicxx#Disable() "{{{2
    if !s:enable
        return
    endif
    " 删除命令
    call s:UninstallCommands()
    " 删除菜单
    call s:UninstallMenus()
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
    " NOTE: 保存工作区的时候可能触发这个事件，然后这里卸载hook，会造成不一致
    call VidemWspSetCreateHookUnregister('videm#plugin#omnicxx#WspSetHook', 0)
    " 执行一次hook动作
    py if ws.IsOpen(): VidemWspOmniCxxHook('close_post', ws, videm_cc_omnicxx)
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
function! videm#plugin#omnicxx#GetWspDbfile() "{{{2
    py if not videm.wsp.IsOpen(): vim.command("return ''")
    py vim.command("return %s" % ToVimEval(
            \ os.path.splitext(videm.wsp.VLWIns.fileName)[0] + '.vtags'))
endfunction
"}}}
function! s:AsyncParseCurrentFile(ignore_needless, deep) "{{{2
    let ignore_needless = a:ignore_needless
    let deep = a:deep
    let fname = expand('%:p')
    if !Videm_IsFileInWorkspace(fname)
        return
    endif
    py videm_cc_omnicxx.ParseWorkspace(videm.wsp, [vim.eval('fname')],
            \                          async=True, quiet=True,
            \                          deep=int(vim.eval('deep')),
            \                          ignore_needless=int(vim.eval('ignore_needless')))
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
from omnicxx.TagsStorage.TagsManager import AppendCtagsOptions
from omnicxx.VimOmniCxx import VimOmniCxx
import Misc
import vim

# 添加额外的ctags选项. TODO 需要更加优雅的方式
if int(vim.eval('videm#settings#Get(".videm.cc.omnicxx.InclAllCondCmplBrch")')):
    AppendCtagsOptions('-m')

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
        dbfile = vim.eval('videm#plugin#omnicxx#GetWspDbfile()')
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
" =================== tags 设置 ===================
"{{{1
"标识用控件 ID {{{2
let s:ID_TagsSettingsIncludePaths = videm#wsp#TagsSettings_ID_SearchPaths
let s:ID_TagsSettingsTagsTokens = 11
let s:ID_TagsSettingsTagsTypes = 12

function! s:TagsSettings() "{{{2
    let dlg = s:CreateTagsSettingsDialog()
    call dlg.Display()
endfunction
"}}}
function! s:SaveTagsSettingsCbk(dlg, data) "{{{2
    py __ins = TagsSettingsST.Get()
    for ctl in a:dlg.controls
        if ctl.GetId() == s:ID_TagsSettingsIncludePaths
            py __ins.includePaths = vim.eval("ctl.values")
        elseif ctl.GetId() == s:ID_TagsSettingsTagsTokens
            py __ins.tagsTokens = vim.eval("ctl.values")
        elseif ctl.GetId() == s:ID_TagsSettingsTagsTypes
            py __ins.tagsTypes = vim.eval("ctl.values")
        endif
    endfor
    " 保存
    py __ins.Save()
    py del __ins
endfunction
"}}}
function! s:GetTagsSettingsHelpText() "{{{2
    let s = "Run the following command to get gcc search paths:\n"
    let s .= "  echo \"\" | gcc -v -x c++ -fsyntax-only -\n"
    return s
endfunction
"}}}
function! s:CreateTagsSettingsDialog() "{{{2
    let dlg = g:VimDialog.New('== OmniCxx Tags Settings ==')
    call dlg.SetExtraHelpContent(s:GetTagsSettingsHelpText())
    py ins = TagsSettingsST.Get()

"===============================================================================
    "1.Include Files
    "let ctl = g:VCStaticText.New("Tags Settings")
    "call ctl.SetHighlight("Special")
    "call dlg.AddControl(ctl)
    "call dlg.AddBlankLine()

    " 公用的公共控件
    let ctls = Videm_GetTagsSettingsControls()
    for ctl in ctls
        call dlg.AddControl(ctl)
    endfor

    "call dlg.AddBlankLine()
    "call dlg.AddSeparator(4)
    "let ctl = g:VCStaticText.New('The followings are only for vlctags parser')
    "call ctl.SetIndent(4)
    "call ctl.SetHighlight('WarningMsg')
    "call dlg.AddControl(ctl)
    "call dlg.AddBlankLine()

    let ctl = g:VCMultiText.New("Macros:")
    call ctl.SetId(s:ID_TagsSettingsTagsTokens)
    call ctl.SetIndent(4)
    py vim.command("let tagsTokens = %s" % ToVimEval(ins.tagsTokens))
    call ctl.SetValue(tagsTokens)
    call ctl.ConnectButtonCallback(function("vlutils#EditTextBtnCbk"), "cpp")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCMultiText.New("Types:")
    call ctl.SetId(s:ID_TagsSettingsTagsTypes)
    call ctl.SetIndent(4)
    py vim.command("let tagsTypes = %s" % ToVimEval(ins.tagsTypes))
    call ctl.SetValue(tagsTypes)
    call ctl.ConnectButtonCallback(function("vlutils#EditTextBtnCbk"), "")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    call dlg.ConnectSaveCallback(s:GetSFuncRef("s:SaveTagsSettingsCbk"), "")

    call dlg.AddFooterButtons()

    py del ins
    return dlg
endfunction
"}}}1
" =================== 工作区设置 ===================
"{{{1
let s:ctls = {}
" 这个函数在工作区设置的时候调用
function! videm#plugin#omnicxx#WspSetHook(event, data, priv) "{{{2
    let event = a:event
    let dlg = a:data
    let ctls = a:priv
    "echo event
    "echo dlg
    "echo ctls
    if event ==# 'create'
        " ======================================================================
        let ctl = g:VCStaticText.New("OmniCxx Tags Settings")
        call ctl.SetHighlight("Special")
        call dlg.AddControl(ctl)
        call dlg.AddBlankLine()

        " 头文件搜索路径
        let ctl = g:VCMultiText.New(
                \ "Add search paths for the vlctags and libclang parser:")
        let ctls['IncludePaths'] = ctl
        call ctl.SetIndent(4)
        py vim.command("let includePaths = %s" %
                \ ToVimEval(ws.VLWSettings.includePaths))
        call ctl.SetValue(includePaths)
        call ctl.ConnectButtonCallback(function("vlutils#EditTextBtnCbk"), "")
        call dlg.AddControl(ctl)

        let ctl = g:VCComboBox.New(
                \ "Use with Global Settings (Only For Search Paths):")
        let ctls['IncPathFlag'] = ctl
        call ctl.SetIndent(4)
        py vim.command("let lItems = %s" %
                \ ToVimEval(ws.VLWSettings.GetIncPathFlagWords()))
        for sI in lItems
            call ctl.AddItem(sI)
        endfor
        py vim.command("call ctl.SetValue(%s)" % 
                \ ToVimEval(ws.VLWSettings.GetCurIncPathFlagWord()))
        call dlg.AddControl(ctl)
        call dlg.AddBlankLine()

        " ======================================================================
        call dlg.AddBlankLine()
        call dlg.AddSeparator(4) " 分割线
        let ctl = g:VCStaticText.New(
                \'The followings are only for vlctags (OmniCxx) parser')
        call ctl.SetIndent(4)
        call ctl.SetHighlight('WarningMsg')
        call dlg.AddControl(ctl)
        call dlg.AddBlankLine()

        let ctl = g:VCMultiText.New("Prepend Search Scopes (For OmniCxx):")
        let ctls['PrependNSInfo'] = ctl
        call ctl.SetIndent(4)
        py vim.command("let prependNSInfo = %s" %
                \ ToVimEval(ws.VLWSettings.GetUsingNamespace()))
        call ctl.SetValue(prependNSInfo)
        call ctl.ConnectButtonCallback(function("vlutils#EditTextBtnCbk"), "")
        call dlg.AddControl(ctl)
        call dlg.AddBlankLine()

        let ctl = g:VCMultiText.New("Macro Files:")
        let ctls['MacroFiles'] = ctl
        call ctl.SetIndent(4)
        py vim.command("let macroFiles = %s" %
                \ ToVimEval(ws.VLWSettings.GetMacroFiles()))
        call ctl.SetValue(macroFiles)
        call ctl.ConnectButtonCallback(function("vlutils#EditTextBtnCbk"), "")
        call dlg.AddControl(ctl)
        call dlg.AddBlankLine()

        let ctl = g:VCMultiText.New("Macros:")
        let ctls['TagsTokens'] = ctl
        call ctl.SetIndent(4)
        py vim.command("let tagsTokens = %s" %
                \ ToVimEval(ws.VLWSettings.tagsTokens))
        call ctl.SetValue(tagsTokens)
        call ctl.ConnectButtonCallback(function("vlutils#EditTextBtnCbk"), "cpp")
        call dlg.AddControl(ctl)
        call dlg.AddBlankLine()

        let ctl = g:VCMultiText.New("Types:")
        let ctls['TagsTypes'] = ctl
        call ctl.SetIndent(4)
        py vim.command("let tagsTypes = %s" %
                \ ToVimEval(ws.VLWSettings.tagsTypes))
        call ctl.SetValue(tagsTypes)
        call ctl.ConnectButtonCallback(function("vlutils#EditTextBtnCbk"), "")
        call dlg.AddControl(ctl)
        call dlg.AddBlankLine()
    elseif event ==# 'save' && !empty(ctls)
        py ws.VLWSettings.includePaths = vim.eval("ctls['IncludePaths'].values")
        py ws.VLWSettings.SetIncPathFlag(vim.eval("ctls['IncPathFlag'].GetValue()"))

        py ws.VLWSettings.SetUsingNamespace(
                \ vim.eval("ctls['PrependNSInfo'].values"))
        py ws.VLWSettings.SetMacroFiles(vim.eval("ctls['MacroFiles'].values"))
        py ws.VLWSettings.tagsTokens = vim.eval("ctls['TagsTokens'].values")
        py ws.VLWSettings.tagsTypes = vim.eval("ctls['TagsTypes'].values")
    endif
endfunction
"}}}
"}}}1

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
