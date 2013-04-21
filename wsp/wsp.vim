" Vim global plugin for handle workspace
" Author:   fanhe <fanhed@163.com>
" License:  This file is placed in the public domain.
" Create:   2011 Mar 18
" Change:   2011 Jun 14

if exists("g:loaded_autoload_wsp")
    finish
endif
let g:loaded_autoload_wsp = 1


if !has('python')
    echoerr "Error: Required vim compiled with +python"
    finish
endif
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

if vlutils#IsWindowsOS()
    call s:InitVariable("g:VimLiteDir", fnamemodify($VIM . '\vimlite', ":p"))
else
    call s:InitVariable("g:VimLiteDir", fnamemodify("~/.vimlite", ":p"))
endif

call s:InitVariable("g:VLWorkspaceWinSize", 30)
call s:InitVariable("g:VLWorkspaceWinPos", "left")
call s:InitVariable("g:VLWorkspaceBufName", '== VLWorkspace ==')
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

" 0 -> none, 1 -> cscope, 2 -> global tags
" 见下面的 python 代码
"call s:InitVariable('g:VLWorkspaceSymbolDatabase', 1)
" Cscope tags database
call s:InitVariable('g:VLWorkspaceCscopeProgram', &cscopeprg)
call s:InitVariable('g:VLWorkspaceCscopeContainExternalHeader', 1)
call s:InitVariable('g:VLWorkspaceCreateCscopeInvertedIndex', 0)
" 以下几个 cscope 选项仅供内部使用
call s:InitVariable('g:VLWorkspaceCscpoeFilesFile', '_cscope.files')
call s:InitVariable('g:VLWorkspaceCscpoeOutFile', '_cscope.out')

" Global tags database
"call s:InitVariable('g:VLWorkspaceGtagsGlobalProgram', 'global')
call s:InitVariable('g:VLWorkspaceGtagsProgram', 'gtags')
call s:InitVariable('g:VLWorkspaceGtagsCscopeProgram', 'gtags-cscope')
call s:InitVariable('g:VLWorkspaceGtagsFilesFile', '_gtags.files')
call s:InitVariable('g:VLWorkspaceUpdateGtagsAfterSave', 1)

" vim 的自定义命令可带 '-' 和 '_' 字符
call s:InitVariable('g:VLWorkspaceHadVimCommandPatch', 0)

" 保存文件时自动解析文件, 仅对属于工作空间的文件有效
call s:InitVariable("g:VLWorkspaceParseFileAfterSave", 1)

" 补全引擎选择，'none', 'omnicpp', 'vimccc'
call s:InitVariable("g:VLWorkspaceCodeCompleteEngine", 'omnicpp')

" 保存调试器信息, 默认不保存, 因为暂时无法具体控制
call s:InitVariable("g:VLWDbgSaveBreakpointsInfo", 1)

" 禁用不必要的工具图标
call s:InitVariable("g:VLWDisableUnneededTools", 1)

" 键绑定
call s:InitVariable('g:VLWShowMenuKey', '.')
call s:InitVariable('g:VLWPopupMenuKey', ',')
call s:InitVariable('g:VLWOpenNodeKey', 'o')
call s:InitVariable('g:VLWOpenNode2Key', 'go')
call s:InitVariable('g:VLWOpenNodeInNewTabKey', 't')
call s:InitVariable('g:VLWOpenNodeInNewTab2Key', 'T')
call s:InitVariable('g:VLWOpenNodeSplitKey', 'i')
call s:InitVariable('g:VLWOpenNodeSplit2Key', 'gi')
call s:InitVariable('g:VLWOpenNodeVSplitKey', 's')
call s:InitVariable('g:VLWOpenNodeVSplit2Key', 'gs')
call s:InitVariable('g:VLWGotoParentKey', 'p')
call s:InitVariable('g:VLWGotoRootKey', 'P')
call s:InitVariable('g:VLWGotoNextSibling', '<C-n>')
call s:InitVariable('g:VLWGotoPrevSibling', '<C-p>')
call s:InitVariable('g:VLWRefreshBufferKey', 'R')
call s:InitVariable('g:VLWToggleHelpInfo', '<F1>')

" 用于调试器的键绑定
call s:InitVariable('g:VLWDbgWatchVarKey', '<C-w>') " 仅用于可视模式下
call s:InitVariable('g:VLWDbgPrintVarKey', '<C-p>') " 仅用于可视模式下

"=======================================
" 标记是否已经运行
call s:InitVariable("g:VLWorkspaceHasStarted", 0)

call s:InitVariable("g:VLWorkspaceDbgConfName", "VLWDbg.conf")

" 模板所在路径
if vlutils#IsWindowsOS()
    call s:InitVariable("g:VLWorkspaceTemplatesPath", 
                \       $VIM . '\vimlite\templates\projects')
else
    call s:InitVariable("g:VLWorkspaceTemplatesPath", 
                \       $HOME . '/.vimlite/templates/projects')
endif

" 工作区文件后缀名
call s:InitVariable("g:VLWorkspaceWspFileSuffix", "vlworkspace")
" 项目文件后缀名
call s:InitVariable("g:VLWorkspacePrjFileSuffix", "vlproject")

" ============================================================================
" 后向兼容选项处理
if exists('g:VLWorkspaceUseVIMCCC') && g:VLWorkspaceUseVIMCCC
    let g:VLWorkspaceCodeCompleteEngine = 'vimccc'
endif

" ============================================================================
" 全部可配置的信息 {{{2
python << PYTHON_EOF
import vim
# python 的字典结构更容易写...
VLWConfigTemplate = {
    'Base': {
        # 补全引擎
        'g:VLWorkspaceCodeCompleteEngine'    : 'omnicpp',
        # 0 -> none, 1 -> cscope, 2 -> global tags. 可用字符串标识，更具可读性
        'g:VLWorkspaceSymbolDatabase'   : 'cscope',
    },

    'VIMCCC': {
    },

    'OmniCpp': {
    },

    'Debugger': {
    }
}

__VLWNeedRestartConfig = set([
    'g:VLWorkspaceCodeCompleteEngine',
    'g:VLWorkspaceSymbolDatabase',
])

# 全局的配置，只初始化一次，见下
VLWGlobalConfig = {}

# ----------------------------------------------------------------------------
def VLWSetCurrentConfig(config, force=True):
    '''把python的配置字典转为vim的配置变量'''
    for name, conf in config.iteritems():
        i = 0
        if force:
            i = 1
        for ______k, ______v in conf.iteritems():
            # 配置信息的值类型只有整数和字符串两种
            if isinstance(______v, str):
                # 安全地转为 vim 的字符串
                vim.command("call s:InitVariable('%s', '%s', %d)"
                                % (______k, ______v.replace("'", "''"), i))
            else:
                vim.command("call s:InitVariable('%s', %s, %d)"
                                % (______k, str(______v), i))

def VLWRestoreConfigToGlobal():
    '''隐藏掉全局变量 VLWGlobalConfig'''
    global VLWGlobalConfig
    VLWSetCurrentConfig(VLWGlobalConfig, force=True)

def VLWSaveCurrentConfig(config):
    '''根据 VLWConfigTemplate 的规则保存当前工作区的配置到 config'''
    global VLWConfigTemplate
    config.clear() # 无论如何都要清空 config
    for name, conf in VLWConfigTemplate.iteritems():
        config[name] = {}
        for k, v in conf.iteritems():
            if isinstance(v, str):
                config[name][k] = vim.eval(k)
            else: # 整数类型
                config[name][k] = int(vim.eval(k))
# ----------------------------------------------------------------------------

# 根据模板初始化配置变量
VLWSetCurrentConfig(VLWConfigTemplate, force=False)

# 保存当前全局配置到 VLWGlobalConfig
VLWSaveCurrentConfig(VLWGlobalConfig)
PYTHON_EOF
"}}}
" ============================================================================

function! s:IsEnableCscope() "{{{2
    if type(g:VLWorkspaceSymbolDatabase) == type('')
        return g:VLWorkspaceSymbolDatabase ==? 'cscope'
    else
        return g:VLWorkspaceSymbolDatabase == 1
    endif
endfunction
"}}}
function! s:IsEnableGtags() "{{{2
    if type(g:VLWorkspaceSymbolDatabase) == type('')
        return g:VLWorkspaceSymbolDatabase ==? 'gtags'
    else
        return g:VLWorkspaceSymbolDatabase == 2
    endif
endfunction
"}}}
" 标识是否第一次初始化
let s:bHadInited = 0

" 命令导出
"command! -nargs=? -complete=file VLWorkspaceOpen 
            "\                               call <SID>InitVLWorkspace('<args>')


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

"===============================================================================
" 基本实用函数
"===============================================================================
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
"===============================================================================
"===============================================================================

"===============================================================================
" VIMCCC 插件的集成
"===============================================================================
"{{{1
" 1. 进入不同的源文件时，切换不同的 clang index，以提供不同的补全
" 2. 更改项目的编译选项后，需要及时更新相应的 index 编译选项
"    可能改变的场合:
"       (1) 选择不同的工作区构建设置时
"       (2) 修改项目设置
"       (3) 修改工作区的 BuildMatrix
"    应该设置一个需要刷新选项的标识
" 3. 只有进入插入模式时，才开始更新翻译单元的线程
function! s:InitVIMCCCFacilities() "{{{2
    "let g:VIMCCC_Enable = 1 " 保证初始化成功。新版本不需要设置这个也能初始化了
    call VIMClangCodeCompletionInit(1) " 先初始化默认的 clang index
    py OrigVIMCCCIndex = VIMCCCIndex
    "let g:VIMCCC_Enable = 0 " 再禁用 VIMCCC
    autocmd! FileType c,cpp call g:InitVIMClangCodeCompletionExt()

python << PYTHON_EOF
'''定义一些 VIMCCC 专用的 python 函数'''

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
    lArgs += ['-I%s' % i for i in ws.GetCommonIncludePaths()]
    lArgs += ['-I%s' % i for i in ws.GetProjectIncludePaths(projName)]
    lArgs += ['-D%s' % i for i in ws.GetProjectPredefineMacros(projName)]
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
    if Globals.IsCppHeaderFile(sHeaderFile):
        # 头文件的话，需要添加对应的源文件中在包含此头文件之前的所有包含语句内容
        swapFiles = ws.GetSHSwapList(sHeaderFile)
        if swapFiles:
            # 简单处理，只取第一个
            srcFile = swapFiles[0]
            vim.command("call VIMCCCSetRelatedFile('%s')" % ToVimStr(srcFile))

PYTHON_EOF

endfunction
"}}}
" FileType 自动命令调用的函数，第一次初始化
function! g:InitVIMClangCodeCompletionExt() "{{{2
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
        autocmd BufEnter <buffer> call <SID>UpdateClangCodeCompletion()
    else
        " 文件不属于工作空间，不操作
        " 使用默认的 clang.cindex.Index
        py VIMCCCIndex = OrigVIMCCCIndex
    endif

    py del project

    call VIMClangCodeCompletionInit()
    let g:VIMCCC_Enable = bak
endfunction
"}}}
function! s:UpdateClangCodeCompletion() "{{{2
    let bNeedUpdate = 0
    py if ws.buildMTime >= VIMCCCIndex.GetArgsMTime(): 
                \vim.command("let bNeedUpdate = 1")
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
"===============================================================================
"===============================================================================

