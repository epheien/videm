" Vim clang code completion plugin
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2011-12-16
" Change:   2013-05-21

let s:sfile = expand('<sfile>:p')
if !has('python')
    echohl ErrorMsg
    echom printf("[%s]: Required Vim compiled with +python", s:sfile)
    echohl None
    finish
endif

if exists('s:loaded')
    finish
endif
let s:loaded = 1

" 基础特性检查
let s:has_InsertCharPre = exists('##InsertCharPre')

" 标识是否第一次初始化
let s:bFirstInit = 1

" 启用状态
let s:enable = 0

" 调试用
let s:nAsyncCompleteCount = 0

let s:dCalltipsData = {}
let s:dCalltipsData.usePrevTags = 0 " 是否使用最近一次的 tags 缓存

" 关联的文件，一般用于头文件关联源文件
" 在头文件头部和尾部添加的额外的内容，用于修正在头文件时的头文件包含等等问题
" {头文件: {'line': 在关联文件中对应的行(#include), 'filename': 关联文件}, ...}
let g:dRelatedFile = {}

let s:sPluginPath = substitute(expand('<sfile>:p:h'), '\\', '/', 'g')

let s:os = vlutils#os

let s:videm_base_dir = s:os.path.dirname(s:os.path.dirname(s:os.path.dirname(s:sfile)))
let s:sDefaultPyModPath = s:os.path.join(s:videm_base_dir, '_videm', 'core')
unlet s:videm_base_dir

function! vimccc#core#Init() "{{{2
    return 0
endfunction
"}}}

function! s:InitVariable(varName, defaultVal) "{{{2
    if !exists(a:varName)
        let {a:varName} = a:defaultVal
        return 1
    else
        return 0
    endif
endfunction
"}}}

" 临时启用选项函数
function! s:SID() " 获取脚本 ID，这个函数名不能变 {{{2
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
let s:sid = s:SID()
function! s:GetSFuncRef(sFuncName) "获取局部于脚本的函数的引用 {{{2
    let sFuncName = a:sFuncName =~ '^s:' ? a:sFuncName[2:] : a:sFuncName
    return function('<SNR>'.s:sid.'_'.sFuncName)
endfunction
"}}}
function! s:StartQucikCalltips() "{{{2
    if !s:enable | return '' | endif
    let s:dCalltipsData.usePrevTags = 1
    call vlcalltips#Start()
    return ''
endfunction
"}}}
" 补全请求前的预检查
function! s:ShouldComplete() "{{{2
    if (getline('.') =~ '#\s*include')
        " 写头文件，忽略
        return 0
    else
        " 检测光标所在的位置，如果在注释、双引号、浮点数时，忽略
        let nRow = line('.')
        let nCol = col('.') - 1 " 是前一列 eg. ->|
        if nCol < 1
            " TODO: 支持续行的补全
            return 0
        endif
        if g:VIMCCC_EnableSyntaxTest
            let lStack = synstack(nRow, nCol)
            let lStack = empty(lStack) ? [] : lStack
            for nID in lStack
                if synIDattr(nID, 'name') 
                            \=~? 'comment\|string\|float\|character'
                    return 0
                endif
            endfor
        else
            " TODO
        endif

        return 1
    endif
endfunction
"}}}
function! s:InitPyIf() "{{{2
    if !s:bFirstInit
        return
    endif

python << PYTHON_EOF
import threading
import subprocess
import StringIO
import traceback
import vim

# FIXME 应该引用
import json

def ToVimEval(o):
    '''把 python 字符串列表和字典转为健全的能被 vim 解析的数据结构
    对于整个字符串的引用必须使用双引号，例如:
        vim.command("echo %s" % ToVimEval(expr))'''
    if isinstance(o, str):
        return "'%s'" % o.replace("'", "''")
    elif isinstance(o, unicode):
        return "'%s'" % o.encode('utf-8').replace("'", "''")
    elif isinstance(o, (list, dict)):
        return json.dumps(o, ensure_ascii=False)
    else:
        return repr(o)


class cc_sync_data:
    '''保存同步的补全的同步数据'''
    def __init__(self):
        self.__lock = threading.Lock()
        self.__parsertd = None # 最近的那个 parser 线程

    def lock(self):
        return self.__lock.acquire()
    def unlock(self):
        return self.__lock.release()

    def latest_td(self):
        return self.__parsertd
    def push_td(self, td):
        '''把新线程压入'''
        self.__parsertd = td
    def clear_td(self):
        self.__parsertd = None

    def clear_td_safe(self):
        self.lock()
        self.clear_td()
        self.unlock()

    def is_alive(self):
        '''判断最近的线程是否正在运行'''
        if self.__parsertd:
            return self.__parsertd.is_alive()
        return False

    def is_done(self):
        '''判断最近的线程的补全结果是否已经产出'''
        if self.__parsertd:
            return self.__parsertd.done
        return False

    def push_and_start_td(self, td):
        self.push_td(td)
        td.start()

PYTHON_EOF
endfunction
"}}}
" 强制启动
function! vimccc#core#InitForcibly() "{{{2
    call s:InitVariable('g:VIMCCC_Enable', 0)
    let bak = g:VIMCCC_Enable
    let g:VIMCCC_Enable = 1
    let ret = vimccc#core#InitEarly()
    let g:VIMCCC_Enable = bak
    if ret != 0
        call vlutils#EchoWarnMsg('Failed to initialize VIMCCC, abort')
        return ret
    endif
    call VIMCCCInit()
endfunction
"}}}
" 这些初始化作为全局存在，已经初始化，永不销毁
function! s:FirstInit() "{{{2
" ============================================================================
    " MayComplete to '.'
    call s:InitVariable('g:VIMCCC_MayCompleteDot', 1)

    " MayComplete to '->'
    call s:InitVariable('g:VIMCCC_MayCompleteArrow', 1)

    " MayComplete to '::'
    call s:InitVariable('g:VIMCCC_MayCompleteColon', 1)

    " 把回车映射为: 
    " 在补全菜单中选择并结束补全时, 若选择的是函数, 自动显示函数参数提示
    call s:InitVariable('g:VIMCCC_MapReturnToDispCalltips', 1)

    " When completeopt does not contain longest option, this setting 
    " controls the behaviour of the popup menu selection 
    " when starting the completion
    "   0 = don't select first item
    "   1 = select first item (inserting it to the text)
    "   2 = select first item (without inserting it to the text)
    "   default = 2
    call s:InitVariable('g:VIMCCC_ItemSelectionMode', 2)

    " 使用语法测试
    call s:InitVariable('g:VIMCCC_EnableSyntaxTest', 1)

    " 本插件的 python 模块路径
    call s:InitVariable('g:VIMCCC_PythonModulePath', s:sDefaultPyModPath)

    " Clang library path
    call s:InitVariable('g:VIMCCC_ClangLibraryPath', '')

    " If clang should complete preprocessor macros and constants
    call s:InitVariable('g:VIMCCC_CompleteMacros', 0)

    " If clang should complete code patterns, i.e loop constructs etc.
    call s:InitVariable('g:VIMCCC_CompletePatterns', 0)

    " Update quickfix list periodically
    call s:InitVariable('g:VIMCCC_PeriodicQuickFix', 0)

    " Ignore case in code completion
    call s:InitVariable('g:VIMCCC_IgnoreCase', &ignorecase)

    " 跳转至符号声明处的默认快捷键
    call s:InitVariable('g:VIMCCC_GotoDeclarationKey', '<C-p>')

    " 跳转至符号实现处的默认快捷键
    call s:InitVariable('g:VIMCCC_GotoImplementationKey', '<C-]>')

    " 异步自动弹出补全菜单
    call s:InitVariable('g:VIMCCC_AutoPopupMenu', 1)

    " 触发自动弹出补全菜单需要输入的字符数
    call s:InitVariable('g:VIMCCC_TriggerCharCount', 2)

" ============================================================================
    let g:VIMCCC_CodeCompleteFlags = 0
    if g:VIMCCC_CompleteMacros
        let g:VIMCCC_CodeCompleteFlags += 1
    endif
    if g:VIMCCC_CompletePatterns
        let g:VIMCCC_CodeCompleteFlags += 2
    endif

    call s:InitPythonInterfaces()

    " 这是异步接口
    call s:InitPyIf()

    " 初始化失败的标志就是 VIMCCCIndex 为 None
    py if VIMCCCIndex is None: vim.command('return -1')
endfunction
"}}}
" 用于支持 videm 的插件动作
function! VIMCCCExit() "{{{2
    if !s:enable
        return
    endif
    delcommand VIMCCCQuickFix
    delcommand VIMCCCSetArgs
    delcommand VIMCCCAppendArgs
    delcommand VIMCCCPrintArgs
    augroup VidemCCVIMCCC
        autocmd!
    augroup END
    silent! augroup! VidemCCVIMCCC
    " NOTE: 即使清除了所有的自动命令，键位绑定还是没法清除的
    "       并且这个清除是不可逆的，即重新初始化的时候，没法恢复这些自动命令
    augroup VIMCCC_AUGROUP
        autocmd!
    augroup END
    silent! augroup! VIMCCC_AUGROUP
    call vlcalltips#Unregister(s:GetSFuncRef('s:RequestCalltips'))
    " 清掉所有缓冲区的补全设施
    call asynccompl#BuffExit(0)
    let s:enable = 0
    " NOTE: VIMCCCIndex 不销毁
endfunction
"}}}
" 最早阶段的初始化，只初始化一些基本设施
function! vimccc#core#InitEarly() "{{{2
    " 是否使用，可用于外部控制
    call s:InitVariable('g:VIMCCC_Enable', 0)
    if !g:VIMCCC_Enable
        return
    endif

    if s:enable
        return
    endif

    if s:bFirstInit
        let ret = s:FirstInit()
        if ret != 0
            return ret
        endif
    endif
    let s:bFirstInit = 0

    " 全局命令
    command! -nargs=0 -bar VIMCCCQuickFix
            \ call <SID>VIMCCCUpdateClangQuickFix(expand('%:p'))

    command! -nargs=+ VIMCCCSetArgs     call <SID>VIMCCCSetArgsCmd(<f-args>)
    command! -nargs=+ VIMCCCAppendArgs  call <SID>VIMCCCAppendArgsCmd(<f-args>)
    command! -nargs=0 VIMCCCPrintArgs   call <SID>VIMCCCPrintArgsCmd(<f-args>)
    command! -nargs=0 VIMCCCResetArgs   call <SID>VIMCCCSetArgsCmd()

    " 自动命令
    augroup VidemCCVIMCCC
        autocmd!
        autocmd! FileType c,cpp call VIMCCCInit()
    augroup END

    " 初始化函数参数提示服务
    call vlcalltips#Register(s:GetSFuncRef('s:RequestCalltips'),
            \                s:dCalltipsData)

    let s:enable = 1
endfunction
"}}}
" 可选参数控制是否立即更新（生成）翻译翻译单元
" 这个初始化是进入缓冲区的时候才调用
function! VIMCCCInit(...) "{{{2
    let bUpdTu = get(a:000, 0, 1)

    if !s:has_InsertCharPre
        echohl ErrorMsg
        echomsg 'Vim does not support InsertCharPre autocmd, so vimccc can not work'
        echomsg 'Please update your Vim to version 7.3.196 or later'
        echohl None
        return -1
    endif

    " TODO 表示缓冲区已经初始化 vimccc
    "      主要作用是保存一个新的文件后，再初始化
    "      暂不实现
    "let b:init = 1

    if (&ft !=# 'c' && &ft !=# 'cpp') || empty(expand('%'))
        return
    endif

    let bAsync = g:VIMCCC_AutoPopupMenu
    if bAsync && (empty(v:servername) || !has('clientserver'))
        let bAsync = 0
    endif

    " 函数参数提示键绑定
    call vlcalltips#InitBuffKeymap()

    if g:VIMCCC_MapReturnToDispCalltips
        inoremap <silent> <expr> <buffer> <CR> pumvisible() ? 
                \"\<C-y>\<C-r>=<SID>StartQucikCalltips()\<Cr>" : 
                \"\<CR>"
    endif

    exec 'nnoremap <silent> <buffer> ' . g:VIMCCC_GotoDeclarationKey 
            \. ' :call <SID>VIMCCCGotoDeclaration()<CR>'

    exec 'nnoremap <silent> <buffer> ' . g:VIMCCC_GotoImplementationKey 
            \. ' :call <SID>VIMCCCSmartJump()<CR>'

    let pats = []

    if g:VIMCCC_MayCompleteDot
        call add(pats, '\.')
    endif

    if g:VIMCCC_MayCompleteArrow
        call add(pats, '>')
    endif

    if g:VIMCCC_MayCompleteColon
        call add(pats, ':')
    endif

    " NOTE: 使用异步补全框架, 整个代码都简单了...
    let ret = VIMCCCAsyncComplInit(join(pats, '\|'))
    if ret != 0
        echohl ErrorMsg
        echomsg "Failed to init asynccompl framework, abort"
        echohl None
        return ret
    endif

    if g:VIMCCC_ItemSelectionMode > 4
        " 若是成员补全, 如 ., ->, :: 之后, 添加 longest 到 completeopt
        " 暂不实现
    endif

    if g:VIMCCC_PeriodicQuickFix
        augroup VIMCCC_AUGROUP
            autocmd! CursorHold,CursorHoldI <buffer> VIMCCCQuickFix
        augroup END
    endif

    if bUpdTu
        py VIMCCCIndex.AsyncUpdateTranslationUnit(vim.eval("expand('%:p')"))
    endif
endfunction
"}}}
" 搜索补全起始列
" 以下7种情形
"   xxx yyy|
"       ^
"   xxx.yyy|
"       ^
"   xxx.   |
"       ^
"   xxx->yyy|
"        ^
"   xxx->  |
"        ^
"   xxx::yyy|
"        ^
"   xxx::   |
"        ^
function! VIMCCCSearchStartColumn(bInCC) "{{{2
    let nRow = line('.')
    let nCol = col('.')
    "let lPos = searchpos('\<\|\.\|->\|::', 'cbn', nRow)
    " NOTE: 光标下的字符应该不算在内
    let lPos = searchpos('\<\|\.\|->\|::', 'bn', nRow)
    let nCol2 = lPos[1] " 搜索到的字符串的起始列号

    if lPos == [0, 0]
        " 这里已经处理了光标放到第一列并且第一列的字符是空白的情况
        let nStartCol = nCol
    else
        let sLine = getline('.')

        if sLine[nCol2 - 1] ==# '.'
            " xxx.   |
            "    ^
            let nStartCol = nCol2 + 1
        elseif sLine[nCol2 -1 : nCol2] ==# '->'
                \ || sLine[nCol2 - 1: nCol2] ==# '::'
            " xxx->   |
            "    ^
            let nStartCol = nCol2 + 2
        else
            " xxx yyy|
            "     ^
            " xxx.yyy|
            "     ^
            " xxx->yyy|
            "      ^
            " 前一个字符可能是 '\W'. eg. xxx yyy(|
            if sLine[nCol-2] =~# '\W'
                " 不补全
                return -1
            endif

            if a:bInCC
                " BUG: 返回 5 后，下次调用此函数时，居然 col('.') 返回 6
                "      亦即补全函数对返回值的解析有错误
                let nStartCol = nCol2 - 1
            else
                " 不在补全函数里面调用的话，返回正确值...
                let nStartCol = nCol2
            endif
        endif
    endif

    return nStartCol
endfunction
"}}}
function! s:RequestCalltips(...) "{{{2
    let bUsePrevTags = a:0 > 0 ? a:1.usePrevTags : 0
    let s:dCalltipsData.usePrevTags = 0 " 清除这个标志
    if bUsePrevTags
    " 从全能补全菜单选择条目后，使用上次的输出
        let sLine = getline('.')
        let nCol = col('.')
        if sLine[nCol-3:] =~ '^()'
            let sFuncName = matchstr(sLine[: nCol-4], '\~\?\w\+$')
            normal! h
            py vim.command("let lCalltips = %s" 
                        \% VIMCCCIndex.GetCalltipsFromCacheFilteredResults(
                        \   vim.eval("sFuncName")))
            call vlcalltips#UnkeepCursor()
            return lCalltips
        endif
    else
    " 普通情况，请求 calltips
        " 确定函数括号开始的位置
        let lOrigCursor = getpos('.')
        let lStartPos = searchpairpos('(', '', ')', 'nWb', 
                \'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"')
        " 考虑刚好在括号内，加 'c' 参数
        let lEndPos = searchpairpos('(', '', ')', 'nWc', 
                \'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"')
        let lCurPos = lOrigCursor[1:2]

        " 不在括号内
        if lStartPos ==# [0, 0]
            return ''
        endif

        " 获取函数名称和名称开始的列，只能处理 '(' "与函数名称同行的情况，
        " 允许之间有空格
        let sStartLine = getline(lStartPos[0])
        let sFuncName = matchstr(sStartLine[: lStartPos[1]-1], '\~\?\w\+\ze\s*($')
        let nFuncStartIdx = match(sStartLine[: lStartPos[1]-1], '\~\?\w\+\ze\s*($')

        let sFileName = expand('%:p')
        " 补全时，行号要加上前置字符串所占的行数，否则位置就会错误
        let nRow = lStartPos[0]
        let nCol = nFuncStartIdx + 1

        let lCalltips = []
        if sFuncName !=# ''
            let calltips = []
            " 找到了函数名，开始全能补全
            let sFileName = g:ToClangFileName(sFileName)
            py VIMCCCIndex.GetTUCodeCompleteResults(
                        \vim.eval("sFileName"), 
                        \int(vim.eval("nRow")),
                        \int(vim.eval("nCol")),
                        \[GetCurUnsavedFile()])
            py vim.command("let lCalltips = %s" 
                        \% VIMCCCIndex.GetCalltipsFromCacheCCResults(
                        \   vim.eval("sFuncName")))
        endif

        call setpos('.', lOrigCursor)
        call vlcalltips#KeepCursor()
        return lCalltips
    endif

    return ''
endfunction
"}}}
function! VIMCCCSetRelatedFile(sRelatedFile, ...) "{{{2
    let sFileName = a:0 > 0 ? a:1 : expand('%:p')
    if sFileName ==# ''
        " 不允许空文件名，因为空字符串不能为字典的键值
        return
    endif
    let g:dRelatedFile[sFileName] = {'line': 0, 'filename': a:sRelatedFile}
    py import IncludeParser
    py vim.command("let g:dRelatedFile[sFileName]['line'] = %d" 
                \% IncludeParser.FillHeaderWithSource(vim.eval("sFileName"), '',
                \                               vim.eval("a:sRelatedFile"))[0])
endfunction
"}}}
" 设置 clang 命令参数，参数可以是字符串或者列表
" 设置完毕后立即异步重建当前文件的翻译单元
function! VIMCCCSetArgs(lArgs) "{{{2
    if type(a:lArgs) == type('')
        let lArgs = split(a:lArgs)
    else
        let lArgs = a:lArgs
    endif

    let sFileName = expand('%:p')
    let sFileName = g:ToClangFileName(sFileName)
    py VIMCCCIndex.SetParseArgs(vim.eval("lArgs"))
    py VIMCCCIndex.AsyncUpdateTranslationUnit(vim.eval("sFileName"), 
                \[GetCurUnsavedFile()], True, True)
endfunction
"}}}
function! VIMCCCGetArgs() "{{{2
    py vim.command('let lArgs = %s' % ToVimEval(VIMCCCIndex.GetParseArgs()))
    return lArgs
endfunction
"}}}
function! VIMCCCAppendArgs(lArgs) "{{{2
    if type(a:lArgs) == type('')
        let lArgs = split(a:lArgs)
    else
        let lArgs = a:lArgs
    endif

    let lArgs = VIMCCCGetArgs() + lArgs
    call VIMCCCSetArgs(lArgs)
endfunction
"}}}
function! s:VIMCCCSetArgsCmd(...) "{{{2
    call VIMCCCSetArgs(a:000)
endfunction
"}}}
function! s:VIMCCCAppendArgsCmd(...) "{{{2
    call VIMCCCAppendArgs(a:000)
endfunction
"}}}
function! s:VIMCCCPrintArgsCmd() "{{{2
    let lArgs = VIMCCCGetArgs()
    echo lArgs
endfunction
"}}}
" 统一处理，主要处理 .h -> .hpp 的问题
function! g:ToClangFileName(sFileName) "{{{2
    let sFileName = a:sFileName
    let sResult = sFileName
    if fnamemodify(sFileName, ':e') ==? 'h'
        " 把 c 的头文件转为 cpp 的头文件，即 .h -> .hpp
        " 暂时简单的处理，前头加两个 '_'，后面加两个 'p'
        let sDirName = fnamemodify(sFileName, ':h')
        let sBaseName = fnamemodify(sFileName, ':t')
        let sResult = sDirName . '/' . '__' . sBaseName . 'pp'
    endif

    return sResult
endfunction
"}}}
function! s:FromClangFileName(sClangFileName) "{{{2
    let sClangFileName = a:sClangFileName
    let sResult = sClangFileName
    if fnamemodify(sClangFileName, ':e') ==? 'hpp' 
                \&& fnamemodify(sClangFileName, ':t')[:1] ==# '__'
        let sDirName = fnamemodify(sClangFileName, ':h')
        let sBaseName = fnamemodify(sClangFileName, ':t')
        let sResult = sDirName . '/' . sBaseName[2:-3]
    endif

    return sResult
endfunction
"}}}
" 更新本地当前窗口的 quickfix 列表
" TODO 需要和代码补全那样在需要的时候 rebuild 翻译单元
function! s:VIMCCCUpdateClangQuickFix(sFileName) "{{{2
    let sFileName = a:sFileName

    " quickfix 里面就不需要添加前置内容了，暂时的处理
    py VIMCCCIndex.UpdateTranslationUnit(vim.eval("sFileName"), 
                \[GetCurUnsavedFile(False)], True)
    py vim.command("let lQF = %s" 
                \% VIMCCCIndex.GetVimQucikFixListFromRecentTU())

    "call setqflist(lQF)
    call setloclist(0, lQF)
    silent! lopen
endfunction
"}}}
function! s:VIMCCCGotoDeclaration() "{{{2
    if !s:enable | return '' | endif
    let sFileName = expand('%:p')
    let nFileLineCount = line('$')

    let dict = get(g:dRelatedFile, sFileName, {})
    let nLineOffset = 0
    if !empty(dict) && dict.line > 0
        let nLineOffset = dict.line - 1
    endif

    let nRow = line('.')
    let nRow += nLineOffset
    let nCol = col('.')
    let sFileName = g:ToClangFileName(sFileName)
    py vim.command("let dLocation = %s" 
                \% VIMCCCIndex.GetSymbolDeclarationLocation(
                \       vim.eval("sFileName"), 
                \       int(vim.eval("nRow")), int(vim.eval("nCol")), 
                \       [GetCurUnsavedFile(UF_Related)], True))

    "echom string(dLocation)
    if !empty(dLocation) && dLocation.filename ==# sFileName
                \&& !empty(dict) && dict.line > 0
        if dLocation.line < dict.line
            " 在关联的文件中，前部
            let dLocation.filename = dict.filename
        elseif dLocation.line >= dict.line + nFileLineCount
            " 在关联的文件中，后部
            let dLocation.line -= (nFileLineCount - 1)
            let dLocation.filename = dict.filename
        else
            " 在当前文件中
            let dLocation.line -= nLineOffset
        endif
        "let dLocation.offset = 0 " 这个暂时无视
    endif
    "echom string(dLocation)

    call s:GotoLocation(dLocation)
endfunction
"}}}
function! s:VIMCCCGotoImplementation() "{{{2
    let sFileName = expand('%:p')
    let nFileLineCount = line('$')

    let dict = get(g:dRelatedFile, sFileName, {})
    let nLineOffset = 0
    if !empty(dict) && dict.line > 0
        let nLineOffset = dict.line - 1
    endif

    let nRow = line('.')
    let nRow += nLineOffset
    let nCol = col('.')
    let sFileName = g:ToClangFileName(sFileName)
    py vim.command("let dLocation = %s" 
                \% VIMCCCIndex.GetSymbolDefinitionLocation(vim.eval("sFileName"), 
                \       int(vim.eval("nRow")), int(vim.eval("nCol")), 
                \       [GetCurUnsavedFile(UF_Related)], True))

    "echom string(dLocation)
    if !empty(dLocation) && dLocation.filename ==# sFileName 
                \&& !empty(dict) && dict.line > 0
        if dLocation.line < dict.line
            " 在关联的文件中，前部
            let dLocation.filename = dict.filename
        elseif dLocation.line >= dict.line + nFileLineCount
            " 在关联的文件中，后部
            let dLocation.line -= (nFileLineCount - 1)
            let dLocation.filename = dict.filename
        else
            " 在当前文件中
            let dLocation.line -= nLineOffset
        endif
        "let dLocation.offset = 0 " 这个暂时无视
    endif
    "echom string(dLocation)

    call s:GotoLocation(dLocation)
endfunction
"}}}
" 智能跳转, 可跳转到包含的文件, 符号的实现处
function! s:VIMCCCSmartJump() "{{{2
    if !s:enable | return '' | endif
    let sLine = getline('.')
    if matchstr(sLine, '^\s*#\s*include') !=# ''
        " 跳转到包含的文件
        if exists(':VOpenIncludeFile') == 2
            VOpenIncludeFile
        endif
    else
        " 跳转到符号的实现处
        call s:VIMCCCGotoImplementation()
    endif
endfunction
"}}}
function! s:GotoLocation(dLocation) "{{{2
    let dLocation = a:dLocation
    if empty(dLocation)
        return
    endif

    let sFileName = dLocation.filename
    let nRow = dLocation.line
    let nCol = dLocation.column

    " 仅在这里需要反转？
    let sFileName = s:FromClangFileName(sFileName)

    if bufnr(sFileName) == bufnr('%')
        " 同一个缓冲区，仅跳至指定的行号和列号
        normal! m'
        call cursor(nRow, nCol)
    else
        let sCmd = printf("e +%d %s", nRow, sFileName)
        exec sCmd
        call cursor(nRow, nCol)
    endif
endfunction
"}}}
function! VIMCCCManualPopupCheck(char) "{{{2
    " NOTE: char 为即将输入的字符
    if col('.') < 2
        return 0
    endif

    let prev_char = getline('.')[col('.')-2 : col('.')-2]
    if a:char ==# ':' && prev_char !=# ':'
        return 0
    elseif a:char ==# '>' && prev_char !=# '-'
        return 0
    endif
    return 1
endfunction
"}}}
function! VIMCCCAsyncComplInit(...) "{{{2
    let config = {}
    let config.ignorecase = g:VIMCCC_IgnoreCase
    let config.manu_popup_pattern = get(a:000, 0, '\.\|>\|:')
    let config.auto_popup_pattern = '[A-Za-z_0-9]'
    let config.auto_popup_base_pattern = '[A-Za-z_]\w*$'
    let config.item_select_mode = g:VIMCCC_ItemSelectionMode
    let config.SearchStartColumnHook = 'CxxSearchStartColumn'
    let config.ManualPopupCheck = 'VIMCCCManualPopupCheck'
    " 使用 completefunc 就不会有补全菜单弹出的 BUG
    "let config.omnifunc = 1
    call asynccompl#Register(config)
    py CommonCompleteHookRegister(VIMCCCCompleteHook, None)
    py CommonCompleteArgsHookRegister(VIMCCCArgsHook, None)
    return asynccompl#BuffInit()
endfunction
"}}}
" NOTE: 调用此函数后，生成全局变量 VIMCCCIndex
function! s:InitPythonInterfaces() "{{{2
    if !s:bFirstInit
        return
    endif

python << PYTHON_EOF
import sys
import vim
try:
    sys.path.index(vim.eval("g:VIMCCC_PythonModulePath"))
except ValueError:
    sys.path.append(vim.eval("g:VIMCCC_PythonModulePath"))

UF_None = 0
UF_Related = 1
UF_RelatedPrepend = 2

def GetCurUnsavedFile(nFlags = UF_None):
    '''
    nFlags:     控制一些特殊补全场合，例如在头文件补全'''
    sFileName = vim.eval("expand('%:p')")
    sClangFileName = vim.eval("g:ToClangFileName(%s)" % ToVimEval(sFileName))

    if nFlags == UF_None:
        return (sClangFileName, '\n'.join(vim.current.buffer[:]))

    if nFlags == UF_Related:
        import IncludeParser
        d = vim.eval("get(g:dRelatedFile, expand('%:p'), {})")
        if d:
            nOffsetRow = d['line']
            sSourceFile = d['filename']
            # 如果没有在关联文件找到要找的 #include 行，nOffsetRow 为 0
            # 文本内容都是以 NL 结尾的
            nOffsetRow, sResult = IncludeParser.FillHeaderWithSource(
                sFileName, '\n'.join(vim.current.buffer[:]) + '\n', sSourceFile)
            #print nOffsetRow
            #print sResult
            vim.command(
                "let g:dRelatedFile[expand('%%:p')]['line'] = %d" % nOffsetRow)
            return (sClangFileName, sResult)
        else:
            return GetCurUnsavedFile(UF_None)

def GetCurCursorPos():
    return vim.current.window.cursor

def GetCurRow():
    #return vim.current.window.cursor[0]
    return int(vim.eval("line('.')"))

def GetCurCol():
    # NOTE: 在补全函数中，与 col('.') 的结果不一致！
    #       这个返回结果为进入补全函数前的位置
    #return vim.current.window.cursor[1]
    return int(vim.eval("col('.')"))

def VIMCCCArgsHook(kwargs):
    args = {
        'file'      : vim.eval('g:ToClangFileName(expand("%:p"))'),
        'us_files'  : [GetCurUnsavedFile()],
        'row'       : kwargs['row'],
        'col'       : kwargs['col'],
        'base'      : kwargs['base'],
        'icase'     : kwargs['icase'],
        'scase'     : kwargs['scase'],
        'flags'     : int(vim.eval("g:VIMCCC_CodeCompleteFlags")),
        'servername': vim.eval('v:servername'),
    }
    #print args
    return args

def VIMCCCCompleteHook(acthread, args):
    '''这个函数在后台线程里面运行'''
    fil = args.get('file')
    row = args.get('row')
    col = args.get('col')
    base = args.get('base')
    icase = args.get('icase')
    us_files = args.get('us_files')
    flags = args.get('flags')

    result = None

    acthread.CommonLock()
    try:
        result = VIMCCCIndex.GetVimCodeCompleteResults(fil, row, col, us_files,
                                                       base, icase, flags)
    except:
        acthread.CommonUnlock()
        raise
    acthread.CommonUnlock()

    return result

# 本插件只操作这个实例，其他事都不管
VIMCCCIndex = None

# FIXME 暂时用这么搓的方法来传递参数给 cindex
__save_argv = sys.argv
sys.argv = [sys.argv[0], vim.eval("g:VIMCCC_ClangLibraryPath")]
try:
    from VIMClangCC import *
except:
    raise
finally:
    sys.argv = __save_argv
    del __save_argv
# 真正的实例
VIMCCCIndex = VIMClangCCIndex()
PYTHON_EOF
endfunction
"}}}
" vim: fdm=marker fen et sts=4 fdl=1
