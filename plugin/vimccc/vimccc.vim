" vimccc code completion plugin for videm
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-05-18
" Change:   2013-12-22

" ============================================================================
" VIMCCC 插件
" ============================================================================

" 工作区设置的控件字典
let s:ctls = {}

let s:enable = 0

let s:VIMCCCSettings = {
    \ '.videm.cc.vimccc.Enable'                     : 0,
    \ '.videm.cc.vimccc.ClangLibraryPath'           : '',
    \ '.videm.cc.vimccc.CompleteMacros'             : 0,
    \ '.videm.cc.vimccc.CompletePatterns'           : 0,
    \ '.videm.cc.vimccc.IgnoreCase'                 : &ignorecase,
    \ '.videm.cc.vimccc.MayCompleteDot'             : 1,
    \ '.videm.cc.vimccc.MayCompleteArrow'           : 1,
    \ '.videm.cc.vimccc.MayCompleteColon'           : 1,
    \ '.videm.cc.vimccc.ItemSelectionMode'          : 2,
    \ '.videm.cc.vimccc.MapReturnToDispCalltips'    : 1,
    \ '.videm.cc.vimccc.GotoDeclKey'                : '<C-p>',
    \ '.videm.cc.vimccc.GotoImplKey'                : '<C-]>',
    \ '.videm.cc.vimccc.AutoPopupMenu'              : 1,
    \ '.videm.cc.vimccc.AutoTriggerCharCount'       : 2,
\ }

