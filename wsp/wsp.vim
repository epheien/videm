" Vim global plugin for handle videm workspace
" Author:   fanhe <fanhed@163.com>
" License:  This file is placed in the public domain.
" Create:   2011-03-18
" Change:   2013-12-22

if exists("g:loaded_autoload_wsp")
    finish
endif
let g:loaded_autoload_wsp = 1

" 先设置 python 脚本编码
python << PYTHON_EOF
# -*- encoding: utf-8 -*-
PYTHON_EOF

" 用于初始化
function! videm#wsp#Init()
    return 1
endfunction

" 本脚本的绝对路径
let s:sfile = expand('<sfile>:p')
function! videm#wsp#SFunPrefix()
    return printf("<SNR>%d_", s:sid)
endfunction

let s:os = vlutils#os

" 载入的插件
let s:loaded_plugins = []

" Plug map example
"if !hasmapto('<Plug>TypecorrAdd')
"   map <unique> <Leader>a  <Plug>TypecorrAdd
"endif
"noremap <unique> <script> <Plug>TypecorrAdd  <SID>Add

" 初始化变量仅在变量没有定义时才赋值，var 必须是合法的变量名
function! s:InitVariable(var, value, ...) "{{{2
    let force = a:0 > 0 ? a:1 : 0
    if force || !exists(a:var)
        if exists(a:var)
            unlet {a:var}
        endif
        let {a:var} = a:value
    endif
endfunction
"}}}2

" 模拟 C 的枚举值，li 是列表，元素是枚举名字
function! s:InitEnum(li, n) "{{{2
    let n = a:n
    for i in a:li
        let {i} = n
        let n += 1
    endfor
endfunction
"}}}2


" 新的命名规范
let g:videm_dir = s:os.path.join(
        \   s:os.path.dirname(s:os.path.dirname(s:os.path.dirname(s:sfile))),
        \   '_videm')
let g:videm_pydir = s:os.path.join(g:videm_dir, 'core')

" 后向兼容
let g:VidemDir = g:videm_dir
let g:VidemPyDir = g:videm_pydir

" 如果这个选项为零，所有后向兼容的选项都失效
if !videm#settings#Has('.videm.Compatible')
    call videm#settings#Set('.videm.Compatible', 1)
endif

call s:InitVariable("g:VLWorkspaceWinSize", 30)
call s:InitVariable("g:VLWorkspaceWinPos", "left")
call s:InitVariable("g:VLWorkspaceBufName", '== VidemWorkspace ==')
call s:InitVariable("g:VLWorkspaceShowLineNumbers", 0)
call s:InitVariable("g:VLWorkspaceHighlightCursorline", 1)
" 若为 1，编辑项目文件时，在工作空间的光标会自动定位到对应的文件所在的行
call s:InitVariable('g:VLWorkspaceLinkToEidtor', 1)
call s:InitVariable('g:VLWorkspaceEnableMenuBarMenu', 1)
call s:InitVariable('g:VLWorkspaceEnableToolBarMenu', 1)
call s:InitVariable('g:VLWorkspaceDispWspNameInTitle', 1)
call s:InitVariable('g:VLWorkspaceSaveAllBeforeBuild', 0)
call s:InitVariable('g:VLWorkspaceHighlightSourceFile', 1)
call s:InitVariable('g:VLWorkspaceActiveProjectHlGroup', 'SpecialKey')

"=======================================
" 标记是否已经运行
call s:InitVariable("g:VLWorkspaceHasStarted", 0)

" 模板所在路径
call s:InitVariable("g:VLWorkspaceTemplatesPath",
        \           s:os.path.join(g:VidemDir, 'templates', 'projects'))

" 工作区文件后缀名
call s:InitVariable("g:VLWorkspaceWspFileSuffix", "vlworkspace")
" 项目文件后缀名
call s:InitVariable("g:VLWorkspacePrjFileSuffix", "vlproject")

" ============================================================================
" 后向兼容选项处理
"{{{
if exists('g:VLWorkspaceUseVIMCCC') && g:VLWorkspaceUseVIMCCC
    let g:VLWorkspaceCodeCompleteEngine = 'vimccc'
endif
function! s:RefreshBackwardOptions() "{{{2
    if      g:VLWorkspaceCodeCompleteEngine == 'omnicpp'
        call videm#settings#Set('.videm.cc.vimccc.Enable', 0)
        call videm#settings#Set('.videm.cc.omnicpp.Enable', 1)
        call videm#settings#Set('.videm.cc.Current', 'omnicpp')
    elseif  g:VLWorkspaceCodeCompleteEngine == 'vimccc'
        call videm#settings#Set('.videm.cc.omnicpp.Enable', 0)
        call videm#settings#Set('.videm.cc.vimccc.Enable', 1)
        call videm#settings#Set('.videm.cc.Current', 'vimccc')
    else
        call videm#settings#Set('.videm.cc.vimccc.Enable', 0)
        call videm#settings#Set('.videm.cc.omnicpp.Enable', 0)
        call videm#settings#Set('.videm.cc.Current', '')
    endif

    if type(g:VLWorkspaceSymbolDatabase) == type('')
        if g:VLWorkspaceSymbolDatabase ==? 'cscope'
            call videm#settings#Set('.videm.symdb.gtags.Enable', 0)
            call videm#settings#Set('.videm.symdb.cscope.Enable', 1)
            call videm#settings#Set('.videm.symdb.Current', 'cscope')
        elseif g:VLWorkspaceSymbolDatabase ==? 'gtags'
            call videm#settings#Set('.videm.symdb.cscope.Enable', 0)
            call videm#settings#Set('.videm.symdb.gtags.Enable', 1)
            call videm#settings#Set('.videm.symdb.Current', 'gtags')
        else
            call videm#settings#Set('.videm.symdb.gtags.Enable', 0)
            call videm#settings#Set('.videm.symdb.cscope.Enable', 0)
            call videm#settings#Set('.videm.symdb.Current', '')
        endif
    else
        if g:VLWorkspaceSymbolDatabase == 1
            call videm#settings#Set('.videm.symdb.gtags.Enable', 0)
            call videm#settings#Set('.videm.symdb.cscope.Enable', 1)
            call videm#settings#Set('.videm.symdb.Current', 'cscope')
        elseif g:VLWorkspaceSymbolDatabase == 2
            call videm#settings#Set('.videm.symdb.cscope.Enable', 0)
            call videm#settings#Set('.videm.symdb.gtags.Enable', 1)
            call videm#settings#Set('.videm.symdb.Current', 'gtags')
        else
            call videm#settings#Set('.videm.symdb.gtags.Enable', 0)
            call videm#settings#Set('.videm.symdb.cscope.Enable', 0)
            call videm#settings#Set('.videm.symdb.Current', '')
        endif
    endif
endfunction
"}}}
"}}}

let s:DefaultSettings = {
    \ '.videm.wsp.WinSize'          : 30,
    \ '.videm.wsp.WinPos'           : 'left',
    \ '.videm.wsp.BufName'          : '== VidemWorkspace ==',
    \ '.videm.wsp.ShowLineNum'      : 0,
    \ '.videm.wsp.HlCursorLine'     : 1,
    \ '.videm.wsp.LinkToEditor'     : 1,
    \ '.videm.wsp.EnableMenuBar'    : 1,
    \ '.videm.wsp.EnablePopUpMenu'  : 1,
    \ '.videm.wsp.EnableToolBar'    : 1,
    \ '.videm.wsp.ShowWspName'      : 1,
    \ '.videm.wsp.SaveBeforeBuild'  : 1,
    \ '.videm.wsp.HlSourceFile'     : 1,
    \ '.videm.wsp.ActProjHlGroup'   : 'SpecialKey',
    \ '.videm.wsp.ShowBriefHelp'    : 1,
    \ '.videm.wsp.AutoSession'      : 0,
    \ '.videm.wsp.SessionOptions'   : 'buffers,curdir,folds,help,localoptions,tabpages,winsize,resize',
    \
    \ '.videm.wsp.keybind.ShowMenu'         : '.',
    \ '.videm.wsp.keybind.PopupMenu'        : ',',
    \ '.videm.wsp.keybind.OpenNode'         : 'o',
    \ '.videm.wsp.keybind.OpenNode2'        : 'go',
    \ '.videm.wsp.keybind.OpenNodeNewTab'   : 't',
    \ '.videm.wsp.keybind.OpenNodeNewTab2'  : 'T',
    \ '.videm.wsp.keybind.OpenNodeSplit'    : 'i',
    \ '.videm.wsp.keybind.OpenNodeSplit2'   : 'gi',
    \ '.videm.wsp.keybind.OpenNodeVSplit'   : 's',
    \ '.videm.wsp.keybind.OpenNodeVSplit2'  : 'gs',
    \ '.videm.wsp.keybind.GotoParent'       : 'p',
    \ '.videm.wsp.keybind.GotoRoot'         : 'P',
    \ '.videm.wsp.keybind.GotoNextSibling'  : '<C-n>',
    \ '.videm.wsp.keybind.GotoPrevSibling'  : '<C-p>',
    \ '.videm.wsp.keybind.RefreshBuffer'    : 'R',
    \ '.videm.wsp.keybind.ToggleHelpInfo'   : '<F1>',
    \ '.videm.wsp.keybind.CutOneNode'       : 'dd',
    \ '.videm.wsp.keybind.CutNodes'         : 'd',
    \ '.videm.wsp.keybind.PasteNodes'       : '<C-v>',
    \
    \ '.videm.cc.Current'       : 'omnicpp',
    \ '.videm.symdb.Current'    : 'gtags',
    \
    \ 
    \ '.videm.symdb.Quickfix'               : 1,
\ }

let s:CompatSettings = {
    \ 'g:VLWorkspaceWinSize'                : '.videm.wsp.WinSize',
    \ 'g:VLWorkspaceWinPos'                 : '.videm.wsp.WinPos',
    \ 'g:VLWorkspaceBufName'                : '.videm.wsp.BufName',
    \ 'g:VLWorkspaceShowLineNumbers'        : '.videm.wsp.ShowLineNum',
    \ 'g:VLWorkspaceHighlightCursorline'    : '.videm.wsp.HlCursorLine',
    \ 'g:VLWorkspaceLinkToEidtor'           : '.videm.wsp.LinkToEditor',
    \ 'g:VLWorkspaceEnableMenuBarMenu'      : '.videm.wsp.EnableMenuBar',
    \ 'g:VLWorkspaceEnableToolBarMenu'      : '.videm.wsp.EnableToolBar',
    \ 'g:VLWorkspaceDispWspNameInTitle'     : '.videm.wsp.ShowWspName',
    \ 'g:VLWorkspaceSaveAllBeforeBuild'     : '.videm.wsp.SaveBeforeBuild',
    \ 'g:VLWorkspaceHighlightSourceFile'    : '.videm.wsp.HlSourceFile',
    \ 'g:VLWorkspaceActiveProjectHlGroup'   : '.videm.wsp.ActProjHlGroup',
    \
    \ 'g:VLWShowMenuKey'            : '.videm.wsp.keybind.ShowMenu',
    \ 'g:VLWPopupMenuKey'           : '.videm.wsp.keybind.PopupMenu',
    \ 'g:VLWOpenNodeKey'            : '.videm.wsp.keybind.OpenNode',
    \ 'g:VLWOpenNode2Key'           : '.videm.wsp.keybind.OpenNode2',
    \ 'g:VLWOpenNodeInNewTabKey'    : '.videm.wsp.keybind.OpenNodeNewTab',
    \ 'g:VLWOpenNodeInNewTab2Key'   : '.videm.wsp.keybind.OpenNodeNewTab2',
    \ 'g:VLWOpenNodeSplitKey'       : '.videm.wsp.keybind.OpenNodeSplit',
    \ 'g:VLWOpenNodeSplit2Key'      : '.videm.wsp.keybind.OpenNodeSplit2',
    \ 'g:VLWOpenNodeVSplitKey'      : '.videm.wsp.keybind.OpenNodeVSplit',
    \ 'g:VLWOpenNodeVSplit2Key'     : '.videm.wsp.keybind.OpenNodeVSplit2',
    \ 'g:VLWGotoParentKey'          : '.videm.wsp.keybind.GotoParent',
    \ 'g:VLWGotoRootKey'            : '.videm.wsp.keybind.GotoRoot',
    \ 'g:VLWGotoNextSibling'        : '.videm.wsp.keybind.GotoNextSibling',
    \ 'g:VLWGotoPrevSibling'        : '.videm.wsp.keybind.GotoPrevSibling',
    \ 'g:VLWRefreshBufferKey'       : '.videm.wsp.keybind.RefreshBuffer',
    \ 'g:VLWToggleHelpInfo'         : '.videm.wsp.keybind.ToggleHelpInfo',
\ }

" 这些是需要反转来使用的选项，设置的时候支持已新选项的方式设置
let s:InverseCompatSettings = {
    \ 'g:VLWorkspaceSymbolDatabase'     : '.videm.wsp.SymbolDatabase',
    \ 'g:VLWorkspaceCodeCompleteEngine' : '.videm.wsp.CodeCompleteEngine',
    \
    \ 'g:VLCalltips_DispCalltipsKey'    : '.videm.common.calltips.DispCalltipsKey',
    \ 'g:VLCalltips_NextCalltipsKey'    : '.videm.common.calltips.NextCalltipsKey',
    \ 'g:VLCalltips_PrevCalltipsKey'    : '.videm.common.calltips.PrevCalltipsKey',
    \ 'g:VLCalltips_IndicateArgument'   : '.videm.common.calltips.IndicateArgument',
    \ 'g:VLCalltips_EnableSyntaxTest'   : '.videm.common.calltips.EnableSyntaxTest',
\ }

" ============================================================================
" 工作区可局部配置的信息 {{{1
let s:WspConfTmpl = {
\ }

" 需要重启的选项
let s:WspConfTmplRestart = {
\ }

" 备份的设置，一般用于保存全局的配置
let s:WspConfBakp = {}
let g:WspConfBakp = s:WspConfBakp

function! videm#wsp#SettingsHook(event, data, priv) "{{{2
    let event = a:event
    let opt = a:data['opt']
    let val = a:data['val']
    let refresh = a:priv

    " 只处理 'set' 事件
    if event !=# 'set'
        return
    endif

    let prefix = ''
    if opt ==# '.videm.cc.Current'
        let prefix = '.videm.cc'
    elseif opt ==# '.videm.symdb.Current'
        let prefix = '.videm.symdb'
    endif

    let li = s:GetAlterList(prefix)
    if empty(prefix) || empty(li)
        return
    endif

    for name in li
        if name !=# val
            " 先禁用其他同类的插件
            let key = printf("%s.%s.Enable", prefix, name)
            call videm#settings#Set(key, 0, refresh)
        endif
    endfor

    " 如果这种选项置为空的话, 表示全部禁用
    if !empty(val)
        " 最后启用指定的插件
        let key = printf("%s.%s.Enable", prefix, val)
        call videm#settings#Set(key, 1, refresh)
    endif
endfunction
"}}}
" 从配置文本读取配置
function! videm#wsp#WspConfSetCurrFromText(conftext, ...) "{{{2
    let conftext = a:conftext
    let refresh = get(a:000, 0, 1)

    let conf = {}
    let texts = split(conftext, "\n")
    for sLine in texts
        " 支持行注释
        if sLine =~# '^\s*#'
            continue
        endif

        " 行末注释只支持 '\s#.*$'
        let sOrigLine = sLine
        let sLine = substitute(sLine, '\s#.*$', '', 'g')

        let li = split(sLine, '\s*=\s*')
        if len(li) == 2
            try
                exec 'let conf[li[0]] =' li[1]
            catch /.*/
                call s:echow(printf('Syntax Error: %s', sOrigLine))
            endtry
        else
            call s:echow(printf('Syntax Error: %s', sOrigLine))
        endif
    endfor

    return videm#wsp#WspConfSetCurr(conf, refresh)
endfunction
"}}}
function! videm#wsp#WspConfSetCurr(conf, ...) "{{{2
    let refresh = get(a:000, 0, 1)
    let conf = a:conf

    " 排序，先处理禁用的，再处理启用的
    let pres = []
    let posts = []
    for opt in keys(conf)
        " NOTE: 需要遵守这个约定: 'xxx.Enable' 选项
        if opt =~? '\.Enable$' && conf[opt]
            call add(posts, opt)
        else
            call add(pres, opt)
        endif
    endfor

    let all = pres + posts

    " 后向兼容处理
    let old_opts = {
        \ '.videm.cc.omnicpp.Enable'    : 1,
        \ '.videm.cc.vimccc.Enable'     : 1,
        \ '.videm.symdb.cscope.Enable'  : 1,
        \ '.videm.symdb.gtags.Enable'   : 1,
    \ }
    let found_old = 0

    for opt in all
        " 只允许设置指定的选项
        if has_key(s:WspConfTmpl, opt)
            let val = conf[opt]
            call videm#settings#Set(opt, val, refresh)
        elseif has_key(old_opts, opt)
            let found_old = 1
            let val = conf[opt]
            " 后向兼容处理
            let lst = split(opt, '\.')
            let optx = printf('.videm.%s.Current', lst[1])
            let valx = lst[2]
            if val
                call videm#settings#Set(optx, valx)
            else
                call videm#settings#Set(optx, '')
            endif
        endif
    endfor

    if found_old
        " 显示转换选项帮助
        echohl WarningMsg
        echo '"Workspace Settings..." has updated, please update your old config.'
        echo 'Please read the "Extra Help" of "Workspace Settings" for more information.'
        echo 'Press any key to continue...'
        echohl None
        call getchar()
    endif
endfunction
"}}}
function! videm#wsp#WspOptRegister(opt, val) "{{{2
    let s:WspConfTmpl[a:opt] = a:val
endfunction
"}}}
function! videm#wsp#WspRestartOptRegister(opt) "{{{2
    let s:WspConfTmplRestart[a:opt] = ''
endfunction
"}}}
function! videm#wsp#WspOptUnregister(opt) "{{{2
    if has_key(s:WspConfTmpl, a:opt)
        unlet s:WspConfTmpl[a:opt]
    endif
endfunction
"}}}
" 还原为全局配置
function! videm#wsp#WspConfRestore(...) "{{{2
    let refresh = get(a:000, 0, 1)
    call videm#wsp#WspConfSetCurr(s:WspConfBakp, refresh)
endfunction
"}}}
" 直接往 a:conf 添加，调用着保证 a:conf 的纯净
function! videm#wsp#WspConfSave(conf) "{{{2
    for key in keys(s:WspConfTmpl)
        let a:conf[key] = videm#settings#Get(key)
    endfor
endfunction
"}}}
"}}}
" ============================================================================
" 新老选项优先级问题
" 1、如果 '.videm.Compatible' 非零，则老选项优先，否则参考2
" 2、如果需要反转的选项的新老选项同时设置，那么新选项优先，会无条件把新选项的
"    值赋予老选项。需要反转的选项无法通过设置新选项的方式实时刷新老选项
function! s:InitInverseCompatSettings() "{{{2
    for [oldopt, newopt] in items(s:InverseCompatSettings)
        if videm#settings#Has(newopt)
            let {oldopt} = videm#settings#Get(newopt)
        endif
    endfor

    " 特殊处理这两个历史选项
    " 0 -> none, 1 -> cscope, 2 -> global tags
    call s:InitVariable('g:VLWorkspaceSymbolDatabase', 'cscope')

    " 补全引擎选择，'none', 'omnicpp', 'vimccc'
    call s:InitVariable("g:VLWorkspaceCodeCompleteEngine", 'omnicpp')
endfunction
"}}}2
function! s:InitCompatSettings() "{{{2
    for item in items(s:CompatSettings)
        if !exists(item[0])
            continue
        endif
        call videm#settings#Set(item[1], {item[0]})
    endfor
    call s:RefreshBackwardOptions()
endfunction
"}}}2
function! s:InitUserSettings() "{{{2
    if !(exists('g:videm_user_options') && type(g:videm_user_options) == type({}))
        return 1
    endif

    for [key, val] in items(g:videm_user_options)
        call videm#settings#Set(key, val)
    endfor
    return 0
endfunction
"}}}2
function! s:InitSettings() "{{{2
    if videm#settings#Get('.videm.Compatible')
        call s:InitCompatSettings()
    endif
    call videm#settings#Init(s:DefaultSettings)
endfunction
"}}}2

" ============================================================================
" 标识是否第一次初始化
let s:bHadInited = 0

function! g:VLWGetAllFiles() "{{{2
    let files = []
    if g:VLWorkspaceHasStarted
        " FIXME: Windows 下，所有反斜扛(\)加倍，因为 python 输出 '\\'
        py vim.command('let files = %s' 
                    \% [i.encode('utf-8') for i in ws.VLWIns.GetAllFiles(True)])
    endif
    return files
endfunction
"}}}

" ============================================================================
" 基本实用函数
" ============================================================================
"{{{1
function! s:SID() "获取脚本 ID {{{2
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
let s:sid = s:SID()
let g:VLWScriptID = s:sid

function! s:GetSFuncRef(sFuncName) " 获取局部于脚本的函数的引用 {{{2
    let sFuncName = a:sFuncName =~ '^s:' ? a:sFuncName[2:] : a:sFuncName
    return function('<SNR>'.s:sid.'_'.sFuncName)
endfunction

function! s:echow(msg) "显示警告信息 {{{2
    echohl WarningMsg | echomsg a:msg | echohl None
endfunction

function! s:exec(cmd) "忽略所有事件运行 cmd {{{2
    let bak_ei = &ei
    set eventignore=all
    exec a:cmd
    let &ei = bak_ei
endfunction


function! s:OpenFile(sFile, ...) "优雅地打开一个文件 {{{2
    let sFile = a:sFile
    if sFile ==# ''
        return
    endif

    let bKeepCursorPos = 0
    if a:0 > 0
        let bKeepCursorPos = a:1
    endif

    let bNeedResizeWspWin = (winnr('$') == 1)

    let bak_splitright = &splitright
    if g:VLWorkspaceWinPos ==? 'left'
        set splitright
    else
        set nosplitright
    endif
    call vlutils#OpenFile(sFile, bKeepCursorPos)
    let &splitright = bak_splitright

    let nWspWinNr = bufwinnr('^'.g:VLWorkspaceBufName.'$')
    if bNeedResizeWspWin && nWspWinNr != -1
        exec 'vertical' nWspWinNr 'resize' g:VLWorkspaceWinSize
    endif

    if bKeepCursorPos
        call vlutils#Exec(nWspWinNr.'wincmd w')
    endif
endfunction


function! s:OpenFileInNewTab(sFile, ...) "{{{2
    let sFile = a:sFile
    let bKeepCursorPos = 0
    if a:0 > 0
        let bKeepCursorPos = a:1
    endif

    call vlutils#OpenFileInNewTab(sFile, bKeepCursorPos)
endfunction


function! s:OpenFileSplit(sFile, ...) "{{{2
    let sFile = a:sFile
    let bKeepCursorPos = 0
    if a:0 > 0
        let bKeepCursorPos = a:1
    endif

    call vlutils#OpenFileSplit(sFile, bKeepCursorPos)
endfunction


function! s:OpenFileVSplit(sFile, ...) "{{{2
    let sFile = a:sFile
    let bKeepCursorPos = 0
    if a:0 > 0
        let bKeepCursorPos = a:1
    endif

    let bak_splitright = &splitright
    if g:VLWorkspaceWinPos ==? 'left'
        set splitright
    else
        set nosplitright
    endif

    let bNeedResizeWspWin = (winnr('$') == 1)
    if bNeedResizeWspWin
        call s:OpenFile(sFile, bKeepCursorPos)
    else
        call vlutils#OpenFileVSplit(sFile, bKeepCursorPos)
    endif

    let &splitright = bak_splitright
endfunction


function! s:StripMultiPathSep(sPath) "{{{2
    if vlutils#IsWindowsOS()
        return substitute(a:sPath, '\\\+', '\\', 'g')
    else
        return substitute(a:sPath, '/\+', '/', 'g')
    endif
endfunction
"}}}1
" ============================================================================
" ============================================================================