"===============================================================================
" 缓冲区与窗口操作
"===============================================================================
"{{{1
" 各种检查，返回 0 表示失败，否则返回 1
function s:SanityCheck() "{{{2
    " gtags 的版本至少需要 5.7.6
    if s:IsEnableGtags()
        let minver = 5.8
        let cmd = printf("%s --version", g:VLWorkspaceGtagsProgram)
        let output = system(cmd)
        let sVersion = get(split(get(split(output, '\n'), 0, '')), -1)
        if empty(output) || empty(sVersion)
            call s:echow('failed to run gtags')
            return 0
        endif
        " 取前面两位
        let ver = str2float(sVersion)
        if ver < minver
            let sErr = printf("Required gtags %.1f or later, "
                        \     . "please update it. ", minver)
            let sErr .= "Or you should set g:VLWorkspaceSymbolDatabase"
                    \    . " to 1 or 0 to disable gtags."
            call s:echow(sErr)
            return 0
        endif
    endif

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
        py ws.HlActiveProject()
        return
    endif

    " 如果之前启动过，无论如何都要先关了旧的
    if g:VLWorkspaceHasStarted
        py ws.CloseWorkspace()
    endif

    " 开始
    let g:VLWorkspaceHasStarted = 1

    " 初始化 vimdialog
    call vimdialog#Init()

    " 初始化所有 python 接口
    call s:InitPythonInterfaces()

    if bNeedConvertWspFileFormat
        " 老格式的 workspace, 提示转换格式
        echo "This workspace file is an old format file!"
        echohl Question
        echo "Are you willing to convert all files to new format?"
        echohl WarningMsg
        echo "NOTE1: Recommend 'yes'."
        echo "NOTE2: It will not change original files."
        echo "NOTE3: It will override existing VimLite's workspace and "
                    \. "project files."
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

    " 先清空用到的自动组
    augroup VLWorkspace
        autocmd!
    augroup END

    " 打开工作区文件，初始化全局变量
    py ws = VimLiteWorkspace(vim.eval('sFile'))

    " 文件类型自动命令
    if g:VLWorkspaceCodeCompleteEngine ==? 'vimccc'
        " 使用 VIMCCC，算法复杂，分治处理
        call s:InitVIMCCCFacilities()
    elseif g:VLWorkspaceCodeCompleteEngine ==? 'omnicpp'
        augroup VLWorkspace
            autocmd! FileType c,cpp call omnicpp#complete#Init()
        augroup END
        if g:VLWorkspaceParseFileAfterSave
            augroup VLWorkspace
                autocmd! BufWritePost * call <SID>AsyncParseCurrentFile(1, 1)
            augroup END
        endif
    else
        " 啥都没有
    endif

    " 安装命令
    call s:InstallCommands()

    if g:VLWorkspaceEnableMenuBarMenu
        " 添加菜单栏菜单
        call s:InstallMenuBarMenu()
    endif

    if g:VLWorkspaceEnableToolBarMenu
        " 添加工具栏菜单
        call s:InstallToolBarMenu()
    endif

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

        autocmd BufReadPost * call <SID>Autocmd_WorkspaceEditorOptions()
        autocmd BufEnter    * call <SID>Autocmd_LocateCurrentFile()
        autocmd VimLeave    * call <SID>Autocmd_Quit()
    augroup END

    if s:IsEnableCscope()
        "call s:InitVLWCscopeDatabase()
        call s:ConnectCscopeDatabase()
    endif

    if s:IsEnableGtags()
        call s:ConnectGtagsDatabase()
        if g:VLWorkspaceUpdateGtagsAfterSave
            augroup VLWorkspace
                autocmd BufWritePost * call <SID>Autocmd_UpdateGtagsDatabase(
                            \                                   expand('%:p'))
            augroup END
        endif
    endif

    " 设置标题栏
    if g:VLWorkspaceDispWspNameInTitle
        set titlestring=%(<%{GetWspName()}>\ %)%t%(\ %M%)
                    \%(\ (%{expand(\"%:~:h\")})%)%(\ %a%)%(\ -\ %{v:servername}%)
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

    " 载入插件
    call s:LoadPlugin()
endfunction
"}}}
function! GetWspName() "{{{2
    py vim.command("return %s" % ToVimEval(ws.VLWIns.name))
endfunction
"}}}
function! GetWspConfName() "{{{2
    py vim.command("return %s" % ToVimEval(ws.cache_confName))
endfunction
"}}}
" 这个函数做的工作比较自动化
function! s:AsyncParseCurrentFile(bFilterNotNeed, bIncHdr) "{{{2
    if !exists("s:AsyncParseCurrentFile_FirstEnter")
        let s:AsyncParseCurrentFile_FirstEnter = 1
python << PYTHON_EOF
import threading
class ParseCurrentFileThread(threading.Thread):
    '''同时只允许单个线程工作'''
    lock = threading.Lock()

    def __init__(self, fileName, filterNotNeed = True, incHdr = True):
        threading.Thread.__init__(self)
        self.fileName = fileName
        self.filterNotNeed = filterNotNeed
        self.incHdr = incHdr

    def run(self):
        ParseCurrentFileThread.lock.acquire()
        try:
            project = ws.VLWIns.GetProjectByFileName(self.fileName)
            if project:
                searchPaths = ws.GetTagsSearchPaths()
                searchPaths += ws.GetProjectIncludePaths(project.GetName())
                extraMacros = ws.GetWorkspacePredefineMacros()
                # 这里必须使用这个函数，因为 sqlite3 的连接实例不能跨线程
                if self.incHdr:
                    ws.AsyncParseFiles([self.fileName] 
                                            + IncludeParser.GetIncludeFiles(
                                                    self.fileName, searchPaths),
                                       extraMacros, self.filterNotNeed)
                else: # 不包括 self.fileName 包含的头文件
                    ws.AsyncParseFiles([self.fileName],
                                       extraMacros, self.filterNotNeed)
        except:
            print 'ParseCurrentFileThread() failed'
        ParseCurrentFileThread.lock.release()
PYTHON_EOF
    endif

    " NOTE: 不是c或c++类型的文件，不继续，这个判断可能和VimLite的py模块不一致
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
            py ParseCurrentFileThread(vim.eval("sFile"), True, True).start()
        else
            py ParseCurrentFileThread(vim.eval("sFile"), True, False).start()
        endif
    else
        if bIncHdr
            py ParseCurrentFileThread(vim.eval("sFile"), False, True).start()
        else
            py ParseCurrentFileThread(vim.eval("sFile"), False, False).start()
        endif
    endif
endfunction
"}}}
function! s:GetCurBufIncList() "{{{2
    let origCursor = getpos('.')
    let results = []

    call setpos('.', [0, 1, 1, 0])
    let firstEnter = 1
    while 1
        if firstEnter
            let flags = 'Wc'
            let firstEnter = 0
        else
            let flags = 'W'
        endif
        let ret = search('\C^\s*#include\>', flags)
        if ret == 0
            break
        endif

        let inc = matchstr(getline('.'), 
                    \'\C^\s*#include\s*\zs\(<\|"\)\f\+\(>\|"\)')
        if inc !=# ''
            call add(results, inc)
        endif
    endwhile

    call setpos('.', origCursor)
    return results
endfunction
"}}}
function! s:CreateVLWorkspaceWin() "创建窗口 {{{2
    "create the workspace window
    let splitMethod = g:VLWorkspaceWinPos ==? "left" ? "topleft " : "botright "
    let splitSize = g:VLWorkspaceWinSize

    if !exists('t:VLWorkspaceBufName')
        let t:VLWorkspaceBufName = g:VLWorkspaceBufName
        silent! exec splitMethod . 'vertical ' . splitSize . ' new'
        silent! exec "edit" fnameescape(t:VLWorkspaceBufName)
    else
        silent! exec splitMethod . 'vertical ' . splitSize . ' split'
        silent! exec "buffer" fnameescape(t:VLWorkspaceBufName)
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
    exec 'nnoremap <silent> <buffer>' g:VLWShowMenuKey 
                \':call <SID>ShowMenu()<CR>'

    exec 'nnoremap <silent> <buffer>' g:VLWPopupMenuKey 
                \':call <SID>OnRightMouseClick()<CR>'

    nnoremap <silent> <buffer> <2-LeftMouse> :call <SID>OnMouseDoubleClick()<CR>
    nnoremap <silent> <buffer> <CR> :call <SID>OnMouseDoubleClick()<CR>

    exec 'nnoremap <silent> <buffer>' g:VLWOpenNodeKey 
                \':call <SID>OnMouseDoubleClick(g:VLWOpenNodeKey)<CR>'
    exec 'nnoremap <silent> <buffer>' g:VLWOpenNode2Key 
                \':call <SID>OnMouseDoubleClick(g:VLWOpenNode2Key)<CR>'

    exec 'nnoremap <silent> <buffer>' g:VLWOpenNodeInNewTabKey 
                \':call <SID>OnMouseDoubleClick(g:VLWOpenNodeInNewTabKey)<CR>'
    exec 'nnoremap <silent> <buffer>' g:VLWOpenNodeInNewTab2Key 
                \':call <SID>OnMouseDoubleClick(g:VLWOpenNodeInNewTab2Key)<CR>'

    exec 'nnoremap <silent> <buffer>' g:VLWOpenNodeSplitKey 
                \':call <SID>OnMouseDoubleClick(g:VLWOpenNodeSplitKey)<CR>'
    exec 'nnoremap <silent> <buffer>' g:VLWOpenNodeSplit2Key 
                \':call <SID>OnMouseDoubleClick(g:VLWOpenNodeSplit2Key)<CR>'

    exec 'nnoremap <silent> <buffer>' g:VLWOpenNodeVSplitKey 
                \':call <SID>OnMouseDoubleClick(g:VLWOpenNodeVSplitKey)<CR>'
    exec 'nnoremap <silent> <buffer>' g:VLWOpenNodeVSplit2Key 
                \':call <SID>OnMouseDoubleClick(g:VLWOpenNodeVSplit2Key)<CR>'

    exec 'nnoremap <silent> <buffer>' g:VLWGotoParentKey 
                \':call <SID>GotoParent()<CR>'
    exec 'nnoremap <silent> <buffer>' g:VLWGotoRootKey 
                \':call <SID>GotoRoot()<CR>'

    exec 'nnoremap <silent> <buffer>' g:VLWGotoNextSibling 
                \':call <SID>GotoNextSibling()<CR>'
    exec 'nnoremap <silent> <buffer>' g:VLWGotoPrevSibling 
                \':call <SID>GotoPrevSibling()<CR>'

    exec 'nnoremap <silent> <buffer>' g:VLWRefreshBufferKey 
                \':call <SID>RefreshBuffer()<CR>'

    exec 'nnoremap <silent> <buffer>' g:VLWToggleHelpInfo 
                \':call <SID>ToggleHelpInfo()<CR>'
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
    if !g:VLWorkspaceLinkToEidtor
        return
    endif

    let sFile = expand('%:p')
    call s:LocateFile(sFile)
endfunction
"}}}
function! s:Autocmd_Quit() "{{{2
    VLWDbgStop
    while 1
        py vim.command('let nCnt = %d' % Globals.GetBgThdCnt())
        if nCnt != 0
            redraw
            let sMsg = printf(
                        \"There %s %d running background thread%s, " 
                        \. "please wait...", 
                        \nCnt == 1 ? 'is' : 'are', nCnt, nCnt > 1 ? 's' : '')
            call s:echow(sMsg)
        else
            break
        endif
        sleep 500m
    endwhile
endfunction
"}}}
function! s:InstallCommands() "{{{2
    if s:bHadInited
        return
    endif
    " 初始化可用的命令

    if s:IsEnableCscope() " 禁用的话直接禁用掉命令
        "command! -nargs=? VLWInitCscopeDatabase 
                    "\               call <SID>InitVLWCscopeDatabase(<f-args>)
        command! -nargs=0 VLWInitCscopeDatabase 
                    \               call <SID>InitVLWCscopeDatabase(1)
        command! -nargs=0 VLWUpdateCscopeDatabase 
                    \               call <SID>UpdateVLWCscopeDatabase(1)
    endif

    if s:IsEnableGtags() " 禁用的话直接禁用掉命令
        command! -nargs=0 VLWInitGtagsDatabase
                    \               call <SID>InitVLWGtagsDatabase(0)
        command! -nargs=0 VLWUpdateGtagsDatabase
                    \               call <SID>UpdateVLWGtagsDatabase()
    endif

    command! -nargs=0 -bar VLWBuildActiveProject    
                \                           call <SID>BuildActiveProject()
    command! -nargs=0 -bar VLWCleanActiveProject    
                \                           call <SID>CleanActiveProject()
    command! -nargs=0 -bar VLWRunActiveProject      
                \                           call <SID>RunActiveProject()
    command! -nargs=0 -bar VLWBuildAndRunActiveProject 
                \                           call <SID>BuildAndRunActiveProject()

    command! -nargs=* -complete=file VLWParseFiles  
                \                               call <SID>ParseFiles(<f-args>)
    command! -nargs=0 -bar VLWParseCurrentFile
                \                               call <SID>ParseCurrentFile(0)
    command! -nargs=0 -bar VLWDeepParseCurrentFile
                \                               call <SID>ParseCurrentFile(1)

    command! -nargs=? -bar VLWDbgStart          call <SID>DbgStart(<f-args>)
    command! -nargs=0 -bar VLWDbgStop           call <SID>DbgStop()
    command! -nargs=0 -bar VLWDbgStepIn         call <SID>DbgStepIn()
    command! -nargs=0 -bar VLWDbgNext           call <SID>DbgNext()
    command! -nargs=0 -bar VLWDbgStepOut        call <SID>DbgStepOut()
    command! -nargs=0 -bar VLWDbgRunToCursor    call <SID>DbgRunToCursor()
    command! -nargs=0 -bar VLWDbgContinue       call <SID>DbgContinue()
    command! -nargs=? -bar VLWDbgToggleBp       
                \                       call <SID>DbgToggleBreakpoint(<f-args>)
    command! -nargs=0 -bar VLWDbgBacktrace      call <SID>DbgBacktrace()
    command! -nargs=0 -bar VLWDbgSetupKeyMap    call <SID>DbgSetupKeyMappings()

    command! -nargs=0 -bar VLWEnvVarSetttings   call <SID>EnvVarSettings()
    command! -nargs=0 -bar VLWTagsSetttings     call <SID>TagsSettings()
    command! -nargs=0 -bar VLWCompilersSettings call <SID>CompilersSettings()
    command! -nargs=0 -bar VLWBuildersSettings  call <SID>BuildersSettings()

    command! -nargs=0 -bar VLWSwapSourceHeader  call <SID>SwapSourceHeader()

    command! -nargs=0 -bar VLWLocateCurrentFile 
                \                           call <SID>LocateFile(expand('%:p'))

    command! -nargs=? -bar VLWFindFiles         call <SID>FindFiles(<q-args>)
    command! -nargs=? -bar VLWFindFilesIC       call <SID>FindFiles(<q-args>, 1)

    command! -nargs=? -bar VLWOpenIncludeFile   call <SID>OpenIncludeFile()

    " 异步解析当前文件，并且会强制解析，无论是否修改过
    command! -nargs=0 -bar VLWAsyncParseCurrentFile
                \                       call <SID>AsyncParseCurrentFile(0, 0)
    " 同 VLWAsyncParseCurrentFile，除了这个会包括头文件外
    command! -nargs=0 -bar VLWDeepAsyncParseCurrentFile
                \                       call <SID>AsyncParseCurrentFile(0, 1)
endfunction
"}}}
function! s:InstallMenuBarMenu() "{{{2
    anoremenu <silent> 200 &VimLite.Build\ Settings.Compilers\ Settings\.\.\. 
                \:call <SID>CompilersSettings()<CR>
    anoremenu <silent> 200 &VimLite.Build\ Settings.Builders\ Settings\.\.\. 
                \:call <SID>BuildersSettings()<CR>
    "anoremenu <silent> 200 &VimLite.Debugger\ Settings\.\.\. <Nop>

    anoremenu <silent> 200 &VimLite.Environment\ Variables\ Settings\.\.\. 
                \:call <SID>EnvVarSettings()<CR>

    "if !g:VLWorkspaceUseVIMCCC
        anoremenu <silent> 200 &VimLite.Tags\ And\ Clang\ Settings\.\.\. 
                    \:call <SID>TagsSettings()<CR>
    "endif
endfunction


function! s:InstallToolBarMenu() "{{{2
    "anoremenu 1.500 ToolBar.-Sep15- <Nop>

    let rtp_bak = &runtimepath
    let &runtimepath = vlutils#PosixPath(g:VimLiteDir) . ',' . &runtimepath

    anoremenu <silent> icon=build   1.510 
                \ToolBar.BuildActiveProject 
                \:call <SID>BuildActiveProject()<CR>
    anoremenu <silent> icon=clean   1.520 
                \ToolBar.CleanActiveProject 
                \:call <SID>CleanActiveProject()<CR>
    anoremenu <silent> icon=execute 1.530 
                \ToolBar.RunActiveProject 
                \:call <SID>RunActiveProject()<CR>

    "调试工具栏
    anoremenu 1.600 ToolBar.-Sep16- <Nop>
    anoremenu <silent> icon=breakpoint 1.605 
                \ToolBar.DbgToggleBreakpoint 
                \:call <SID>DbgToggleBreakpoint()<CR>

    anoremenu 1.609 ToolBar.-Sep17- <Nop>
    anoremenu <silent> icon=start 1.610 
                \ToolBar.DbgStart 
                \:call <SID>DbgStart()<CR>
    anoremenu <silent> icon=stepin 1.630 
                \ToolBar.DbgStepIn 
                \:call <SID>DbgStepIn()<CR>
    anoremenu <silent> icon=next 1.640 
                \ToolBar.DbgNext 
                \:call <SID>DbgNext()<CR>
    anoremenu <silent> icon=stepout 1.650 
                \ToolBar.DbgStepOut 
                \:call <SID>DbgStepOut()<CR>
    anoremenu <silent> icon=continue 1.660 
                \ToolBar.DbgContinue 
                \:call <SID>DbgContinue()<CR>
    anoremenu <silent> icon=runtocursor 1.665 
                \ToolBar.DbgRunToCursor 
                \:call <SID>DbgRunToCursor()<CR>
    anoremenu <silent> icon=stop 1.670 
                \ToolBar.DbgStop 
                \:call <SID>DbgStop()<CR>

    tmenu ToolBar.BuildActiveProject    Build Active Project
    tmenu ToolBar.CleanActiveProject    Clean Active Project
    tmenu ToolBar.RunActiveProject      Run Active Project

    tmenu ToolBar.DbgStart              Start / Run Debugger
    tmenu ToolBar.DbgStop               Stop Debugger
    tmenu ToolBar.DbgStepIn             Step In
    tmenu ToolBar.DbgNext               Next
    tmenu ToolBar.DbgStepOut            Step Out
    tmenu ToolBar.DbgRunToCursor        Run to cursor
    tmenu ToolBar.DbgContinue           Continue

    tmenu ToolBar.DbgToggleBreakpoint   Toggle Breakpoint

    call s:DbgRefreshToolBar()

    let &runtimepath = rtp_bak
endfunction


function! s:ParseCurrentFile(...) "可选参数为是否解析包含的头文件 {{{2
    let deep = 0
    if a:0 > 0
        let deep = a:1
    endif
    let curFile = expand("%:p")
    let files = [curFile]
    if deep
        py l_project = ws.VLWIns.GetProjectByFileName(vim.eval('curFile'))
        py l_searchPaths = ws.GetTagsSearchPaths()
        py if l_project: l_searchPaths += ws.GetProjectIncludePaths(
                    \l_project.GetName())
        py ws.ParseFiles(vim.eval('files') 
                    \+ IncludeParser.GetIncludeFiles(vim.eval('curFile'),
                    \   l_searchPaths))
        py del l_searchPaths
        py del l_project
    else
        py ws.ParseFiles(vim.eval('files'), False)
    endif
endfunction
"}}}
function! s:ParseFiles(files) "{{{2
    py ws.ParseFiles(vim.eval("a:files"))
endfunction
"}}}
function! s:AsyncParseFiles(files, ...) "{{{2
    py ws.AsyncParseFiles(vim.eval("a:files"))
endfunction
"}}}
"}}}1
"===============================================================================
"===============================================================================


"===============================================================================
" 基本操作
"===============================================================================
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


function! s:MenuOperation(menu) "菜单操作 {{{2
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


function! s:HlActiveProject() "{{{2
    py ws.HlActiveProject()
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
        call s:ToggleHelpInfo()
    endif

    py ws.RefreshBuffer()

    if bNeedDispHelp
        call s:ToggleHelpInfo()
    endif

    call setpos('.', lOrigCursor)

    " 跳回原来的窗口
    if nWspWinNr != nOrigWinNr
        exec 'noautocmd ' . nOrigWinNr . ' wincmd w'
    endif
endfunction


function! s:ToggleHelpInfo() "{{{2
    if !exists('b:bHelpInfoOn')
        let b:bHelpInfoOn = 0
    endif

    if !b:bHelpInfoOn
        let b:dOrigView = winsaveview()
    endif

    let lHelpInfo = []

    let sLine = '" ============================'
    call add(lHelpInfo, sLine)

    let sLine = '" File node mappings~'
    call add(lHelpInfo, sLine)

    let sLine = '" <2-LeftMouse>,'
    call add(lHelpInfo, sLine)
    let sLine = '" <CR>,'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWOpenNodeKey.': open file gracefully'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWOpenNode2Key.': preview'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWOpenNodeInNewTabKey.': open in new tab'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWOpenNodeInNewTab2Key.': open in new tab silently'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWOpenNodeSplitKey.': open split'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWOpenNodeSplit2Key.': preview split'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWOpenNodeVSplitKey.': open vsplit'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWOpenNodeVSplit2Key.': preview vsplit'
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
    let sLine = '" '.g:VLWOpenNodeKey.': open & close node'
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
    let sLine = '" '.g:VLWOpenNodeKey.': open & close node'
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
    let sLine = '" '.g:VLWOpenNodeKey.': show build config menu'
    call add(lHelpInfo, sLine)
    call add(lHelpInfo, '')

    let sLine = '" ----------------------------'
    call add(lHelpInfo, sLine)
    let sLine = '" Tree navigation mappings~'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWGotoRootKey.': go to root'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWGotoParentKey.': go to parent'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWGotoNextSibling.': go to next sibling'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWGotoPrevSibling.': go to prev sibling'
    call add(lHelpInfo, sLine)
    call add(lHelpInfo, '')

    let sLine = '" ----------------------------'
    call add(lHelpInfo, sLine)
    let sLine = '" Other mappings~'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWPopupMenuKey.': popup menu'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWShowMenuKey.': show text menu'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWRefreshBufferKey.': refresh buffer'
    call add(lHelpInfo, sLine)
    let sLine = '" '.g:VLWToggleHelpInfo.': toggle help info'
    call add(lHelpInfo, sLine)
    call add(lHelpInfo, '')


    setlocal ma
    if b:bHelpInfoOn
        let b:bHelpInfoOn = 0
        exec 'silent! 1,'.(1+len(lHelpInfo)-1) . ' delete _'
        py ws.VLWIns.SetWorkspaceLineNum(ws.VLWIns.GetRootLineNum() - 
                    \int(vim.eval('len(lHelpInfo)')))

        if exists('b:dOrigView')
            call winrestview(b:dOrigView)
            unlet b:dOrigView
        endif
    else
        let b:bHelpInfoOn = 1
        call append(0, lHelpInfo)
        py ws.VLWIns.SetWorkspaceLineNum(ws.VLWIns.GetRootLineNum() + 
                    \int(vim.eval('len(lHelpInfo)')))
        call cursor(1, 1)
    endif
    setlocal noma
endfunction


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
" =================== 调试操作 ===================
"{{{1
let s:dbgProjectName = ''
let s:dbgProjectDirName = ''
let s:dbgProjectConfName = ''
let s:dbgProjectFile = ''
let s:dbgSavedPos = []
let s:dbgSavedUpdatetime = &updatetime
let s:dbgFirstStart = 1
let s:dbgStandalone = 0 " 独立运行
function! s:Autocmd_DbgRestoreCursorPos() "{{{2
    normal! `Z
    call setpos("'Z", s:dbgSavedPos)
    au! AU_VLWDbgTemp CursorHold *
    augroup! AU_VLWDbgTemp
    let &updatetime = s:dbgSavedUpdatetime
endfunction
"}}}
" 调试器键位映射
function! s:DbgSetupKeyMappings() "{{{2
    exec 'xnoremap <silent>' g:VLWDbgWatchVarKey 
                \':<C-u>exec "Cdbgvar" vlutils#GetVisualSelection()<CR>'
    exec 'xnoremap <silent>' g:VLWDbgPrintVarKey 
                \':<C-u>exec "Cprint" vlutils#GetVisualSelection()<CR>'

    " vim 的命令支持特殊字符的话
    if g:VLWorkspaceHadVimCommandPatch
        command! -bar -nargs=* -complete=file Ccore-file
                    \   :C core-file <args>
        command! -bar -nargs=* -complete=file Cadd-symbol-file
                    \   :C add-system-file <args>
    else
        command! -bar -nargs=* -complete=file CCoreFile
                    \   :C core-file <args>
        command! -bar -nargs=* -complete=file CAddSymbolFile
                    \   :C add-symbol-file <args>
    endif
endfunction
"}}}
function! s:DbgHadStarted() "{{{2
    if has("netbeans_enabled")
        return 1
    else
        return 0
    endif
endfunction
"}}}
" 可选参数 a:1 弱存在且非零，则表示为独立运行
function! s:DbgStart(...) "{{{2
    let s:dbgStandalone = a:0 > 0 ? a:1 : 0
    " TODO: pyclewn 首次运行, pyclewn 运行中, pyclewn 一次调试完毕后
    if !s:DbgHadStarted() && !s:dbgStandalone
        " 检查
        py if not ws.VLWIns.GetActiveProjectName(): vim.command(
                    \'call s:echow("There is no active project!") | return')

        " Windows 平台暂时有些问题没有解决
        if vlutils#IsWindowsOS()
            echohl WarningMsg
            echo 'Notes!!!'
            echo 'The debugger on Windows does not work correctly currently.' 
                        \'So...'
            echo '1. If the "(clewn)_console" buffer does not have any output,' 
                        \' please run ":Cpwd" manually to flush the buffer.'
            echo '2. If there are some problems when using debugger toolbar' 
                        \'icon, use commands instead. For example, ":Cstep".'
            echo '3. Sorry about this.'
            echo 'Press any key to continue...'
            echohl None
            call getchar()
        endif

        if g:VLWDbgSaveBreakpointsInfo
            py proj = ws.VLWIns.FindProjectByName(
                        \ws.VLWIns.GetActiveProjectName())
            py if proj: vim.command("let s:dbgProjectFile = '%s'" % ToVimStr(
                        \os.path.join(
                        \   proj.dirName, ws.VLWIns.GetActiveProjectName() 
                        \       + '_' + vim.eval("g:VLWorkspaceDbgConfName"))))
            " 设置保存的断点
            py vim.command("let s:dbgProjectName = %s" % ToVimEval(proj.name))
            py vim.command("let s:dbgProjectDirName = %s" % 
                        \   ToVimEval(proj.dirName))
            py vim.command("let s:dbgProjectConfName = %s" % ToVimEval(
                        \           ws.GetProjectCurrentConfigName(proj.name)))
            py del proj
            " 用临时文件
            let s:dbgProjectFile = tempname()
            py Globals.Touch(vim.eval('s:dbgProjectFile'))
            call s:DbgLoadBreakpointsToFile(s:dbgProjectFile)
            " 需要用 g:VLWDbgProjectFile 这种方式，否则会有同步问题
            let g:VLWDbgProjectFile = s:dbgProjectFile
        endif

        let bNeedRestorePos = 1
        " 又要特殊处理了...
        if bufname('%') ==# '' && !&modified
            " 初始未修改的未命名缓冲区的话，就不需要恢复位置了
            let bNeedRestorePos = 0
        endif
        let s:dbgSavedPos = getpos("'Z")
        if bNeedRestorePos
            normal! mZ
        endif
        silent VPyclewn
        " BUG:? 运行 ws.DebugActiveProject() 前必须运行一条命令,
        " 否则出现灵异事件. 这条命令会最后才运行
        Cpwd

        "if g:VLWDbgSaveBreakpointsInfo && filereadable(s:dbgProjectFile)
            "py ws.DebugActiveProject(True)
        "else
            "py ws.DebugActiveProject(False)
        "endif

        py ws.DebugActiveProject(False)
        " 再 source
        if g:VLWDbgSaveBreakpointsInfo
            exec 'Csource' fnameescape(s:dbgProjectFile)
            if bNeedRestorePos
                " 这个办法是没办法的办法...
                set updatetime=1000
                augroup AU_VLWDbgTemp
                    au!
                    au! CursorHold * call <SID>Autocmd_DbgRestoreCursorPos()
                augroup END
            endif
        endif

        call s:DbgSetupKeyMappings()

        if s:dbgFirstStart
            call s:DbgPythonInterfacesInit()
            let s:dbgFirstStart = 0
        endif
        call s:DbgRefreshToolBar()
    elseif !s:DbgHadStarted() && s:dbgStandalone
        " 独立运行
        VPyclewn
        call s:DbgSetupKeyMappings()
    else
        let sLastDbgOutput = getbufline(bufnr('(clewn)_console'), '$')[0]
        if sLastDbgOutput !=# '(gdb) '
            " 正在运行, 中断之, 重新运行
            Csigint
        endif
        " 为避免修改了程序参数, 需要重新设置程序参数
        py ws.DebugActiveProject(False, False)
    endif
endfunction
"}}}
function! s:DbgToggleBreakpoint(...) "{{{2
    let bHardwareBp = a:0 > 0 ? a:1 : 0
    if !s:DbgHadStarted()
        call s:echow('Please start the debugger firstly.')
        return
    endif
    let nCurLine = line('.')
    let sCurFile = vlutils#PosixPath(expand('%:p'))
    if empty(sCurFile)
        return
    endif

    let nSigintFlag = 0
    let nIsDelBp = 0

    let sCursorSignName = ''
    for sLine in split(g:GetCmdOutput('sign list'), "\n")
        if sLine =~# '^sign '
            if matchstr(sLine, '\Ctext==>') !=# ''
                let sCursorSignName = matchstr(sLine, '\C^sign \zs\w\+\>')
                break
            elseif matchstr(sLine, '\Ctext=') ==# ''
                " 没有文本
                let sCursorSignName = matchstr(sLine, '\C^sign \zs\w\+\>')
                break
            endif
        endif
    endfor

    let sLastDbgOutput = getbufline(bufnr('(clewn)_console'), '$')[0]
    if sLastDbgOutput !=# '(gdb) '
        " 正在运行时添加断点, 必须先中断然后添加
        Csigint
        let nSigintFlag = 1
    endif

    for sLine in split(g:GetCmdOutput('sign place buffer=' . bufnr('%')), "\n")
        if sLine =~# '^\s\+line='
            let nSignLine = str2nr(matchstr(sLine, '\Cline=\zs\d\+'))
            let sSignName = matchstr(sLine, '\Cname=\zs\w\+\>')
            if nSignLine == nCurLine && sSignName !=# sCursorSignName
                " 获取断点的编号, 按编号删除
                "let nID = str2nr(matchstr(sLine, '\Cid=\zs\d\+'))
                " 获取断点的名字, 按名字删除
                let sName = matchstr(sLine, '\Cid=\zs\w\+')
                for sLine2 in split(g:GetCmdOutput('sign list'), "\n")
                    "if matchstr(sLine2, '\C^sign ' . nID) !=# ''
                    if matchstr(sLine2, '\C^sign ' . sName) !=# ''
                        let sBpID = matchstr(sLine2, '\Ctext=\zs\d\+')
                        exec 'Cdelete ' . sBpID
                        break
                    endif
                endfor

                "exec "Cclear " . sCurFile . ":" . nSignLine
                let nIsDelBp = 1
                break
            endif
        endif
    endfor

    if !nIsDelBp
        if bHardwareBp
            exec "Chbreak " . sCurFile . ":" . nCurLine
        else
            exec "Cbreak " . sCurFile . ":" . nCurLine
        endif
    endif

    if nSigintFlag
        Ccontinue
    endif
endfunction
"}}}
function! s:DbgStop() "{{{2
    if s:dbgStandalone
        Cstop
        nbclose
        return
    endif
python << PYTHON_EOF
def DbgSaveBreakpoints(data):
    ins = VLProjectSettings()
    ins.SetBreakpoints(data['s:dbgProjectConfName'],
                       DumpBreakpointsFromFile(data['s:dbgProjectFile'],
                                               data['s:dbgProjectDirName']))
    return ins.Save(data['sSettingsFile'])
def SaveDbgBpsFunc(data):
    dbgProjectFile = data['s:dbgProjectFile']
    if not dbgProjectFile:
        return
    baseTime = time.time()
    for i in xrange(10): # 顶多试十次
        modiTime = Globals.GetMTime(dbgProjectFile)
        if modiTime > baseTime:
            # 开工
            DbgSaveBreakpoints(data)
            try:
                # 删除文件
                os.remove(dbgProjectFile)
            except:
                pass
            break
        time.sleep(0.5)
PYTHON_EOF
    if s:DbgHadStarted()
        silent Cstop
        " 保存断点信息
        if g:VLWDbgSaveBreakpointsInfo
            exec 'Cproject' fnameescape(s:dbgProjectFile)
            " 要用异步的方式保存...
            "py Globals.RunSimpleThread(SaveDbgBpsFunc, 
                        "\              vim.eval('s:GenSaveDbgBpsFuncData()'))
            " 还是用同步的方式保存比较靠谱，懒得处理同步问题
            py SaveDbgBpsFunc(vim.eval('s:GenSaveDbgBpsFuncData()'))
        endif
        silent nbclose
        let g:VLWDbgProjectFile = ''
        call s:DbgRefreshToolBar()
    endif
endfunction
"}}}2
function! s:GenSaveDbgBpsFuncData() "{{{2
    let d = {}
    py vim.command("let sSettingsFile = %s" % ToVimEval(
                \   os.path.join(vim.eval('s:dbgProjectDirName'), 
                \      vim.eval('s:dbgProjectName') + '.projsettings')))
    let d['sSettingsFile'] = sSettingsFile
    let d['s:dbgProjectFile'] = s:dbgProjectFile
    let d['s:dbgProjectDirName'] = s:dbgProjectDirName
    let d['s:dbgProjectConfName'] = s:dbgProjectConfName
    return d
endfunction
"}}}2
function! s:DbgStepIn() "{{{2
    if !s:DbgHadStarted()
        echoerr 'Please start the debugger firstly.'
        return
    endif
    silent Cstep
endfunction

function! s:DbgNext() "{{{2
    if !s:DbgHadStarted()
        echoerr 'Please start the debugger firstly.'
        return
    endif
    silent Cnext
endfunction

function! s:DbgStepOut() "{{{2
    if !s:DbgHadStarted()
        echoerr 'Please start the debugger firstly.'
        return
    endif
    silent Cfinish
endfunction

function! s:DbgContinue() "{{{2
    if !s:DbgHadStarted()
        echoerr 'Please start the debugger firstly.'
        return
    endif
    silent Ccontinue
endfunction

function! s:DbgRunToCursor() "{{{2
    if !s:DbgHadStarted()
        echoerr 'Please start the debugger firstly.'
        return
    endif
    let nCurLine = line('.')
    let sCurFile = vlutils#PosixPath(expand('%:p'))

    let sLastDbgOutput = getbufline(bufnr('(clewn)_console'), '$')[0]
    if sLastDbgOutput !=# '(gdb) '
        " 正在运行时添加断点, 必须先中断然后添加
        Csigint
    endif

    exec "Cuntil " . sCurFile . ":" . nCurLine
endfunction
"}}}
function! s:DbgBacktrace() "{{{2
    " FIXME: 这个命令不会阻塞, 很可能得不到结果
    "silent! Cbt
    let nBufNr = bufnr('(clewn)_console')
    let nWinNr = bufwinnr(nBufNr)
    if nWinNr == -1
        return
    endif

    " 获取文本
    exec 'noautocmd ' . nWinNr . 'wincmd w'
    let lOrigCursor = getpos('.')
    call cursor(line('$'), 1)
    let sLine = getline('.')
    if sLine !~# '^(gdb)'
        call setpos('.', lOrigCursor)
        noautocmd wincmd p
        return
    endif

    let nEndLineNr = line('$')
    let nStartLineNr = search('^(gdb) bt$', 'bn')
    if nStartLineNr == 0
        call setpos('.', lOrigCursor)
        noautocmd wincmd p
        return
    endif

    call setpos('.', lOrigCursor)
    noautocmd wincmd p

    " 使用错误列表
    let bak_efm = &errorformat
    set errorformat=%m\ at\ %f:%l
    exec printf("%d,%d cgetbuffer %d", nStartLineNr + 1, nEndLineNr - 1, nBufNr)
    let &errorformat = bak_efm
endfunction
"}}}2
function! s:DbgSaveBreakpoints(sPyclewnProjFile) "{{{2
    let sPyclewnProjFile = a:sPyclewnProjFile
    if sPyclewnProjFile !=# ''
        py vim.command("let sSettingsFile = %s" % ToVimEval(
                    \   os.path.join(vim.eval('s:dbgProjectDirName'), 
                    \      vim.eval('s:dbgProjectName') + '.projsettings')))
        "echomsg sSettingsFile
        py l_ins = VLProjectSettings()
        py l_ins.SetBreakpoints(vim.eval('s:dbgProjectConfName'), 
                    \   DumpBreakpointsFromFile(
                    \                   vim.eval('sPyclewnProjFile'), 
                    \                   vim.eval('s:dbgProjectDirName')))
        py l_ins.Save(vim.eval('sSettingsFile'))
        py del l_ins
    endif
endfunction
"}}}2
function! s:DbgLoadBreakpointsToFile(sPyclewnProjFile) "{{{2
python << PYTHON_EOF
def DbgLoadBreakpointsToFile(pyclewnProjFile):
    settingsFile = os.path.join(vim.eval('s:dbgProjectDirName'),
                                vim.eval('s:dbgProjectName') + '.projsettings')
    #print settingsFile
    if not settingsFile:
        return False
    ds = Globals.DirSaver()
    os.chdir(vim.eval('s:dbgProjectDirName'))
    ins = VLProjectSettings()
    if not ins.Load(settingsFile):
        return False

    try:
        f = open(pyclewnProjFile, 'wb')
        for d in ins.GetBreakpoints(vim.eval('s:dbgProjectConfName')):
            f.write('break %s:%d\n' % (os.path.abspath(d['file']), int(d['line'])))
    except IOError:
        return False
    f.close()

    return True
PYTHON_EOF
    let sPyclewnProjFile = a:sPyclewnProjFile
    if sPyclewnProjFile ==# ''
        return
    endif
    py DbgLoadBreakpointsToFile(vim.eval('sPyclewnProjFile'))
endfunction
"}}}2
function! s:DbgEnableToolBar() "{{{2
    anoremenu enable ToolBar.DbgStop
    anoremenu enable ToolBar.DbgStepIn
    anoremenu enable ToolBar.DbgNext
    anoremenu enable ToolBar.DbgStepOut
    anoremenu enable ToolBar.DbgRunToCursor
    anoremenu enable ToolBar.DbgContinue
endfunction
"}}}
function! s:DbgDisableToolBar() "{{{2
    if !g:VLWDisableUnneededTools
        return
    endif
    anoremenu disable ToolBar.DbgStop
    anoremenu disable ToolBar.DbgStepIn
    anoremenu disable ToolBar.DbgNext
    anoremenu disable ToolBar.DbgStepOut
    anoremenu disable ToolBar.DbgRunToCursor
    anoremenu disable ToolBar.DbgContinue
endfunction
"}}}
function! s:DbgRefreshToolBar() "{{{2
    if s:DbgHadStarted()
        call s:DbgEnableToolBar()
    else
        call s:DbgDisableToolBar()
    endif
endfunction
"}}}
" 调试器用的 python 例程
function! s:DbgPythonInterfacesInit() "{{{2
python << PYTHON_EOF
def DumpBreakpointsFromFile(pyclewnProjFile, relStartPath = '.'):
    debug = False
    fn = pyclewnProjFile
    bps = [] # 项目为 {<文件相对路径>, <行号>}
    f = open(fn, 'rb')
    for line in f:
        if line.startswith('break '):
            if debug: print 'line:', line
            if debug: print line.lstrip('break ').rsplit(':', 1)
            li = line.lstrip('break ').rsplit(':', 1)
            if len(li) != 2:
                continue
            fileName = li[0]
            fileLine = li[1]
            fileName = os.path.relpath(fileName, relStartPath)
            fileLine = int(fileLine.strip())
            if debug: print fileName, fileLine
            bps.append({'file': fileName, 'line': fileLine})
    return bps

PYTHON_EOF
endfunction
"}}}2
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
                \'Create the workspace under a seperate directory')
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
    call s:HlActiveProject()
endfunction

function! s:CreateProjectCategoriesCbk(ctl, data) "{{{2
    let ctl = a:ctl
    let tblCtl = a:data
    let categories = ctl.GetValue()
    call tblCtl.DeleteAllLines()
    call tblCtl.SetSelection(1)
python << PYTHON_EOF
def CreateProjectCategoriesCbk():
    templates = GetTemplateDict(vim.eval('g:VLWorkspaceTemplatesPath'))
    key = vim.eval('categories')
    for line in templates[key]:
        vim.command("call tblCtl.AddLineByValues('%s')" % ToVimStr(line['name']))
CreateProjectCategoriesCbk()
PYTHON_EOF
    call ctl.owner.RefreshCtl(tblCtl)
    "刷新组合框
    for i in ctl.owner.controls
        if i.id == 4
            call s:TemplatesTableCbk(tblCtl, i)
            break
        endif
    endfor
endfunction

function! s:TemplatesTableCbk(ctl, data) "{{{2
    let ctl = a:ctl
    let comboCtl = a:data
    try
        let name = ctl.GetSelectedLine()[0]
    catch
        " TODO: 空表，没有获取到任何项目模版
        return
    endtry
    let categories = ''
    for i in ctl.owner.controls
        if i.id == 5
            let categories = i.GetValue()
            break
        endif
    endfor
python << PYTHON_EOF
def TemplatesTableCbk():
    templates = GetTemplateDict(vim.eval('g:VLWorkspaceTemplatesPath'))
    name = vim.eval('name')
    key = vim.eval('categories')
    for line in templates[key]:
        if line['name'] == name:
            vim.command("call comboCtl.SetValue('%s')" % ToVimStr(line['cmpType']))
            break
TemplatesTableCbk()
PYTHON_EOF
    call ctl.owner.RefreshCtl(comboCtl)
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
        let l:cmpType = 'gnu gcc'
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
        if l:projName !=# ''
            let sep = g:vlutils#os.sep
            if l:isSepPath != 0
                let l:file = l:projPath . sep . l:projName . sep 
                            \. l:projName . '.' . g:VLWorkspacePrjFileSuffix
            else
                let l:file = l:projPath . sep 
                            \. l:projName . '.' . g:VLWorkspacePrjFileSuffix
            endif
        endif

        "更新显示的文件名
        if a:1.type != g:VC_DIALOG
            if l:projName !=# ''
                let a:2.label = l:file
            else
                let a:2.label = ''
            endif
            call dialog.RefreshCtl(a:2)
        endif

        "开始创建项目
        if a:1.type == g:VC_DIALOG && l:projName !=# ''
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

    let ctl = g:VCSingleText.New('Project Name:')
    call ctl.SetId(0)
    call g:newProjDialog.AddControl(ctl)
    call g:newProjDialog.AddBlankLine()
    let tmpCtl = ctl

    let ctl = g:VCSingleText.New('Project Path:')
    call ctl.SetValue(getcwd())

    if g:VLWorkspaceHasStarted
        py vim.command("call ctl.SetValue('%s')" % ToVimStr(ws.VLWIns.dirName))
    endif

    call ctl.SetId(1)
    call g:newProjDialog.AddControl(ctl)
    call g:newProjDialog.AddBlankLine()
    let tmpCtl1 = ctl

    let ctl = g:VCCheckItem.New('Create the project under a seperate directory')
    call ctl.SetId(2)
    call g:newProjDialog.AddControl(ctl)
    call g:newProjDialog.AddBlankLine()
    let tmpCtl2 = ctl

    let ctl = g:VCStaticText.New('File Name:')
    call g:newProjDialog.AddControl(ctl)
    let ctl = g:VCStaticText.New('')
    let ctl.editable = 1
    call ctl.SetIndent(8)
    call ctl.SetHighlight('Special')
    call g:newProjDialog.AddControl(ctl)
    call g:newProjDialog.AddBlankLine()
    call tmpCtl.ConnectActionPostCallback(s:GetSFuncRef('s:CreateProject'), ctl)
    call tmpCtl1.ConnectActionPostCallback(s:GetSFuncRef('s:CreateProject'), ctl)
    call tmpCtl2.ConnectActionPostCallback(s:GetSFuncRef('s:CreateProject'), ctl)

    " 项目类型
    "let ctl = g:VCComboBox.New('Project Type:')
    "call ctl.SetId(3)
    "call ctl.AddItem('Static Library')
    "call ctl.AddItem('Dynamic Library')
    "call ctl.AddItem('Executable')
    "call ctl.SetValue('Executable')
    "call g:newProjDialog.AddControl(ctl)
    "call g:newProjDialog.AddBlankLine()

    " 编译器
    let ctl = g:VCComboBox.New('Compiler Type:')
    call ctl.SetId(4)
    call ctl.SetIndent(4)
    " TODO: 应该从配置文件读出
    call ctl.AddItem('cobra')
    call ctl.AddItem('gnu g++')
    call ctl.AddItem('gnu gcc')
    call ctl.SetValue('gnu gcc')
    call g:newProjDialog.AddControl(ctl)
    call g:newProjDialog.AddBlankLine()

    let cmpTypeCtl = ctl

    " 模版类别
    let ctl = g:VCComboBox.New('Templates Categories:')
    call ctl.SetId(5)
    call ctl.SetIndent(4)
    call g:newProjDialog.AddControl(ctl)

    let tblCtl = g:VCTable.New('', 1)
    call tblCtl.SetId(6)
    call tblCtl.SetIndent(4)
    call tblCtl.SetColTitle(1, 'Type')
    call tblCtl.SetDispHeader(0)
    call tblCtl.SetCellEditable(0)
    call tblCtl.SetDispButtons(0)
    call g:newProjDialog.AddControl(tblCtl)
    call ctl.ConnectActionPostCallback(
                \s:GetSFuncRef('s:CreateProjectCategoriesCbk'), tblCtl)
    call tblCtl.ConnectSelectionCallback(
                \s:GetSFuncRef('s:TemplatesTableCbk'), cmpTypeCtl)
python << PYTHON_EOF
def CreateTemplateCtls():
    templates = GetTemplateDict(vim.eval('g:VLWorkspaceTemplatesPath'))
    if not templates: return
    for key in templates.keys():
        vim.command("call ctl.AddItem('%s')" % ToVimStr(key))
    for line in templates[templates.keys()[0]]:
        vim.command("call tblCtl.AddLineByValues('%s')" % ToVimStr(line['name']))
    vim.command("call tblCtl.SetSelection(1)")
CreateTemplateCtls()
PYTHON_EOF

    call g:newProjDialog.DisableApply()
    call g:newProjDialog.AddFooterButtons()
    call g:newProjDialog.AddCallback(s:GetSFuncRef("s:CreateProject"))
    call g:newProjDialog.Display()

    "第一次也需要刷新组合框
    call s:TemplatesTableCbk(tblCtl, cmpTypeCtl)
python << PYTHON_EOF
PYTHON_EOF
endfunction

"}}}1
" =================== 其他组件 ===================
"{{{1
" ========== Cscope =========
function! s:InitVLWCscopeDatabase(...) "{{{2
    " 初始化 cscope 数据库。文件的更新采用粗略算法，
    " 只比较记录文件与 cscope.files 的时间戳而不是很详细的记录每次增删条目
    " 如果 cscope.files 比工作空间和包含的所有项目都要新，无须刷新 cscope.files

    " 如果传进来的第一个参数非零，强制全部初始化并刷新全部

    if !g:VLWorkspaceHasStarted || !s:IsEnableCscope()
        return
    endif

    py l_ds = Globals.DirSaver()
    py if os.path.isdir(ws.VLWIns.dirName): os.chdir(ws.VLWIns.dirName)

    let lFiles = []
    let sWspName = GetWspName()
    let sCsFilesFile = sWspName . g:VLWorkspaceCscpoeFilesFile
    let sCsOutFile = sWspName . g:VLWorkspaceCscpoeOutFile

    let l:force = 0
    if exists('a:1') && a:1 != 0
        let l:force = 1
    endif

python << PYTHON_EOF
def InitVLWCscopeDatabase():
    # 检查是否需要更新 cscope.files 文件
    csFilesMt = Globals.GetFileModificationTime(vim.eval('sCsFilesFile'))
    wspFileMt = ws.VLWIns.GetWorkspaceFileLastModifiedTime()
    needUpdateCsNameFile = False
    # FIXME: codelite 每次退出都会更新工作空间文件的时间戳
    if wspFileMt > csFilesMt:
        needUpdateCsNameFile = True
    else:
        for project in ws.VLWIns.projects.itervalues():
            if project.GetProjFileLastModifiedTime() > csFilesMt:
                needUpdateCsNameFile = True
                break
    if needUpdateCsNameFile or vim.eval('l:force') == '1':
        #vim.command('let lFiles = %s' 
            #% [i.encode('utf-8') for i in ws.VLWIns.GetAllFiles(True)])
        # 直接 GetAllFiles 可能会出现重复的情况，直接用 filesIndex 字典键值即可
        ws.VLWIns.GenerateFilesIndex() # 重建，以免任何特殊情况
        files = ws.VLWIns.filesIndex.keys()
        files.sort()
        vim.command('let lFiles = %s' % json.dumps(files, ensure_ascii=False))

    # TODO: 添加激活的项目的包含头文件路径选项
    # 这只关系到跳到定义处，如果实现了 ctags 数据库，就不需要
    # 比较麻烦，暂不实现
    incPaths = []
    if vim.eval('g:VLWorkspaceCscopeContainExternalHeader') != '0':
        incPaths = ws.GetWorkspaceIncludePaths()
    vim.command('let lIncludePaths = %s"' % ToVimEval(incPaths))

InitVLWCscopeDatabase()
PYTHON_EOF

    "echom string(lFiles)
    if !empty(lFiles)
        if vlutils#IsWindowsOS()
            " Windows 的 cscope 不能处理 \ 分割的路径，转为 posix 路径
            call map(lFiles, 'vlutils#PosixPath(v:val)')
        endif
        call writefile(lFiles, sCsFilesFile)
    endif

    let sIncludeOpts = ''
    if !empty(lIncludePaths)
        call map(lIncludePaths, 'shellescape(v:val)')
        let sIncludeOpts = '-I' . join(lIncludePaths, ' -I')
    endif

    " Windows 下必须先断开链接，否则无法更新
    exec 'silent! cs kill '. sCsOutFile

    let retval = 0
    if filereadable(sCsOutFile)
        " 已存在，但不更新，应该由用户调用 s:UpdateVLWCscopeDatabase 来更新
        " 除非为强制初始化全部
        if l:force
            if g:VLWorkspaceCreateCscopeInvertedIndex
                let sFirstOpts = '-bqkU'
            else
                let sFirstOpts = '-bkU'
            endif
            let sCmd = printf('%s %s %s -i %s -f %s', 
                        \shellescape(g:VLWorkspaceCscopeProgram), 
                        \sFirstOpts, sIncludeOpts, 
                        \shellescape(sCsFilesFile), shellescape(sCsOutFile))
            "call system(sCmd)
            py vim.command('let retval = %d' % System(vim.eval('sCmd'))[0])
        endif
    else
        if g:VLWorkspaceCreateCscopeInvertedIndex
            let sFirstOpts = '-bqk'
        else
            let sFirstOpts = '-bk'
        endif
        let sCmd = printf('%s %s %s -i %s -f %s', 
                    \shellescape(g:VLWorkspaceCscopeProgram), 
                    \sFirstOpts, sIncludeOpts, 
                    \shellescape(sCsFilesFile), shellescape(sCsOutFile))
        "call system(sCmd)
        py vim.command('let retval = %d' % System(vim.eval('sCmd'))[0])
    endif

    if retval
        echom printf("cscope occur error: %d", retval)
        echom sCmd
        py del l_ds
        return
    endif

    set cscopetagorder=0
    set cscopetag
    "set nocsverb
    exec 'silent! cs kill '. sCsOutFile
    exec 'cs add '. sCsOutFile
    "set csverb

    py del l_ds
endfunction


function! s:UpdateVLWCscopeDatabase(...) "{{{2
    " 默认仅仅更新 .out 文件，如果有参数传进来且为 1，也更新 .files 文件
    " 仅在已经存在能用的 .files 文件时才会更新

    if !g:VLWorkspaceHasStarted || !s:IsEnableCscope()
        return
    endif

    py l_ds = Globals.DirSaver()
    py if os.path.isdir(ws.VLWIns.dirName): os.chdir(ws.VLWIns.dirName)

    let sWspName = GetWspName()
    let sCsFilesFile = sWspName . g:VLWorkspaceCscpoeFilesFile
    let sCsOutFile = sWspName . g:VLWorkspaceCscpoeOutFile

    if !filereadable(sCsFilesFile)
        " 没有必要文件，自动忽略
        py del l_ds
        return
    endif

    if exists('a:1') && a:1 != 0
        " 如果传入参数且非零，强制刷新文件列表
        py vim.command('let lFiles = %s' % json.dumps(
                    \ws.VLWIns.GetAllFiles(True), ensure_ascii=False))
        if vlutils#IsWindowsOS()
            " Windows 的 cscope 不能处理 \ 分割的路径
            call map(lFiles, 'vlutils#PosixPath(v:val)')
        endif
        call writefile(lFiles, sCsFilesFile)
    endif

    let lIncludePaths = []
    if g:VLWorkspaceCscopeContainExternalHeader
        py vim.command("let lIncludePaths = %s" % json.dumps(
                    \ws.GetWorkspaceIncludePaths(), ensure_ascii=False))
    endif
    let sIncludeOpts = ''
    if !empty(lIncludePaths)
        call map(lIncludePaths, 'shellescape(v:val)')
        let sIncludeOpts = '-I' . join(lIncludePaths, ' -I')
    endif

    let sFirstOpts = '-bkU'
    if g:VLWorkspaceCreateCscopeInvertedIndex
        let sFirstOpts .= 'q'
    endif
    let sCmd = printf('%s %s %s -i %s -f %s', 
                \shellescape(g:VLWorkspaceCscopeProgram), sFirstOpts, 
                \sIncludeOpts, 
                \shellescape(sCsFilesFile), shellescape(sCsOutFile))

    " Windows 下必须先断开链接，否则无法更新
    exec 'silent! cs kill '. sCsOutFile

    "call system(sCmd)
    py vim.command('let retval = %d' % System(vim.eval('sCmd'))[0])

    if retval
        echom printf("cscope occur error: %d", retval)
        echom sCmd
        "py del l_ds
        "return
    endif

    exec 'cs add '. sCsOutFile

    py del l_ds
endfunction
"}}}
" 可选参数为 cscope.out 文件
function! s:ConnectCscopeDatabase(...) "{{{2
    " 默认的文件名...
    py l_ds = Globals.DirSaver()
    py if os.path.isdir(ws.VLWIns.dirName): os.chdir(ws.VLWIns.dirName)
    let sWspName = GetWspName()
    let sCsOutFile = sWspName . g:VLWorkspaceCscpoeOutFile

    let sCsOutFile = a:0 > 0 ? a:1 : sCsOutFile
    if filereadable(sCsOutFile)
        let &cscopeprg = g:VLWorkspaceCscopeProgram
        set cscopetagorder=0
        set cscopetag
        exec 'silent! cs kill '. sCsOutFile
        exec 'cs add '. sCsOutFile
    endif
    py del l_ds
endfunction
"}}}
" ========== GNU Global Tags =========
function! s:InitVLWGtagsDatabase(bIncremental) "{{{2
    " 求简单，调用这个函数就表示强制新建数据库
    py l_ds = Globals.DirSaver()
    py if os.path.isdir(ws.VLWIns.dirName): os.chdir(ws.VLWIns.dirName)

    let lFiles = []
    py ws.VLWIns.GenerateFilesIndex() # 重建，以免任何特殊情况
    py l_files = ws.VLWIns.filesIndex.keys()
    py l_files.sort()
    py vim.command('let lFiles = %s' % json.dumps(l_files, ensure_ascii=False))
    py del l_files

    let sWspName = GetWspName()
    let sGlbFilesFile = sWspName . g:VLWorkspaceGtagsFilesFile
    let sGlbOutFile = 'GTAGS'
    let sGtagsProgram = g:VLWorkspaceGtagsProgram

    if !empty(lFiles)
        if vlutils#IsWindowsOS()
            " Windows 的 cscope 不能处理 \ 分割的路径
            call map(lFiles, 'vlutils#PosixPath(v:val)')
        endif
        call writefile(lFiles, sGlbFilesFile)
    endif

    exec 'silent! cs kill '. sGlbOutFile
    let sCmd = printf('%s -f %s', 
                \     shellescape(sGtagsProgram), shellescape(sGlbFilesFile))
    if a:bIncremental && filereadable(sGlbOutFile)
        " 增量更新
        let sCmd .= ' -i'
    endif
    "call system(sCmd)
    py vim.command('let retval = %d' % System(vim.eval('sCmd'))[0])
    if retval
        echom printf("gtags occur error: %d", retval)
        echom sCmd
        "py del l_ds
        "return
    endif

    call s:ConnectGtagsDatabase(sGlbOutFile)

    py del l_ds
endfunction
"}}}
function! s:UpdateVLWGtagsDatabase() "{{{2
    " 仅在已经初始化过了才可以更新
    if exists('s:bHadConnGtagsDb') && s:bHadConnGtagsDb
        call s:InitVLWGtagsDatabase(1)
    endif
endfunction
"}}}
" 可选参数为 GTAGS 文件
function! s:ConnectGtagsDatabase(...) "{{{2
    let sGlbOutFile = a:0 > 0 ? a:1 : 'GTAGS'
    if filereadable(sGlbOutFile)
        let sDir = fnamemodify(sGlbOutFile, ':h')
        if sDir ==# '.' || empty(sDir)
            let sDir = getcwd()
        endif
        let &cscopeprg = g:VLWorkspaceGtagsCscopeProgram
        set cscopetagorder=0
        set cscopetag
        exec 'silent! cs kill' fnameescape(sGlbOutFile)
        exec 'cs add' fnameescape(sGlbOutFile) fnameescape(sDir)
        let s:bHadConnGtagsDb = 1
    endif
endfunction
"}}}
" 假定 sFile 是绝对路径的文件名
function! s:Autocmd_UpdateGtagsDatabase(sFile) "{{{2
    py if not ws.VLWIns.IsWorkspaceFile(vim.eval("a:sFile")):
                \vim.command('return')

    if exists('s:bHadConnGtagsDb') && s:bHadConnGtagsDb
        let sGlbFilesFile = GetWspName() . g:VLWorkspaceGtagsFilesFile
        py vim.command("let sWspDir = %s" % ToVimEval(ws.VLWIns.dirName))
        let sGlbFilesFile = g:vlutils#os.path.join(sWspDir, sGlbFilesFile)
        let sCmd = printf("cd %s && %s -f %s --single-update %s &", 
                    \     shellescape(sWspDir),
                    \     shellescape(g:VLWorkspaceGtagsProgram),
                    \     shellescape(sGlbFilesFile),
                    \     shellescape(a:sFile))
        "echo sCmd
        "exec sCmd
        call system(sCmd)
        "echom 'enter s:Autocmd_UpdateGtagsDatabase()'
    endif
endfunction
"}}}
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
    py l_searchPaths = ws.GetCommonIncludePaths()
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
" ==============================================================================
" ==============================================================================


" ==============================================================================
" 使用控件系统的交互操作
" ==============================================================================
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
    py ins.ExpandSelf()
    py del ins
    py ws.VLWIns.TouchAllProjectFiles()
endfunction
"}}}
function! s:GetEnvVarSettingsHelpText() "{{{2
python << PYTHON_EOF
def GetEnvVarSettingsHelpText():
    s = '''\
==============================================================================
##### Environment Variables #####
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
    py vim.command("let lEnvVarSets = %s" % ins.envVarSets.keys())
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
        vim.command("let dData['%s'] = []" % ToVimStr(setName))
        for envVar in envVars:
            vim.command("call add(dData['%s'], '%s')" 
                        \% (ToVimStr(setName), ToVimStr(envVar.GetString())))
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
" =================== tags 设置 ===================
"{{{1
"标识用控件 ID {{{2
let s:ID_TagsSettingsIncludePaths = 10
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
"           let table = ctl.table
"           py del ins.includePaths[:]
"           for line in table
"               py ins.includePaths.append(vim.eval("line[0]"))
"           endfor
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
    py ws.InitOmnicppTypesVar()
endfunction

function! s:CreateTagsSettingsDialog() "{{{2
    let dlg = g:VimDialog.New('== Tags And Clang Settings ==')
    py ins = TagsSettingsST.Get()

"===============================================================================
    "1.Include Files
    "let ctl = g:VCStaticText.New("Tags Settings")
    "call ctl.SetHighlight("Special")
    "call dlg.AddControl(ctl)
    "call dlg.AddBlankLine()

    " 老的使用表格的设置，不需要了，先留着
"   let ctl = g:VCTable.New(
"               \'Add search paths for the vlctags and libclang parser', 1)
"   call ctl.SetId(s:ID_TagsSettingsIncludePaths)
"   call ctl.SetIndent(4)
"   call ctl.SetDispHeader(0)
"   py vim.command("let includePaths = %s" % ToVimEval(ins.includePaths))
"   for includePath in includePaths
"       if vlutils#IsWindowsOS()
"           call ctl.AddLineByValues(s:StripMultiPathSep(includePath))
"       else
"           call ctl.AddLineByValues(includePath)
"       endif
"   endfor
"   call ctl.ConnectBtnCallback(0, s:GetSFuncRef('s:AddSearchPathCbk'), '')
"   call ctl.ConnectBtnCallback(2, s:GetSFuncRef('s:EditSearchPathCbk'), '')
"   call dlg.AddControl(ctl)
"   call dlg.AddBlankLine()

    " 头文件搜索路径
    let ctl = g:VCMultiText.New(
                \"Add search paths for the vlctags and libclang parser:")
    call ctl.SetId(s:ID_TagsSettingsIncludePaths)
    call ctl.SetIndent(4)
    py vim.command("let includePaths = %s" % ToVimEval(ins.includePaths))
    call ctl.SetValue(includePaths)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditTextBtnCbk"), "")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    call dlg.AddBlankLine()
    call dlg.AddSeparator(4)
    let ctl = g:VCStaticText.New('The followings are only for vlctags parser')
    call ctl.SetIndent(4)
    call ctl.SetHighlight('WarningMsg')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCMultiText.New("Macros:")
    call ctl.SetId(s:ID_TagsSettingsTagsTokens)
    call ctl.SetIndent(4)
    py vim.command("let tagsTokens = %s" % ToVimEval(ins.tagsTokens))
    call ctl.SetValue(tagsTokens)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditTextBtnCbk"), "cpp")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCMultiText.New("Types:")
    call ctl.SetId(s:ID_TagsSettingsTagsTypes)
    call ctl.SetIndent(4)
    py vim.command("let tagsTypes = %s" % ToVimEval(ins.tagsTypes))
    call ctl.SetValue(tagsTypes)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditTextBtnCbk"), "")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    call dlg.ConnectSaveCallback(s:GetSFuncRef("s:SaveTagsSettingsCbk"), "")

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

" ==============================================================================
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

    ds = Globals.DirSaver()
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

    py ds = Globals.DirSaver()
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
    py vim.command("let lNames = %s" % ws.VLWSettings.GetBatchBuildNames())
    for sName in lNames
        call ctl.AddItem(sName)
    endfor
    call ctl.ConnectActionPostCallback(
                \s:GetSFuncRef('s:BBS_ChangeBatchBuildNameCbk'), '')
    call dlg.AddControl(ctl)

    " 顺序列表控件
    py vim.command('let lProjectNames = %s' % ws.VLWIns.GetProjectList())
    py vim.command('let lBatchBuild = %s' 
                \% ws.VLWSettings.GetBatchBuildList('Default'))

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
    projectNameList.sort(Globals.Cmp)
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
                        \% ToVimEval(ws.VLWSettings.GetEnvVarSetName()))
            let sNewName = ctl.GetValue()
            py ws.VLWSettings.SetEnvVarSetName(vim.eval("sNewName"))
            if sOldName !=# sNewName
                " 下面固定调用这个了
                "py ws.VLWIns.TouchAllProjectFiles()
            endif
        elseif ctl.GetId() == s:ID_WspSettingsIncludePaths
"           let table = ctl.table
"           py del ws.VLWSettings.includePaths[:]
"           for line in table
"               py ws.VLWSettings.includePaths.append(vim.eval("line[0]"))
"           endfor
            py ws.VLWSettings.includePaths = vim.eval("ctl.values")
        elseif ctl.GetId() == s:ID_WspSettingsPrependNSInfo
            py ws.VLWSettings.SetUsingNamespace(vim.eval("ctl.values"))
        elseif ctl.GetId() == s:ID_WspSettingsMacroFiles
            py ws.VLWSettings.SetMacroFiles(vim.eval("ctl.values"))
        elseif ctl.GetId() == s:ID_WspSettingsTagsTokens
            py ws.VLWSettings.tagsTokens = vim.eval("ctl.values")
        elseif ctl.GetId() == s:ID_WspSettingsTagsTypes
            py ws.VLWSettings.tagsTypes = vim.eval("ctl.values")
        elseif ctl.GetId() == s:ID_WspSettingsIncPathFlag
            py ws.VLWSettings.SetIncPathFlag(vim.eval("ctl.GetValue()"))
        elseif ctl.GetId() == s:ID_WspSettingsEditorOptions
            py ws.VLWSettings.SetEditorOptions(vim.eval("ctl.GetValue()"))
        elseif ctl.GetId() == s:ID_WspSettingsCSourceExtensions
            py ws.VLWSettings.cSrcExts = 
                        \SplitSmclStr(vim.eval("ctl.GetValue()"))
        elseif ctl.GetId() == s:ID_WspSettingsCppSourceExtensions
            py ws.VLWSettings.cppSrcExts = 
                        \SplitSmclStr(vim.eval("ctl.GetValue()"))
        elseif ctl.GetId() == s:ID_WspSettingsEnableLocalConfig
            py ws.VLWSettings.enableLocalConfig = int(vim.eval("ctl.GetValue()"))
        elseif ctl.GetId() == s:ID_WspSettingsLocalConfig
            let sTempFile = tempname()
            " ctl.values 是列表
            call writefile(ctl.values, sTempFile)
            exec 'source' fnameescape(sTempFile)
            call delete(sTempFile)
            py VLWSaveCurrentConfig(ws.VLWSettings.localConfig)
        endif
    endfor
    " 保存
    py ws.SaveWspSettings()
    " Extension Options 关系到项目 Makefile
    py ws.VLWIns.TouchAllProjectFiles()
    " 对于工作区设置，先还原，再设置
    py VLWRestoreConfigToGlobal()
    " NOTE: 基本上不支持正在运行的时候设置变量，需要重启，现在还没实现...
    py if ws.VLWSettings.enableLocalConfig:
            \ VLWSetCurrentConfig(ws.VLWSettings.localConfig, force=True)
endfunction

function! s:AddSearchPathCbk(ctl, data) "{{{2
    echohl Question
    let input = input("Add Parser Search Path:\n")
    echohl None
    if input !=# ''
        call a:ctl.AddLineByValues(input)
    endif
endfunction

function! s:EditSearchPathCbk(ctl, data) "{{{2
    let value = a:ctl.GetSelectedLine()[0]
    echohl Question
    let input = input("Edit Search Path:\n", value)
    echohl None
    if input !=# '' && input !=# value
        call a:ctl.SetCellValue(a:ctl.selection, 1, input)
    endif
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
current support configuration variables:
'''
    global VLWConfigTemplate
    for name, conf in VLWConfigTemplate.iteritems():
        for k, v in conf.iteritems():
            s += '  %s' % k
            if k in __VLWNeedRestartConfig:
                s += '*'
            s += '\n'

    s += '''
Variables which with trailing '*' need to restart VimLite to take effect.
'''

    return s
PYTHON_EOF
    py vim.command("return %s" % ToVimEval(GetWspSettingsHelpText()))
endfunction
"}}}
function! s:CreateWspSettingsDialog() "{{{2
    let dlg = g:VimDialog.New('== Workspace Settings ==')
    call dlg.SetExtraHelpContent(s:GetWspSettingsHelpText())

"===============================================================================
    " 1.Environment
    let ctl = g:VCStaticText.New("Environment")
    call ctl.SetHighlight("Special")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCComboBox.New('Environment Sets:')
    call ctl.SetId(s:ID_WspSettingsEnvironment)
    call ctl.SetIndent(4)
    py vim.command("let lEnvVarSets = %s" 
                \% EnvVarSettingsST.Get().envVarSets.keys())
    call sort(lEnvVarSets)
    for sEnvVarSet in lEnvVarSets
        call ctl.AddItem(sEnvVarSet)
    endfor
    py vim.command("call ctl.SetValue('%s')" % 
                \ToVimStr(ws.VLWSettings.GetEnvVarSetName()))
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

"===============================================================================
    " 2. Editor Options
    let ctl = g:VCStaticText.New("Editor")
    call ctl.SetHighlight("Special")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCMultiText.New("Editor Options (Run as vim script, "
                \."single line will be faster):")
    call ctl.SetId(s:ID_WspSettingsEditorOptions)
    call ctl.SetIndent(4)
    py vim.command("let editorOptions = %s" 
                \% ToVimEval(ws.VLWSettings.GetEditorOptions()))
    call ctl.SetValue(editorOptions)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditTextBtnCbk"), "vim")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

"===============================================================================
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
            \       % ToVimEval(ws.VLWSettings.GetLocalConfigScript()))
    call ctl.SetValue(localConfig)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditTextBtnCbk"), "vim")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

"===============================================================================
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

"===============================================================================
    " TODO: 如果不需要，隐藏这个设置
    " 4.Include Files
    let ctl = g:VCStaticText.New("Tags And Clang Settings")
    call ctl.SetHighlight("Special")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

"===
    " 头文件搜索路径
    let ctl = g:VCMultiText.New(
                \"Add search paths for the vlctags and libclang parser:")
    call ctl.SetId(s:ID_WspSettingsIncludePaths)
    call ctl.SetIndent(4)
    py vim.command("let includePaths = %s" % ws.VLWSettings.includePaths)
    call ctl.SetValue(includePaths)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditTextBtnCbk"), "")
    call dlg.AddControl(ctl)
    "call dlg.AddBlankLine()

    let ctl = g:VCComboBox.New(
                \"Use with Global Settings (Only For Search Paths):")
    call ctl.SetId(s:ID_WspSettingsIncPathFlag)
    call ctl.SetIndent(4)
    py vim.command("let lItems = %s" % ws.VLWSettings.GetIncPathFlagWords())
    for sI in lItems
        call ctl.AddItem(sI)
    endfor
    py vim.command("call ctl.SetValue('%s')" % 
                \ToVimStr(ws.VLWSettings.GetCurIncPathFlagWord()))
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()
"===

    call dlg.AddBlankLine()
    call dlg.AddSeparator(4) " 分割线
    let ctl = g:VCStaticText.New('The followings are only for vlctags parser')
    call ctl.SetIndent(4)
    call ctl.SetHighlight('WarningMsg')
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCMultiText.New("Prepend Search Scopes (For OmniCpp):")
    call ctl.SetId(s:ID_WspSettingsPrependNSInfo)
    call ctl.SetIndent(4)
    py vim.command("let prependNSInfo = %s" % ws.VLWSettings.GetUsingNamespace())
    call ctl.SetValue(prependNSInfo)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditTextBtnCbk"), "")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCMultiText.New("Macro Files:")
    call ctl.SetId(s:ID_WspSettingsMacroFiles)
    call ctl.SetIndent(4)
    py vim.command("let macroFiles = %s" % ws.VLWSettings.GetMacroFiles())
    call ctl.SetValue(macroFiles)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditTextBtnCbk"), "")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCMultiText.New("Macros:")
    call ctl.SetId(s:ID_WspSettingsTagsTokens)
    call ctl.SetIndent(4)
    py vim.command("let tagsTokens = %s" % ws.VLWSettings.tagsTokens)
    call ctl.SetValue(tagsTokens)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditTextBtnCbk"), "cpp")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    let ctl = g:VCMultiText.New("Types:")
    call ctl.SetId(s:ID_WspSettingsTagsTypes)
    call ctl.SetIndent(4)
    py vim.command("let tagsTypes = %s" % ws.VLWSettings.tagsTypes)
    call ctl.SetValue(tagsTypes)
    call ctl.ConnectButtonCallback(s:GetSFuncRef("s:EditTextBtnCbk"), "")
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()

    call dlg.ConnectSaveCallback(
                \s:GetSFuncRef("s:SaveWspSettingsCbk"), "")

    call dlg.AddFooterButtons()
    return dlg
endfunction
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
##### Available Macros #####
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

VimLite will expand `expression` firstly and then expand above $() macros.

##### Project Settings #####
Compiler and linker options are string seperated by ';' and join with ' '.
eg: "-g;-Wall" -> "-g -Wall".

If you need a literal ';', just input ";;".
eg: "-DSmcl=\;;;-Wall" -> "-DSmcl=\; -Wall".

"Include Paths", "Predefine Macros", "Library Paths" and "Libraries" options
will be seperated by ';' and modify by corresponding compiler pattern and
join with ' '.
eg: ".;test/include" -> "-I. -Itest/include", and be passed to gcc.
eg: "stdc++;m" -> "-lstdc++ -lm", and be passed to gcc.

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
    if input !=# ''
        for lLine in ctl.table
            if lLine[0] ==# input
                echohl ErrorMsg
                echo "Target '" . input . "' already exists!"
                echohl None
                return
            endif
        endfor
        call ctl.AddLineByValues(input, '')
    endif
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
                call dlg.SetActivatedByGId(
                            \s:GID_PSCtl_SepDbgArgs, confDict['useSepDbgArgs'])
            endif
        elseif ctlId == s:ID_PSCtl_DebugArgs
            if bIsSave
                let confDict['dbgArgs'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['dbgArgs'])
            endif
        elseif ctlId == s:ID_PSCtl_IgnoreFiles
            if bIsSave
                " 这个是不允许修改的，所以不用保存了
                "let confDict['ignFiles'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['ignFiles'])
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

" ==============================================================================
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

    let ctl = g:VCCheckItem.New("Use seperate debug arguments")
    call ctl.SetId(s:ID_PSCtl_UseSepDbgArgs)
    call ctl.SetIndent(8)
    call ctl.ConnectActionPostCallback(s:GetSFuncRef('s:ActiveIfCheckCbk'), 
                \s:GID_PSCtl_SepDbgArgs)
    call dlg.AddControl(ctl)

    let ctl = g:VCSingleText.New("Debug Arguments:")
    call ctl.SetId(s:ID_PSCtl_DebugArgs)
    call ctl.SetGId(s:GID_PSCtl_SepDbgArgs)
    call ctl.SetIndent(8)
    call dlg.AddControl(ctl)
    call dlg.AddBlankLine()
    let sep = g:VCSeparator.New('-')
    call sep.SetIndent(8)
    call dlg.AddControl(sep)

    let ctl = g:VCMultiText.New("Ignored Files "
                \. "(Please add/remove them by Workspace popup menus):")
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

" ==============================================================================
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

" ==============================================================================
" 3. Customize
    " --------------------------------------------------------------------------
    " Customize
    " --------------------------------------------------------------------------
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

" ==============================================================================
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

" ==============================================================================
    call dlg.AddFooterButtons()
    call dlg.ConnectSaveCallback(s:GetSFuncRef("s:ProjectSettings_SaveCbk"), '')

    return dlg
endfunction
"}}}2
"}}}1
"===============================================================================
"===============================================================================

function g:VLWVersion() "{{{2
    if s:bHadInited
        py vim.command("return %d" % Globals.VIMLITE_VER)
    else
        return 0
    endif
endfunction
"}}}
function! s:InitPythonInterfaces() "{{{2
    " 防止重复初始化
    if s:bHadInited
        return
    endif

    let pyf = g:vlutils#os.path.join(fnamemodify(s:sfile, ':h'), 'wsp.py')
    exec 'pyfile' fnameescape(pyf)
endfunction
"}}}2
function! s:LoadPlugin()
    let sPluginPath = expand('~/.vim/autoload/videm/plugin')
    let lPlugin = split(globpath(sPluginPath, "*.vim"), '\n')
    for sFile in lPlugin
        let sName = fnamemodify(sFile, ':t:r')
        exec printf('call videm#plugin#%s#Init()', sName)
    endfor
endfunction

" vim:fdm=marker:fen:et:sts=4:fdl=1:
