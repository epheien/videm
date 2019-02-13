" OmniCpp plugin for Videm
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-05-18
" Change:   2013-12-22

" import library
let s:os = vlutils#os

" 工作区设置的控件字典
let s:ctls = {}

let s:enable = 0

" 备用，暂时还没有起作用
let s:OmniCppSettings = {
    \ '.videm.cc.omnicpp.Enable'                : 1,
    \ '.videm.cc.omnicpp.ShowAccessSymbol'      : 1,
    \ '.videm.cc.omnicpp.MayCompleteDot'        : 1,
    \ '.videm.cc.omnicpp.MayCompleteArrow'      : 1,
    \ '.videm.cc.omnicpp.MayCompleteColon'      : 1,
    \ '.videm.cc.omnicpp.EnableSyntaxTest'      : 1,
    \ '.videm.cc.omnicpp.ReturnToCalltips'      : 1,
    \ '.videm.cc.omnicpp.ItemSelectMode'        : 2,
    \ '.videm.cc.omnicpp.GotoDeclKey'           : '<C-p>',
    \ '.videm.cc.omnicpp.GotoImplKey'           : '<C-]>',
    \ '.videm.cc.omnicpp.UseLibCxxParser'       : 0,
    \ '.videm.cc.omnicpp.InclAllCondCmplBrch'   : 1,
    \ '.videm.cc.omnicpp.LibCxxParserPath'      : s:os.path.join(g:VidemDir,
    \                                                   '/lib/libCxxParser.so'),
\ }

let s:CompatSettings = {
    \ 'g:VLOmniCpp_ShowAccessSymbol'    : '.videm.cc.omnicpp.ShowAccessSymbol',
    \ 'g:VLOmniCpp_MayCompleteDot'      : '.videm.cc.omnicpp.MayCompleteDot',
    \ 'g:VLOmniCpp_MayCompleteArrow'    : '.videm.cc.omnicpp.MayCompleteArrow',
    \ 'g:VLOmniCpp_MayCompleteColon'    : '.videm.cc.omnicpp.MayCompleteColon',
    \ 'g:VLOmniCpp_EnableSyntaxTest'    : '.videm.cc.omnicpp.EnableSyntaxTest',
    \ 'g:VLOmniCpp_MapReturnToDispCalltips'
    \       : '.videm.cc.omnicpp.ReturnToCalltips',
    \ 'g:VLOmniCpp_ItemSelectionMode'   : '.videm.cc.omnicpp.ItemSelectMode',
    \ 'g:VLOmniCpp_GotoDeclarationKey'  : '.videm.cc.omnicpp.GotoDeclKey',
    \ 'g:VLOmniCpp_GotoImplementationKey'   : '.videm.cc.omnicpp.GotoImplKey',
    \ 'g:VLOmniCpp_LibCxxParserPath'    : '.videm.cc.omnicpp.LibCxxParserPath',
    \ 'g:VLOmniCpp_UseLibCxxParser'     : '.videm.cc.omnicpp.UseLibCxxParser',
\ }

function! s:InitCompatSettings() "{{{2
    for item in items(s:CompatSettings)
        if !exists(item[0])
            continue
        endif
        call videm#settings#Set(item[1], {item[0]})
    endfor
endfunction
"}}}2
" 初始化反转的兼容选项，即实现处还是使用 g:XXX 判断，但是支持开始的时候使用
" '.videm.xxx' 来设置
function! s:InitInverseCompatSettings() "{{{2
    for [oldopt, newopt] in items(s:CompatSettings)
        if videm#settings#Has(newopt)
            let {oldopt} = videm#settings#Get(newopt)
        endif
    endfor
endfunction
"}}}2
function! s:InitSettings() "{{{2
    call s:InitInverseCompatSettings()
    if videm#settings#Get('.videm.Compatible')
        call s:InitCompatSettings()
    endif
    if vlutils#IsWindowsOS() &&
            \ !videm#settings#Has('.videm.cc.omnicpp.LibCxxParserPath')
        call videm#settings#Set('.videm.cc.omnicpp.LibCxxParserPath',
                \           s:os.path.join(g:VidemDir, 'lib\libCxxParser.dll'))
    endif
    call videm#settings#Init(s:OmniCppSettings)
endfunction
"}}}
function! s:SID() "获取脚本 ID {{{2
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
let s:sid = s:SID()

function! s:GetSFuncRef(sFuncName) " 获取局部于脚本的函数的引用 {{{2
    let sFuncName = a:sFuncName =~ '^s:' ? a:sFuncName[2:] : a:sFuncName
    return function('<SNR>'.s:sid.'_'.sFuncName)
endfunction
"}}}
" 需要等待后台线程完成
function! s:Autocmd_Quit() "{{{2
    while 1
        py vim.command('let nCnt = %d' % GetBgThdCnt())
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
" NOTE: 用到了python的全局变量 ws
function! s:AsyncParseCurrentFile(bFilterNotNeed, bIncHdr) "{{{2
    if !exists("s:AsyncParseCurrentFile_FirstEnter")
        let s:AsyncParseCurrentFile_FirstEnter = 1
python << PYTHON_EOF
import threading
import IncludeParser
from VimUtils import VimExcHdr

# 需要先初始化
VimExcHdr.Init()

class ParseCurrentFileThread(threading.Thread):
    '''同时只允许单个线程工作'''
    lock = threading.Lock()

    def __init__(self, wsp, ins, fileName, filterNotNeed = True, incHdr = True):
        threading.Thread.__init__(self)
        self.fileName = fileName
        self.filterNotNeed = filterNotNeed
        self.incHdr = incHdr
        # VidemWorkspace 实例
        self.wsp = wsp
        # OmniCpp 实例
        self.ins = ins

        self.name = 'Videm-' + self.name

    def run(self):
        ParseCurrentFileThread.lock.acquire()
        try:
            project = self.wsp.VLWIns.GetProjectByFileName(self.fileName)
            if project:
                searchPaths = self.wsp.GetTagsSearchPaths()
                searchPaths += self.wsp.GetProjectIncludePaths(project.GetName())
                extraMacros = self.wsp.GetWorkspacePredefineMacros()
                # 这里必须使用这个函数，因为 sqlite3 的连接实例不能跨线程
                if self.incHdr:
                    self.ins.AsyncParseFiles(self.wsp, [self.fileName] 
                                            + IncludeParser.GetIncludeFiles(
                                                    self.fileName, searchPaths),
                                       extraMacros, self.filterNotNeed)
                else: # 不包括 self.fileName 包含的头文件
                    self.ins.AsyncParseFiles(self.wsp, [self.fileName],
                                       extraMacros, self.filterNotNeed)
        except:
            VimExcHdr.VimRaise()
        ParseCurrentFileThread.lock.release()
PYTHON_EOF
    endif

    " NOTE: 不是c或c++类型的文件，不继续，这个判断可能和Videm的py模块不一致
    if &filetype !=# 'c' && &filetype !=# 'cpp'
        return
    endif

    let bFilterNotNeed = a:bFilterNotNeed
    let bIncHdr = a:bIncHdr
    let sFile = expand('%:p')
    " 不是工作区的文件的话就返回
    py if not ws.VLWIns.IsWorkspaceFile(vim.eval("sFile")):
                \vim.command("return")

    if bFilterNotNeed
        if bIncHdr
            py ParseCurrentFileThread(ws, videm_cc_omnicpp,
                        \             vim.eval("sFile"), True, True).start()
        else
            py ParseCurrentFileThread(ws, videm_cc_omnicpp,
                        \             vim.eval("sFile"), True, False).start()
        endif
    else
        if bIncHdr
            py ParseCurrentFileThread(ws, videm_cc_omnicpp,
                        \             vim.eval("sFile"), False, True).start()
        else
            py ParseCurrentFileThread(ws, videm_cc_omnicpp,
                        \             vim.eval("sFile"), False, False).start()
        endif
    endif
endfunction
"}}}
function! s:ParseFiles(...) "{{{2
    if empty(a:000)
        return
    endif
    py videm_cc_omnicpp.ParseFiles(ws, vim.eval("a:000"))
endfunction
"}}}
function! s:ParseCurrentFile(bFilterNotNeed, bIncHdr) "{{{2
    let bFilterNotNeed = a:bFilterNotNeed
    let bIncHdr = a:bIncHdr
    let curFile = expand("%:p")
    if empty(curFile)
        return
    endif

    let files = [curFile]
    if bIncHdr
        py l_project = ws.VLWIns.GetProjectByFileName(vim.eval('curFile'))
        py l_searchPaths = ws.GetTagsSearchPaths()
        py if l_project: l_searchPaths += ws.GetProjectIncludePaths(
                \ l_project.GetName())
        if bFilterNotNeed
            py videm_cc_omnicpp.ParseFiles(ws, vim.eval('files') 
                    \       + IncludeParser.GetIncludeFiles(vim.eval('curFile'),
                    \                                       l_searchPaths),
                    \   filterNotNeed=True)
        else
            py videm_cc_omnicpp.ParseFiles(ws, vim.eval('files') 
                    \       + IncludeParser.GetIncludeFiles(vim.eval('curFile'),
                    \                                       l_searchPaths),
                    \   filterNotNeed=False)
        endif
        py del l_searchPaths
        py del l_project
    else
        if bFilterNotNeed
            py videm_cc_omnicpp.ParseFiles(ws, vim.eval('files'), False,
                    \                      filterNotNeed=True)
        else
            py videm_cc_omnicpp.ParseFiles(ws, vim.eval('files'), False,
                    \                      filterNotNeed=False)
        endif
    endif
endfunction
"}}}
function! s:InstallCommands() "{{{2
    " 异步解析当前文件，并且会强制解析，无论是否修改过
    command! -nargs=0 -bar VOmniCppAsyncParseCurrFile
            \                           call <SID>AsyncParseCurrentFile(0, 0)
    " 同 VOmniCppAsyncParseCurrFile，除了这个会包括头文件外
    command! -nargs=0 -bar VOmniCppAsyncParseCurrFileDeep
            \                           call <SID>AsyncParseCurrentFile(0, 1)
    command! -nargs=0 -bar VOmniCppTagsSetttings    call <SID>TagsSettings()

    command! -nargs=0 -bar VOmniCppParseCurrFile
            \                                   call <SID>ParseCurrentFile(0, 0)
    command! -nargs=0 -bar VOmniCppParseCurrFileDeep
            \                                   call <SID>ParseCurrentFile(0, 1)
    command! -nargs=* -complete=file VOmniCppParseFiles
            \                                   call <SID>ParseFiles(<f-args>)
    command! -nargs=+ VOmniCppGetTagsBySql
            \                               echo vltagmgr#GetTagsBySql(<q-args>)
endfunction
"}}}
function! s:UninstallCommands() "{{{2
    delcommand VOmniCppAsyncParseCurrFile
    delcommand VOmniCppAsyncParseCurrFileDeep
    delcommand VOmniCppTagsSetttings
    delcommand VOmniCppParseFiles
    delcommand VOmniCppParseCurrFile
    delcommand VOmniCppParseCurrFileDeep
    delcommand VOmniCppGetTagsBySql
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

function! s:SaveTagsSettingsCbk(dlg, data) "{{{2
    py ins = TagsSettingsST.Get()
    for ctl in a:dlg.controls
        if ctl.GetId() == s:ID_TagsSettingsIncludePaths
            py ins.includePaths = vim.eval("ctl.values")
        elseif ctl.GetId() == s:ID_TagsSettingsTagsTokens
            py ins.tagsTokens = vim.eval("ctl.values")
        elseif ctl.GetId() == s:ID_TagsSettingsTagsTypes
            py ins.tagsTypes = vim.eval("ctl.values")
        endif
    endfor
    " 保存
    py ins.Save()
    py del ins
    " 重新初始化 OmniCpp 类型替换字典
    py OmniCppUpdateTypesVar(ws)
endfunction
"}}}
function! s:GetTagsSettingsHelpText() "{{{2
    let s = "Run the following command to get gcc search paths:\n"
    let s .= "  echo \"\" | gcc -v -x c++ -fsyntax-only -\n"
    return s
endfunction
"}}}
function! s:CreateTagsSettingsDialog() "{{{2
    let dlg = g:VimDialog.New('== OmniCpp Tags Settings ==')
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
function! videm#plugin#omnicpp#WspSetHook(event, data, priv) "{{{2
    let event = a:event
    let dlg = a:data
    let ctls = a:priv
    "echo event
    "echo dlg
    "echo ctls
    if event ==# 'create'
        " ======================================================================
        let ctl = g:VCStaticText.New("OmniCpp Tags Settings")
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
                \'The followings are only for vlctags (OmniCpp) parser')
        call ctl.SetIndent(4)
        call ctl.SetHighlight('WarningMsg')
        call dlg.AddControl(ctl)
        call dlg.AddBlankLine()

        let ctl = g:VCMultiText.New("Prepend Search Scopes (For OmniCpp):")
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
function! s:ThisInit() "{{{2
    " python 接口
    call s:InitPythonIterfaces()
    " 一些命令
    call s:InstallCommands()
    " 注册回调
    py VidemWorkspace.RegDelNodePostHook(DelNodePostHook, 0, videm_cc_omnicpp)
    py VidemWorkspace.RegRnmNodePostHook(RnmNodePostHook, 0, videm_cc_omnicpp)
    py VidemWorkspace.wsp_ntf.Register(VidemWspOmniCppHook, 0, videm_cc_omnicpp)
    " 自动命令
    augroup VidemCCOmniCpp
        autocmd!
        autocmd! FileType c,cpp call omnicpp#complete#Init()
        autocmd! BufWritePost * call <SID>AsyncParseCurrentFile(1, 1)
        autocmd! VimLeave     * call <SID>Autocmd_Quit()
    augroup END
    py OmniCppWMenuAction()
    " 工作区设置
    call VidemWspSetCreateHookRegister('videm#plugin#omnicpp#WspSetHook',
            \                          0, s:ctls)
    " 菜单
    anoremenu <silent> 200 &Videm.OmniCpp\ Tags\ Settings\.\.\. 
            \ :call <SID>TagsSettings()<CR>
    "echomsg 'omnicpp init ok'
endfunction
"}}}
function! videm#plugin#omnicpp#SettingsHook(event, data, priv) "{{{2
    let event = a:event
    let opt = a:data['opt']
    let val = a:data['val']
    if event ==# 'set'
        if opt ==# '.videm.cc.omnicpp.Enable'
            if val
                call videm#plugin#omnicpp#Enable()
            else
                call videm#plugin#omnicpp#Disable()
            endif
        endif
    endif
endfunction
"}}}
function! videm#plugin#omnicpp#Init() "{{{2
    call s:InitSettings()
    call videm#settings#RegisterHook('videm#plugin#omnicpp#SettingsHook', 0, 0)
    "call videm#wsp#WspOptRegister('.videm.cc.omnicpp.Enable',
            "\                   videm#settings#Get('.videm.cc.omnicpp.Enable'))
    "call videm#wsp#WspRestartOptRegister('.videm.cc.omnicpp.Enable')
    if videm#settings#Get('.videm.cc.omnicpp.Enable', 0)
        call videm#plugin#omnicpp#Enable()
    endif
endfunction
"}}}
function! videm#plugin#omnicpp#HasEnabled() "{{{2
    return s:enable
endfunction
"}}}
function! videm#plugin#omnicpp#Enable() "{{{2
    if s:enable
        return
    endif
    call s:ThisInit()
    py if ws.IsOpen(): VidemWspOmniCppHook('open_post', ws, videm_cc_omnicpp)
    let s:enable = 1
endfunction
"}}}
" 禁用插件时的动作
function! videm#plugin#omnicpp#Disable() "{{{2
    if !s:enable
        return
    endif
    call s:UninstallCommands()
    py VidemWorkspace.UnregDelNodePostHook(DelNodePostHook, 0)
    py VidemWorkspace.UnregRnmNodePostHook(RnmNodePostHook, 0)
    py VidemWorkspace.wsp_ntf.Unregister(VidemWspOmniCppHook, 0)
    " 删除自动命令前先用自动命令进行清理
    doautocmd VidemCCOmniCpp VimLeave *
    " 删除自动命令
    augroup VidemCCOmniCpp
        autocmd!
    augroup END
    augroup! VidemCCOmniCpp
    py OmniCppWMenuAction(remove=True)
    " NOTE: 保存工作区的时候可能触发这个事件，然后这里卸载hook，会造成不一致
    call VidemWspSetCreateHookUnregister('videm#plugin#omnicpp#WspSetHook', 0)
    aunmenu &Videm.OmniCpp\ Tags\ Settings\.\.\.
    py if ws.IsOpen(): VidemWspOmniCppHook('close_post', ws, videm_cc_omnicpp)
    let s:enable = 0
endfunction
"}}}
" 卸载插件时的动作
function! videm#plugin#omnicpp#Exit() "{{{2
endfunction
"}}}
function! s:InitPythonIterfaces() "{{{2
python << PYTHON_EOF
import sys
import os.path

#from Notifier import Notifier
from TagsSettings import GetGccIncludeSearchPaths
from omnicpp.OmniCpp import OmniCpp

# 设置资源位置
vim.command("let g:VimTagsManager_SrcDir = "
            "fnamemodify(omnicpp#settings#GetSfile(), ':h')")
# 初始化后，vtm全局python变量即可用
vim.command("call vltagmgr#Init()")
videm_cc_omnicpp = OmniCpp(vtm)

def DelNodePostHook(wsp, nodepath, nodetype, files, ins):
    ins.tagmgr.DeleteTagsByFiles(files, True)
    ins.tagmgr.DeleteFileEntries(files, True)

def RnmNodePostHook(wsp, nodepath, nodetype, oldfile, newfile, ins):
    if nodetype == VidemWorkspace.NT_FILE:
        ins.tagmgr.DeleteFileEntry(oldfile, True)
        ins.tagmgr.InsertFileEntry(newfile)
        ins.tagmgr.UpdateTagsFileColumnByFile(newfile, oldfile)

def VidemWspOmniCppHook(event, wsp, ins):
    #print 'enter VidemWspOmniCppHook():', event, wsp, ins
    if   event == 'open_post':
        dbfile = os.path.splitext(wsp.VLWIns.fileName)[0] + '.vltags'
        if not ins.tagmgr.OpenDatabase(dbfile):
            print 'Failed to open database:', dbfile
        # 更新OmniCpp类型替换
        OmniCppUpdateTypesVar(wsp)
        # 更新额外的搜索域
        vim.command("let g:VLOmniCpp_PrependSearchScopes = %s" %
                    ToVimEval(wsp.VLWSettings.GetUsingNamespace()))
    elif event == 'close_post':
        ins.tagmgr.CloseDatabase()

    return Notifier.OK

def OmniCppMenuWHook(wsp, choice, ins):
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

def OmniCppUpdateTypesVar(wsp):
    '''更新OmniCpp补全的类型替换'''
    vim.command("let g:dOCppTypes = {}")
    for i in (wsp.VLWSettings.tagsTypes + TagsSettingsST.Get().tagsTypes):
        li = i.partition('=')
        path = vim.eval("omnicpp#utils#GetVariableType(%s).name" 
                        % ToVimEval(li[0]))
        vim.command("let g:dOCppTypes[%s] = {}" % (ToVimEval(path),))
        vim.command("let g:dOCppTypes[%s].orig = %s" 
                    % (ToVimEval(path), ToVimEval(li[0])))
        vim.command("let g:dOCppTypes[%s].repl = %s" 
                    % (ToVimEval(path), ToVimEval(li[2])))

def OmniCppWMenuAction(remove=False):
    # 菜单动作，只添加工作区菜单
    li = [
        '-Sep_OmniCpp-',
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
            VidemWorkspace.InsertWMenu(idx, item,
                                       OmniCppMenuWHook, videm_cc_omnicpp)
            idx += 1

PYTHON_EOF
endfunction
"}}}
" vim: fdm=marker fen et sw=4 sts=4 fdl=1