" ============================================================================
" 缓冲区与窗口操作
" ============================================================================
"{{{1
" 各种检查，返回 0 表示失败，否则返回 1
function! s:SanityCheck() "{{{2
    " 这个特性在有些环境比较难实现
    "if g:VLWorkspaceCodeCompleteEngine ==? 'vimccc' && empty(v:servername)
        "call s:echow("Please start vim as server")
        "call s:echow("eg. vim --servername {name}")
        "return 0
    "endif

    return 1
endfunction
"}}}
function! VLWStatusLine() "{{{2
    return printf('%s[%s]', GetWspName(), GetWspConfName())
endfunction
"}}}2
function! videm#wsp#InitWorkspace(sWspFile) "{{{2
    call s:InitVLWorkspace(a:sWspFile)
endfunction
"}}}2
function! videm#wsp#IsStarted() "{{{2
    return g:VLWorkspaceHasStarted
endfunction
"}}}
" 获取多选一的一个列表, 如从 '.wsp.cc' 选出 'omnicpp', 'omnicxx', 'vimccc'
function! s:GetAlterList(opt) "{{{2
    let opt = a:opt

    try
        let li = keys(videm#settings#Get(opt))
    catch /.*/
        let li = []
    endtry

    let result = []
    for o in li
        if videm#settings#Has(printf("%s.%s.Enable", opt, o))
            " 有 o.Enable 键的话就认为有这个选项
            call add(result, o)
        endif
    endfor

    return result
endfunction
"}}}
let s:OnceInit = 0
" 这个函数只初始化一次，无论调用多少次
function! s:OnceInit() "{{{2
    if s:OnceInit
        return 1
    endif

    " 初始化 vimdialog
    call vimdialog#Init()

    " 初始化所有 python 接口
    call s:InitPythonInterfaces()

    " 先清空用到的自动组
    augroup VLWorkspace
        autocmd!
    augroup END

    " 初始化用户的选项
    call s:InitUserSettings()
    " 需要反转使用的选项
    call s:InitInverseCompatSettings()
    " 初始化配置
    call s:InitSettings()

    if videm#settings#Get('.videm.wsp.EnableMenuBar')
        " 添加菜单栏菜单
        call s:InstallMenuBarMenu()
    endif

    if videm#settings#Get('.videm.wsp.EnableToolBar')
        " 添加工具栏菜单
        call s:InstallToolBarMenu()
    endif

    if videm#settings#Get('.videm.wsp.EnablePopUpMenu')
        " 添加右键弹出菜单
        call s:InstallPopUpMenu()
    endif

    " 安装命令
    call s:InstallCommands()

    " 安装自动命令
    augroup VLWorkspace
        autocmd Syntax dbgvar nnoremap <buffer> 
                    \<CR> :exec "Cfoldvar " . line(".")<CR>
        autocmd Syntax dbgvar nnoremap <buffer> 
                    \<2-LeftMouse> :exec "Cfoldvar " . line(".")<CR>
        autocmd Syntax dbgvar nnoremap <buffer> 
                    \dd :exec "Cdelvar" matchstr(getline('.'),
                    \   '^[^a-zA-Z_]\{3} \zsvar\d\+')<CR>
                    "\   '^\(\[[-+]\]\| \* \)\s*\zsvar\d\+')<CR> " FIXME: BUG

        autocmd Syntax dbgvar nnoremap <silent> <buffer> 
                    \p :call search('^'.repeat(' ',
                    \   len(matchstr(getline('.'), '^.\{-1,}[-+*]'))-2-2)
                    \.'.[-+*]', 'bcW')<CR>

        autocmd BufReadPost         * call <SID>Autocmd_WorkspaceEditorOptions()
        autocmd BufEnter            * call <SID>Autocmd_LocateCurrentFile()
        autocmd SessionLoadPost     * call videm#wsp#InitWorkspace('')
        " NOTE: 现在vim退出的时候，不会先把工作空间关掉，所以需要这个自动命令
        autocmd VimLeavePre         * call s:AutoSaveSession()
    augroup END

    " 设置标题栏
    if videm#settings#Get('.videm.wsp.ShowWspName')
        set titlestring=%(<%{GetWspName()}>\ %)%t%(\ %M%)
                \%(\ (%{expand(\"%:~:h\")})%)%(\ %a%)%(\ -\ %{v:servername}%)
    endif

    " 这几个全局变量是常驻的，因为插件会引用到
    py ws = VimLiteWorkspace()
    " 以后统一使用 videm
    py videm.wsp = ws
    py videm.org.cpp = ws

    " 载入插件，应该在初始化所有公共设施后、初始化任何工作区实例前执行
    call s:LoadPlugin()

    " 载入插件后, 再注册 Current 选项
    call videm#wsp#WspOptRegister('.videm.cc.Current',
            \                     join(s:GetAlterList('.videm.cc'), '|'))
    call videm#wsp#WspOptRegister('.videm.symdb.Current',
            \                     join(s:GetAlterList('.videm.symdb'), '|'))
    call videm#wsp#WspRestartOptRegister('.videm.cc.Current')
    call videm#settings#RegisterHook('videm#wsp#SettingsHook', 0, 1)
    " 注册了hook后刷新一次这个选项, 可能会产生抖动,
    " 因为有些插件经历了启用后再禁用, 现时工作区未打开, 插件应该检查这一状况
    call videm#settings#Set('.videm.cc.Current',
            \               videm#settings#Get('.videm.cc.Current'))
    call videm#settings#Set('.videm.symdb.Current',
            \               videm#settings#Get('.videm.symdb.Current'))

    let s:OnceInit = 1
endfunction
"}}}
" 入口
function! s:InitVLWorkspace(file) " 初始化 {{{2
    let sFile = a:file

    if !s:SanityCheck()
        " 检查不通过
        echohl ErrorMsg
        echomsg "SanityCheck failed! Please fix it up."
        echohl None
        call getchar()
        return
    endif

    let bNeedConvertWspFileFormat = 0
    if !empty(sFile)
        if fnamemodify(sFile, ":e") ==? 'workspace'
            let bNeedConvertWspFileFormat = 1
        elseif fnamemodify(sFile, ":e") !=? g:VLWorkspaceWspFileSuffix
            call s:echow("Is it a valid workspace file?")
            return
        endif

        if !filereadable(sFile)
            call s:echow("Can not read the file: " . sFile)
            return
        endif
    endif

    " 如果之前已经启动过，而现在 sFile 为空的话，直接打开原来的缓冲区即可
    if sFile ==# '' && g:VLWorkspaceHasStarted
        py ws.CreateWindow()
        py ws.SetupStatusLine()
        return
    endif

    " 如果之前启动过，无论如何都要先关了旧的
    if g:VLWorkspaceHasStarted
        py ws.CloseWorkspace()
    endif

    " 开始
    let g:VLWorkspaceHasStarted = 1

    " 设施初始化
    call s:OnceInit()

    if bNeedConvertWspFileFormat
        " 老格式的 workspace, 提示转换格式
        echo "This workspace file is an old format file!"
        echohl Question
        echo "Are you willing to convert all files to new format?"
        echohl WarningMsg
        echo "NOTE1: Recommend 'yes'."
        echo "NOTE2: It will not change original files."
        echo "NOTE3: It will override existing Videm's workspace and "
                \ . "project files."
        echohl Question
        let sAnswer = input("(y/n): ")
        echohl None
        if sAnswer =~? '^y'
            py VLWorkspace.ConvertWspFileToNewFormat(vim.eval('sFile'))
            let sFile = fnamemodify(sFile, ':r') . '.' 
                        \. g:VLWorkspaceWspFileSuffix
            redraw
            echo 'Done. Press any key to continue...'
            call getchar()
        endif
    endif

    " 备份全局配置，这个动作要在载入所有插件之后
    call videm#wsp#WspConfSave(s:WspConfBakp)

    " 打开工作区文件，初始化全局变量
    py ws = VimLiteWorkspace()
    " 以后统一使用 videm
    py videm.wsp = ws
    py videm.org.cpp = ws
    py ws.OpenWorkspace(vim.eval('sFile'))
    py ws.RefreshBuffer()
    if videm#settings#Get('.videm.wsp.ShowBriefHelp')
        call s:ToggleBriefHelp()
    endif

    " 用于项目设置的全局变量
    py g_projects = {}
    py g_settings = {}
    py g_bldConfs = {}
    py g_glbBldConfs = {}

    " 重置帮助信息开关
    let b:bHelpInfoOn = 0

    setlocal nomodifiable

    let s:bHadInited = 1
endfunction
"}}}
" *DEPRECATED*
function! GetWspName() "{{{2
    py vim.command("return %s" % ToVimEval(ws.VLWIns.name))
endfunction
"}}}
function! GetWspConfName() "{{{2
    py vim.command("return %s" % ToVimEval(ws.cache_confName))
endfunction
"}}}
" 创建窗口，会确保一个标签页只打开一个工作空间窗口
function! s:CreateVLWorkspaceWin() "{{{2
    "create the workspace window
    let splitMethod = g:VLWorkspaceWinPos ==? "left" ? "topleft " : "botright "
    let splitSize = g:VLWorkspaceWinSize

    if !exists('t:VLWorkspaceBufName')
        let t:VLWorkspaceBufName = g:VLWorkspaceBufName
        silent! exec splitMethod . 'vertical ' . splitSize . ' new'
        silent! exec "edit" fnameescape(t:VLWorkspaceBufName)
    else
        if bufwinnr(t:VLWorkspaceBufName) != -1
            " 缓冲区已经打开并可见，跳过去即可
            exec bufwinnr(t:VLWorkspaceBufName) 'wincmd w'
        else
            " 缓冲区隐藏了，重新打开
            silent! exec splitMethod . 'vertical ' . splitSize . ' split'
            silent! exec "buffer" fnameescape(t:VLWorkspaceBufName)
        endif
    endif

    setlocal winfixwidth

    "throwaway buffer options
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal nowrap
    setlocal foldcolumn=0
    setlocal nobuflisted
    setlocal nospell
    if g:VLWorkspaceShowLineNumbers
        setlocal nu
    else
        setlocal nonu
    endif

    "删除所有插入模式的缩写
    iabc <buffer>

    if g:VLWorkspaceHighlightCursorline
        setlocal cursorline
    endif

    setfiletype vlworkspace
endfunction


function! s:SetupKeyMappings() "设置键盘映射 {{{2
    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.ShowMenu')
            \ ':call <SID>ShowMenu()<CR>'

    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.PopupMenu')
            \ ':call <SID>OnRightMouseClick()<CR>'

    nnoremap <silent> <buffer> <2-LeftMouse> :call <SID>OnMouseDoubleClick()<CR>
    nnoremap <silent> <buffer> <CR> :call <SID>OnMouseDoubleClick()<CR>

    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.OpenNode')
            \ ':call <SID>OnMouseDoubleClick(g:VLWOpenNodeKey)<CR>'
    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.OpenNode2')
            \ ':call <SID>OnMouseDoubleClick(g:VLWOpenNode2Key)<CR>'

    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.OpenNodeNewTab')
            \ ':call <SID>OnMouseDoubleClick(g:VLWOpenNodeInNewTabKey)<CR>'
    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.OpenNodeNewTab2')
            \ ':call <SID>OnMouseDoubleClick(g:VLWOpenNodeInNewTab2Key)<CR>'

    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.OpenNodeSplit')
            \ ':call <SID>OnMouseDoubleClick(g:VLWOpenNodeSplitKey)<CR>'
    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.OpenNodeSplit2')
            \ ':call <SID>OnMouseDoubleClick(g:VLWOpenNodeSplit2Key)<CR>'

    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.OpenNodeVSplit')
            \ ':call <SID>OnMouseDoubleClick(g:VLWOpenNodeVSplitKey)<CR>'
    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.OpenNodeVSplit2')
            \ ':call <SID>OnMouseDoubleClick(g:VLWOpenNodeVSplit2Key)<CR>'

    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.GotoParent')
            \ ':call <SID>GotoParent()<CR>'
    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.GotoRoot')
            \ ':call <SID>GotoRoot()<CR>'

    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.GotoNextSibling')
            \ ':call <SID>GotoNextSibling()<CR>'
    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.GotoPrevSibling')
            \ ':call <SID>GotoPrevSibling()<CR>'

    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.RefreshBuffer')
            \ ':call <SID>RefreshBuffer()<CR>'

    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.ToggleHelpInfo')
            \ ':call <SID>ToggleHelpInfo()<CR>'

    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.CutOneNode')
            \ ':call <SID>CutOneNode()<CR>'
    exec 'xnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.CutNodes')
            \ ':<C-u>call <SID>CutNodes()<CR>'
    exec 'nnoremap <silent> <buffer>'
            \ videm#settings#Get('.videm.wsp.keybind.PasteNodes')
            \ ':call <SID>PasteNodes()<CR>'
endfunction


function! s:LocateFile(fileName) "{{{2
    let l:curWinNum = winnr()
    let l:winNum = bufwinnr(g:VLWorkspaceBufName)
    if l:winNum == -1
        return 1
    endif

    py vim.command("let l:path = '%s'" % ToVimStr(
                \ws.VLWIns.GetWspFilePathByFileName(vim.eval('a:fileName'))))
    if l:path ==# ''
        " 文件不属于工作空间, 返回
        return 2
    endif

    " 当前光标所在文件即为正在编辑的文件, 直接返回
    py if ws.VLWIns.GetFileByLineNum(ws.window.cursor[0], True)
                \== vim.eval('a:fileName'): vim.command('return 3')

    if l:curWinNum != l:winNum
        call s:exec(l:winNum . 'wincmd w')
    endif

    call setpos('.', [0, 1, 1, 0])
    " NOTE: 这是 wsp path，是用 / 分割的
    let l:paths = split(l:path, '/')
    let l:depth = 1
    let l:spacePerDepth = 2
    for l:name in l:paths
        let l:pattern = '^.\{' . (l:depth * l:spacePerDepth) . '}' . l:name
        "let l:pattern = '^[| ~+-]\{' .(l:depth * l:spacePerDepth). '}' . l:name
        "echo l:name
        "echom l:pattern
        if search(l:pattern, 'c') == 0
            break
        endif
        call s:ExpandNode()
        let depth += 1
    endfor

    " NOTE: search 函数居然不自动滚动窗口?!
    let topLine = line('w0')
    let botLine = line('w$')
    let curLine = line('.')
    if curLine < topLine || curLine > botLine
        normal! zz
    endif

    if g:VLWorkspaceHighlightCursorline
        " NOTE: 高亮光标所在行时, 刷新有点问题, 强制刷新
        set nocursorline
        set cursorline
    endif

    if l:curWinNum != l:winNum
        call s:exec('wincmd p')
    endif

    return l:paths
endfunction
"}}}
function s:Autocmd_WorkspaceEditorOptions() "{{{2
    let sFile = expand('%:p')
    " NOTE: 老版本的 vim 中, 空字符串传给 python 的时候, 是 None
    if empty(sFile)
        return
    endif
    " 不是工作区的文件就直接跳出
    py if not ws.VLWIns.IsWorkspaceFile(vim.eval("sFile")):
                \vim.command('return')

    py vim.command("let lEditorOptions = %s" 
                \% ToVimEval(ws.VLWSettings.GetEditorOptions()))

    if empty(lEditorOptions)
        return
    endif

    " 鼓励编写单行的脚本，这样可以运行得更快，限制是不能有注释
    if len(lEditorOptions) == 1
        exec lEditorOptions[0]
        return
    endif

    " 这样就支持脚本了，每次都新建一个文件，效率可能会有问题
    let sTempFile = tempname()
    call writefile(lEditorOptions, sTempFile)
    exec 'source' fnameescape(sTempFile)
    call delete(sTempFile)
endfunction
"}}}
function! s:Autocmd_LocateCurrentFile() "{{{2
    " 会不会比较慢？
    if !videm#settings#Get('.videm.wsp.LinkToEditor')
        return
    endif

    let sFile = expand('%:p')
    call s:LocateFile(sFile)
endfunction
"}}}
function! s:InstallCommands() "{{{2
    if s:bHadInited
        return
    endif

    command! -nargs=0 -bar VBuildActiveProject    
            \                           call <SID>BuildActiveProject()
    command! -nargs=0 -bar VCleanActiveProject    
            \                           call <SID>CleanActiveProject()
    command! -nargs=0 -bar VRunActiveProject      
            \                           call <SID>RunActiveProject()
    command! -nargs=0 -bar VBuildAndRunActiveProject 
            \                           call <SID>BuildAndRunActiveProject()

    command! -nargs=0 -bar VEnvVarSetttings   call <SID>EnvVarSettings()
    command! -nargs=0 -bar VCompilersSettings call <SID>CompilersSettings()
    command! -nargs=0 -bar VBuildersSettings  call <SID>BuildersSettings()

    command! -nargs=0 -bar VSwapSourceHeader  call <SID>SwapSourceHeader()

    command! -nargs=0 -bar VLocateCurrentFile 
            \                           call <SID>LocateFile(expand('%:p'))

    command! -nargs=? -bar VFindFiles       call <SID>FindFiles(<q-args>)
    command! -nargs=? -bar VFindFilesIC     call <SID>FindFiles(<q-args>, 1)

    command! -nargs=? -bar VOpenIncludeFile call <SID>OpenIncludeFile()

    command! -nargs=0 -bar VSymbolDatabaseInit      call Videm_SymdbInit()
    command! -nargs=0 -bar VSymbolDatabaseUpdate    call Videm_SymdbUpdate()

    command! -nargs=1 -bar VSearchSymbolDefinition
            \               call <SID>SearchSymbolDefinition(<q-args>)
    command! -nargs=1 -bar VSearchSymbolDeclaration
            \               call <SID>SearchSymbolDeclaration(<q-args>)
    command! -nargs=1 -bar VSearchSymbolCalling
            \               call <SID>SearchSymbolCalling(<q-args>)
    command! -nargs=1 -bar VSearchSymbolReference
            \               call <SID>SearchSymbolReference(<q-args>)

    command! -nargs=1 -bar VSaveSession
            \               call s:SaveSession(<q-args>)
    command! -nargs=1 -bar -complete=file VLoadSession
            \               call s:LoadSession(<q-args>)

    command! -nargs=0 -bar VPlugInfo call videm#wsp#PlugInfo()
endfunction
"}}}
function! s:InstallMenuBarMenu() "{{{2
    anoremenu <silent> 200 &Videm.Build\ Settings.Compilers\ Settings\.\.\. 
                \:call <SID>CompilersSettings()<CR>
    anoremenu <silent> 200 &Videm.Build\ Settings.Builders\ Settings\.\.\. 
                \:call <SID>BuildersSettings()<CR>
    "anoremenu <silent> 200 &Videm.Debugger\ Settings\.\.\. <Nop>

    anoremenu <silent> 200 &Videm.Environment\ Variables\ Settings\.\.\. 
                \:call <SID>EnvVarSettings()<CR>

endfunction
"}}}
function! s:InstallToolBarMenu() "{{{2
    "anoremenu 1.500 ToolBar.-Sep15- <Nop>

    let rtp_bak = &runtimepath
    let &runtimepath = vlutils#PosixPath(g:VidemDir) . ',' . &runtimepath

    anoremenu <silent> icon=build   1.510 
                \ToolBar.BuildActiveProject 
                \:call <SID>BuildActiveProject()<CR>
    anoremenu <silent> icon=clean   1.520 
                \ToolBar.CleanActiveProject 
                \:call <SID>CleanActiveProject()<CR>
    anoremenu <silent> icon=execute 1.530 
                \ToolBar.RunActiveProject 
                \:call <SID>RunActiveProject()<CR>

    let &runtimepath = rtp_bak
endfunction
"}}}
" 用于在可视/选择模式获取选择的字符串，只支持单行的，如果跨行，返回空字符串
function! s:GetVisualSelection() "{{{2
    let spos = getpos("'<")
    let epos = getpos("'>")
    if spos[1] != epos[1]
        " 跨行了
        return ''
    endif

    let line = getline(spos[1])
    let sidx = spos[2] - 1
    let eidx = epos[2] - 1
    if &selection ==# 'exclusive'
        let eidx -= 1
    endif

    let result = line[sidx : eidx]
    "echomsg result
    return result
endfunction
"}}}
" 可视/选择模式的入口，会预处理字符串
function! s:VisualSearchSymbol(choice) "{{{2
    let word = s:GetVisualSelection()
    if empty(word) || word =~# '\W'
        call s:echow('Invalid selection for searching symbol')
        return
    endif

    if     a:choice ==# 'Definition'
        call <SID>SearchSymbolDefinition(word)
    elseif a:choice ==# 'Declaration'
        call <SID>SearchSymbolDeclaration(word)
    elseif a:choice ==# 'Calling'
        call <SID>SearchSymbolCalling(word)
    elseif a:choice ==# 'Reference'
        call <SID>SearchSymbolReference(word)
    endif
endfunction
"}}}
function! s:InstallPopUpMenu() "{{{2
    nnoremenu <silent> 1.55 PopUp.Search\ Definition
            \ :call <SID>SearchSymbolDefinition(expand('<cword>'))<CR>
    nnoremenu <silent> 1.55 PopUp.Search\ Declaration
            \ :call <SID>SearchSymbolDeclaration(expand('<cword>'))<CR>
    nnoremenu <silent> 1.55 PopUp.Search\ Calling
            \ :call <SID>SearchSymbolCalling(expand('<cword>'))<CR>
    nnoremenu <silent> 1.55 PopUp.Search\ Reference
            \ :call <SID>SearchSymbolReference(expand('<cword>'))<CR>
    nnoremenu <silent> 1.55 PopUp.-SEP- <Nop>

    vnoremenu <silent> 1.55 PopUp.Search\ Definition
            \ :<C-u>call <SID>VisualSearchSymbol('Definition')<CR>
    vnoremenu <silent> 1.55 PopUp.Search\ Declaration
            \ :<C-u>call <SID>VisualSearchSymbol('Declaration')<CR>
    vnoremenu <silent> 1.55 PopUp.Search\ Calling
            \ :<C-u>call <SID>VisualSearchSymbol('Calling')<CR>
    vnoremenu <silent> 1.55 PopUp.Search\ Reference
            \ :<C-u>call <SID>VisualSearchSymbol('Reference')<CR>
    "vnoremenu <silent> 1.55 PopUp.Debug
            "\ :<C-u>call <SID>GetVisualSelection()<CR>
    vnoremenu <silent> 1.55 PopUp.-SEP- <Nop>
endfunction
"}}}
function! s:IsWorkspaceFile(file) "{{{2
    py if ws.VLWIns.IsWorkspaceFile(vim.eval("a:file")):
            \ vim.command('return 1')
    return 0
endfunction
"}}}
" 关闭所有打开的工作空间的文件的缓冲区
function! s:CloseWorkspaceFiles() "{{{2
    let buffer_count = bufnr('$')
    for bufnr in range(1, buffer_count)
        if !bufloaded(bufnr)
            continue
        endif

        let filename = fnamemodify(bufname(bufnr), ':p')
        if s:IsWorkspaceFile(filename)
            " TODO 需要优雅的删除方式
            exec 'confirm bdelete' bufnr
        endif
    endfor
endfunction
"}}}
"}}}1
" ============================================================================
" ============================================================================


" ============================================================================
" 基本操作
" ============================================================================
" =================== 工作空间树操作 ===================
"{{{1
function! s:OnMouseDoubleClick(...) "{{{2
    let sKey = ''
    if a:0 > 0
        let sKey = a:1
    endif
    py ws.OnMouseDoubleClick(vim.eval("sKey"))
endfunction


function! s:OnRightMouseClick() "{{{2
    py ws.OnRightMouseClick()
endfunction


function! s:ChangeBuildConfig() "{{{2
    py ws.ChangeBuildConfig()
endfunction


function! s:ShowMenu() "显示菜单 {{{2
    py ws.ShowMenu()
endfunction


function! videm#wsp#MenuOperation(menu) "菜单操作 {{{2
    "menu 作为 id, 工作空间菜单形如 'W_Create a New Project'
    py ws.MenuOperation(vim.eval('a:menu'))
endfunction


function! s:ExpandNode() "{{{2
    py ws.ExpandNode()
endfunction


function! s:FoldNode() "{{{2
    py ws.FoldNode()
endfunction


function! s:GotoParent() "{{{2
    py ws.GotoParent()
endfunction


function! s:GotoRoot() "{{{2
    py ws.GotoRoot()
endfunction


function! s:GotoNextSibling() "{{{2
    py ws.GotoNextSibling()
endfunction


function! s:GotoPrevSibling() "{{{2
    py ws.GotoPrevSibling()
endfunction


function! s:AddFileNode(lnum, name) "{{{2
    py ws.AddFileNode(vim.eval('a:lnum'), vim.eval('a:name'))
endfunction


function! s:AddFileNodes(lnum, names) "批量添加文件节点 {{{2
    py ws.AddFileNodes(vim.eval('a:lnum'), vim.eval('a:names'))
endfunction


function! s:AddVirtualDirNode(lnum, name) "{{{2
    py ws.AddVirtualDirNode(vim.eval('a:lnum'), vim.eval('a:name'))
endfunction


function! s:AddProjectNode(lnum, projFile) "{{{2
    py ws.AddProjectNode(vim.eval('a:lnum'), vim.eval('a:projFile'))
endfunction


function! s:DeleteNode(lnum) "{{{2
    py ws.DeleteNode(vim.eval('a:lnum'))
endfunction


function! s:RefreshLines(start, end) "刷新数行，不包括 end 行 {{{2
    py ws.RefreshLines(vim.eval('a:start'), vim.eval('a:end'))
endfunction

function! s:RefreshStatusLine() "{{{2
    py ws.RefreshStatusLine()
endfunction

function! s:RefreshBuffer() "{{{2
    " 跳至工作区缓冲区窗口
    let nOrigWinNr = winnr()
    py vim.command("let nWspBufNum = %d" % ws.bufNum)
    let nWspWinNr = bufwinnr(nWspBufNum)
    if nWspWinNr == -1
        " 没有打开工作区窗口
        return
    endif
    if nWspWinNr != nOrigWinNr
        exec 'noautocmd ' . nWspWinNr . ' wincmd w'
    endif

    let lOrigCursor = getpos('.')

    let bNeedDispHelp = 0
    if exists('b:bHelpInfoOn') && b:bHelpInfoOn
        let bNeedDispHelp = 1
    endif
    let bNeedBriefHelp = 0
    if exists('b:bBriefHelpOn') && b:bBriefHelpOn
        let bNeedBriefHelp = 1
    endif

    call s:ToggleHelpInfo(0)
    call s:ToggleBriefHelp(0)
    py ws.RefreshBuffer()

    if bNeedBriefHelp
        call s:ToggleBriefHelp(1)
    endif
    if bNeedDispHelp
        call s:ToggleHelpInfo(1)
    endif

    call setpos('.', lOrigCursor)

    " 跳回原来的窗口
    if nWspWinNr != nOrigWinNr
        exec 'noautocmd ' . nOrigWinNr . ' wincmd w'
    endif
endfunction


function! s:ToggleHelpInfo(...) "{{{2
    let flag = get(a:000, 0, -1)
    if !exists('b:bHelpInfoOn')
        let b:bHelpInfoOn = 0
    endif

    if !b:bHelpInfoOn
        let b:dOrigView = winsaveview()
    endif

    " FIXME videm#settings#Get 不能获取函数引用...
    function! s:SGet(opt, ...)
        let val = get(a:000, 0, 0)
        return videm#settings#Get(a:opt, val)
    endfunction
    let prefix = '.videm.wsp.keybind.'

    let lHelpInfo = []

    let sLine = '" ============================'
    call add(lHelpInfo, sLine)
    let sLine = '" Main mappings~'
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: popup menu', s:SGet(prefix.'PopupMenu'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: show text menu', s:SGet(prefix.'ShowMenu'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: refresh buffer', s:SGet(prefix.'RefreshBuffer'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: toggle help info',
            \          s:SGet(prefix.'ToggleHelpInfo'))
    call add(lHelpInfo, sLine)
    call add(lHelpInfo, '')

    let sLine = '" ----------------------------'
    call add(lHelpInfo, sLine)
    let sLine = '" File node mappings~'
    call add(lHelpInfo, sLine)
    let sLine = '" <2-LeftMouse>,'
    call add(lHelpInfo, sLine)
    let sLine = '" <CR>,'
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: open file gracefully', s:SGet(prefix.'OpenNode'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: preview', s:SGet(prefix.'OpenNode2'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: open in new tab', s:SGet(prefix.'OpenNodeNewTab'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: open in new tab silently',
            \          s:SGet(prefix.'OpenNodeNewTab2'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: open split', s:SGet(prefix.'OpenNodeSplit'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: preview split', s:SGet(prefix.'OpenNodeSplit2'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: open vsplit', s:SGet(prefix.'OpenNodeVSplit'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: preview vsplit', s:SGet(prefix.'OpenNodeVSplit2'))
    call add(lHelpInfo, sLine)
    call add(lHelpInfo, '')

    let sLine = '" ----------------------------'
    call add(lHelpInfo, sLine)
    let sLine = '" Directory node mappings~'
    call add(lHelpInfo, sLine)
    let sLine = '" <2-LeftMouse>,'
    call add(lHelpInfo, sLine)
    let sLine = '" <CR>,'
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: open & close node', s:SGet(prefix.'OpenNode'))
    call add(lHelpInfo, sLine)
    call add(lHelpInfo, '')

    let sLine = '" ----------------------------'
    call add(lHelpInfo, sLine)
    let sLine = '" Project node mappings~'
    call add(lHelpInfo, sLine)
    let sLine = '" <2-LeftMouse>,'
    call add(lHelpInfo, sLine)
    let sLine = '" <CR>,'
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: open & close node', s:SGet(prefix.'OpenNode'))
    call add(lHelpInfo, sLine)
    call add(lHelpInfo, '')

    let sLine = '" ----------------------------'
    call add(lHelpInfo, sLine)
    let sLine = '" Workspace node mappings~'
    call add(lHelpInfo, sLine)
    let sLine = '" <2-LeftMouse>,'
    call add(lHelpInfo, sLine)
    let sLine = '" <CR>,'
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: show build config menu', s:SGet(prefix.'OpenNode'))
    call add(lHelpInfo, sLine)
    call add(lHelpInfo, '')

    let sLine = '" ----------------------------'
    call add(lHelpInfo, sLine)
    let sLine = '" Tree navigation mappings~'
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: go to root', s:SGet(prefix.'GotoRoot'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: go to parent', s:SGet(prefix.'GotoParent'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: go to next sibling',
            \          s:SGet(prefix.'GotoNextSibling'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: go to prev sibling',
            \          s:SGet(prefix.'GotoPrevSibling'))
    call add(lHelpInfo, sLine)
    call add(lHelpInfo, '')

    let sLine = '" ----------------------------'
    call add(lHelpInfo, sLine)
    let sLine = '" Tree node operation~'
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: Cut one node', s:SGet(prefix.'CutOneNode'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: Cut nodes (visual mode)', s:SGet(prefix.'CutNodes'))
    call add(lHelpInfo, sLine)
    let sLine = printf('" %s: Paste nodes', s:SGet(prefix.'PasteNodes'))
    call add(lHelpInfo, sLine)
    call add(lHelpInfo, '')

    delfunction s:SGet

    if flag == 0
        " off
        if !b:bHelpInfoOn
            return
        endif
        let b:bHelpInfoOn = 0
        setlocal modifiable
        exec 'silent! 1,'.(1+len(lHelpInfo)-1) . ' delete _'
        setlocal nomodifiable
        py ws.VLWIns.SetWorkspaceLineNum(ws.VLWIns.GetRootLineNum() - 
                \ int(vim.eval('len(lHelpInfo)')))

        if exists('b:dOrigView')
            call winrestview(b:dOrigView)
            unlet b:dOrigView
        endif
    elseif flag > 0
        " on
        if b:bHelpInfoOn
            return
        endif
        let b:bHelpInfoOn = 1
        setlocal modifiable
        call append(0, lHelpInfo)
        setlocal nomodifiable
        py ws.VLWIns.SetWorkspaceLineNum(ws.VLWIns.GetRootLineNum() + 
                \ int(vim.eval('len(lHelpInfo)')))
        call cursor(1, 1)
    else
        " toggle
        if b:bHelpInfoOn
            call s:ToggleHelpInfo(0)
        else
            call s:ToggleHelpInfo(1)
        endif
    endif
endfunction
"}}}
function! s:ToggleBriefHelp(...) "{{{2
    " -1: toggle, 0: disable, 1: enable
    let flag = get(a:000, 0, -1)
    if !exists('b:bBriefHelpOn')
        let b:bBriefHelpOn = 0
    endif

    let lHelpInfo = []
    let prefix = '.videm.wsp.keybind.'

    let sLine = printf('" Press %s to display help',
            \          videm#settings#Get(prefix.'ToggleHelpInfo'))
    call add(lHelpInfo, sLine)
    call add(lHelpInfo, '')

    if flag == 0
        " off
        if !b:bBriefHelpOn
            return
        endif
        let b:bBriefHelpOn = 0
        setlocal modifiable
        exec printf('silent! 1,%d delete _', len(lHelpInfo))
        setlocal nomodifiable
        py ws.VLWIns.SetWorkspaceLineNum(ws.VLWIns.GetRootLineNum() - 
                \ int(vim.eval('len(lHelpInfo)')))
    elseif flag > 0
        " on
        if b:bBriefHelpOn
            return
        endif
        let b:bBriefHelpOn = 1
        setlocal modifiable
        call append(0, lHelpInfo)
        setlocal nomodifiable
        py ws.VLWIns.SetWorkspaceLineNum(ws.VLWIns.GetRootLineNum() + 
                \ int(vim.eval('len(lHelpInfo)')))
    else
        if b:bBriefHelpOn
            return s:ToggleBriefHelp(0)
        else
            return s:ToggleBriefHelp(1)
        endif
    endif
endfunction
"}}}
function! s:CutOneNode() "{{{2
    let row = line('.')
    py ws.CutNodes(int(vim.eval('row')), 1)
endfunction
"}}}
function! s:CutNodes() "{{{2
    let start = line("'<")
    let end = line("'>")
    let length = end - start + 1

    py ws.CutNodes(int(vim.eval('start')), int(vim.eval('length')))
endfunction
"}}}
function! s:PasteNodes() "{{{2
    let row = line('.')
    py ws.PasteNodes(int(vim.eval('row')))
endfunction
"}}}
"}}}1
" =================== 构建操作 ===================
"{{{1
function! s:BuildProject(projName) "{{{2
    "au! BufReadPost quickfix setlocal nonu nowrap | nunmap <2-LeftMouse>
    py ws.BuildProject(vim.eval('a:projName'))
endfunction

function! s:CleanProject(projName) "{{{2
    py ws.CleanProject(vim.eval('a:projName'))
endfunction

function! s:RebuildProject(projName) "{{{2
    py ws.RebuildProject(vim.eval('a:projName'))
endfunction

function! s:RunProject(projName) "{{{2
    py ws.RunProject(vim.eval('a:projName'))
endfunction

function! s:BuildActiveProject() "{{{2
    if g:VLWorkspaceHasStarted
        py ws.BuildActiveProject()
    endif
endfunction
function! s:CleanActiveProject() "{{{2
    if g:VLWorkspaceHasStarted
        py ws.CleanActiveProject()
    endif
endfunction
function! s:RunActiveProject() "{{{2
    if g:VLWorkspaceHasStarted
        py ws.RunActiveProject()
    endif
endfunction


function! s:BuildAndRunActiveProject() "{{{2
    if g:VLWorkspaceHasStarted
        py ws.BuildAndRunActiveProject()
    endif
endfunction


"}}}1
" =================== 创建操作 ===================
"{{{1
function! s:CreateWorkspacePostCbk(dlg, data) "{{{2
    if a:data ==# 'True'
        "call s:RefreshBuffer()
        py ws.ReloadWorkspace()
    endif
endfunction

function! s:CreateWorkspace(...) "{{{2
    if exists('a:1')
        " Run as callback
        if a:1.type == g:VC_DIALOG
            let dialog = a:1
        else
            let dialog = a:1.owner
        endif

        let sWspName = ''
        let l:wspPath = ''
        let l:isSepPath = 0
        for i in dialog.controls
            if i.id == 0
                let sWspName = i.value
            elseif i.id == 1
                let l:wspPath = i.value
            elseif i.id == 2
                let l:isSepPath = i.value
            else
                continue
            endif
        endfor
        if sWspName !=# ''
            let sep = g:vlutils#os.sep
            if l:isSepPath != 0
                let l:file = l:wspPath . sep . sWspName . sep
                            \. sWspName . '.' . g:VLWorkspaceWspFileSuffix
            else
                let l:file = l:wspPath . sep
                            \. sWspName . '.' . g:VLWorkspaceWspFileSuffix
            endif
        endif

        if a:1.type != g:VC_DIALOG
            call a:2.SetId(100)
            if sWspName !=# ''
                let a:2.label = l:file
            else
                let a:2.label = ''
            endif
            call dialog.RefreshCtlById(100)
        endif

        if a:1.type == g:VC_DIALOG && sWspName !=# ''
            "echo sWspName
            "echo l:file
            py ret = ws.VLWIns.CreateWorkspace(vim.eval('sWspName'), 
                        \os.path.dirname(vim.eval('l:file')))
            "py if ret: ws.LoadWspSettings()
            "py if ret: ws.OpenTagsDatabase()
            py vim.command('call dialog.ConnectPostCallback('
                        \'s:GetSFuncRef("s:CreateWorkspacePostCbk"), "%s")' 
                        \% str(ret))
        endif

        return 0
    endif

    let g:newWspDialog = g:VimDialog.New('New Workspace')

    let ctl = g:VCSingleText.New('Workspace Name:')
    call ctl.SetId(0)
    call g:newWspDialog.AddControl(ctl)
    call g:newWspDialog.AddBlankLine()
    let tmpCtl = ctl

    let ctl = g:VCSingleText.New('Workspace Path:')
    call ctl.SetValue(getcwd())
    call ctl.SetId(1)
    call g:newWspDialog.AddControl(ctl)
    call g:newWspDialog.AddBlankLine()
    let tmpCtl1 = ctl

    let ctl = g:VCCheckItem.New(
                \'Create the workspace under a separate directory')
    call ctl.SetId(2)
    call g:newWspDialog.AddControl(ctl)
    call g:newWspDialog.AddBlankLine()
    let tmpCtl2 = ctl

    let ctl = g:VCStaticText.New('File Name:')
    call g:newWspDialog.AddControl(ctl)
    let ctl = g:VCStaticText.New('')
    let ctl.editable = 1
    call ctl.SetIndent(8)
    call ctl.SetHighlight('Special')
    call g:newWspDialog.AddControl(ctl)
    call tmpCtl.ConnectActionPostCallback(s:GetSFuncRef('s:CreateWorkspace'), ctl)
    call tmpCtl1.ConnectActionPostCallback(s:GetSFuncRef('s:CreateWorkspace'), ctl)
    call tmpCtl2.ConnectActionPostCallback(s:GetSFuncRef('s:CreateWorkspace'), ctl)

    call g:newWspDialog.DisableApply()
    call g:newWspDialog.AddFooterButtons()
    call g:newWspDialog.AddCallback(s:GetSFuncRef("s:CreateWorkspace"))
    call g:newWspDialog.Display()
endfunction

function! s:CreateProjectPostCbk(dlg, data) "{{{2
    setlocal modifiable
python << PYTHON_EOF
def CreateProjectPostCbk(ret):
    # 只需刷新添加的节点的上一个兄弟节点到添加的节点之间的显示
    ln = ws.VLWIns.GetPrevSiblingLineNum(ret)
    if ln == ret:
        ln = ws.VLWIns.GetRootLineNum(0)

    texts = []
    for i in range(ln, ret + 1):
        texts.append(ws.VLWIns.GetLineText(i).encode('utf-8'))
    if texts:
        ws.buffer[ln - 1 : ret - 1] = texts
CreateProjectPostCbk(int(vim.eval("a:data")))
PYTHON_EOF
    setlocal nomodifiable
endfunction

function! s:CreateProjectCategoriesCbk(ctl, data) "{{{2
    let ctl = a:ctl
    let tblCtl = a:data[0]
    let cmpTypeCtl = a:data[1]
    let descCtl = a:data[2]
    let categories = ctl.GetValue()
    call tblCtl.DeleteAllLines()
    call tblCtl.SetSelection(1)
python << PYTHON_EOF
def CreateProjectCategoriesCbk():
    templates = GetTemplateDict(vim.eval('g:VLWorkspaceTemplatesPath'))
    key = vim.eval('categories')
    names = []
    for line in templates[key]:
        names.append(line['name'])
    names.sort()
    for name in names:
        vim.command("call tblCtl.AddLineByValues(%s)" % ToVimEval(name))
CreateProjectCategoriesCbk()
PYTHON_EOF
    call ctl.owner.RefreshCtl(tblCtl)
    " 刷新编译器类型
    call s:TemplatesTableCbk(tblCtl, [cmpTypeCtl, descCtl])
endfunction

function! s:TemplatesTableCbk(ctl, data) "{{{2
    let ctl = a:ctl
    let cmpTypeCtl = a:data[0]
    let descCtl = a:data[1]
    try
        let name = ctl.GetSelectedLine()[0]
    catch
        " TODO: 空表，没有获取到任何项目模版
        return
    endtry
    let category = ''
    for i in ctl.owner.controls
        if i.id == 5
            let category = i.GetValue()
            break
        endif
    endfor
python << PYTHON_EOF
def TemplatesTableCbk():
    templates = GetTemplateDict(vim.eval('g:VLWorkspaceTemplatesPath'))
    name = vim.eval('name')
    category = vim.eval('category')
    for line in templates[category]:
        if line['name'] == name:
            if vim.eval("empty(cmpTypeCtl)") == '0':
                vim.command("call cmpTypeCtl.SetValue(%s)"
                            % ToVimEval(line['cmpType']))
            if vim.eval("empty(descCtl)") == '0':
                vim.command("call descCtl.SetValue(%s)"
                            % ToVimEval(line['desc']))
            break
# 立即调用
TemplatesTableCbk()
PYTHON_EOF
    if !empty(cmpTypeCtl)
        call ctl.owner.RefreshCtl(cmpTypeCtl)
    endif
    if !empty(descCtl)
        call ctl.owner.RefreshCtl(descCtl)
    endif
endfunction

function! s:CreateProject(...) "{{{2
    if exists('a:1')
        " Run as callback
        if a:1.type == g:VC_DIALOG
            let dialog = a:1
        else
            let dialog = a:1.owner
        endif

        let l:projName = ''
        let l:projPath = ''
        let l:isSepPath = 0
        let l:projType = 'Executable'
        let l:cmpType = ''
        let l:categories = ''
        let l:templateFile = ''
        for i in dialog.controls
            if i.id == 0
                let l:projName = i.value
            elseif i.id == 1
                let l:projPath = i.value
            elseif i.id == 2
                let l:isSepPath = i.value
            elseif i.id == 3
                let l:projType = i.value
            elseif i.id == 4
                let l:cmpType = i.value
            elseif i.id == 5
                let l:categories = i.value
            elseif i.id == 6
                try
                    let l:templateName = i.GetSelectedLine()[0]
                catch
                    " 没有项目模板
                    let l:templateName = ''
                    continue
                endtry
python << PYTHON_EOF
templates = GetTemplateDict(vim.eval('g:VLWorkspaceTemplatesPath'))
key = vim.eval('l:categories')
name = vim.eval('l:templateName')
template = {}
for template in templates[key]:
    if template['name'] == name:
        vim.command("let l:templateFile = '%s'" % ToVimStr(template['file']))
templates.clear()
del templates, template, key, name
PYTHON_EOF
            else
                continue
            endif
        endfor

        if !empty(l:projName)
            let sep = g:vlutils#os.sep
            if l:isSepPath
                let l:file = l:projPath . sep . l:projName . sep 
                            \. l:projName . '.' . g:VLWorkspacePrjFileSuffix
            else
                let l:file = l:projPath . sep 
                            \. l:projName . '.' . g:VLWorkspacePrjFileSuffix
            endif
        endif

        " 更新显示的文件名
        if a:1.type != g:VC_DIALOG
            if l:projName !=# ''
                let a:2.label = l:file
            else
                let a:2.label = ''
            endif
            call dialog.RefreshCtl(a:2)
        endif

        " 开始创建项目
        if a:1.type == g:VC_DIALOG
            if empty(l:projName)
                call s:echow("The project name is null, can not create.")
                return 1
            endif
            "echo l:projName
            "echo l:file
            "echo l:projType
            "echo l:cmpType
            "echo l:categories
            "echo l:templateFile
            if l:templateFile !=# ''
                py ret = ws.VLWIns.CreateProjectFromTemplate(
                            \vim.eval('l:projName'), 
                            \os.path.dirname(vim.eval('l:file')), 
                            \vim.eval('l:templateFile'), 
                            \vim.eval('l:cmpType'))
            else
                " 没有项目模板，默认创建 'Executable' 的空项目
                py ret = ws.VLWIns.CreateProject(
                            \vim.eval('l:projName'), 
                            \os.path.dirname(vim.eval('l:file')), 
                            \vim.eval('l:projType'), 
                            \vim.eval('l:cmpType'))
            endif

            " 创建失败
            py if isinstance(ret, bool) and not ret: vim.command('return 1')

            py vim.command('call dialog.ConnectPostCallback('
                        \'s:GetSFuncRef("s:CreateProjectPostCbk"), %d)' % ret)
        endif

        return 0
    endif

    let g:newProjDialog = g:VimDialog.New('New Project')
    let dlg = g:newProjDialog

    let ctl = g:VCSingleText.New('Project Name:')
    call ctl.SetId(0)
    call g:newProjDialog.AddControl(ctl)
    call g:newProjDialog.AddBlankLine()
    let projNameCtl = ctl

    let ctl = g:VCSingleText.New('Project Path:')
    call ctl.SetValue(getcwd())

    if g:VLWorkspaceHasStarted
        py vim.command("call ctl.SetValue('%s')" % ToVimStr(ws.VLWIns.dirName))
    endif

    call ctl.SetId(1)
    call g:newProjDialog.AddControl(ctl)
    call g:newProjDialog.AddBlankLine()
    let projPathCtl = ctl

    let ctl = g:VCCheckItem.New('Create the project under a separate directory')
    call ctl.SetId(2)
    call g:newProjDialog.AddControl(ctl)
    call g:newProjDialog.AddBlankLine()
    let sepDirCtl = ctl

    let ctl = g:VCStaticText.New('File Name:')
    call g:newProjDialog.AddControl(ctl)
    let ctl = g:VCStaticText.New('')
    let ctl.editable = 1
    call ctl.SetIndent(8)
    call ctl.SetHighlight('Special')
    call g:newProjDialog.AddControl(ctl)
    call g:newProjDialog.AddBlankLine()
    call projNameCtl.ConnectActionPostCallback(
            \ s:GetSFuncRef('s:CreateProject'), ctl)
    call projPathCtl.ConnectActionPostCallback(
            \ s:GetSFuncRef('s:CreateProject'), ctl)
    call sepDirCtl.ConnectActionPostCallback(
            \ s:GetSFuncRef('s:CreateProject'), ctl)

    call dlg.AddSeparator('-')
    let ctl = g:VCStaticText.New('Available Project Templates:')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    " 模版类别
    let ctl = g:VCComboBox.New('Template Categories:')
    call ctl.SetId(5)
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)
    let tpltCtgr = ctl

    let tblCtl = g:VCTable.New('Project Templates:', 1)
    call tblCtl.SetId(6)
    call tblCtl.SetIndent(4)
    call tblCtl.SetColTitle(1, 'Type')
    call tblCtl.SetDispHeader(0)
    call tblCtl.SetCellEditable(0)
    call tblCtl.SetDispButtons(0)
    call g:newProjDialog.AddControl(tblCtl)

" Information about this project template
    let indent = 4
    call dlg.AddBlankLine()
    let ctl = g:VCStaticText.New('Information about this project template:')
    call ctl.SetIndent(indent)
    call dlg.AddControl(ctl)
    call dlg.AddSeparator('-', indent)

    " 项目类型
    "let ctl = g:VCComboBox.New('Project Type:')
    "call ctl.SetId(3)
    "call ctl.AddItem('Static Library')
    "call ctl.AddItem('Dynamic Library')
    "call ctl.AddItem('Executable')
    "call ctl.SetValue('Executable')
    "call g:newProjDialog.AddControl(ctl)
    "call g:newProjDialog.AddBlankLine()

    " NOTE: 简单化，不支持修改，只能使用模板设定的值
    let ctl = g:VCStaticText.New('Compiler:')
    call ctl.SetIndent(indent)
    call dlg.AddControl(ctl)
    let ctl = g:VCStaticText.New('')
    let ctl.editable = 1
    call ctl.SetIndent(indent)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()
    let cmpTypeCtl = ctl

    let ctl = g:VCMultiText.New('Description:')
    call ctl.SetIndent(indent)
    call ctl.SetWrap(1)
    call ctl.SetLineBreak(1)
    call dlg.AddControl(ctl)
    let descCtl = ctl

    call tpltCtgr.ConnectActionPostCallback(
            \ s:GetSFuncRef('s:CreateProjectCategoriesCbk'),
            \               [tblCtl, cmpTypeCtl, descCtl])
    call tblCtl.ConnectSelectionCallback(
            \ s:GetSFuncRef('s:TemplatesTableCbk'), [cmpTypeCtl, descCtl])

python << PYTHON_EOF
def CreateTemplateCtls():
    templates = GetTemplateDict(vim.eval('g:VLWorkspaceTemplatesPath'))
    if not templates:
        return
    keys = templates.keys()
    keys.sort()
    for key in keys:
        vim.command("call tpltCtgr.AddItem(%s)" % ToVimEval(key))
    names = []
    for line in templates[keys[0]]:
        names.append(line['name'])
    # 排序
    names.sort()
    for name in names:
        vim.command("call tblCtl.AddLineByValues(%s)" % ToVimEval(name))
    vim.command("call tblCtl.SetSelection(1)")
CreateTemplateCtls()
PYTHON_EOF

    call g:newProjDialog.DisableApply()
    call g:newProjDialog.AddFooterButtons()
    call g:newProjDialog.AddCallback(s:GetSFuncRef("s:CreateProject"))
    call g:newProjDialog.Display()

    " 第一次也需要刷新组合框
    call s:TemplatesTableCbk(tblCtl, [cmpTypeCtl, descCtl])
python << PYTHON_EOF
PYTHON_EOF
endfunction

"}}}1
" =================== 其他组件 ===================
"{{{1
"}}}
" ========== Swap Source / Header =========
function! s:SwapSourceHeader() "{{{2
    let sFile = expand("%:p")
    py ws.SwapSourceHeader(vim.eval("sFile"))
endfunction
"}}}
" ========== Find Files =========
function! s:FindFiles(sMatchName, ...) "{{{2
    let sMatchName = a:sMatchName
    let bNoCase = a:0 > 0 ? a:1 : 0
    if sMatchName ==# ''
        echohl Question
        let sMatchName = input("Input name to be matched:\n")
        echohl None
    endif
    py ws.FindFiles(vim.eval('sMatchName'), int(vim.eval('bNoCase')))
endfunction
"}}}
" ========== Open Include File =========
function! s:OpenIncludeFile() "{{{2
    let sLine = getline('.')
    let sRawInclude = matchstr(
                \sLine, '^\s*#\s*include\s*\zs\(<[^>]\+>\|"[^"]\+"\)')
    if sRawInclude ==# ''
        return ''
    endif

    let sInclude = sRawInclude[1:-2]
    let bUserInclude = 0
    if sRawInclude[0] ==# '"'
        let bUserInclude = 1
    endif

    let sCurFile = expand('%:p')
    let sFile = ''

    py l_project = ws.VLWIns.GetProjectByFileName(vim.eval('sCurFile'))
    py l_searchPaths = ws.GetParserSearchPaths()
    py if l_project: l_searchPaths += ws.GetProjectIncludePaths(
                \l_project.GetName())
    " 如果没有所属的项目, 就用当前活动的项目的头文件搜索路径
    py if not l_project: l_searchPaths += ws.GetActiveProjectIncludePaths()
    py vim.command("let sFile = '%s'" % ToVimStr(IncludeParser.ExpandIncludeFile(
                \l_searchPaths,
                \vim.eval('sInclude'),
                \int(vim.eval('bUserInclude')))))
    py del l_searchPaths
    py del l_project

    if sFile !=# ''
        exec 'e ' . sFile
    endif

    return sFile
endfunction
"}}}
"}}}1
" ============================================================================
" ============================================================================


" ============================================================================
" 使用控件系统的交互操作
" ============================================================================
" =================== 环境变量设置 ===================
"{{{1
"标识用控件 ID {{{2
let s:ID_EnvVarSettingsEnvVarSets = 100
let s:ID_EnvVarSettingsEnvVarList = 101


function! s:EnvVarSettings() "{{{2
    let dlg = s:CreateEnvVarSettingsDialog()
    call dlg.Display()
endfunction

function! s:EVS_NewSetCbk(ctl, data) "{{{2
    echohl Question
    let sNewSet = input("Enter Name:\n")
    echohl None
    if sNewSet ==# ''
        return 0
    endif

    let ctl = a:ctl
    let nSetsID = s:ID_EnvVarSettingsEnvVarSets
    let nListID = s:ID_EnvVarSettingsEnvVarList
    let dlg = ctl.owner
    let dSetsCtl = dlg.GetControlByID(nSetsID)
    let dListCtl = dlg.GetControlByID(nListID)

    if !empty(dSetsCtl)
        "检查同名
        if index(dSetsCtl.GetItems(), sNewSet) != -1
            echohl ErrorMsg
            echo printf("The same name already exists: '%s'", sNewSet)
            echohl None
            return 0
        endif

        call dSetsCtl.AddItem(sNewSet)
        call dSetsCtl.SetValue(sNewSet)
        call dlg.RefreshCtl(dSetsCtl)

        "更新 data
        let dData = dSetsCtl.GetData()
        let dData[sNewSet] = []
        "保存当前的
        let sCurSet = dListCtl.GetData()
        if has_key(dData, sCurSet)
            call filter(dData[sCurSet], 0)
            for lLine in dListCtl.table
                call add(dData[sCurSet], lLine[0])
            endfor
        endif
        call dSetsCtl.SetData(dData)

        if !empty(dListCtl)
            call dListCtl.DeleteAllLines()
            call dlg.RefreshCtl(dListCtl)

            "更新 data
            call dListCtl.SetData(sNewSet)
        endif
    endif

    return 0
endfunction

function! s:EVS_DeleteSetCbk(ctl, data) "{{{2
    let ctl = a:ctl
    let nSetsID = s:ID_EnvVarSettingsEnvVarSets
    let nListID = s:ID_EnvVarSettingsEnvVarList
    let dlg = ctl.owner
    let dSetsCtl = dlg.GetControlByID(nSetsID)
    let dListCtl = dlg.GetControlByID(nListID)

    if empty(dSetsCtl) || dSetsCtl.GetValue() ==# 'Default'
        "不能删除默认组
        return 0
    endif

    if !empty(dSetsCtl)
        let sCurSet = dSetsCtl.GetValue()
        let data = dSetsCtl.GetData()
        if has_key(data, sCurSet)
            call remove(data, sCurSet)
        endif
        call dSetsCtl.RemoveItem(sCurSet)
        call dlg.RefreshCtl(dSetsCtl)

        if !empty(dListCtl)
            call dListCtl.DeleteAllLines()
            for sEnvVarExpr in dSetsCtl.GetData()[dSetsCtl.GetValue()]
                call dListCtl.AddLineByValues(sEnvVarExpr)
            endfor
            call dListCtl.SetData(dSetsCtl.GetValue())
            call dlg.RefreshCtl(dListCtl)
        endif
    endif

    return 0
endfunction

function! s:EVS_EditEnvVarBtnCbk(ctl, data) "{{{2
    let ctl = a:ctl
    let editDialog = g:VimDialog.New('Edit', ctl.owner)

    let lContent = []
    for lLine in ctl.table
        call add(lContent, lLine[0])
    endfor
    let sContent = join(lContent, "\n")

    call editDialog.SetIsPopup(1)
    call editDialog.SetAsTextCtrl(1)
    call editDialog.SetTextContent(sContent)
    call editDialog.ConnectSaveCallback(
                \s:GetSFuncRef('s:EVS_EditEnvVarSaveCbk'), ctl)
    call editDialog.Display()
endfunction

function! s:EVS_EditEnvVarSaveCbk(ctl, data) "{{{2
    let ctl = a:data
    let textsList = getline(1, '$')
    call filter(textsList, 'v:val !~ "^\\s\\+$\\|^$"')
    call ctl.DeleteAllLines()
    for sText in textsList
        call ctl.AddLineByValues(sText)
        call ctl.SetSelection(1)
    endfor
    call ctl.owner.RefreshCtl(ctl)
endfunction

function! s:AddEnvVarCbk(ctl, data) "{{{2
    echohl Question
    let input = input("New Environment Variable:\n")
    echohl None
    if input !=# ''
        call a:ctl.AddLineByValues(input)
    endif
endfunction

function! s:EditEnvVarCbk(ctl, data) "{{{2
    let value = a:ctl.GetSelectedLine()[0]
    echohl Question
    let input = input("Edit Environment Variable:\n", value)
    echohl None
    if input !=# '' && input !=# value
        call a:ctl.SetCellValue(a:ctl.selection, 0, input)
    endif
endfunction

function! s:ChangeEditingEnvVarSetCbk(ctl, data) "{{{2
    let dSetsCtl = a:ctl
    let dListCtl = a:data
    let dData = dSetsCtl.GetData()
    let sCurSet = dListCtl.GetData()

    "更新 data
    if has_key(dData, sCurSet)
        call filter(dData[sCurSet], 0)
        for lLine in dListCtl.table
            call add(dData[sCurSet], lLine[0])
        endfor
    endif

    call dListCtl.DeleteAllLines()
    for sEnvVarExpr in dData[dSetsCtl.GetValue()]
        call dListCtl.AddLineByValues(sEnvVarExpr)
    endfor
    call dListCtl.SetData(dSetsCtl.GetValue())
    call dSetsCtl.owner.RefreshCtl(dListCtl)
endfunction

function! s:SaveEnvVarSettingsCbk(dlg, data) "{{{2
    py ins = EnvVarSettingsST.Get()
    py ins.DeleteAllEnvVarSets()
    let sCurSet = ''
    for ctl in a:dlg.controls
        if ctl.GetId() == s:ID_EnvVarSettingsEnvVarSets
            let sCurSet = ctl.GetValue()
            let dData = ctl.GetData()
            for item in items(dData)
                if sCurSet ==# item[0]
                    " 跳过 data 中的 sCurSet 的数据, 应该用 table 控件的数据
                    continue
                endif
                py ins.NewEnvVarSet(vim.eval("item[0]"))
                for expr in item[1]
                    py ins.AddEnvVar(vim.eval("item[0]"), vim.eval("expr"))
                endfor
            endfor
        elseif ctl.GetId() == s:ID_EnvVarSettingsEnvVarList
            let table = ctl.table
            py ins.NewEnvVarSet(vim.eval("sCurSet"))
            py ins.ClearEnvVarSet(vim.eval("sCurSet"))
            for line in table
                py ins.AddEnvVar(vim.eval("sCurSet"), vim.eval("line[0]"))
            endfor
        endif
    endfor
    " 保存
    py ins.Save()
    py ins._ExpandSelf()
    py del ins
    py ws.VLWIns.TouchAllProjectFiles()
endfunction
"}}}
function! s:GetEnvVarSettingsHelpText() "{{{2
python << PYTHON_EOF
def GetEnvVarSettingsHelpText():
    s = '''\
==============================================================================
+-----------------------+
| Environment Variables |
+-----------------------+
A variable name may be a '[a-zA-Z_][a-zA-Z0-9_]*' pattern string. A variable
value may be any character except 'newline'. Leading whitespace characters of
variable value are discarded from your input before substitution of variable
references. And environment variables can be used. For example:
    tempdir = $(HOME)/tmp

You can also use them to introduce controlled leading whitespace into variable
values. Leading whitespace characters are discarded from your input before
substitution of variable references; this means you can include leading spaces
in a variable value by protecting them with variable references, like this:
     nullstring =
     space = $(nullstring) 
                          ^--- a space

The ordor of environment variable definition is important, the latter one will
be expanded by the former one. For example:
    a = abc         ->      a = abc
    b = xyz$(a)     ->      b = xyzabc
and
    b = xyz$(a)     ->      b = xyz
    a = abc         ->      a = abc

After all, all undefined variables will be expanded to ''(nullstring).

*** NOTE ***
Currently, "Environment Variables" is only valid for "Project Settings".
'''
    return s
PYTHON_EOF
    py vim.command("return %s" % ToVimEval(GetEnvVarSettingsHelpText()))
endfunction
function! s:CreateEnvVarSettingsDialog() "{{{2
    let dlg = g:VimDialog.New('== Environment Variables Settings ==')
    call dlg.SetExtraHelpContent(s:GetEnvVarSettingsHelpText())
    py ins = EnvVarSettingsST.Get()

    "1.EnvVarSets
    "===========================================================================
    let ctl = g:VCStaticText.New('Available Environment Sets:')
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)

    let ctl = g:VCButtonLine.New('')
    call ctl.SetIndent(4)
    call ctl.AddButton('New Set...')
    call ctl.AddButton('Delete Set')
    call ctl.ConnectButtonCallback(0, s:GetSFuncRef('s:EVS_NewSetCbk'), '')
    call ctl.ConnectButtonCallback(1, s:GetSFuncRef('s:EVS_DeleteSetCbk'), '')
    call dlg.AddControl(ctl)

    let ctl = g:VCComboBox.New('')
    let dSetsCtl = ctl
    call ctl.SetId(s:ID_EnvVarSettingsEnvVarSets)
    call ctl.SetIndent(4)
    py vim.command("let lEnvVarSets = %s" % ToVimEval(ins.envVarSets.keys()))
    call sort(lEnvVarSets)
    for sEnvVarSet in lEnvVarSets
        call ctl.AddItem(sEnvVarSet)
    endfor
    call ctl.SetValue('Default')
    call dlg.AddControl(ctl)

    "2.EnvVarList
    "===========================================================================
    let ctl = g:VCTable.New('')
    let dListCtl = ctl
    call ctl.SetId(s:ID_EnvVarSettingsEnvVarList)
    call ctl.SetDispHeader(0)
    call ctl.SetIndent(4)
    call ctl.ConnectBtnCallback(0, s:GetSFuncRef('s:AddEnvVarCbk'), '')
    "call ctl.ConnectBtnCallback(2, s:GetSFuncRef('s:EditEnvVarCbk'), '')
    call ctl.ConnectBtnCallback(2, s:GetSFuncRef('s:EVS_EditEnvVarBtnCbk'), '')
    call dlg.AddControl(ctl)

    call dlg.AddBlankLine()

    call dSetsCtl.ConnectActionPostCallback(
                \s:GetSFuncRef('s:ChangeEditingEnvVarSetCbk'), dListCtl)

    call dlg.ConnectSaveCallback(s:GetSFuncRef("s:SaveEnvVarSettingsCbk"), "")

python << PYTHON_EOF
def CreateEnvVarSettingsData():
    ins = EnvVarSettingsST.Get()
    vim.command('let dData = {}')
    for setName, envVars in ins.envVarSets.iteritems():
        vim.command("let dData[%s] = []" % ToVimEval(setName))
        for envVar in envVars:
            vim.command("call add(dData[%s], %s)" 
                        \% (ToVimEval(setName), ToVimEval(envVar.GetString())))
CreateEnvVarSettingsData()
PYTHON_EOF

    "私有变量保存环境变量全部数据
    call dSetsCtl.SetData(dData)
    if has_key(dData, dSetsCtl.GetValue())
        for sEnvVarExpr in dData[dSetsCtl.GetValue()]
            call dListCtl.AddLineByValues(sEnvVarExpr)
        endfor
    endif
    "私有变量保存当前环境变量列表的 setName
    call dListCtl.SetData(dSetsCtl.GetValue())

    call dlg.AddFooterButtons()

    py del ins
    return dlg
endfunction
"}}}1
" =================== Compilers 设置 ===================
"{{{1
"标识用控件 ID {{{2
let s:IDS_CSCtls = [
            \'s:ID_CSCtl_Compiler',
            \'s:ID_CSCtl_cCmpCmd',
            \'s:ID_CSCtl_cxxCmpCmd',
            \'s:ID_CSCtl_cPrpCmd',
            \'s:ID_CSCtl_cxxPrpCmd',
            \'s:ID_CSCtl_cDepGenCmd',
            \'s:ID_CSCtl_cxxDepGenCmd',
            \'s:ID_CSCtl_linkCmd',
            \'s:ID_CSCtl_arGenCmd',
            \'s:ID_CSCtl_soGenCmd',
            \'s:ID_CSCtl_objExt',
            \'s:ID_CSCtl_depExt',
            \'s:ID_CSCtl_prpExt',
            \'s:ID_CSCtl_PATH',
            \'s:ID_CSCtl_envSetupCmd',
            \'s:ID_CSCtl_includePaths',
            \'s:ID_CSCtl_libraryPaths',
            \'s:ID_CSCtl_incPat',
            \'s:ID_CSCtl_macPat',
            \'s:ID_CSCtl_lipPat',
            \'s:ID_CSCtl_libPat',
                    \]
call s:InitEnum(s:IDS_CSCtls, 10)
"}}}2
function! s:CompilersSettings() "{{{2
    let dDlg = s:CreateCompilersSettingsDialog()
    call s:CompilerSettings_OperateContents(dDlg, 0, 0)
    call dDlg.Display()
endfunction
"}}}
function! s:CompilerSettings_OperateContents(dDlg, bIsSave, bPreValue) "{{{2
    let dDlg = a:dDlg
    let bIsSave = a:bIsSave " 非零表示从控件内容保存，零表示更新控件内容
    let bPreValue = a:bPreValue " 非零表示使用 combo 控件上次的值获取 py 实例
    let dCtl = dDlg.GetControlByID(s:ID_CSCtl_Compiler)
    if bPreValue
        py cmpl = BuildSettingsST.Get().GetCompilerByName(
                    \vim.eval("dCtl.GetPrevValue()"))
    else
        py cmpl = BuildSettingsST.Get().GetCompilerByName(
                    \vim.eval("dCtl.GetValue()"))
    endif
    py if not cmpl: vim.command("return")
    for dCtl in dDlg.controls
        let ctlId = dCtl.GetId()
        if 0
        " ====== Start =====
        elseif ctlId == s:ID_CSCtl_cCmpCmd
            if bIsSave
                py cmpl.cCmpCmd = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.cCmpCmd))
            endif
        elseif ctlId == s:ID_CSCtl_cxxCmpCmd
            if bIsSave
                py cmpl.cxxCmpCmd = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.cxxCmpCmd))
            endif
        elseif ctlId == s:ID_CSCtl_cPrpCmd
            if bIsSave
                py cmpl.cPrpCmd = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.cPrpCmd))
            endif
        elseif ctlId == s:ID_CSCtl_cxxPrpCmd
            if bIsSave
                py cmpl.cxxPrpCmd = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.cxxPrpCmd))
            endif
        elseif ctlId == s:ID_CSCtl_cDepGenCmd
            if bIsSave
                py cmpl.cDepGenCmd = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.cDepGenCmd))
            endif
        elseif ctlId == s:ID_CSCtl_cxxDepGenCmd
            if bIsSave
                py cmpl.cxxDepGenCmd = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.cxxDepGenCmd))
            endif
        elseif ctlId == s:ID_CSCtl_linkCmd
            if bIsSave
                py cmpl.linkCmd = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.linkCmd))
            endif
        elseif ctlId == s:ID_CSCtl_arGenCmd
            if bIsSave
                py cmpl.arGenCmd = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.arGenCmd))
            endif
        elseif ctlId == s:ID_CSCtl_soGenCmd
            if bIsSave
                py cmpl.soGenCmd = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.soGenCmd))
            endif
        elseif ctlId == s:ID_CSCtl_objExt
            if bIsSave
                py cmpl.objExt = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.objExt))
            endif
        elseif ctlId == s:ID_CSCtl_depExt
            if bIsSave
                py cmpl.depExt = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.depExt))
            endif
        elseif ctlId == s:ID_CSCtl_prpExt
            if bIsSave
                py cmpl.prpExt = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.prpExt))
            endif
        elseif ctlId == s:ID_CSCtl_PATH
            if bIsSave
                py cmpl.PATH = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.PATH))
            endif
        elseif ctlId == s:ID_CSCtl_envSetupCmd
            if bIsSave
                py cmpl.envSetupCmd = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.envSetupCmd))
            endif
        elseif ctlId == s:ID_CSCtl_includePaths
            if bIsSave
                py cmpl.includePaths = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.includePaths))
            endif
        elseif ctlId == s:ID_CSCtl_libraryPaths
            if bIsSave
                py cmpl.libraryPaths = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.libraryPaths))
            endif
        elseif ctlId == s:ID_CSCtl_incPat
            if bIsSave
                py cmpl.incPat = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.incPat))
            endif
        elseif ctlId == s:ID_CSCtl_macPat
            if bIsSave
                py cmpl.macPat = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.macPat))
            endif
        elseif ctlId == s:ID_CSCtl_lipPat
            if bIsSave
                py cmpl.lipPat = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.lipPat))
            endif
        elseif ctlId == s:ID_CSCtl_libPat
            if bIsSave
                py cmpl.libPat = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" 
                            \% ToVimEval(cmpl.libPat))
            endif
        else
        " ====== End =====
        endif
    endfor

    if bIsSave
        " 保存
        py BuildSettingsST.Get().SetCompilerByName(cmpl, cmpl.name)
        py BuildSettingsST.Get().Save()
    endif
    py del cmpl
endfunction
"}}}
function! s:CompilerSettingsSaveCbk(dDlg, data) "{{{2
    call s:CompilerSettings_OperateContents(a:dDlg, 1, 0)
    " 所有项目都需要重建 Makefile 了
    py ws.VLWIns.TouchAllProjectFiles()
endfunction
"}}}
function! s:CompilerSettingsChangeCompilerCbk(dCtl, data) "{{{2
    let dDlg = a:dCtl.owner

    if dDlg.IsModified()
        " 如果本页可能已经修改，给出警告
        echohl WarningMsg
        let sAnswer = input("Settings seems to have been modified, "
                    \."would you like to save them? (y/n): ", "y")
        echohl None
        if sAnswer ==? 'y'
            call s:CompilerSettings_OperateContents(dDlg, 1, 1)
        endif
    endif

    call s:CompilerSettings_OperateContents(dDlg, 0, 0)
    call dDlg.Refresh()
    call dDlg.SetModified(0)
endfunction
"}}}
function! s:CreateCompilersSettingsDialog() "{{{2
    let dDlg = g:VimDialog.New('== Compilers Settings ==')

    let nIndent1 = 0
    let nIndent2 = 4

    let dCtl = g:VCComboBox.New('Available Compilers:')
    call dCtl.SetId(s:ID_CSCtl_Compiler)
    let dCtl.ignoreModify = 1 " 不统计本控件的修改
    call dCtl.ConnectActionPostCallback(
                \s:GetSFuncRef('s:CompilerSettingsChangeCompilerCbk'), '')
    py vim.command('let lCmplNames = %s' 
                \% ToVimEval(BuildSettingsST.Get().GetCompilerNameList()))
    for cmplName in lCmplNames
        call dCtl.AddItem(cmplName)
    endfor
    call dDlg.AddControl(dCtl)
    "call dDlg.AddBlankLine()

" 各个具体的设置
    call dDlg.AddSeparator()

    " ==========
    let dCtl = g:VCSingleText.New('Environment Setup Command:')
    call dCtl.SetId(s:ID_CSCtl_envSetupCmd)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)

    let dCtl = g:VCSingleText.New('PATH Environment Variable:')
    call dCtl.SetId(s:ID_CSCtl_PATH)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)

    let dSep = g:VCSeparator.New('=')
    call dSep.SetIndent(nIndent2)
    call dDlg.AddControl(dSep)
    " ==========

    let dCtl = g:VCSingleText.New('C Compile Command:')
    call dCtl.SetId(s:ID_CSCtl_cCmpCmd)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Cpp Compile Command:')
    call dCtl.SetId(s:ID_CSCtl_cxxCmpCmd)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('C Preprocess Command:')
    call dCtl.SetId(s:ID_CSCtl_cPrpCmd)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Cpp Preprocess Command:')
    call dCtl.SetId(s:ID_CSCtl_cxxPrpCmd)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('C Depends Generate Command:')
    call dCtl.SetId(s:ID_CSCtl_cDepGenCmd)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Cpp Depends Generate Command:')
    call dCtl.SetId(s:ID_CSCtl_cxxDepGenCmd)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Objects Link Command:')
    call dCtl.SetId(s:ID_CSCtl_linkCmd)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Archive Generate Command:')
    call dCtl.SetId(s:ID_CSCtl_arGenCmd)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Shared Object Generate Command:')
    call dCtl.SetId(s:ID_CSCtl_soGenCmd)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Objects Extension:')
    call dCtl.SetId(s:ID_CSCtl_objExt)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Depends Extension:')
    call dCtl.SetId(s:ID_CSCtl_depExt)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Preprocessed Extension:')
    call dCtl.SetId(s:ID_CSCtl_prpExt)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Global Include Paths:')
    call dCtl.SetId(s:ID_CSCtl_includePaths)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Global Library Paths:')
    call dCtl.SetId(s:ID_CSCtl_libraryPaths)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Include Pattern:')
    call dCtl.SetId(s:ID_CSCtl_incPat)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Macro Definition Pattern:')
    call dCtl.SetId(s:ID_CSCtl_macPat)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Library Search Pattern:')
    call dCtl.SetId(s:ID_CSCtl_lipPat)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    let dCtl = g:VCSingleText.New('Library Link Pattern:')
    call dCtl.SetId(s:ID_CSCtl_libPat)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    call dDlg.ConnectSaveCallback(
                \s:GetSFuncRef('s:CompilerSettingsSaveCbk'), '')

    call dDlg.AddFooterButtons()
    return dDlg
endfunction
"}}}
"}}}1
" =================== Builders 设置 ===================
"{{{1
"标识用控件 ID {{{2
let s:ID_BSSCtl_Builders = 1

let s:ID_BSSCtl_BuilderCommand = 10
"}}}
function! s:BuildersSettings() "{{{2
    let dDlg = s:CreateBuildersSettingsDialog()
    call s:BuildersSettings_OperateContents(dDlg, 0, 0)
    call dDlg.Display()
endfunction
"}}}
function! s:BuildersSettings_OperateContents(dDlg, bIsSave, bPreValue) "{{{2
    let dDlg = a:dDlg
    let bIsSave = a:bIsSave " 非零表示从控件内容保存，零表示更新控件内容
    let bPreValue = a:bPreValue " 非零表示使用 combo 控件上次的值获取 py 实例
    let dCtl = dDlg.GetControlByID(s:ID_BSSCtl_Builders)
    if bPreValue
        py bs = BuildSettingsST.Get().GetBuilderByName(
                    \vim.eval("dCtl.GetPrevValue()"))
    else
        py bs = BuildSettingsST.Get().GetBuilderByName(
                    \vim.eval("dCtl.GetValue()"))
    endif
    py if not bs: vim.command("return")
    for dCtl in dDlg.controls
        if 0
        " ======
        elseif dCtl.GetId() == s:ID_BSSCtl_BuilderCommand
            if bIsSave
                py bs.command = vim.eval("dCtl.GetValue()")
            else
                py vim.command("call dCtl.SetValue(%s)" % ToVimEval(bs.command))
            endif
        " ======
        else
        endif
    endfor

    if bIsSave
        " 保存
        py BuildSettingsST.Get().SetBuilderByName(bs, bs.name)
        py BuildSettingsST.Get().Save()
        if !bPreValue
        " 进这个分支表示是保存退出
            " 设置激活的 Builder
            py BuildSettingsST.Get().SetActiveBuilder(bs.name)
        endif
        " 重新读取 ws.builder
        py ws.builder = BuilderManagerST.Get().GetActiveBuilderInstance()
    endif
    py del bs
endfunction
"}}}
function! s:BuildersSettingsSaveCbk(dDlg, data) "{{{2
    call s:BuildersSettings_OperateContents(a:dDlg, 1, 0)
endfunction
"}}}
function! s:BuildersSettingsChangeBuilderCbk(dCtl, data) "{{{2
    let dDlg = a:dCtl.owner

    if dDlg.IsModified()
        " 如果本页可能已经修改，给出警告
        echohl WarningMsg
        let sAnswer = input("Settings seems to have been modified, "
                    \."would you like to save them? (y/n): ", "y")
        echohl None
        if sAnswer ==? 'y'
            call s:BuildersSettings_OperateContents(dDlg, 1, 1)
        endif
    endif

    call s:BuildersSettings_OperateContents(dDlg, 0, 0)
    call dDlg.Refresh()
    call dDlg.SetModified(0)
endfunction
"}}}
function! s:CreateBuildersSettingsDialog() "{{{2
    let dDlg = g:VimDialog.New('== Builder Settings ==')

    let nIndent1 = 0
    let nIndent2 = 4

    let dCtl = g:VCComboBox.New('Available Builders:')
    call dCtl.SetId(s:ID_BSSCtl_Builders)
    let dCtl.ignoreModify = 1 " 不统计本控件的修改
    call dCtl.ConnectActionPostCallback(
                \s:GetSFuncRef('s:BuildersSettingsChangeBuilderCbk'), '')

    let lBuilders = []
    py vim.command("let lBuilders = %s" 
                \% ToVimEval(BuildSettingsST.Get().GetBuilderNameList()))
    for sBuilderName in lBuilders
        call dCtl.AddItem(sBuilderName)
    endfor
    py vim.command("call dCtl.SetValue(%s)" % ToVimEval(ws.builder.name))

    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()
    call dDlg.AddSeparator()

" ============================================================================
    let dCtl = g:VCSingleText.New('Builder Command:')
    call dCtl.SetId(s:ID_BSSCtl_BuilderCommand)
    call dCtl.SetIndent(nIndent2)
    call dDlg.AddControl(dCtl)
    call dDlg.AddBlankLine()

    call dDlg.ConnectSaveCallback(
                \s:GetSFuncRef('s:BuildersSettingsSaveCbk'), '')

    call dDlg.AddFooterButtons()
    return dDlg
endfunction
"}}}
"}}}1
" =================== PCH 设置 ===================
"{{{1
function! s:GetVLWProjectCompileOpts(projName) "{{{2
    if !g:VLWorkspaceHasStarted
        return
    endif

    let l:ret = ''
python << PYTHON_EOF
def GetVLWProjectCompileOpts(projName):
    matrix = ws.VLWIns.GetBuildMatrix()
    wspSelConfName = matrix.GetSelectedConfigurationName()
    project = ws.VLWIns.FindProjectByName(projName)
    if not project:
        vim.command("echom 'no project'")
        return

    ds = DirSaver()
    try:
        os.chdir(project.dirName)
    except OSError:
        return

    projSelConfName = matrix.GetProjectSelectedConf(wspSelConfName, 
                                                    project.GetName())
    bldConf = ws.VLWIns.GetProjBuildConf(project.GetName(), projSelConfName)
    if not bldConf or bldConf.IsCustomBuild():
        vim.command("echom 'no bldConf or is custom build'")
        return

    opts = []

    includePaths = bldConf.GetIncludePath()
    for i in SplitSmclStr(includePaths):
        if i:
            opts.append('-I%s' % i)

    cmpOpts = bldConf.GetCompileOptions().replace('$(shell', '$(')

    # 合并 C 和 C++ 两个编译选项
    cmpOpts += ' ' + bldConf.GetCCompileOptions().replace('$(shell', '$(')

    # clang 不接受 -g3 参数
    cmpOpts = cmpOpts.replace('-g3', '-g')

    opts += SplitSmclStr(cmpOpts)

    pprOpts = bldConf.GetPreprocessor()

    for i in SplitSmclStr(pprOpts):
        if i:
            opts.append('-D%s' % i)

    vim.command("let l:ret = '%s'" % ToVimStr(' '.join(opts).encode('utf-8')))
GetVLWProjectCompileOpts(vim.eval('a:projName'))
PYTHON_EOF
    return l:ret
endfunction

function! s:InitVLWProjectClangPCH(projName) "{{{2
    if !g:VLWorkspaceHasStarted
        return
    endif

    py ds = DirSaver()
    py project = ws.VLWIns.FindProjectByName(vim.eval('a:projName'))
    py if project and os.path.exists(project.dirName): os.chdir(project.dirName)

    py vim.command("let l:pchHeader = '%s'" % ToVimStr(
                \os.path.join(project.dirName, project.name) + '_VLWPCH.h'))
    if filereadable(l:pchHeader)
        let cmpOpts = s:GetVLWProjectCompileOpts(a:projName)
        let b:command = 'clang -x c++-header ' . l:pchHeader . ' ' . cmpOpts
                    \. ' -fno-exceptions -fnext-runtime' 
                    \. ' -o ' . l:pchHeader . '.pch'
        call system(b:command)
    endif

    py del project
    py del ds
endfunction
"}}}1
" =================== Batch Build 设置 ===================
"{{{1
"标识用控件 ID {{{2
let s:ID_BatchBuildSettingsNames = 100
let s:ID_BatchBuildSettingsOrder = 101

function! s:WspBatchBuildSettings() "{{{2
    let dlg = s:CreateBatchBuildSettingsDialog()
    call dlg.Display()
endfunction

function! s:BBS_NewSetCbk(ctl, data) "{{{2
    echohl Question
    let sNewSet = input("Enter Name:\n")
    echohl None
    if sNewSet ==# ''
        return 0
    endif

    let ctl = a:ctl
    let nSetsID = s:ID_BatchBuildSettingsNames
    let nListID = s:ID_BatchBuildSettingsOrder
    let dlg = ctl.owner
    let dSetsCtl = dlg.GetControlByID(nSetsID)
    let dListCtl = dlg.GetControlByID(nListID)

    if !empty(dSetsCtl)
        "检查同名
        if index(dSetsCtl.GetItems(), sNewSet) != -1
            echohl ErrorMsg
            echo printf("The same name already exists: '%s'", sNewSet)
            echohl None
            return 0
        endif

        call dSetsCtl.AddItem(sNewSet)
        call dSetsCtl.SetValue(sNewSet)
        call dlg.RefreshCtl(dSetsCtl)

        "更新 data
        let dData = dSetsCtl.GetData()
        let dData[sNewSet] = []
        "保存当前的
        let sCurSet = dListCtl.GetData()
        if has_key(dData, sCurSet)
            call filter(dData[sCurSet], 0)
            for lLine in dListCtl.table
                if lLine[0]
                    call add(dData[sCurSet], lLine[1])
                endif
            endfor
        endif
        call dSetsCtl.SetData(dData)

        if !empty(dListCtl)
            call dListCtl.DeleteAllLines()
            py vim.command(
                        \'let lProjectNames = %s' % ws.VLWIns.GetProjectList())
            for sProjectName in lProjectNames
                call dListCtl.AddLineByValues(0, sProjectName)
            endfor
            call dListCtl.SetData(dSetsCtl.GetValue())
            call dlg.RefreshCtl(dListCtl)
        endif
    endif

    return 0
endfunction

function! s:BBS_DeleteSetCbk(ctl, data) "{{{2
    let ctl = a:ctl
    let nSetsID = s:ID_BatchBuildSettingsNames
    let nListID = s:ID_BatchBuildSettingsOrder
    let dlg = ctl.owner
    let dSetsCtl = dlg.GetControlByID(nSetsID)
    let dListCtl = dlg.GetControlByID(nListID)

    if empty(dSetsCtl) || dSetsCtl.GetValue() ==# 'Default'
        "不能删除默认组
        return 0
    endif

    if !empty(dSetsCtl)
        let sCurSet = dSetsCtl.GetValue()
        let data = dSetsCtl.GetData()
        if has_key(data, sCurSet)
            call remove(data, sCurSet)
        endif
        call dSetsCtl.RemoveItem(sCurSet)
        call dlg.RefreshCtl(dSetsCtl)

        " 刷新 order 列表
        call s:BBS_ChangeBatchBuildNameCbk(dSetsCtl, '')
    endif

    return 0
endfunction

function! s:BBS_ChangeBatchBuildNameCbk(ctl, data) "{{{2
    let dlg = a:ctl.owner
    let dSetsCtl = dlg.GetControlByID(s:ID_BatchBuildSettingsNames)
    let dListCtl = dlg.GetControlByID(s:ID_BatchBuildSettingsOrder)
    let dData = dSetsCtl.GetData()
    let sCurSet = dListCtl.GetData()

    "更新 data
    if has_key(dData, sCurSet)
        call filter(dData[sCurSet], 0)
        for lLine in dListCtl.table
            if lLine[0]
                call add(dData[sCurSet], lLine[1])
            endif
        endfor
    endif

    call dListCtl.DeleteAllLines()
    py vim.command('let lProjectNames = %s' % ws.VLWIns.GetProjectList())
    let lBatchBuild = dData[dSetsCtl.GetValue()]
    for sProjectName in lBatchBuild
        call dListCtl.AddLineByValues(1, sProjectName)
        " 删除另一个列表中对应的项
        let nIdx = index(lProjectNames, sProjectName)
        if nIdx != -1
            call remove(lProjectNames, nIdx)
        endif
    endfor
    for sProjectName in lProjectNames
        call dListCtl.AddLineByValues(0, sProjectName)
    endfor
    call dListCtl.SetData(dSetsCtl.GetValue())
    call dlg.RefreshCtl(dListCtl)
endfunction

function! s:BatchBuildSettingsSaveCbk(dlg, data) "{{{2
    let dSetsCtl = a:dlg.GetControlByID(s:ID_BatchBuildSettingsNames)
    let dListCtl = a:dlg.GetControlByID(s:ID_BatchBuildSettingsOrder)
    let dData = dSetsCtl.GetData()
    let sCurSet = dListCtl.GetData()

    "更新 data
    if has_key(dData, sCurSet)
        call filter(dData[sCurSet], 0)
        for lLine in dListCtl.table
            if lLine[0]
                call add(dData[sCurSet], lLine[1])
            endif
        endfor
    endif

    "直接字典间赋值
    py ws.VLWSettings.batchBuild = vim.eval("dSetsCtl.GetData()")
    py ws.VLWSettings.Save()
endfunction

function! s:CreateBatchBuildSettingsDialog() "{{{2
    let dlg = g:VimDialog.New("== Batch Build Settings ==")

    let ctl = g:VCStaticText.New('Batch Build:')
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)

    " 按钮
    let ctl = g:VCButtonLine.New('')
    call ctl.SetIndent(4)
    call ctl.AddButton('New Set...')
    call ctl.AddButton('Delete Set')
    call ctl.ConnectButtonCallback(0, s:GetSFuncRef('s:BBS_NewSetCbk'), '')
    call ctl.ConnectButtonCallback(1, s:GetSFuncRef('s:BBS_DeleteSetCbk'), '')
    call dlg.AddControl(ctl)

    " 组合框
    let ctl = g:VCComboBox.New('')
    let dSetsCtl = ctl
    call ctl.SetId(s:ID_BatchBuildSettingsNames)
    call ctl.SetIndent(4)
    py vim.command("let lNames = %s"
            \      % ToVimEval(ws.VLWSettings.GetBatchBuildNames()))
    for sName in lNames
        call ctl.AddItem(sName)
    endfor
    call ctl.ConnectActionPostCallback(
                \s:GetSFuncRef('s:BBS_ChangeBatchBuildNameCbk'), '')
    call dlg.AddControl(ctl)

    " 顺序列表控件
    py vim.command('let lProjectNames = %s'
            \      % ToVimEval(ws.VLWIns.GetProjectList()))
    py vim.command('let lBatchBuild = %s' 
            \      % ToVimEval(ws.VLWSettings.GetBatchBuildList('Default')))

    let ctl = g:VCTable.New('', 2)
    let dListCtl = ctl
    call ctl.SetId(s:ID_BatchBuildSettingsOrder)
    call ctl.SetIndent(4)
    call ctl.SetDispHeader(0)
    call ctl.SetCellEditable(0)
    call ctl.DisableButton(0)
    call ctl.DisableButton(1)
    call ctl.DisableButton(2)
    call ctl.DisableButton(5)
    call ctl.SetColType(1, ctl.CT_CHECK)
    for sProjectName in lBatchBuild
        call ctl.AddLineByValues(1, sProjectName)
        " 删除另一个列表中对应的项
        let nIdx = index(lProjectNames, sProjectName)
        if nIdx != -1
            call remove(lProjectNames, nIdx)
        endif
    endfor
    for sProjectName in lProjectNames
        call ctl.AddLineByValues(0, sProjectName)
    endfor
    call dlg.AddControl(ctl)

    " 保存整个字典
    py vim.command("let dData = %s" % ToVimEval(ws.VLWSettings.batchBuild))
    call dSetsCtl.SetData(dData)

    " 保存当前所属的 set 名字，在 change callback 里面有用
    call dListCtl.SetData(dSetsCtl.GetValue())

    call dlg.ConnectSaveCallback(
                \s:GetSFuncRef("s:BatchBuildSettingsSaveCbk"), '')

    call dlg.AddFooterButtons()
    return dlg
endfunction
"}}}1
" =================== 工作空间构建设置 ===================
"{{{1
"标识用控件 ID {{{2
let s:WspConfigurationCtlID = 10
let s:BuildMatrixMappingGID = 11


function! s:WspBuildConfigManager() "{{{2
    let dlg = s:CreateWspBuildConfDialog()
    call dlg.Display()
endfunction

function! s:NewConfigCbk(dlg, data) "{{{2
    let dlg = a:dlg
    let comboCtl = a:data
    let newConfName = ''
    let copyFrom = '--None--'
    for ctl in dlg.controls
        if ctl.id == 1
            let newConfName = ctl.value
        elseif ctl.id == 2
            let copyFrom = ctl.value
        endif
    endfor

    if newConfName !=# ''
        if index(comboCtl.GetItems(), newConfName) != -1
            "存在同名设置
            echohl ErrorMsg
            echo "Create failed, existing a similar name."
            echohl None
            return
        endif

        let projName = comboCtl.data
        call comboCtl.InsertItem(newConfName, -2)
python << PYTHON_EOF
def NewBuildConfig(projName, newConfName, copyFrom):
    from BuildConfig import BuildConfig
    project = ws.VLWIns.FindProjectByName(projName)
    if not project:
        return

    settings = project.GetSettings()
    if copyFrom == '--None--':
        newBldConf = BuildConfig()
    else:
        newBldConf = settings.GetBuildConfiguration(copyFrom).Clone()
    newBldConf.name = newConfName
    settings.SetBuildConfiguration(newBldConf)
    project.SetSettings(settings)
    ws.UpdateBuildMTime()
    del BuildConfig
NewBuildConfig(
    vim.eval('projName'), 
    vim.eval('newConfName'), 
    vim.eval('copyFrom'))
PYTHON_EOF
    endif
endfunction

function! s:WspBCMRenameCbk(ctl, data) "{{{2
    let ctl = a:ctl
    let comboCtl = a:data
    let projName = comboCtl.data
    if ctl.id == 3
        "重命名项目构建设置
        if ctl.selection <= 0
            return
        endif
        "重命名项目构建设置
        let line = ctl.GetLine(ctl.selection)
        let oldBcName = line[0]
        let newBcName = input("Enter New Name:\n", oldBcName)
        if newBcName !=# '' && newBcName !=# oldBcName
python << PYTHON_EOF
def RenameProjectBuildConfig(projName, oldBcName, newBcName):
    '''可能重命名失败, 当同名的配置已经存在的时候
    
    若重命名失败, 则还原显示, 什么都不做'''
    project = ws.VLWIns.FindProjectByName(projName)
    if not project or oldBcName == newBcName:
        return

    settings = project.GetSettings()
    oldBldConf = settings.GetBuildConfiguration(oldBcName)
    if not oldBldConf:
        return

    if settings.GetBuildConfiguration(newBcName):
        # 存在同名配置
        vim.command("echohl ErrorMsg")
        vim.command('echo "Rename failed, existing a similar name."')
        vim.command("echohl None")
        return

    # 修改项目文件
    settings.RemoveConfiguration(oldBcName)
    oldBldConf.SetName(newBcName)
    settings.SetBuildConfiguration(oldBldConf)
    project.SetSettings(settings)
    ws.UpdateBuildMTime()

    # 修改工作空间文件
    matrix = ws.VLWIns.GetBuildMatrix()
    for configuration in matrix.GetConfigurations():
        for mapping in configuration.GetConfigMappingList():
            if mapping.name == oldBcName:
                mapping.name = newBcName
    ws.VLWIns.SetBuildMatrix(matrix)
    ws.UpdateBuildMTime()

    # 更新当前窗口显示
    vim.command("let line[0] = newBcName")
    # 更新父窗口组合框显示
    vim.command("call comboCtl.RenameItem(oldBcName, newBcName)")
    vim.command("call comboCtl.owner.RefreshCtl(comboCtl)")

RenameProjectBuildConfig(
    vim.eval('projName'), 
    vim.eval('oldBcName'), 
    vim.eval('newBcName'))
PYTHON_EOF
        endif
    elseif ctl.id == 4
        "重命名工作空间 BuildMatrix
        if ctl.selection <= 0
            return
        endif
        let line = ctl.GetLine(ctl.selection)
        let oldConfName = line[0]
        let newConfName = input("Enter New Configuration Name:\n", oldConfName)
        if newConfName !=# '' && newConfName !=# oldConfName
python << PYTHON_EOF
def RenameWorkspaceConfiguration(oldConfName, newConfName):
    if not newConfName or newConfName == oldConfName:
        return

    matrix = ws.VLWIns.GetBuildMatrix()
    oldWspConf = matrix.GetConfigurationByName(oldConfName)

    if not oldWspConf:
        return
    if matrix.GetConfigurationByName(newConfName):
        # 存在同名配置
        vim.command("echohl ErrorMsg")
        vim.command('echo "Rename failed, existing a similar name."')
        vim.command("echohl None")
        return

    matrix.RemoveConfiguration(oldConfName)
    oldWspConf.SetName(newConfName)
    matrix.SetConfiguration(oldWspConf)
    ws.VLWIns.SetBuildMatrix(matrix)
    # 更新 buildMTime
    ws.UpdateBuildMTime()

    # 更新当前窗口表格
    vim.command("let line[0] = newConfName")
    # 更新父窗口组合框
    vim.command("call comboCtl.RenameItem(oldConfName, newConfName)")
    vim.command("call comboCtl.owner.RefreshCtl(comboCtl)")

RenameWorkspaceConfiguration(vim.eval('oldConfName'), vim.eval('newConfName'))
PYTHON_EOF
        call s:RefreshStatusLine()
        endif
    endif
endfunction

function! s:WspBCMRemoveCbk(ctl, data) "{{{2
    let ctl = a:ctl
    let comboCtl = a:data
    let projName = comboCtl.data
    if len(ctl.table) == 1
        echohl ErrorMsg
        echo "Can not remove the last configuration."
        echohl None
        return
    endif

    if ctl.id == 3
        "删除项目的构建设置
        if ctl.selection <= 0
            return
        endif
        let line = ctl.GetLine(ctl.selection)
        let bldConfName = line[0]
        echohl WarningMsg
        let input = input("Remove configuration \""
                    \.bldConfName."\"? (y/n): ", 'y')
        echohl None
        if input ==? 'y'
            call ctl.DeleteLine(ctl.selection)
            let ctl.selection = 0
            "更新组合框
            call comboCtl.RemoveItem(bldConfName)
            call comboCtl.owner.RefreshCtl(comboCtl)