let s:CompatSettings = {
    \ 'g:VIMCCC_ClangLibraryPath'         : '.videm.cc.vimccc.ClangLibraryPath',
    \ 'g:VIMCCC_CompleteMacros'           : '.videm.cc.vimccc.CompleteMacros',
    \ 'g:VIMCCC_CompletePatterns'         : '.videm.cc.vimccc.CompletePatterns',
    \ 'g:VIMCCC_IgnoreCase'               : '.videm.cc.vimccc.IgnoreCase',
    \ 'g:VIMCCC_MayCompleteDot'           : '.videm.cc.vimccc.MayCompleteDot',
    \ 'g:VIMCCC_MayCompleteArrow'         : '.videm.cc.vimccc.MayCompleteArrow',
    \ 'g:VIMCCC_MayCompleteColon'         : '.videm.cc.vimccc.MayCompleteColon',
    \ 'g:VIMCCC_ItemSelectionMode'        : '.videm.cc.vimccc.ItemSelectionMode',
    \ 'g:VIMCCC_MapReturnToDispCalltips'  : '.videm.cc.vimccc.MapReturnToDispCalltips',
    \ 'g:VIMCCC_GotoDeclarationKey'       : '.videm.cc.vimccc.GotoDeclKey',
    \ 'g:VIMCCC_GotoImplementationKey'    : '.videm.cc.vimccc.GotoImplKey',
    \ 'g:VIMCCC_AutoPopupMenu'            : '.videm.cc.vimccc.AutoPopupMenu',
    \ 'g:VIMCCC_TriggerCharCount'         : '.videm.cc.vimccc.AutoTriggerCharCount',
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
    call videm#settings#Init(s:VIMCCCSettings)
endfunction
"}}}
function! s:SID() "获取脚本 ID {{{2
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
let s:sid = s:SID()
let g:VLWScriptID = s:sid

function! s:GetSFuncRef(sFuncName) " 获取局部于脚本的函数的引用 {{{2
    let sFuncName = a:sFuncName =~ '^s:' ? a:sFuncName[2:] : a:sFuncName
    return function('<SNR>'.s:sid.'_'.sFuncName)
endfunction
"}}}

"{{{1
" 1. 进入不同的源文件时，切换不同的 clang index，以提供不同的补全
" 2. 更改项目的编译选项后，需要及时更新相应的 index 编译选项
"    可能改变的场合:
"       (1) 选择不同的工作区构建设置时
"       (2) 修改项目设置
"       (3) 修改工作区的 BuildMatrix
"    应该设置一个需要刷新选项的标识，现阶段通过 BufEnter 自动命令实现实时更新
" 3. 只有进入插入模式时，才开始更新翻译单元的线程
function! videm#plugin#vimccc#InitFacilities() "{{{2
    let g:VIMCCC_Enable = 1 " 保证初始化成功
    " 先初始化默认的 clang index
    let ret = vimccc#core#InitEarly()
    py OrigVIMCCCIndex = VIMCCCIndex
    let g:VIMCCC_Enable = 0 " 再禁用 VIMCCC
    return ret
endfunction
"}}}
" FileType 自动命令调用的函数，第一次初始化
function! s:VIMCCCInitExt() "{{{2
    let bak = g:VIMCCC_Enable
    let g:VIMCCC_Enable = 1

    let sFile = expand('%:p')
    let bool = 0
    py project = ws.VLWIns.GetProjectByFileName(vim.eval("sFile"))
    py if project: vim.command("let bool = 1")

    if bool

python << PYTHON_EOF
# 使用关联的 clang index
if ws.clangIndices.has_key(project.name):
    # 使用已经存在的
    VIMCCCIndex = ws.clangIndices[project.name]
    HandleHeaderIssue(vim.eval("sFile"))
else:
    # 新建并关联
    VIMCCCIndex = VIMClangCCIndex()
    UpdateVIMCCCIndexArgs(VIMCCCIndex, project.name)
    ws.clangIndices[project.name] = VIMCCCIndex
    HandleHeaderIssue(vim.eval("sFile"))
PYTHON_EOF

        " 稳当起见，先调用一次，这个函数对于多余的调用开销不大
        call s:UpdateClangCodeCompletion()
        " 同时安装 BufEnter 自动命令，以保持持续更新
        augroup VidemCCVIMCCC
            autocmd! BufEnter <buffer> call <SID>UpdateClangCodeCompletion()
        augroup END
    else
        " 文件不属于工作空间，不操作
        " 使用默认的 clang.cindex.Index
        py VIMCCCIndex = OrigVIMCCCIndex
    endif

    py del project

    call VIMCCCInit()
    let g:VIMCCC_Enable = bak
endfunction
"}}}
function! s:UpdateClangCodeCompletion() "{{{2
    let bNeedUpdate = 0
    py if ws.buildMTime >= VIMCCCIndex.GetArgsMTime():
            \ vim.command("let bNeedUpdate = 1")
    py projInst = ws.VLWIns.GetProjectByFileName(vim.eval("expand('%:p')"))
    py if not projInst: vim.command("return")
    " 把当前 index 设置为正确的实例
    py VIMCCCIndex = ws.clangIndices.get(projInst.name, OrigVIMCCCIndex)

    if bNeedUpdate
        py UpdateVIMCCCIndexArgs(VIMCCCIndex, projInst.name)
        " 启动异步更新线程，强制刷新
        "echom 'call UpdateClangCodeCompletion() at ' . string(localtime())
        py VIMCCCIndex.AsyncUpdateTranslationUnit(vim.eval("expand('%:p')"), 
                    \[VLGetCurUnsavedFile()], True, True)
    endif

    py del projInst
endfunction
"}}}
"}}}1
"{{{1
"标识用控件 ID {{{2
let s:ID_TagsSettingsIncludePaths = videm#wsp#TagsSettings_ID_SearchPaths

function! s:TagsSettings() "{{{2
    let dlg = s:CreateTagsSettingsDialog()
    call dlg.Display()
endfunction

function! s:SaveTagsSettingsCbk(dlg, data) "{{{2
    py ins = TagsSettingsST.Get()
    for ctl in a:dlg.controls
        if ctl.GetId() == s:ID_TagsSettingsIncludePaths
            py ins.includePaths = vim.eval("ctl.values")
        endif
    endfor
    " 保存
    py ins.Save()
    py del ins
endfunction

function! s:GetTagsSettingsHelpText() "{{{2
    let s = "Run the following command to get gcc search paths:\n"
    let s .= "  echo \"\" | gcc -v -x c++ -fsyntax-only -\n"
    return s
endfunction
"}}}
function! s:CreateTagsSettingsDialog() "{{{2
    let dlg = g:VimDialog.New('== VIMCCC Settings ==')
    call dlg.SetExtraHelpContent(s:GetTagsSettingsHelpText())
    py ins = TagsSettingsST.Get()

"===============================================================================
    " 公用的公共控件
    let ctls = Videm_GetTagsSettingsControls()
    for ctl in ctls
        call dlg.AddControl(ctl)
    endfor

    call dlg.ConnectSaveCallback(s:GetSFuncRef("s:SaveTagsSettingsCbk"), "")

    call dlg.AddFooterButtons()

    py del ins
    return dlg
endfunction
"}}}1
function! videm#plugin#vimccc#WspSetHook(event, data, priv) "{{{2
    let event = a:event
    let dlg = a:data
    let ctls = a:priv
    if event ==# 'create'
        let ctl = g:VCStaticText.New("VIMCCC Settings")
        call ctl.SetHighlight("Special")
        call dlg.AddControl(ctl)
        call dlg.AddBlankLine()

        " 头文件搜索路径
        let ctl = g:VCMultiText.New(
                \ "Add search paths for the vlctags and libclang parser:")
        let ctls['IncludePaths'] = ctl
        call ctl.SetIndent(4)
        py vim.command("let includePaths = %s" % ToVimEval(ws.VLWSettings.includePaths))
        call ctl.SetValue(includePaths)
        call ctl.ConnectButtonCallback(function("vlutils#EditTextBtnCbk"), "")
        call dlg.AddControl(ctl)

        let ctl = g:VCComboBox.New(
                \ "Use with Global Settings (Only For Search Paths):")
        let ctls['IncPathFlag'] = ctl
        call ctl.SetIndent(4)
        py vim.command("let lItems = %s" % ToVimEval(ws.VLWSettings.GetIncPathFlagWords()))
        for sI in lItems
            call ctl.AddItem(sI)
        endfor
        py vim.command("call ctl.SetValue(%s)" % 
                \ ToVimEval(ws.VLWSettings.GetCurIncPathFlagWord()))
        call dlg.AddControl(ctl)
        call dlg.AddBlankLine()
    elseif event ==# 'save' && !empty(ctls)
        py ws.VLWSettings.includePaths = vim.eval("ctls['IncludePaths'].values")
        py ws.VLWSettings.SetIncPathFlag(vim.eval("ctls['IncPathFlag'].GetValue()"))
    endif
endfunction
"}}}
function! s:ThisInit() "{{{2
    " 先设置模块目录
    let g:VIMCCC_PythonModulePath = g:VidemPyDir
    call s:InitPythonIterfaces()
    let ret = videm#plugin#vimccc#InitFacilities()
    if ret != 0
        " 初始化失败了
        return ret
    endif
    py VidemWorkspace.wsp_ntf.Register(VidemWspVIMCCCHook, 0, None)
    " 替换自动命令
    augroup VidemCCVIMCCC
        autocmd!
        autocmd! FileType c,cpp call <SID>VIMCCCInitExt()
    augroup END
    " 工作区设置
    call VidemWspSetCreateHookRegister('videm#plugin#vimccc#WspSetHook',
            \                          0, s:ctls)
    " 菜单
    anoremenu <silent> 200 &Videm.VIMCCC\ Settings\.\.\. 
            \ :call <SID>TagsSettings()<CR>
    command! -nargs=0 -bar VVIMCCCSettings  call <SID>TagsSettings()
endfunction
"}}}
function! videm#plugin#vimccc#SettingsHook(event, data, priv) "{{{2
    let event = a:event
    let opt = a:data['opt']
    let val = a:data['val']
    if event ==# 'set'
        if opt ==# '.videm.cc.vimccc.Enable'
            if val
                call videm#plugin#vimccc#Enable()
            else
                call videm#plugin#vimccc#Disable()
            endif
        endif
    endif
endfunction
"}}}
function! videm#plugin#vimccc#Init() "{{{2
    call s:InitSettings()
    call videm#settings#RegisterHook('videm#plugin#vimccc#SettingsHook', 0, 0)
    if videm#settings#Get('.videm.cc.vimccc.Enable', 0)
        call videm#plugin#vimccc#Enable()
    endif
endfunction
"}}}
function! videm#plugin#vimccc#HasEnabled() "{{{2
    return s:enable
endfunction
function! videm#plugin#vimccc#Enable() "{{{2
    if s:enable
        return
    endif
    let ret = s:ThisInit()
    if ret != 0
        call vlutils#EchoWarnMsg("Failed to initialize VIMCCC, disable")
        return ret
    endif
    let s:enable = 1
endfunction
"}}}
" 禁用插件时的动作
function! videm#plugin#vimccc#Disable() "{{{2
    if !s:enable
        return
    endif
    py VidemWorkspace.wsp_ntf.Unregister(VidemWspVIMCCCHook, 0)
    augroup VidemCCVIMCCC
        autocmd!
    augroup END
    silent! augroup! VidemCCVIMCCC
    call VidemWspSetCreateHookUnregister('videm#plugin#vimccc#WspSetHook', 0)
    aunmenu &Videm.VIMCCC\ Settings\.\.\.
    delcommand VVIMCCCSettings
    " 清理 python 全局数据
    py VIMCCCIndex = OrigVIMCCCIndex
    py ws.clangIndices.clear()
    call VIMCCCExit()
    let s:enable = 0
endfunction
"}}}
function! s:InitPythonIterfaces() "{{{2
python << PYTHON_EOF
'''定义一些 VIMCCC 专用的 python 函数'''
import sys
import os.path
from Utils import IsCppHeaderFile

def UpdateVIMCCCIndexArgs(iVIMCCCIndex, projName):
    '''\
    现在 clang 的补全没有区分是 C 还是 C++ 补全，所以获取的编译选项是 C 和 C++
    的编译选项的并集。

    VimLite 对项目的编译选项的假定是：
        所有 C 源文件都用相同的编译选项，所有的 C++ 源文件都用相同的编译选项
    所以，理论上，每个项目都要维护两个 clang index，一个用于 C，一个用于 C++，
    暂时没有实现，暂时只用一个，并且把 C 和 C++ 的编译选项合并，这在大多数场合都
    够用，先用着，以后再说。
'''
    # 参数过多可能会影响速度，有拖慢了 0.05s 的情况，暂时不明原因
    lArgs = []
    lArgs += ['-I%s' % i for i in ws.GetParserSearchPaths()]
    lArgs += ['-I%s' % i for i in ws.GetProjectIncludePaths4CodeComplete(projName)]
    lArgs += ['-D%s' % i for i in ws.GetProjectPredefineMacros4CodeComplete(projName)]
    # TODO: -U 也需要

    # 过滤重复行
    d = set()
    lTmpArgs = lArgs
    lArgs = []
    for sArg in lTmpArgs:
        if sArg in d:
            continue
        else:
            d.add(sArg)
            lArgs.append(sArg)

    iVIMCCCIndex.SetParseArgs(lArgs)

def VLGetCurUnsavedFile():
    return (vim.current.buffer.name,
            '\n'.join(vim.current.buffer[:]))

def HandleHeaderIssue(sHeaderFile):
    '''处理头文件的问题'''
    if IsCppHeaderFile(sHeaderFile):
        # 头文件的话，需要添加对应的源文件中在包含此头文件之前的所有包含语句内容
        swapFiles = ws.GetSHSwapList(sHeaderFile)
        if swapFiles:
            # 简单处理，只取第一个
            srcFile = swapFiles[0]
            vim.command("call VIMCCCSetRelatedFile(%s)" % ToVimEval(srcFile))

def VidemWspVIMCCCHook(event, wsp, ins):
    if   event == 'open_post':
        pass
    elif event == 'close_post':
        pass
    return Notifier.OK

PYTHON_EOF
endfunction
"}}}
" vim: fdm=marker fen et sw=4 sts=4 fdl=1