python << PYTHON_EOF
def RemoveProjectBuildConfig(projName, bldConfName):
    project = ws.VLWIns.FindProjectByName(projName)
    if not project:
        return

    settings = project.GetSettings()
    settings.RemoveConfiguration(bldConfName)
    project.SetSettings(settings)
    ws.UpdateBuildMTime()

    # 修正工作空间文件
    matrix = ws.VLWIns.GetBuildMatrix()
    for configuration in matrix.GetConfigurations():
        for mapping in configuration.GetConfigMappingList():
            if mapping.name == bldConfName:
                # 随便选择一个可用的补上
                mapping.name = settings.GetFirstBuildConfiguration().GetName()
    ws.VLWIns.SetBuildMatrix(matrix)
    ws.UpdateBuildMTime()

RemoveProjectBuildConfig(vim.eval('projName'), vim.eval('bldConfName'))
PYTHON_EOF
        endif
    elseif ctl.id == 4
        "删除工作空间 BuildMatrix 的 config
        if ctl.selection <= 0
            return
        endif
        let configName = ctl.GetLine(ctl.selection)[0]
        echohl WarningMsg
        let input = input("Remove workspace configuration \""
                    \.configName."\"? (y/n): ", 'y')
        echohl None
        if input ==? 'y'
            call ctl.DeleteLine(ctl.selection)
            let ctl.selection = 0
            "更新组合框
            call comboCtl.RemoveItem(configName)
            call comboCtl.owner.RefreshCtl(comboCtl)
python << PYTHON_EOF
def RemoveWorkspaceConfiguration(confName):
    if not confName: return
    matrix = ws.VLWIns.GetBuildMatrix()
    matrix.RemoveConfiguration(confName)
    ws.VLWIns.SetBuildMatrix(matrix)
    ws.UpdateBuildMTime()

RemoveWorkspaceConfiguration(vim.eval('configName'))
PYTHON_EOF
            " 刷新工作区的状态栏显示
            call s:RefreshStatusLine()
            " 再刷新所有项目对应的构建设置控件
            call s:WspBCMActionPostCbk(comboCtl, '*')
        endif
    endif
endfunction

function! s:WspBCMChangePreCbk(ctl, data) "{{{2
    "返回 1 表示不继续处理控件的 Action
    "目的在于保存改变前的值
    let ctl = a:ctl
    let dlg = ctl.owner
    call ctl.SetData(ctl.GetValue())

    return 0
endfunction

function! s:WspBCMActionPostCbk(ctl, data) "{{{2
    let ctl = a:ctl
    let dlg = a:ctl.owner
    if a:ctl.id == s:WspConfigurationCtlID
    "工作空间的构建设置
        let wspSelConfName = a:ctl.GetValue()
        if wspSelConfName ==# '<New...>'
            echohl Question
            let input = input("\nEnter New Configuration Name:\n")
            echohl None
            let copyFrom = a:ctl.GetPrevValue()
            call a:ctl.SetValue(copyFrom)
            if input !=# ''
                if index(a:ctl.GetItems(), input) != -1
                    "存在同名
                    echohl ErrorMsg
                    echo "Create failed, existing a similar name."
                    echohl None
                    return 1
                endif

                call a:ctl.InsertItem(input, -2)
python << PYTHON_EOF
def NewWspConfig(newConfName, copyFrom):
    if not newConfName or not copyFrom:
        return

    matrix = ws.VLWIns.GetBuildMatrix()
    copyFromConf = matrix.GetConfigurationByName(copyFrom)
    if not copyFromConf:
        wspSelConfName = matrix.GetSelectedConfigurationName()
        newWspConf = matrix.GetConfigurationByName(wspSelConfName)
    else:
        newWspConf = copyFromConf.Clone()
    newWspConf.SetName(newConfName)
    matrix.SetConfiguration(newWspConf)
    ws.VLWIns.SetBuildMatrix(matrix)
    ws.UpdateBuildMTime()
NewWspConfig(vim.eval('input'), vim.eval('copyFrom'))
PYTHON_EOF
            endif
        elseif wspSelConfName ==# '<Edit...>'
            call a:ctl.SetValue(a:ctl.GetPrevValue())
            let editConfigsDlg = g:VimDialog.New(
                        \'Edit Wrokspace Configurations', dlg)
            let newCtl = g:VCTable.New('')
            call editConfigsDlg.AddControl(newCtl)
            call newCtl.SetDispHeader(0)
            call newCtl.SetId(4)
            call newCtl.ConnectBtnCallback(
                        \2, s:GetSFuncRef('s:WspBCMRenameCbk'), a:ctl)
            call newCtl.ConnectBtnCallback(
                        \1, s:GetSFuncRef('s:WspBCMRemoveCbk'), a:ctl)
            call newCtl.SetCellEditable(0)
            call newCtl.DisableButton(0)
            call newCtl.DisableButton(3)
            call newCtl.DisableButton(4)
            call newCtl.DisableButton(5)
            for item in a:ctl.GetItems()
                if item !=# '<New...>' && item !=# '<Edit...>'
                    call newCtl.AddLineByValues(item)
                endif
            endfor
            call editConfigsDlg.AddCloseButton()
            call editConfigsDlg.Display()
        else
            let bModified = dlg.GetData()
            if bModified
                echohl WarningMsg
                let sAnswer = input("Settings for workspace configuration '"
                            \. a:ctl.GetData()
                            \."' have been changed, would you like to save"
                            \." them? (y/n): ", "y")
                echohl None
                if sAnswer ==? 'y'
                    redraw
                    "保存前切换到之前的值
                    let bak_value = ctl.GetValue()
                    call ctl.SetValue(ctl.GetData())
                    silent call dlg.Save()
                    call ctl.SetValue(bak_value)
                elseif sAnswer ==? 'n'
                    "继续
                else
                    "返回
                    call ctl.SetValue(ctl.GetData())
                    return 1
                endif
            endif
            py matrix = ws.VLWIns.GetBuildMatrix()
            for ctl in dlg.controls
                if ctl.gId == s:BuildMatrixMappingGID
                    let projName = ctl.data
                    py vim.command("call ctl.SetValue('%s')" 
                                \% ToVimStr(matrix.GetProjectSelectedConf(
                                \vim.eval("wspSelConfName"), 
                                \vim.eval("projName"))))
                    "echo ctl.GetData()
                endif
                if !empty(a:data)
                    "刷新控件. WspBCMRemoveCbk() 中调用是使用
                    call dlg.RefreshCtlByGId(s:BuildMatrixMappingGID)
                endif
            endfor
            py del matrix
            if empty(a:data)
                call dlg.RequestRefresh() " 要求回调后刷新
            endif
            "标记为未修改
            call dlg.SetData(0)
        endif
    else
    "项目的构建设置
        let value = ctl.GetValue()
        if value ==# '<New...>'
            call a:ctl.SetValue(a:ctl.GetPrevValue())
            let newConfDlg = g:VimDialog.New('New Configuration', dlg)
            let newCtl = g:VCSingleText.New('Configuration Name:')
            call newCtl.SetId(1)
            call newConfDlg.AddControl(newCtl)
            call newConfDlg.AddBlankLine()

            let newCtl = g:VCComboBox.New('Copy Settings From:')
            call newCtl.SetId(2)
            call newCtl.AddItem('--None--')
            for item in ctl.GetItems()
                if item !=# '<New...>' && item !=# '<Edit...>'
                    call newCtl.AddItem(item)
                endif
            endfor
            call newConfDlg.ConnectSaveCallback(s:GetSFuncRef('s:NewConfigCbk'),
                        \ctl)
            call newConfDlg.AddControl(newCtl)
            call newConfDlg.AddFooterButtons()
            call newConfDlg.Display()
        elseif value ==# '<Edit...>'
            call a:ctl.SetValue(a:ctl.GetPrevValue())
            let editConfigsDlg = g:VimDialog.New('Edit Configurations', dlg)
            let newCtl = g:VCTable.New('')
            call editConfigsDlg.AddControl(newCtl)
            call newCtl.SetDispHeader(0)
            call newCtl.SetId(3)
            call newCtl.ConnectBtnCallback(
                        \2, s:GetSFuncRef('s:WspBCMRenameCbk'), a:ctl)
            call newCtl.ConnectBtnCallback(
                        \1, s:GetSFuncRef('s:WspBCMRemoveCbk'), a:ctl)
            call newCtl.SetCellEditable(0)
            call newCtl.DisableButton(0)
            call newCtl.DisableButton(3)
            call newCtl.DisableButton(4)
            call newCtl.DisableButton(5)
            for item in ctl.GetItems()
                if item !=# '<New...>' && item !=# '<Edit...>'
                    call newCtl.AddLineByValues(item)
                endif
            endfor
            call editConfigsDlg.AddCloseButton()
            call editConfigsDlg.Display()
        else
            "标记为已修改
            call dlg.SetData(1)
        endif
    endif
endfunction

function! s:WspBCMSaveCbk(dlg, data) "{{{2
python << PYTHON_EOF
def WspBCMSaveCbk(matrix, wspConfName, projName, confName):
    wspConf = matrix.GetConfigurationByName(wspConfName)
    if wspConf:
        for mapping in wspConf.GetMapping():
            if mapping.project == projName:
                mapping.name = confName
                break
PYTHON_EOF
    let dlg = a:dlg
    let wspConfName = ''
    py matrix = ws.VLWIns.GetBuildMatrix()
    for ctl in dlg.controls
        if ctl.GetId() == s:WspConfigurationCtlID
            let wspConfName = ctl.GetValue()
        elseif ctl.GetGId() == s:BuildMatrixMappingGID
            let projName = ctl.GetData()
            let confName = ctl.GetValue()
            py WspBCMSaveCbk(matrix, vim.eval('wspConfName'), 
                        \vim.eval('projName'), vim.eval('confName'))
        endif
    endfor

    "保存
    py ws.VLWIns.SetBuildMatrix(matrix)
    py ws.UpdateBuildMTime()
    py del matrix

    "重置为未修改
    call dlg.SetData(0)
endfunction

function! s:CreateWspBuildConfDialog() "{{{2
    let wspBCMDlg = g:VimDialog.New('== Workspace Build Configuration ==')
python << PYTHON_EOF
def CreateWspBuildConfDialog():
    matrix = ws.VLWIns.GetBuildMatrix()
    wspSelConfName = matrix.GetSelectedConfigurationName()
    vim.command("let ctl = g:VCComboBox.New('Workspace Configuration:')")
    vim.command("call ctl.SetId(s:WspConfigurationCtlID)")
    vim.command("call wspBCMDlg.AddControl(ctl)")
    for wspConf in matrix.configurationList:
        vim.command("call ctl.AddItem('%s')" % ToVimStr(wspConf.name))
    vim.command("call ctl.SetValue('%s')" % ToVimStr(wspSelConfName))
    vim.command("call ctl.AddItem('<New...>')")
    vim.command("call ctl.AddItem('<Edit...>')")
    vim.command("call ctl.ConnectActionCallback("\
            "s:GetSFuncRef('s:WspBCMChangePreCbk'), '')")
    vim.command("call ctl.ConnectActionPostCallback("\
            "s:GetSFuncRef('s:WspBCMActionPostCbk'), '')")
    vim.command("call wspBCMDlg.AddSeparator()")
    vim.command("call wspBCMDlg.AddControl("\
            "g:VCStaticText.New('Available project configurations:'))")
    vim.command("call wspBCMDlg.AddBlankLine()")

    projectNameList = ws.VLWIns.projects.keys()
    projectNameList.sort(CmpIC)
    for projName in projectNameList:
        project = ws.VLWIns.FindProjectByName(projName)
        vim.command("let ctl = g:VCComboBox.New('%s')" % ToVimStr(projName))
        vim.command("call ctl.SetGId(s:BuildMatrixMappingGID)")
        vim.command("call ctl.SetData('%s')" % ToVimStr(projName))
        vim.command("call ctl.SetIndent(4)")
        vim.command("call ctl.ConnectActionPostCallback("\
                "s:GetSFuncRef('s:WspBCMActionPostCbk'), '')")
        vim.command("call wspBCMDlg.AddControl(ctl)")
        for confName in project.GetSettings().configs.keys():
            vim.command("call ctl.AddItem('%s')" % ToVimStr(confName))
        projSelConfName = matrix.GetProjectSelectedConf(wspSelConfName, 
                                                        projName)
        vim.command("call ctl.SetValue('%s')" % ToVimStr(projSelConfName))
        vim.command("call ctl.AddItem('<New...>')")
        vim.command("call ctl.AddItem('<Edit...>')")
        vim.command("call wspBCMDlg.AddBlankLine()")
CreateWspBuildConfDialog()
PYTHON_EOF
    call wspBCMDlg.SetData(0)
    call wspBCMDlg.ConnectSaveCallback(s:GetSFuncRef('s:WspBCMSaveCbk'), '')
    call wspBCMDlg.AddFooterButtons()

    " 最后基本都要刷新一下缓冲区
    function! s:RefreshBufferX(...)
        call s:RefreshBuffer()
    endfunction
    call wspBCMDlg.ConnectPostCallback(s:GetSFuncRef('s:RefreshBufferX'), '')

    return wspBCMDlg
endfunction
"}}}1
" =================== 工作空间设置 ===================
"{{{1
"标识用控件 ID {{{2
let s:ID_WspSettingsEnvironment = 9
let s:ID_WspSettingsIncludePaths = 10
let s:ID_WspSettingsTagsTokens = 11
let s:ID_WspSettingsTagsTypes = 12
let s:ID_WspSettingsMacroFiles = 13
let s:ID_WspSettingsPrependNSInfo = 14
let s:ID_WspSettingsIncPathFlag = 15
let s:ID_WspSettingsEditorOptions = 16
let s:ID_WspSettingsCSourceExtensions = 17
let s:ID_WspSettingsCppSourceExtensions = 18
let s:ID_WspSettingsEnableLocalConfig = 19
let s:ID_WspSettingsLocalConfig = 20

let Notifier = vlutils#Notifier
let s:WspSetNotf = Notifier.New('WspSet')
let g:WspSetNotf = s:WspSetNotf

function! VidemWspSetCreateHookRegister(hook, prio, priv) "{{{2
    return s:WspSetNotf.Register(a:hook, a:prio, a:priv)
endfunction
"}}}
function! VidemWspSetCreateHookUnregister(hook, prio) "{{{2
    return s:WspSetNotf.Unregister(a:hook, a:prio)
endfunction
"}}}
function! s:WspSettings() "{{{2
    let dlg = s:CreateWspSettingsDialog()
    call dlg.Display()
endfunction

function! s:EditTextBtnCbk(ctl, data) "{{{2
    let ft = a:data " data 需要设置的文件类型
    let l:editDialog = g:VimDialog.New('Edit', a:ctl.owner)
    let content = a:ctl.GetValue()
    call l:editDialog.SetIsPopup(1)
    call l:editDialog.SetAsTextCtrl(1)
    call l:editDialog.SetTextContent(content)
    call l:editDialog.ConnectSaveCallback(
                \s:GetSFuncRef('s:EditTextSaveCbk'), a:ctl)
    call l:editDialog.Display()
    if ft !=# ''
        let &filetype = ft
    endif
endfunction

function! s:EditTextSaveCbk(dlg, data) "{{{2
    let textsList = getline(1, '$')
    call filter(textsList, 'v:val !~ "^\\s\\+$\\|^$"')
    call a:data.SetValue(textsList)
    call a:data.owner.RefreshCtl(a:data)
endfunction

function! s:SaveWspSettingsCbk(dlg, data) "{{{2
    for ctl in a:dlg.controls
        if ctl.GetId() == s:ID_WspSettingsEnvironment
            py vim.command('let sOldName = %s'
                    \ % ToVimEval(ws.VLWSettings.GetEnvVarSetName()))
            let sNewName = ctl.GetValue()
            py ws.VLWSettings.SetEnvVarSetName(vim.eval("sNewName"))
            if sOldName !=# sNewName
                " 下面固定调用这个了
                "py ws.VLWIns.TouchAllProjectFiles()
            endif
        elseif ctl.GetId() == s:ID_WspSettingsEditorOptions
            py ws.VLWSettings.SetEditorOptions(vim.eval("ctl.GetValue()"))
        elseif ctl.GetId() == s:ID_WspSettingsCSourceExtensions
            py ws.VLWSettings.cSrcExts =
                    \ SplitSmclStr(vim.eval("ctl.GetValue()"))
        elseif ctl.GetId() == s:ID_WspSettingsCppSourceExtensions
            py ws.VLWSettings.cppSrcExts =
                    \ SplitSmclStr(vim.eval("ctl.GetValue()"))
        elseif ctl.GetId() == s:ID_WspSettingsEnableLocalConfig
            py ws.VLWSettings.enableLocalConfig = int(vim.eval("ctl.GetValue()"))
        elseif ctl.GetId() == s:ID_WspSettingsLocalConfig
            let text = join(ctl.values, "\n")
            py ws.VLWSettings.SetLocalConfigText(vim.eval("text"))
        endif
    endfor
    " 回调
    call s:WspSetNotf.CallChain('save', a:dlg)
    " 保存
    py ws.SaveWspSettings()
    " Extension Options 关系到项目 Makefile
    py ws.VLWIns.TouchAllProjectFiles()
    " 是否启动局部配置直接影响还原设置的方式
    py if not ws.VLWSettings.enableLocalConfig:
            \ vim.command("call videm#wsp#WspConfRestore(1)")
    py if ws.VLWSettings.enableLocalConfig:
            \ vim.command("call videm#wsp#WspConfRestore(0)")
    " 载入的时候就有刷新操作了
    py ws.LoadWspSettings()
endfunction
"}}}
" 工作区设置的帮助信息
function! s:GetWspSettingsHelpText() "{{{2
python << PYTHON_EOF
def GetWspSettingsHelpText():
    s = '''\
==============================================================================
##### Some Extra Help Information #####

== Editor Options ==
'Editor Options' will be run as vim script, but if the option value is a
single line script, it will be run by ':execute' which will be faster.
But ':execute' cannot be followed by a comment directly, so do not write a
comment while writing a single line script.
'''
    s += '''\

== Wrokspace Local Configurations ==
Supported configuration variables:
'''
    conf = vim.eval("s:WspConfTmpl")
    li = conf.keys()
    li.sort()
    restart_conf = vim.eval("s:WspConfTmplRestart")

    minlen = 1
    for k in li:
        if len(k) > minlen:
            minlen = len(k)

    for k in li:
        v = conf[k]
        # 处理数字
        if vim.eval('type(s:WspConfTmpl[%s]) == type(0)' % ToVimEval(k)) == '1':
            v = int(v)
        if restart_conf.has_key(k):
            s += '* %-*s = %s' % (minlen, k, ToVimEval(v))
        else:
            s += '  %-*s = %s' % (minlen, k, ToVimEval(v))
        s += '\n'

    s += '''
Variables which start with '*' need to restart Videm to take effect.
'''

    return s
PYTHON_EOF
    py vim.command("return %s" % ToVimEval(GetWspSettingsHelpText()))
endfunction
"}}}
" 这个动作可以定制，具有一定的定义性，用于 OmniCpp 和 VIMCCC
function! s:CreateWspSettingsDialog() "{{{2
    let dlg = g:VimDialog.New('== Workspace Settings ==')
    call dlg.SetExtraHelpContent(s:GetWspSettingsHelpText())

" ============================================================================
    " 1.Environment
    let ctl = g:VCStaticText.New("Environment")
    call ctl.SetHighlight("Special")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCComboBox.New('Environment Sets:')
    call ctl.SetId(s:ID_WspSettingsEnvironment)
    call ctl.SetIndent(4)
    py vim.command("let lEnvVarSets = %s"
            \      % ToVimEval(EnvVarSettingsST.Get().envVarSets.keys()))
    call sort(lEnvVarSets)
    for sEnvVarSet in lEnvVarSets
        call ctl.AddItem(sEnvVarSet)
    endfor
    py vim.command("call ctl.SetValue(%s)"
            \      % ToVimEval(ws.VLWSettings.GetEnvVarSetName()))
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

" ============================================================================
    " 2. Editor Options
    let ctl = g:VCStaticText.New("Editor")
    call ctl.SetHighlight("Special")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCMultiText.New("Editor Options (Run as vim script, "
            \                   . "single line will be faster):")
    call ctl.SetId(s:ID_WspSettingsEditorOptions)
    call ctl.SetIndent(4)
    py vim.command("let editorOptions = %s" 
            \      % ToVimEval(ws.VLWSettings.GetEditorOptions()))
    call ctl.SetValue(editorOptions)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditTextBtnCbk"), "vim")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

" ============================================================================
    " 3. Local Config
    let ctl = g:VCStaticText.New("Workspace Local Configurations")
    call ctl.SetHighlight("Special")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCCheckItem.New('Enable Local Configurations:')
    call ctl.SetId(s:ID_WspSettingsEnableLocalConfig)
    call ctl.SetIndent(4)
    py if ws.VLWSettings.enableLocalConfig: vim.command("call ctl.SetValue(1)")
    call dlg.AddControl(ctl)
    let sep = g:VCSeparator.New('~')
    call sep.SetIndent(4)
    call dlg.AddControl(sep)

    let ctl = g:VCMultiText.New("Workspace Local Configurations"
            \ . " (Please read the Extra Help info):")
    call ctl.SetId(s:ID_WspSettingsLocalConfig)
    call ctl.SetIndent(4)
    py vim.command("let localConfig = %s"
            \       % ToVimEval(ws.VLWSettings.GetLocalConfigText()))
    call ctl.SetValue(localConfig)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditTextBtnCbk"), "conf")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

" ============================================================================
    " 3. Extension Options
    let ctl = g:VCStaticText.New("Extension Options")
    call ctl.SetHighlight("Special")
    call dlg.AddControl(ctl)
    let ctl = g:VCStaticText.New(
                \'Option values will be appended to default set.')
    call ctl.SetHighlight('Comment')
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)
    let ctl = g:VCStaticText.New(
                \'These depend on the support of the specific compiler.')
    call ctl.SetHighlight('Comment')
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)
    let ctl = g:VCStaticText.New(
                \'Default C Source Extensions:   .c')
    call ctl.SetHighlight('Comment')
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)
    let ctl = g:VCStaticText.New(
                \'Default C++ source Extensions: .cpp;.cxx;.c++;.cc')
    call ctl.SetHighlight('Comment')
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    py vim.command("let cSrcExts = %s" % ToVimEval(ws.VLWSettings.cSrcExts))
    let ctl = g:VCSingleText.New('Additional C Source File Extensions:')
    call ctl.SetId(s:ID_WspSettingsCSourceExtensions)
    call ctl.SetIndent(4)
    call ctl.SetValue(vlutils#JoinToSmclStr(cSrcExts))
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    py vim.command("let cppSrcExts = %s" % ToVimEval(ws.VLWSettings.cppSrcExts))
    let ctl = g:VCSingleText.New('Additional C++ Source File Extensions:')
    call ctl.SetId(s:ID_WspSettingsCppSourceExtensions)
    call ctl.SetIndent(4)
    call ctl.SetValue(vlutils#JoinToSmclStr(cppSrcExts))
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

" ============================================================================
    call dlg.ConnectSaveCallback(s:GetSFuncRef("s:SaveWspSettingsCbk"), "")

    call s:WspSetNotf.CallChain('create', dlg)

    call dlg.AddFooterButtons()
    return dlg
endfunction
"}}}
" 导出的控件 ID
let videm#wsp#TagsSettings_ID_SearchPaths = 10000
" FIXME: 上面那个变量可以导出，但是本脚本就不能使用，why?
let s:ID_TagsSettingsSearchPaths = videm#wsp#TagsSettings_ID_SearchPaths
" 获取 tags 设置的一些公共的控件
function! s:TagsSettings_ReinitSearchPathsHook(ctl, data) "{{{2
    let spctl = a:data
    echohl WarningMsg
    let prompt = 'It will re-initialize the search paths by gcc, are you sure? (y/n): '
    let answer = input(prompt)
    echohl None
    " 这就是清掉输出的正确方法
    redraw | echo ''
    if answer[0 : 0] !~? 'y'
        return
    endif

    " 重新初始化
    py from TagsSettings import GetGccIncludeSearchPaths
    py vim.command("let paths = %s" % ToVimEval(GetGccIncludeSearchPaths()))
    if empty(paths)
        echohl Error
        echo "Failed to get search paths by gcc, nothing changed"
        echohl None
        return 1
    endif
    call spctl.SetValue(paths)
    if !empty(spctl.owner)
        let dlg = spctl.owner
        call dlg.SetModified(1)
        call dlg.RefreshCtl(spctl)
    endif
endfunction
"}}}
function! Videm_GetTagsSettingsControls(...) "{{{2
    let indent = get(a:000, 0, 4)
    let ctls = []
    " 头文件搜索路径
    let ctl = g:VCMultiText.New(
            \ "Add search paths for the vlctags, libclang and other parsers:")
    " XXX BUG?!
    "call ctl.SetId(videm#wsp#TagsSettings_ID_SearchPaths)
    call ctl.SetId(s:ID_TagsSettingsSearchPaths)
    call ctl.SetIndent(indent)
    py vim.command("let includePaths = %s" %
            \      ToVimEval(TagsSettingsST.Get().includePaths))
    call ctl.SetValue(includePaths)
    call ctl.ConnectButtonCallback(function("vlutils#EditTextBtnCbk"), "")
    call add(ctls, ctl)
    let spctl = ctl

    let ctl = g:VCButtonLine.New('Re-initialize the search paths: ')
    call ctl.SetIndent(indent)
    call ctl.AddButton("Reset...")
    call ctl.ConnectButtonCallback(
            \ 0, s:GetSFuncRef('s:TagsSettings_ReinitSearchPathsHook'), spctl)
    call add(ctls, ctl)

    call add(ctls, g:VCBlankLine.New())

    return ctls
endfunction
"}}}
"}}}1
" =================== 项目设置 ===================
"{{{1
" 标识用控件 ID {{{2
let s:IDS_PSCtls = [
            \'s:ID_PSCtl_ProjectConfigurations',
            \'s:ID_PSCtl_ProjectType',
            \'s:ID_PSCtl_Compiler',
            \'s:ID_PSCtl_OutDir',
            \'s:ID_PSCtl_OutputFile',
            \'s:ID_PSCtl_Program',
            \'s:ID_PSCtl_ProgramWD',
            \'s:ID_PSCtl_ProgramArgs',
            \'s:ID_PSCtl_UseSepDbgArgs',
            \'s:ID_PSCtl_DebugArgs',
            \'s:ID_PSCtl_IgnoreFiles',
            \'s:ID_PSCtl_UseSepCCEArgs',
            \'s:ID_PSCtl_CCEngIncArgs',
            \'s:ID_PSCtl_CCEngMacArgs',
            \
            \'s:ID_PSCtl_Cmpl_UseWithGlb',
            \'s:ID_PSCtl_Cmpl_COpts',
            \'s:ID_PSCtl_Cmpl_CxxOpts',
            \'s:ID_PSCtl_Cmpl_CCxxOpts',
            \'s:ID_PSCtl_Cmpl_IncPaths',
            \'s:ID_PSCtl_Cmpl_Prep',
            \'s:ID_PSCtl_Cmpl_PCH',
            \'s:ID_PSCtl_Link_UseWithGlb',
            \'s:ID_PSCtl_Link_Opts',
            \'s:ID_PSCtl_Link_LibPaths',
            \'s:ID_PSCtl_Link_Libs',
            \
            \'s:ID_PSCtl_PreBuild',
            \'s:ID_PSCtl_PostBuild',
            \
            \'s:ID_PSCtl_CstBld_Enable',
            \'s:ID_PSCtl_CstBld_WorkDir',
            \'s:ID_PSCtl_CstBld_Targets',
            \
            \'s:ID_PSCtl_Glb_Cmpl_COpts',
            \'s:ID_PSCtl_Glb_Cmpl_CxxOpts',
            \'s:ID_PSCtl_Glb_Cmpl_CCxxOpts',
            \'s:ID_PSCtl_Glb_Cmpl_IncPaths',
            \'s:ID_PSCtl_Glb_Cmpl_Prep',
            \'s:ID_PSCtl_Glb_Link_Opts',
            \'s:ID_PSCtl_Glb_Link_LibPaths',
            \'s:ID_PSCtl_Glb_Link_Libs',
            \]
call s:InitEnum(s:IDS_PSCtls, 10)
let s:GIDS_PSCtls = [
            \'s:GID_PSCtl_SepDbgArgs',
            \'s:GID_PSCtl_SepCCEArgs',
            \'s:GID_PSCtl_CustomBuild',
            \]
call s:InitEnum(s:GIDS_PSCtls, 10)
"}}}2
function! s:GetProjectSettingsHelpText() "{{{2
python << PYTHON_EOF
def GetProjectSettingsHelpText():
    s = '''\
$(ProjectFiles)          A space delimited string containing all of the 
                         project files in a relative path to the project file
$(ProjectFilesAbs)       A space delimited string containing all of the 
                         project files in an absolute path
$(CurrentFileName)       Expand to current file name (without extension and 
                         path)
$(CurrentFileExt)        Expand to current file extension
$(CurrentFilePath)       Expand to current file path
$(CurrentFileFullPath)   Expand to current file full path (path and full name)

'''
    s = '''\
==============================================================================
+------------------+
| Available Macros |
+------------------+
$(WorkspaceName)         Expand to the workspace name
$(WorkspacePath)         Expand to the workspace path
$(ProjectName)           Expand to the project name
$(ProjectPath)           Expand to the project path
$(ConfigurationName)     Expand to the current project selected configuration
$(IntermediateDirectory) Expand to the project intermediate directory path, 
                         as set in the project settings
$(OutDir)                An alias to $(IntermediateDirectory)
$(User)                  Expand to logged-in user as defined by the OS
$(Date)                  Expand to current date
`expression`             Evaluates the expression inside the backticks into a 
                         string

Videm will expand above macros firstly, and then expand Environment Variables.
After this, expand `expression` at last.

+------------------+
| Project Settings |
+------------------+
##
## Code Complete Arguments
##
"Separate Code Complete Arguments" are only used for VIMCCC, exclude OmniCpp.
If you use other code complete engine, read its help file.

##
## Compiler And Linker
##
Compiler and linker options are string separated by ';' and join with ' '.
eg: "-g;-Wall" -> "-g -Wall".

If you need a literal ';', just input ";;".
eg: "-DSmcl=\;;;-Wall" -> "-DSmcl=\; -Wall".

"Include Paths", "Predefine Macros", "Library Paths" and "Libraries" options
will be separated by ';' and modify by corresponding compiler pattern and
join with ' '.
eg: ".;test/include" -> "-I. -Itest/include", and be passed to gcc.
eg: "stdc++;m" -> "-lstdc++ -lm", and be passed to gcc.

##
## Misc
##
Working directory starts with directory of the project file except set it to a
absolute path.
'''
    return s
PYTHON_EOF
    py vim.command("return %s" % ToVimEval(GetProjectSettingsHelpText()))
endfunction
"}}}2
function! s:AddBuildTblLineCbk(ctl, data) "{{{2
    echohl Question
    let input = input("New Command:\n")
    echohl None
    if input !=# ''
        call a:ctl.AddLineByValues(1, input)
    endif
endfunction
"}}}2
function! s:EditBuildTblLineCbk(ctl, data) "{{{2
    let value = a:ctl.GetSelectedLine()[1]
    echohl Question
    let input = input("Edit Command:\n", value)
    echohl None
    if input !=# '' && input !=# value
        call a:ctl.SetCellValue(a:ctl.selection, 2, input)
    endif
endfunction
"}}}2
function! s:CustomBuildTblAddCbk(ctl, data) "{{{2
    let ctl = a:ctl
    echohl Question
    let input = input("New Target:\n")
    echohl None
    if empty(input)
        return
    endif

    let inputpat = '[-A-Za-z0-9_]'
    if input !~# '^'.inputpat.'\+$'
        echohl ErrorMsg
        echo "\nA target name must consists of this letters:" inputpat
        echohl None
        call getchar()
        return
    endif

    for lLine in ctl.table
        if lLine[0] ==# input
            echohl ErrorMsg
            echo "Target '" . input . "' already exists!"
            echohl None
            return
        endif
    endfor
    call ctl.AddLineByValues(input, '')
endfunction
"}}}2
function! s:CustomBuildTblSelectionCbk(ctl, data) "{{{2
    let ctl = a:ctl
    let lLine = ctl.GetSelectedLine()
    if empty(lLine)
        return
    endif

    let lHoldValue = ['Build', 'Clean', 'Rebuild', 'Compile Single File', 
                \'Preprocess File']
    if index(lHoldValue, lLine[0]) != -1
        call ctl.DisableButton(1)
    else
        call ctl.EnableButton(1)
    endif
    call ctl.owner.RefreshCtl(ctl)
endfunction
"}}}2
function! s:ActiveIfCheckCbk(ctl, data) "{{{2
    let bool = a:ctl.GetValue()
    for ctl in a:ctl.owner.controls
        if ctl.gId == a:data
            if bool
                call ctl.SetActivated(1)
            else
                call ctl.SetActivated(0)
            endif
        endif
    endfor
    call a:ctl.owner.RefreshCtlByGId(a:data)
endfunction
"}}}2
function! s:ActiveIfUnCheckCbk(ctl, data) "{{{2
    let bool = a:ctl.GetValue()
    for ctl in a:ctl.owner.controls
        if ctl.gId == a:data
            if !bool
                call ctl.SetActivated(1)
            else
                call ctl.SetActivated(0)
            endif
        endif
    endfor
    call a:ctl.owner.RefreshCtlByGId(a:data)
endfunction
"}}}2
function! s:EditPSOptBtnCbk(ctl, data) "{{{2
    let editDialog = g:VimDialog.New('Edit', a:ctl.owner)
    let content = join(vlutils#SplitSmclStr(a:ctl.GetValue()), "\n")
    if content !=# ''
        let content .= "\n"
    endif
    call editDialog.SetIsPopup(1)
    call editDialog.SetAsTextCtrl(1)
    call editDialog.SetTextContent(content)
    call editDialog.ConnectSaveCallback(
                \s:GetSFuncRef('s:EditPSOptSaveCbk'), a:ctl)
    call editDialog.Display()
endfunction
"}}}2
function! s:EditPSOptSaveCbk(dlg, data) "{{{2
    let textsList = getline(1, '$')
    call filter(textsList, 'v:val !~ "^\\s\\+$\\|^$"') " 剔除空白行
    call a:data.SetValue(vlutils#JoinToSmclStr(textsList))
    call a:data.owner.RefreshCtl(a:data)
endfunction
"}}}2
function! s:ProjectSettings(sProjectName) "{{{2
    let dlg = s:ProjectSettings_CreateDialog(a:sProjectName)
    call s:ProjectSettings_OperateContents(dlg, 0, 0)
    call dlg.Display()
endfunction
"}}}2
function! s:ProjectSettings_OperateContents(dlg, bIsSave, bUsePreValue) "{{{2
    let dlg = a:dlg
    let bIsSave = a:bIsSave
    let bUsePreValue = a:bUsePreValue
    let sProjectName = dlg.GetData()
    let ctl = dlg.GetControlByID(s:ID_PSCtl_ProjectConfigurations)
    if bUsePreValue
        let sConfigName = ctl.GetPrevValue()
    else
        let sConfigName = ctl.GetValue()
    endif
    py vim.command("let confDict = %s" % ToVimEval(ws.GetProjectConfigDict(
                \           vim.eval('sProjectName'), vim.eval('sConfigName'))))
    py vim.command("let glbCnfDict = %s" % ToVimEval(
                \ws.GetProjectGlbCnfDict(vim.eval('sProjectName'))))
    for ctl in dlg.controls
        let ctlId = ctl.GetId()
        if 0
        " ====== Start =====
        elseif ctlId == s:ID_PSCtl_ProjectType
            if bIsSave
                let confDict['type'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['type'])
            endif
        elseif ctlId == s:ID_PSCtl_Compiler
            if bIsSave
                let confDict['cmplName'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['cmplName'])
            endif
        elseif ctlId == s:ID_PSCtl_OutDir
            if bIsSave
                let confDict['outDir'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['outDir'])
            endif
        elseif ctlId == s:ID_PSCtl_OutputFile
            if bIsSave
                let confDict['output'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['output'])
            endif
        elseif ctlId == s:ID_PSCtl_Program
            if bIsSave
                let confDict['program'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['program'])
            endif
        elseif ctlId == s:ID_PSCtl_ProgramWD
            if bIsSave
                let confDict['progWD'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['progWD'])
            endif
        elseif ctlId == s:ID_PSCtl_ProgramArgs
            if bIsSave
                let confDict['progArgs'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['progArgs'])
            endif
        elseif ctlId == s:ID_PSCtl_UseSepDbgArgs
            if bIsSave
                if ctl.GetValue()
                    let confDict['useSepDbgArgs'] = ctl.GetValue()
                else
                    " vim 的数字传到 python 之后是字符串
                    let confDict['useSepDbgArgs'] = ''
                endif
            else
                call ctl.SetValue(confDict['useSepDbgArgs'])
                call dlg.SetActivatedByGId(s:GID_PSCtl_SepDbgArgs,
                        \                  confDict['useSepDbgArgs'])
            endif
        elseif ctlId == s:ID_PSCtl_DebugArgs
            if bIsSave
                let confDict['dbgArgs'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['dbgArgs'])
            endif
        elseif ctlId == s:ID_PSCtl_UseSepCCEArgs
            if bIsSave
                if ctl.GetValue()
                    let confDict['useSepCCEngArgs'] = ctl.GetValue()
                else
                    " vim 的数字传到 python 之后是字符串
                    " 要求在布尔上下文中为False即可
                    let confDict['useSepCCEngArgs'] = ''
                endif
            else
                call ctl.SetValue(confDict['useSepCCEngArgs'])
                call dlg.SetActivatedByGId(s:GID_PSCtl_SepCCEArgs,
                        \                  confDict['useSepCCEngArgs'])
            endif
        elseif ctlId == s:ID_PSCtl_CCEngIncArgs
            if bIsSave
                let confDict['sepCCEngIncArgs'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['sepCCEngIncArgs'])
            endif
        elseif ctlId == s:ID_PSCtl_CCEngMacArgs
            if bIsSave
                let confDict['sepCCEngMacArgs'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['sepCCEngMacArgs'])
            endif
        elseif ctlId == s:ID_PSCtl_IgnoreFiles
            if bIsSave
                " 这个是不允许修改的，所以不用保存了
                "let confDict['ignFiles'] = ctl.GetValue()
            else
                "call ctl.SetValue(confDict['ignFiles'])
                py vim.command("call ctl.SetValue(%s)" % ToVimEval(
                        \        PrettyIgnoredFiles(vim.eval('sProjectName'),
                        \               vim.eval("confDict['ignFiles']"))))
            endif
        elseif ctlId == s:ID_PSCtl_Cmpl_UseWithGlb
            if bIsSave
                let confDict['cmplOptsFlag'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['cmplOptsFlag'])
            endif
        elseif ctlId == s:ID_PSCtl_Cmpl_COpts
            if bIsSave
                let confDict['cCmplOpts'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['cCmplOpts'])
            endif
        elseif ctlId == s:ID_PSCtl_Cmpl_CxxOpts
            if bIsSave
                let confDict['cxxCmplOpts'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['cxxCmplOpts'])
            endif
        elseif ctlId == s:ID_PSCtl_Cmpl_CCxxOpts
            if bIsSave
                let confDict['cCxxCmplOpts'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['cCxxCmplOpts'])
            endif
        elseif ctlId == s:ID_PSCtl_Cmpl_IncPaths
            if bIsSave
                let confDict['incPaths'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['incPaths'])
            endif
        elseif ctlId == s:ID_PSCtl_Cmpl_Prep
            if bIsSave
                let confDict['preprocs'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['preprocs'])
            endif
        elseif ctlId == s:ID_PSCtl_Cmpl_PCH
            if bIsSave
                let confDict['PCH'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['PCH'])
            endif
        elseif ctlId == s:ID_PSCtl_Link_UseWithGlb
            if bIsSave
                let confDict['linkOptsFlag'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['linkOptsFlag'])
            endif
        elseif ctlId == s:ID_PSCtl_Link_Opts
            if bIsSave
                let confDict['linkOpts'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['linkOpts'])
            endif
        elseif ctlId == s:ID_PSCtl_Link_LibPaths
            if bIsSave
                let confDict['libPaths'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['libPaths'])
            endif
        elseif ctlId == s:ID_PSCtl_Link_Libs
            if bIsSave
                let confDict['libs'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['libs'])
            endif
        elseif ctlId == s:ID_PSCtl_PreBuild
            if bIsSave
                "let confDict['preBldCmds'] = ctl.GetValue()
                let confDict['preBldCmds'] = []
                for line in ctl.table
                    let d = {}
                    let d['enabled'] = line[0] ? '1' : ''
                    let d['command'] = line[1]
                    call add(confDict['preBldCmds'], d)
                endfor
            else
                "call ctl.SetValue(confDict['preBldCmds'])
                call ctl.DeleteAllLines()
                for d in confDict['preBldCmds']
                    call ctl.AddLine([d['enabled'], d['command']])
                endfor
            endif
        elseif ctlId == s:ID_PSCtl_PostBuild
            if bIsSave
                "let confDict['postBldCmds'] = ctl.GetValue()
                let confDict['postBldCmds'] = []
                for line in ctl.table
                    let d = {}
                    let d['enabled'] = line[0] ? '1' : ''
                    let d['command'] = line[1]
                    call add(confDict['postBldCmds'], d)
                endfor
            else
                "call ctl.SetValue(confDict['postBldCmds'])
                call ctl.DeleteAllLines()
                for d in confDict['postBldCmds']
                    call ctl.AddLine([d['enabled'], d['command']])
                endfor
            endif
        elseif ctlId == s:ID_PSCtl_CstBld_Enable
            if bIsSave
                if ctl.GetValue()
                    let confDict['enableCstBld'] = ctl.GetValue()
                else
                    let confDict['enableCstBld'] = ''
                endif
            else
                call ctl.SetValue(confDict['enableCstBld'])
                call dlg.SetActivatedByGId(
                            \s:GID_PSCtl_CustomBuild, confDict['enableCstBld'])
            endif
        elseif ctlId == s:ID_PSCtl_CstBld_WorkDir
            if bIsSave
                let confDict['cstBldWD'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['cstBldWD'])
            endif
        elseif ctlId == s:ID_PSCtl_CstBld_Targets
            if bIsSave
                "let confDict['othCstTgts'] = ctl.GetValue()
                " 这个要清空
                let confDict['othCstTgts'] = {}
                for line in ctl.table
                    let sTgt = line[0]
                    let sCmd = line[1]
                    if sTgt ==# 'Build'
                        let confDict['cstBldCmd'] = sCmd
                    elseif sTgt ==# 'Clean'
                        let confDict['cstClnCmd'] = sCmd
                    else
                        let confDict['othCstTgts'][sTgt] = sCmd
                    endif
                endfor
            else
                "call ctl.SetValue(confDict['othCstTgts'])
                call ctl.DeleteAllLines()
                call ctl.AddLine(['Build', confDict['cstBldCmd']])
                call ctl.AddLine(['Clean', confDict['cstClnCmd']])
                for li in items(confDict['othCstTgts'])
                    call ctl.AddLine(li)
                endfor
            endif
        " ====== Global Settings =====
        elseif ctlId == s:ID_PSCtl_Glb_Cmpl_COpts
            if bIsSave
                let glbCnfDict['cCmplOpts'] = ctl.GetValue()
            else
                call ctl.SetValue(glbCnfDict['cCmplOpts'])
            endif
        elseif ctlId == s:ID_PSCtl_Glb_Cmpl_CxxOpts
            if bIsSave
                let glbCnfDict['cxxCmplOpts'] = ctl.GetValue()
            else
                call ctl.SetValue(glbCnfDict['cxxCmplOpts'])
            endif
        elseif ctlId == s:ID_PSCtl_Glb_Cmpl_CCxxOpts
            if bIsSave
                let glbCnfDict['cCxxCmplOpts'] = ctl.GetValue()
            else
                call ctl.SetValue(glbCnfDict['cCxxCmplOpts'])
            endif
        elseif ctlId == s:ID_PSCtl_Glb_Cmpl_IncPaths
            if bIsSave
                let glbCnfDict['incPaths'] = ctl.GetValue()
            else
                call ctl.SetValue(glbCnfDict['incPaths'])
            endif
        elseif ctlId == s:ID_PSCtl_Glb_Cmpl_Prep
            if bIsSave
                let glbCnfDict['preprocs'] = ctl.GetValue()
            else
                call ctl.SetValue(glbCnfDict['preprocs'])
            endif
        elseif ctlId == s:ID_PSCtl_Glb_Link_Opts
            if bIsSave
                let glbCnfDict['linkOpts'] = ctl.GetValue()
            else
                call ctl.SetValue(glbCnfDict['linkOpts'])
            endif
        elseif ctlId == s:ID_PSCtl_Glb_Link_LibPaths
            if bIsSave
                let glbCnfDict['libPaths'] = ctl.GetValue()
            else
                call ctl.SetValue(glbCnfDict['libPaths'])
            endif
        elseif ctlId == s:ID_PSCtl_Glb_Link_Libs
            if bIsSave
                let glbCnfDict['libs'] = ctl.GetValue()
            else
                call ctl.SetValue(glbCnfDict['libs'])
            endif
        " ====== End =====
        else
        endif
    endfor
    if bIsSave
        " 保存
        py ws.SaveProjectSettings(vim.eval('sProjectName'), 
                    \             vim.eval('sConfigName'), 
                    \             vim.eval('confDict'), 
                    \             vim.eval('glbCnfDict'))
        py ws.UpdateBuildMTime()
    endif
endfunction
"}}}2
function! s:ProjectSettings_ChangeConfigCbk(dCtl, data) "{{{2
    let dDlg = a:dCtl.owner

    if dDlg.IsModified()
        " 如果本页可能已经修改，给出警告
        echohl WarningMsg
        let sAnswer = input("Settings seems to have been modified, "
                    \."would you like to save them? (y/n): ", "y")
        echohl None
        if sAnswer ==? 'y'
            call s:ProjectSettings_OperateContents(dDlg, 1, 1)
        endif
    endif

    call s:ProjectSettings_OperateContents(dDlg, 0, 0)
    call dDlg.Refresh()
    call dDlg.SetModified(0)
endfunction
"}}}2
function! s:ProjectSettings_SaveCbk(dlg, data) "{{{2
    call s:ProjectSettings_OperateContents(a:dlg, 1, 0)
endfunction
"}}}2
function! s:ProjectSettings_CreateDialog(sProjectName) "{{{2
    let sProjectName = a:sProjectName
    let sBufName = printf('== %s ProjectSettings ==', sProjectName)
    let dlg = g:VimDialog.New(sBufName)
    call dlg.SetData(sProjectName) " 对话框的私有数据保存项目名字
    call dlg.SetExtraHelpContent(s:GetProjectSettingsHelpText())

    let ctl = g:VCComboBox.New("Project Configuration")
    call ctl.SetId(s:ID_PSCtl_ProjectConfigurations)
    let ctl.ignoreModify = 1 " 不统计本控件的修改
    call ctl.ConnectActionPostCallback(
                \s:GetSFuncRef('s:ProjectSettings_ChangeConfigCbk'), '')
    py vim.command('let lConfigs = %s' % ToVimEval(
                \       ws.GetProjectConfigList(vim.eval('sProjectName'))))
    for sConfigName in lConfigs
        call ctl.AddItem(sConfigName)
    endfor
    " 设置当前的配置名字
    py vim.command('call ctl.SetValue(%s)' % ToVimEval(
                \ws.GetProjectCurrentConfigName(vim.eval('sProjectName'))))
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

" ============================================================================
" 1. Common Settings
    call dlg.AddSeparator()
    let ctl = g:VCStaticText.New('Common Settings')
    call ctl.SetHighlight("Special")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    " --------------------------------------------------------------------------
    " General
    " --------------------------------------------------------------------------
    " 1.1.常规设置
    let ctl = g:VCStaticText.New("General")
    call ctl.SetHighlight("Identifier")
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)

    " 1.1.1.项目类型
    let ctl = g:VCComboBox.New('Project Type:')
    call ctl.SetId(s:ID_PSCtl_ProjectType)
    call ctl.SetIndent(8)
    call ctl.AddItem('Executable')
    call ctl.AddItem('Dynamic Library')
    call ctl.AddItem('Static Library')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    " 1.1.2.编译器
    let ctl = g:VCComboBox.New('Compiler:')
    call ctl.SetId(s:ID_PSCtl_Compiler)
    call ctl.SetIndent(8)
    py vim.command('let lCmplNames = %s' 
                \% ToVimEval(BuildSettingsST.Get().GetCompilerNameList()))
    for sCmplName in lCmplNames
        call ctl.AddItem(sCmplName)
    endfor
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    " 1.1.3.过渡文件夹
    let ctl = g:VCSingleText.New("Intermediate Directory:")
    call ctl.SetId(s:ID_PSCtl_OutDir)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    " 1.1.4.输出文件
    let ctl = g:VCSingleText.New("Output File:")
    call ctl.SetId(s:ID_PSCtl_OutputFile)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()
    let sep = g:VCSeparator.New('-')
    call sep.SetIndent(8)
    call dlg.AddControl(sep)

    let ctl = g:VCSingleText.New("Program:")
    call ctl.SetId(s:ID_PSCtl_Program)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("Program Working Directory:")
    call ctl.SetId(s:ID_PSCtl_ProgramWD)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("Program Arguments:")
    call ctl.SetId(s:ID_PSCtl_ProgramArgs)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCCheckItem.New("Use Separate Debug Arguments")
    call ctl.SetId(s:ID_PSCtl_UseSepDbgArgs)
    call ctl.SetIndent(8)
    call ctl.ConnectActionPostCallback(s:GetSFuncRef('s:ActiveIfCheckCbk'), 
            \                          s:GID_PSCtl_SepDbgArgs)
    call dlg.AddControl(ctl)

    let ctl = g:VCSingleText.New("Separate Debug Arguments:")
    call ctl.SetId(s:ID_PSCtl_DebugArgs)
    call ctl.SetGId(s:GID_PSCtl_SepDbgArgs)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    " 其他的一些特殊设置
    let sep = g:VCSeparator.New('-')
    call sep.SetIndent(8)
    call dlg.AddControl(sep)

    " 补全引擎参数
    let ctl = g:VCCheckItem.New("Use Separate Code Complete Arguments")
    call ctl.SetId(s:ID_PSCtl_UseSepCCEArgs)
    call ctl.SetIndent(8)
    call ctl.ConnectActionPostCallback(s:GetSFuncRef('s:ActiveIfCheckCbk'), 
            \                          s:GID_PSCtl_SepCCEArgs)
    call dlg.AddControl(ctl)
    let ctl = g:VCSingleText.New("Separate Code Complete Include Paths:")
    call ctl.SetId(s:ID_PSCtl_CCEngIncArgs)
    call ctl.SetGId(s:GID_PSCtl_SepCCEArgs)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    let ctl = g:VCSingleText.New("Separate Code Complete Predefine Macros:")
    call ctl.SetId(s:ID_PSCtl_CCEngMacArgs)
    call ctl.SetGId(s:GID_PSCtl_SepCCEArgs)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCMultiText.New(
            \"Ignored Files (Please add/remove them by Workspace popup menus):")
    call ctl.SetId(s:ID_PSCtl_IgnoreFiles)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    " --------------------------------------------------------------------------
    " Compiler
    " --------------------------------------------------------------------------
    let ctl = g:VCStaticText.New("Compiler")
    call ctl.SetHighlight("Identifier")
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)

    let ctl = g:VCComboBox.New('Use With Global Settings:')
    call ctl.SetId(s:ID_PSCtl_Cmpl_UseWithGlb)
    call ctl.SetIndent(8)
    call ctl.AddItem('overwrite')
    call ctl.AddItem('append')
    call ctl.AddItem('prepend')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("C and C++ Compile Options (for C and C++):")
    call ctl.SetId(s:ID_PSCtl_Cmpl_CCxxOpts)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("C Compile Options (for C):")
    call ctl.SetId(s:ID_PSCtl_Cmpl_COpts)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("C++ Compile Options (for C++):")
    call ctl.SetId(s:ID_PSCtl_Cmpl_CxxOpts)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("Include Paths (for C and C++):")
    call ctl.SetId(s:ID_PSCtl_Cmpl_IncPaths)
    call ctl.SetIndent(8)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditPSOptBtnCbk"), '')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("Predefine Macros (for C and C++):")
    call ctl.SetId(s:ID_PSCtl_Cmpl_Prep)
    call ctl.SetIndent(8)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditPSOptBtnCbk"), '')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    " 这个东西暂时不用，以后再说
    let ctl = g:VCSingleText.New("PCH:")
    call ctl.SetId(s:ID_PSCtl_Cmpl_PCH)
    call ctl.SetIndent(8)
    "call dlg.AddControl(ctl)
    "call dlg.AddBlankLine()

    " --------------------------------------------------------------------------
    " Linker
    " --------------------------------------------------------------------------
    let ctl = g:VCStaticText.New("Linker")
    call ctl.SetHighlight("Identifier")
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)

    let ctl = g:VCComboBox.New('Use With Global Settings:')
    call ctl.SetId(s:ID_PSCtl_Link_UseWithGlb)
    call ctl.SetIndent(8)
    call ctl.AddItem('overwrite')
    call ctl.AddItem('append')
    call ctl.AddItem('prepend')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("Options:")
    call ctl.SetId(s:ID_PSCtl_Link_Opts)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("Library Paths:")
    call ctl.SetId(s:ID_PSCtl_Link_LibPaths)
    call ctl.SetIndent(8)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditPSOptBtnCbk"), '')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("Libraries:")
    call ctl.SetId(s:ID_PSCtl_Link_Libs)
    call ctl.SetIndent(8)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditPSOptBtnCbk"), '')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

" ============================================================================
" 2. Pre / Post Build Commands
    " --------------------------------------------------------------------------
    " Pre / Post Build Commands
    " --------------------------------------------------------------------------
    call dlg.AddBlankLine()
    call dlg.AddSeparator()
    let ctl = g:VCStaticText.New('Pre / Post Build Commands')
    call ctl.SetHighlight("Special")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCStaticText.New("Pre Build")
    call ctl.SetHighlight("Identifier")
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)

    let ctl = g:VCTable.New('Set the commands to run in the pre build stage:', 
                \2)
    call ctl.SetId(s:ID_PSCtl_PreBuild)
    call ctl.SetIndent(8)
    call ctl.SetColType(1, ctl.CT_CHECK)
    call ctl.SetDispHeader(0)
    call ctl.ConnectBtnCallback(0, s:GetSFuncRef('s:AddBuildTblLineCbk'), '')
    call ctl.ConnectBtnCallback(2, s:GetSFuncRef('s:EditBuildTblLineCbk'), '')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCStaticText.New("Post Build")
    call ctl.SetHighlight("Identifier")
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)

    let ctl = g:VCTable.New('Set the commands to run in the post build stage:', 
                \2)
    call ctl.SetId(s:ID_PSCtl_PostBuild)
    call ctl.SetIndent(8)
    call ctl.SetColType(1, ctl.CT_CHECK)
    call ctl.SetDispHeader(0)
    call ctl.ConnectBtnCallback(0, s:GetSFuncRef('s:AddBuildTblLineCbk'), '')
    call ctl.ConnectBtnCallback(2, s:GetSFuncRef('s:EditBuildTblLineCbk'), '')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

" ============================================================================
" 3. Customize
    " ------------------------------------------------------------------------
    " Customize
    " ------------------------------------------------------------------------
    call dlg.AddBlankLine()
    call dlg.AddSeparator()
    let ctl = g:VCStaticText.New('Customize')
    call ctl.SetHighlight("Special")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCStaticText.New("Custom Build")
    call ctl.SetHighlight("Identifier")
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)

    let ctl = g:VCCheckItem.New('Enable custom build')
    call ctl.SetId(s:ID_PSCtl_CstBld_Enable)
    call ctl.SetIndent(8)
    call ctl.ConnectActionPostCallback(s:GetSFuncRef('s:ActiveIfCheckCbk'), 
                \s:GID_PSCtl_CustomBuild)
    call dlg.AddControl(ctl)
    let sep = g:VCSeparator.New('~')
    call sep.SetIndent(8)
    call dlg.AddControl(sep)

    let ctl = g:VCSingleText.New('Working Directory')
    call ctl.SetId(s:ID_PSCtl_CstBld_WorkDir)
    call ctl.SetGId(s:GID_PSCtl_CustomBuild)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCTable.New('', 2)
    call ctl.SetId(s:ID_PSCtl_CstBld_Targets)
    call ctl.SetGId(s:GID_PSCtl_CustomBuild)
    call ctl.SetIndent(8)
    call ctl.SetColTitle(1, 'Target')
    call ctl.SetColTitle(2, 'Command')
    call ctl.ConnectBtnCallback(0, s:GetSFuncRef('s:CustomBuildTblAddCbk'), '')
    call ctl.ConnectSelectionCallback(
                \s:GetSFuncRef('s:CustomBuildTblSelectionCbk'), '')
    call ctl.DisableButton(2)
    call ctl.DisableButton(5)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

" ============================================================================
" 3. Global Settings
    call dlg.AddBlankLine()
    call dlg.AddSeparator()
    let ctl = g:VCStaticText.New('Global Settings')
    call ctl.SetHighlight("Special")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()
    " --------------------------------------------------------------------------
    " Compiler
    " --------------------------------------------------------------------------
    let ctl = g:VCStaticText.New("Compiler")
    call ctl.SetHighlight("Identifier")
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)

    let ctl = g:VCSingleText.New("C and C++ Compile Options (for C and C++):")
    call ctl.SetId(s:ID_PSCtl_Glb_Cmpl_CCxxOpts)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("C Compile Options (for C):")
    call ctl.SetId(s:ID_PSCtl_Glb_Cmpl_COpts)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("C++ Compile Options (for C++):")
    call ctl.SetId(s:ID_PSCtl_Glb_Cmpl_CxxOpts)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("Include Paths (for C and C++):")
    call ctl.SetId(s:ID_PSCtl_Glb_Cmpl_IncPaths)
    call ctl.SetIndent(8)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditPSOptBtnCbk"), '')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("Predefine Macros (for C and C++):")
    call ctl.SetId(s:ID_PSCtl_Glb_Cmpl_Prep)
    call ctl.SetIndent(8)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditPSOptBtnCbk"), '')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    " --------------------------------------------------------------------------
    " Linker
    " --------------------------------------------------------------------------
    let ctl = g:VCStaticText.New("Linker")
    call ctl.SetHighlight("Identifier")
    call ctl.SetIndent(4)
    call dlg.AddControl(ctl)

    let ctl = g:VCSingleText.New("Options:")
    call ctl.SetId(s:ID_PSCtl_Glb_Link_Opts)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("Library Paths:")
    call ctl.SetId(s:ID_PSCtl_Glb_Link_LibPaths)
    call ctl.SetIndent(8)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditPSOptBtnCbk"), '')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCSingleText.New("Libraries:")
    call ctl.SetId(s:ID_PSCtl_Glb_Link_Libs)
    call ctl.SetIndent(8)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditPSOptBtnCbk"), '')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

" ============================================================================
    call dlg.AddFooterButtons()
    call dlg.ConnectSaveCallback(s:GetSFuncRef("s:ProjectSettings_SaveCbk"), '')

    return dlg
endfunction
"}}}2
"}}}1
" =================== 代码导航 ===================
"{{{1
" ===== 符号数据库统一框架的接口 =====
function s:EmptyFunc(...) "{{{2
    "echomsg 'calling empty function...'
    echohl WarningMsg
    echomsg "Without using any symbol database, nothing to do"
    echohl None
endfunction
"}}}
let s:SymdbInitHook = s:GetSFuncRef('s:EmptyFunc')
let s:SymdbInitHookData = ''
let s:SymdbUpdateHook = s:GetSFuncRef('s:EmptyFunc')
let s:SymdbUpdateHookData = ''
function! Videm_DumpSymdbHook() "{{{2
    echo s:SymdbInitHook
    echo s:SymdbInitHookData
    echo s:SymdbUpdateHook
    echo s:SymdbUpdateHookData
    return ''
endfunction
"}}}
function! Videm_RegisterSymdbInitHook(hook, data) "{{{2
    if type(a:hook) == type('')
        let s:SymdbInitHook = function(a:hook)
    else
        let s:SymdbInitHook = a:hook
    endif
    unlet s:SymdbInitHookData
    let s:SymdbInitHookData = a:data
endfunction
"}}}
function! Videm_UnregisterSymdbInitHook(hook) "{{{2
    if type(a:hook) == type('')
        let Hook = function(a:hook)
    else
        let Hook = a:hook
    endif
    if s:SymdbInitHook != Hook
        return
    endif

    let s:SymdbInitHook = s:GetSFuncRef('s:EmptyFunc')
    unlet s:SymdbInitHookData
    let s:SymdbInitHookData = ''
endfunction
"}}}
function! Videm_RegisterSymdbUpdateHook(hook, data) "{{{2
    if type(a:hook) == type('')
        let s:SymdbUpdateHook = function(a:hook)
    else
        let s:SymdbUpdateHook = a:hook
    endif
    unlet s:SymdbUpdateHookData
    let s:SymdbUpdateHookData = a:data
endfunction
"}}}
function! Videm_UnregisterSymdbUpdateHook(hook) "{{{2
    if type(a:hook) == type('')
        let Hook = function(a:hook)
    else
        let Hook = a:hook
    endif
    if s:SymdbUpdateHook != Hook
        return
    endif

    let s:SymdbUpdateHook = s:GetSFuncRef('s:EmptyFunc')
    unlet s:SymdbUpdateHookData
    let s:SymdbUpdateHookData = ''
endfunction
"}}}
function! Videm_SymdbInit() "{{{2
    "echo 'Initializing Symbol Database...'
    let ret = s:SymdbInitHook(s:SymdbInitHookData)
    "redraw | echo 'Done'
    return ret
endfunction
"}}}
function! Videm_SymdbUpdate() "{{{2
    "echo 'Updating Symbol Database...'
    let ret = s:SymdbUpdateHook(s:SymdbUpdateHookData)
    "redraw | echo 'Done'
    return ret
endfunction
"}}}
function! s:SymdbInited() "{{{2
    let output = vlutils#GetCmdOutput('cs show')
    let lines = split(output, '\n')
    let wspname = GetWspName()
    for line in lines
        if empty(line) || line =~# '^\s\+#'
            continue
        endif
        let s = substitute(line, '^\s*\d\+\s\+\d\+\s\+', '', '')
        let s = split(s)[0]
        " 只取basename检查
        let bname = fnamemodify(s, ':t')
        " 工作空间名字就是特征
        if stridx(bname, wspname) == 0 || bname ==# 'GTAGS'
            return 1
        endif
    endfor
    return 0
endfunction
"}}}
" 符号数据库预处理，提示初始化等等
" @return: 1 - ok，0 - fail
function! s:SymdbPreproc() "{{{2
    if s:SymdbInited()
        return 1
    endif

    echohl WarningMsg
    let prompt  = 'Symbol database has not been initialized, '
    let prompt .= 'would you like to initialize it now? (y/n): '
    let sAnswer = input(prompt)
    echohl None
    if sAnswer[0:0] !=? 'y'
        redraw | echo ''
        return 0
    endif

    " 初始化
    echo "\nInitializing symbol database..."
    call Videm_SymdbInit()
    " 防止 Videm_SymdbInit() 有打印，影响输出美感
    redraw | echo ''
    return 1
endfunction
"}}}
function! s:SetupSymdbQuickfix(...) "{{{2
    " cscopequickfix 的选项
    let opt = get(a:000, 0, '')
    augroup VLWorkspace
        autocmd! QuickFixCmdPost * call s:SymdbQuifixHook()
    augroup END
    if opt !=# 'keep' " 支持一个特殊值
        let s:cscopequickfix_bak = &cscopequickfix
        let &cscopequickfix = opt
    endif
endfunction
"}}}
function! s:SymdbQuifixHook() "{{{2
    " 先清理
    call s:CleanSymdbQuickfix()

    if len(getqflist()) <= 1
        return
    endif

    " 打开 quickfix 窗口
    bo cw
endfunction
"}}}
function! s:CleanSymdbQuickfix() "{{{2
    " 删除自动命令
    autocmd! VLWorkspace QuickFixCmdPost
    " 恢复选项
    if exists('s:cscopequickfix_bak')
        let &cscopequickfix = s:cscopequickfix_bak
        unlet s:cscopequickfix_bak
    endif
endfunction
"}}}
" 搜索符号定义
function! s:SearchSymbolDefinition(symbol) "{{{2
    if empty(a:symbol)
        return 0
    endif
    if !s:SymdbPreproc()
        return 1
    endif
    if videm#settings#Get('.videm.symdb.Quickfix')
        call s:SetupSymdbQuickfix('keep')
    endif
    try
        exec 'cs find g' a:symbol
    catch
        call s:CleanSymdbQuickfix()
    endtry
endfunction
"}}}
" 搜索符号声明
function! s:SearchSymbolDeclaration(symbol) "{{{2
    if empty(a:symbol)
        return 0
    endif
    if !s:SymdbPreproc()
        return 1
    endif
    if videm#settings#Get('.videm.symdb.Quickfix')
        call s:SetupSymdbQuickfix('keep')
    endif
    try
        exec 'cs find g' a:symbol
    catch
        call s:CleanSymdbQuickfix()
    endtry
endfunction
"}}}
" 搜索符号调用
function! s:SearchSymbolCalling(symbol) "{{{2
    if empty(a:symbol)
        return 0
    endif
    if !s:SymdbPreproc()
        return 1
    endif
    if videm#settings#Get('.videm.symdb.Quickfix')
        call s:SetupSymdbQuickfix('c-')
    endif
    try
        exec 'cs find c' a:symbol
    catch
        call s:CleanSymdbQuickfix()
    endtry
endfunction
"}}}
" 搜索符号引用
function! s:SearchSymbolReference(symbol) "{{{2
    if empty(a:symbol)
        return 0
    endif
    if !s:SymdbPreproc()
        return 1
    endif
    if videm#settings#Get('.videm.symdb.Quickfix')
        call s:SetupSymdbQuickfix('s-')
    endif
    try
        exec 'cs find s' a:symbol
    "catch /^Vim\%((\a\+)\)\=:E259/ " 捕获特定的错误，E259 表示查找失败
    catch
        call s:CleanSymdbQuickfix()
    endtry
endfunction
"}}}
"}}}1
" ============================================================================
" ============================================================================

" 会话文件的后缀，前缀统一为工作空间名字
let s:videm_session_suffix = '.session'

function! Videm_GetVersion() "{{{2
    if s:bHadInited
        py vim.command("return %d" % VIMLITE_VER)
    else
        return 0
    endif
endfunction
"}}}
function! Videm_GetWorkspaceName() "{{{2
    py vim.command("return %s" % ToVimEval(ws.VLWIns.name))
endfunction
"}}}
function! Videm_IsFileInWorkspace(fname) "{{{2
    return s:IsWorkspaceFile(a:fname)
endfunction
"}}}
" *DEPRECATED*
function! VidemVersion() "{{{2
    return Videm_GetVersion()
endfunction
"}}}
function! s:SaveSession(filename) "{{{2
    let filename = a:filename
    if empty(filename)
        " 空文件名的话，表示使用默认的名字
        let filename = printf('%s%s',
                \              Videm_GetWorkspaceName(), s:videm_session_suffix)
    endif
    let sessionoptions_bak = &sessionoptions
    let &sessionoptions = videm#settings#Get('.videm.wsp.SessionOptions')
    py l_session = VidemSession()
    py vim.command("let ret = %d" % l_session.Save(vim.eval('filename')))
    py del l_session
    let &sessionoptions = sessionoptions_bak
    if ret != 0
        call s:echow('Failed to save videm session!')
    endif
    return ret
endfunction
"}}}
function! s:LoadSession(filename) "{{{2
    let filename = a:filename
    if empty(filename)
        " 空文件名的话，表示使用默认的名字
        let filename = printf('%s%s',
                \              Videm_GetWorkspaceName(), s:videm_session_suffix)
    endif
    py l_session = VidemSession()
    py vim.command("let ret = %d" % l_session.Load(vim.eval('filename')))
    py del l_session
    if ret != 0
        call s:echow('Failed to load videm session!')
    endif
    return ret
endfunction
"}}}
function! s:AutoLoadSession() "{{{2
    if !videm#settings#Get('.videm.wsp.AutoSession')
        return
    endif
    py if not videm.wsp.IsOpen(): vim.command('return')
    py vim.command("let dir = %s" % ToVimEval(videm.wsp.VLWIns.dirName))
    let filename = s:os.path.join(dir,
            \               Videm_GetWorkspaceName() . s:videm_session_suffix)
    return s:LoadSession(filename)
endfunction
"}}}
function! s:AutoSaveSession() "{{{2
    if !videm#settings#Get('.videm.wsp.AutoSession')
        return
    endif
    py if not videm.wsp.IsOpen(): vim.command('return')
    py vim.command("let dir = %s" % ToVimEval(videm.wsp.VLWIns.dirName))
    let filename = s:os.path.join(dir,
            \               Videm_GetWorkspaceName() . s:videm_session_suffix)
    return s:SaveSession(filename)
endfunction
"}}}
function! s:InitPythonInterfaces() "{{{2
    " 防止重复初始化
    if s:bHadInited
        return
    endif

    call vpymod#driver#Init()
    let pyf = g:vlutils#os.path.join(fnamemodify(s:sfile, ':h'), 'wsp.py')
    exec 'pyfile' fnameescape(pyf)
    py from Misc import GetBgThdCnt, Touch, GetMTime
    py from Macros import VIMLITE_VER
endfunction
"}}}2
function! s:LoadPlugin() "{{{2
    let sPluginPath = s:os.path.join(s:os.path.dirname(s:sfile), 'plugin')
    let lPlugin = split(globpath(sPluginPath, "*.vim"), '\n')
    for sFile in lPlugin
        let sName = fnamemodify(sFile, ':t:r')
        exec printf('call videm#plugin#%s#Init()', sName)
        call add(s:loaded_plugins, sName)
    endfor
endfunction
"}}}2
function! videm#wsp#PlugInfo() "{{{2
    let enables = []
    let disables = []
    for name in s:loaded_plugins
        let funcname = printf("videm#plugin#%s#HasEnabled", name)
        let state = 'Unknown'
        if exists('*'.funcname)
            exec printf("let ret = %s()", funcname)
            let state = 'Disabled'
            if ret
                let state = 'Enabled'
            endif
        endif
        let msg = printf("%s\t[%s]", name, state)
        if state ==# 'Enabled'
            call add(enables, msg)
        else
            call add(disables, msg)
        endif
    endfor

    " 显示
    echohl Special
    for msg in enables
        echo msg
    endfor
    echohl None
    for msg in disables
        echo msg
    endfor
    return ''
endfunction
" 获取已经载入的插件
function! VidemGetLoadedPlugins() "{{{2
    return s:loaded_plugins
endfunction
"}}}

" vim:fdm=marker:fen:et:sts=4:fdl=1:
