" Vim clang code completion plugin
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2011-12-16
" Change:   2013-01-23

if !has('python')
    echohl ErrorMsg
    echom printf("[%s]: Required vim compiled with +python",
            \    expand('<sfile>:p'))
    echohl None
    finish
endif

if exists("g:loaded_VIMClangCC")
    finish
endif
let g:loaded_VIMClangCC = 1

" 在 console 跑的 vim 没法拥有这个特性...
let s:has_clientserver = 0
if has('clientserver')
    let s:has_clientserver = 1
endif

autocmd FileType c,cpp call VIMClangCodeCompletionInit()

" 标识是否第一次初始化
let s:bFirstInit = 1

" 调试用
let s:nAsyncCompleteCount = 0

let s:dCalltipsData = {}
let s:dCalltipsData.usePrevTags = 0 " 是否使用最近一次的 tags 缓存

" 检查是否支持 noexpand 选项
let s:__temp = &completeopt
let s:has_noexpand = 1
try
    set completeopt+=noexpand
catch /.*/
    let s:has_noexpand = 0
endtry
let &completeopt = s:__temp
unlet s:__temp
"let g:has_noexpand = s:has_noexpand

let s:has_InsertCharPre = 0
if v:version >= 703 && has('patch196')
    let s:has_InsertCharPre = 1
endif

" 关联的文件，一般用于头文件关联源文件
" 在头文件头部和尾部添加的额外的内容，用于修正在头文件时的头文件包含等等问题
" {头文件: {'line': 在关联文件中对应的行(#include), 'filename': 关联文件}, ...}
let g:dRelatedFile = {}

let s:sPluginPath = substitute(expand('<sfile>:p:h'), '\\', '/', 'g')

if has('win32') || has('win64')
    let s:sDefaultPyModPath = fnamemodify($VIM . '\vimlite\VimLite', ":p")
else
    let s:sDefaultPyModPath = fnamemodify("~/.vimlite/VimLite", ":p")
endif

function! s:InitVariable(varName, defaultVal) "{{{2
    if !exists(a:varName)
        let {a:varName} = a:defaultVal
        return 1
    else
        return 0
    endif
endfunction
"}}}

command! -nargs=0 -bar VIMCCCInitForcibly call <SID>VIMCCCInitForcibly()

" 临时启用选项函数 {{{2
function! s:SetOpts()
    let s:bak_cot = &completeopt

    if g:VIMCCC_ItemSelectionMode == 0 " 不选择
        set completeopt-=menu,longest
        set completeopt+=menuone
    elseif g:VIMCCC_ItemSelectionMode == 1 " 选择并插入文本
        set completeopt-=menuone,longest
        set completeopt+=menu
    elseif g:VIMCCC_ItemSelectionMode == 2 " 选择但不插入文本
        if s:has_noexpand
            " 支持 noexpand 就最好了
            set completeopt+=noexpand
            set completeopt-=longest
        else
            set completeopt-=menu,longest
            set completeopt+=menuone
        endif
    else
        set completeopt-=menu
        set completeopt+=menuone,longest
    endif

    return ''
endfunction
function! s:RestoreOpts()
    if exists('s:bak_cot')
        let &completeopt = s:bak_cot
        unlet s:bak_cot
    else
        return ""
    endif

    let sRet = ""

    if pumvisible()
        if g:VIMCCC_ItemSelectionMode == 0 " 不选择
            let sRet = "\<C-p>"
        elseif g:VIMCCC_ItemSelectionMode == 1 " 选择并插入文本
            let sRet = ""
        elseif g:VIMCCC_ItemSelectionMode == 2 " 选择但不插入文本
            if !s:has_noexpand
                let sRet = "\<C-p>\<Down>"
            endif
        else
            let sRet = "\<Down>"
        endif
    endif

    return sRet
endfunction
function! s:CheckIfSetOpts()
    let sLine = getline('.')
    let nCol = col('.') - 1
    " 若是成员补全，添加 longest
    if sLine[nCol-2:] =~ '->' || sLine[nCol-1:] =~ '\.' 
                \|| sLine[nCol-2:] =~ '::'
        call s:SetOpts()
    endif

    return ''
endfunction
"}}}
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
    let s:dCalltipsData.usePrevTags = 1
    call g:VLCalltips_Start()
    return ''
endfunction
"}}}
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
function! s:LaunchCodeCompletion() "{{{2
    if s:ShouldComplete()
        return "\<C-x>\<C-o>"
    else
        return ''
    endif
endfunction
"}}}
" 触发条件
"
" 触发的情形:
"   abcdefg
"          ^    并且离单词起始位置的长度大于或等于触发字符数
"
" 不触发的情形:
"   abcdefg
"         ^
" 插入模式光标自动命令的上一个状态
" ccrow: 代码完成的行号
" cccol: 代码完成的列号
" base: base
" pumvisible : 0|1
" init: 0|1 起始状态，暂时只有在进入插入模式时初始化
"
" FIXME: 这些状态，连我自己都分不清了...
"        等 7.3.196 使用 InsertCharPre 事件就好了
" InsertCharPre   When a character is typed in Insert mode,
"     before inserting the char.
"     The |v:char| variable indicates the char typed
"     and can be changed during the event to insert
"     a different character.  When |v:char| is set
"     to more than one character this text is
"     inserted literally.
"     It is not allowed to change the text |textlock|.
"     The event is not triggered when 'paste' is
"     set.
let s:aucm_prev_stat = {}
function! VIMCCCAsyncComplete(charPre) "{{{2
    if pumvisible() " 不重复触发
        return ''
    endif

    " InsertCharPre 自动命令用
    let sChar = ''
    if a:charPre
        let sChar = v:char
        if sChar !~# '[A-Za-z_0-9]'
            return ''
        endif
    endif

    let nTriggerCharCount = g:VIMCCC_TriggerCharCount
    let nCol = col('.')
    let sLine = getline('.')
    let sPrevChar = sLine[nCol-2]
    let sCurrChar = sLine[nCol-1]
    " 光标在单词之间，不需要启动 {for CursorMovedI}
    if !a:charPre &&
            \ (sPrevChar !~# '[A-Za-z_0-9]' || sCurrChar =~# '[A-Za-z_0-9]')
        return ''
    endif

" ==============================================================================
" 利用前状态和当前状态优化
    " 前状态
    let dPrevStat = s:aucm_prev_stat

    " 刚进入插入模式
    if !a:charPre && get(dPrevStat, 'init', 0)
        call s:ResetAucmPrevStat()
        return ''
    endif

    let sPrevWord = matchstr(sLine[: nCol-2], '[A-Za-z_]\w*$')
    if a:charPre
        let sPrevWord .= sChar
    endif
    if len(sPrevWord) < nTriggerCharCount
        " 如果之前补全过就重置状态
        if get(dPrevStat, 'cccol', 0) > 0
            call s:ResetAucmPrevStat()
        endif
        return ''
    endif

    " 获取当前状态
    let nRow = line('.')
    let nCol = VIMCCCSearchStartColumn(0)
    let sBase = getline('.')[nCol-1 : col('.')-2]
    if a:charPre
        let sBase .= sChar
    endif

    " 补全起始位置一样就不需要再次启动了
    " 貌似是有条件的，要判断 sPrevWord 的长度
    " case: 如果前面的单词的长度 < nTriggerCharCount，那么就需要启动了
    "       例如一直删除字符
    " 1. 起始行和上次相同
    " 2. 起始列和上次相同
    " 3. 光标前的字符串长度大于等于触发长度
    " 4. 上次的 base 是光标前的字符串的前缀(InsertCharPre 专用)
    " 1 && 2 && 3 && 4 则忽略请求
    let save_ic = &ignorecase
    let &ignorecase = g:VIMCCC_IgnoreCase
    if get(dPrevStat, 'ccrow', 0) == nRow && get(dPrevStat, 'cccol', 0) == nCol
            \ && len(sPrevWord) >= nTriggerCharCount
            \ && (!a:charPre || sBase =~ '^'.get(dPrevStat, 'base', ''))
        call s:UpdateAucmPrevStat(nRow, nCol, sBase, pumvisible())
        let &ignorecase = save_ic
        return ''
    endif
    let &ignorecase = save_ic
    " 关于补全菜单和 CursorMovedI 自动命令
    " 不触发:
    "   弹出补全菜单(eg. <C-x><C-n>)
    " 触发:
    "   取消补全菜单(eg. <C-e>)
    "   接受补全结果(eg. <C-y>)
    " 所以这里的条件是，只要前状态的 'pumvisible' 为真，本次就不启动
    " 并且需要重置状态
    if !a:charPre && get(dPrevStat, 'pumvisible', 0)
        call s:ResetAucmPrevStat()
        return ''
    endif
" ==============================================================================
    " NOTE: 无法处理的情况: 光标随意移动到单词的末尾
    "       因为无法分辨到底是输入字符到达末尾还是移动过去 {for CursorMovedI}

    " ok，启动
    call VIMCCCLaunchCCThread(nRow, nCol, sBase)
    let s:nAsyncCompleteCount += 1

    " 更新状态
    call s:UpdateAucmPrevStat(nRow, nCol, sBase, pumvisible())
endfunction
"}}}
" 导出这个变量
function! VIMCCCAsyncCompleteCount() "{{{2
    return s:nAsyncCompleteCount
endfunction
"}}}
" 重置状态
function! s:ResetAucmPrevStat() "{{{2
    call s:UpdateAucmPrevStat(0, 0, '', 0)
    let s:aucm_prev_stat['init'] = 0
endfunction
"}}}
function! s:InitAucmPrevStat() "{{{2
    call s:UpdateAucmPrevStat(0, 0, '', 0)
    let s:aucm_prev_stat['init'] = 1
endfunction
"}}}
function! s:UpdateAucmPrevStat(nRow, nCol, sBase, pumv) "{{{2
    let s:aucm_prev_stat['ccrow'] = a:nRow
    let s:aucm_prev_stat['cccol'] = a:nCol
    let s:aucm_prev_stat['base'] = a:sBase
    let s:aucm_prev_stat['pumvisible'] = a:pumv
endfunction
"}}}
" NOTE: a:char 必须是已经输入完成的，否则补全会失效，
"       因为补全线程需要获取这个字符
function! s:CompleteByCharAsync(char) "{{{2
    let nRow = line('.')
    let nCol = col('.')
    let sBase = ''
    if a:char ==# '.'
        call s:UpdateAucmPrevStat(nRow, nCol, sBase, pumvisible())
        return VIMCCCLaunchCCThread(nRow, nCol, sBase)
    elseif a:char ==# '>'
        if getline('.')[col('.') - 3] != '-'
            return ''
        else
            call s:UpdateAucmPrevStat(nRow, nCol, sBase, pumvisible())
            return VIMCCCLaunchCCThread(nRow, nCol, sBase)
        endif
    elseif a:char ==# ':'
        if getline('.')[col('.') - 3] != ':'
            return ''
        else
            call s:UpdateAucmPrevStat(nRow, nCol, sBase, pumvisible())
            return VIMCCCLaunchCCThread(nRow, nCol, sBase)
        endif
    else
        " TODO: A-Za-Z_0-9
    endif
endfunction
"}}}
function! s:CompleteByChar(char) "{{{2
    if a:char ==# '.'
        return a:char . s:LaunchCodeCompletion()
    elseif a:char ==# '>'
        if getline('.')[col('.') - 2] != '-'
            return a:char
        else
            return a:char . s:LaunchCodeCompletion()
        endif
    elseif a:char ==# ':'
        if getline('.')[col('.') - 2] != ':'
            return a:char
        else
            return a:char . s:LaunchCodeCompletion()
        endif
    endif
endfunction
"}}}
function! s:InitPyIf() "{{{2
python << PYTHON_EOF
import threading
import subprocess
import StringIO
import traceback
import vim

# FIXME: 应该引用
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


def vimcs_eval_expr(servername, expr, prog='vim'):
    '''在vim服务器上执行表达式expr，返回输出——字符串
    FIXME: 这个函数不能对自身的服务器调用，否则死锁！'''
    if not expr:
        return ''
    cmd = [prog, '--servername', servername, '--remote-expr', expr]
    p = subprocess.Popen(cmd, shell=False,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()

    # 最后的换行干掉
    if out.endswith('\r\n'):
        return out[:-2]
    elif out.endswith('\n'):
        return out[:-1]
    elif out.endswith('\r'):
        return out[:-1]
    else:
        return out

def vimcs_send_keys(servername, keys, prog='vim'):
    '''发送按键到vim服务器'''
    if not servername:
        return -1
    cmd = [prog, '--servername', servername, '--remote-send', keys]
    p = subprocess.Popen(cmd, shell=False,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()
    return p.returncode

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

class cc_thread(threading.Thread):
    # 保证 VIMCCCIndex 完整性的锁，否则可能段错误
    indexlock = threading.Lock()

    '''代码补全搜索线程'''
    def __init__(self, arg, vimprog = 'vim'):
        threading.Thread.__init__(self)
        self.arg = arg      # 传给 clang 补全的参数，字典
        self.result = []    # 补全结果
        self.done = False   # 标识主要工作已经完成
        self.vimprog = vimprog

    @property
    def row(self):
        return self.arg['row']
    @property
    def col(self):
        return self.arg['col']
    @property
    def base(self):
        return self.arg['base']

    def run(self):
        try:
            # 开始干活
            fil = self.arg['file']
            row = self.arg['row']
            col = self.arg['col']
            us_files = self.arg['us_files']
            base = self.arg['base']
            ic = self.arg['ic']
            flags = self.arg['flags']
            servername = self.arg['servername']
            if False:
                # just for test
                self.result = ['f', 'ff', 'fff']
            else:
                # 必须加锁，因为 clang 的解析不是线程安全的(大概)
                cc_thread.indexlock.acquire()
                try:
                    self.result = VIMCCCIndex.GetVimCodeCompleteResults(
                            fil, row, col, us_files, base, ic, flags)
                except:
                    # 异常后需要解锁并且传递异常
                    cc_thread.indexlock.release()
                    raise
                cc_thread.indexlock.release()

            if not self.result: # 有结果才继续
                return

            # 完成后
            self.done = True
            brk = False
            g_SyncData.lock()
            if not g_SyncData.latest_td() is self:
                brk = True
            g_SyncData.unlock()
            if brk:
                return

            # 发送消息到服务器
            vimcs_eval_expr(servername, 'VIMCCCThreadHandler()', self.vimprog)

        except:
            # 把异常信息显示给用户
            sio = StringIO.StringIO()
            print >> sio, "Exception in user code:"
            print >> sio, '-' * 60
            traceback.print_exc(file=sio)
            print >> sio, '-' * 60
            errmsg = sio.getvalue()
            sio.close()
            vimcs_eval_expr(servername, "VIMCCCExceptHandler('%s')"
                                        % errmsg.replace("'", "''"),
                            self.vimprog)

PYTHON_EOF
endfunction
"}}}
" 这个函数是从后台线程调用的，现在假设这个调用和vim前台调用是串行的，无竟态的
" NOTE: 这个函数被python后台线程调用的时候，python后台线程还没有退出
function! VIMCCCThreadHandler() "{{{2
    if mode() !=# 'i' && mode() !=# 'R'
        echoerr 'error mode'
        return -1
    endif
    if pumvisible() " 已经有补全窗口了，本次自动取消
        return 0
    endif
    let nRow = line('.')
    let nCol = VIMCCCSearchStartColumn(0)
    let sBase = getline('.')[nCol-1 : col('.')-2]
    let td_row = 0
    let td_col = 0
    let td_base = ''
    let brk = 0
    py g_SyncData.lock()
    py if not g_SyncData.is_done(): vim.command('let brk = 1')
    py s_latest_td = g_SyncData.latest_td()
    py g_SyncData.unlock()
    " 如果最近线程还没有完成，返回
    if brk
        py del s_latest_td
        echomsg 'cc_thread is not done'
        return 1
    endif
    " 到这里，s_latest_td 肯定非空并且肯定有结果
    py vim.command("let td_row = %d" % s_latest_td.row)
    py vim.command("let td_col = %d" % s_latest_td.col)
    py vim.command("let td_base = '%s'" % s_latest_td.base.replace("'", "''"))

    let save_ic = &ignorecase
    let &ignorecase = g:VIMCCC_IgnoreCase
    if !(td_row == nRow && td_col == nCol && sBase =~ '^'.td_base)
        " 这个结果不适合于当前位置，直接返回
        let &ignorecase = save_ic
        py del s_latest_td
        return 0
    endif

    " 需要进一步过滤这种情况的补全结果: sBase = 'abc', td_base = 'ab'
    if 1 " python实现的过滤
        py s_lResults = s_latest_td.result
        if g:VIMCCC_IgnoreCase " 忽略大小写
" ============================================================================
python << PYTHON_EOF
s_base = vim.eval("sBase").upper()
if isinstance(s_lResults[0], str):
    s_lResults = filter(lambda x: x.upper().startswith(s_base), s_lResults)
else:
    s_lResults = filter(lambda x: x['word'].upper().startswith(s_base),
                        s_lResults)
del s_base
PYTHON_EOF
" ============================================================================
        else " 区分大小写
" ============================================================================
python << PYTHON_EOF
s_base = vim.eval("sBase")
if isinstance(s_lResults[0], str):
    s_lResults = filter(lambda x: x.startswith(s_base), s_lResults)
else:
    s_lResults = filter(lambda x: x['word'].startswith(s_base), s_lResults)
del s_base
PYTHON_EOF
" ============================================================================
        endif
        py s_latest_td.result = s_lResults
        py del s_lResults
    else " vim script实现的过滤
        py vim.command("let lResults = %s" % s_latest_td.result)
        if type(lResults[0]) == type('')
            call filter(lResults, 'v:val =~ ^.sBase')
        else
            call filter(lResults, 'v:val["word"] =~ "^".sBase')
        endif
        py s_latest_td.result = vim.eval("lResults")
    endif
    let &ignorecase = save_ic
    " 过滤完毕后如果为空，直接结束即可
    py if not s_latest_td.result: del s_latest_td; vim.command("return 0")

    " NOTE: 基于一个重要的假设，当前控制路径时，输入队列中没有任何字符了
    "       这样方可保证当前的补全结果是最新可用的结果
    py g_SyncDataResult = s_latest_td
    let sKeys = ""
    " FIXME \<C-r>=Fun()\<Cr> 这样执行函数在命令行会显示，能避免吗？
    let sKeys .= "\<C-r>=VIMCCCAsyncCCPre()\<Cr>"
    let sKeys .= "\<C-x>\<C-o>"
    let sKeys .= "\<C-r>=VIMCCCAsyncCCPost()\<Cr>"
    call feedkeys(sKeys, "n")
    py del s_latest_td
    return 0
endfunction
"}}}
function! VIMCCCExceptHandler(msg) "{{{2
    if empty(a:msg)
        return
    endif
    echohl ErrorMsg
    for sLine in split(a:msg, '\n')
        echomsg sLine
    endfor
    echomsg '!!!Catch an exception!!!'
    echohl None
endfunction
"}}}
" VIMCCCThreadHandler() 调用，执行一些前置动作
function! VIMCCCAsyncCCPre() "{{{2
    call s:SetOpts()
    return ''
endfunction
"}}}
" VIMCCCThreadHandler() 调用，执行一些后续动作
function! VIMCCCAsyncCCPost() "{{{2
    call feedkeys(s:RestoreOpts(), "n")
    return ''
endfunction
"}}}
" 强制启动
function! s:VIMCCCInitForcibly() "{{{2
    let bak = g:VIMCCC_Enable
    let g:VIMCCC_Enable = 1
    call VIMClangCodeCompletionInit()
    let g:VIMCCC_Enable = bak
endfunction
"}}}
" 首次启动
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
    command! -nargs=0 -bar VIMCCCQuickFix
            \ call <SID>VIMCCCUpdateClangQuickFix(expand('%:p'))

    command! -nargs=+ VIMCCCSetArgs call <SID>VIMCCCSetArgsCmd(<f-args>)
    command! -nargs=+ VIMCCCAppendArgs call <SID>VIMCCCAppendArgsCmd(<f-args>)
    command! -nargs=0 VIMCCCPrintArgs call <SID>VIMCCCPrintArgsCmd(<f-args>)

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
    " === 全局结构
    " 异步线程队列
    py g_SyncData = cc_sync_data()
    " 当前补全的结果，cc_thread实例，串行修改
    py g_SyncDataResult = None
endfunction
"}}}
" 可选参数存在且非零，不 '冷启动'(异步新建不存在的当前文件对应的翻译单元)
function! VIMClangCodeCompletionInit(...) "{{{2
    " 是否使用，可用于外部控制
    call s:InitVariable('g:VIMCCC_Enable', 0)
    if !g:VIMCCC_Enable
        return
    endif

    if s:bFirstInit
        call s:FirstInit()
    endif
    let s:bFirstInit = 0

    let bAsync = g:VIMCCC_AutoPopupMenu

    " 特性检查
    if bAsync && (empty(v:servername) || !has('clientserver'))
        echohl WarningMsg
        echom '-------------------- VIMCCC --------------------'
        if empty(v:servername)
            echom "Please start vim as server, eg. vim --servername {name}"
            echom "Auto popup menu feature will be disabled this time"
        else
            echom 'Auto popup menu feature required vim compiled vim with '
                    \ . '+clientserver'
            echom 'The feature will be disabled this time'
        endif
        echom "You can run ':let g:VIMCCC_AutoPopupMenu = 0' to diable this "
                \ . "message"
        echohl None
        let bAsync = 0
    endif

    setlocal omnifunc=VIMClangCodeCompletion

    if g:VIMCCC_PeriodicQuickFix
        augroup VIMCCC_AUGROUP
            autocmd! CursorHold,CursorHoldI <buffer> VIMCCCQuickFix
        augroup END
    endif

    " 初始化函数参数提示服务
    call g:VLCalltips_RegisterCallback(
                \s:GetSFuncRef('s:RequestCalltips'), s:dCalltipsData)
    call g:InitVLCalltips()

    if g:VIMCCC_MayCompleteDot
        if bAsync
            inoremap <silent> <buffer> . .
                    \<C-r>=<SID>CompleteByCharAsync('.')<CR>
        else
            inoremap <silent> <buffer> . 
                    \<C-r>=<SID>SetOpts()<CR>
                    \<C-r>=<SID>CompleteByChar('.')<CR>
                    \<C-r>=<SID>RestoreOpts()<CR>
        endif
    endif

    if g:VIMCCC_MayCompleteArrow
        if bAsync
            inoremap <silent> <buffer> > >
                        \<C-r>=<SID>CompleteByCharAsync('>')<CR>
        else
            inoremap <silent> <buffer> > 
                        \<C-r>=<SID>SetOpts()<CR>
                        \<C-r>=<SID>CompleteByChar('>')<CR>
                        \<C-r>=<SID>RestoreOpts()<CR>
        endif
    endif

    if g:VIMCCC_MayCompleteColon
        if bAsync
            inoremap <silent> <buffer> : :
                        \<C-r>=<SID>CompleteByCharAsync(':')<CR>
        else
            inoremap <silent> <buffer> : 
                        \<C-r>=<SID>SetOpts()<CR>
                        \<C-r>=<SID>CompleteByChar(':')<CR>
                        \<C-r>=<SID>RestoreOpts()<CR>
        endif
    endif

    if g:VIMCCC_ItemSelectionMode > 4
        inoremap <silent> <buffer> <C-n> 
                    \<C-r>=<SID>CheckIfSetOpts()<CR>
                    \<C-r>=<SID>LaunchCodeCompletion()<CR>
                    \<C-r>=<SID>RestoreOpts()<CR>
    else
        "inoremap <silent> <buffer> <C-n> 
                    "\<C-r>=<SID>SetOpts()<CR>
                    "\<C-r>=<SID>LaunchCodeCompletion()<CR>
                    "\<C-r>=<SID>RestoreOpts()<CR>
    endif

    if g:VIMCCC_MapReturnToDispCalltips
        "inoremap <silent> <expr> <buffer> <CR> pumvisible() ? 
                    "\"\<C-y>\<C-r>=<SID>RequestCalltips(1)\<Cr>" : 
                    "\"\<CR>"
        inoremap <silent> <expr> <buffer> <CR> pumvisible() ? 
                    \"\<C-y><C-r>=<SID>StartQucikCalltips()\<Cr>" : 
                    \"\<CR>"
    endif

    exec 'nnoremap <silent> <buffer> ' . g:VIMCCC_GotoDeclarationKey 
                \. ' :call <SID>VIMCCCGotoDeclaration()<CR>'

    exec 'nnoremap <silent> <buffer> ' . g:VIMCCC_GotoImplementationKey 
                \. ' :call <SID>VIMCCCSmartJump()<CR>'

    if bAsync
        " 真正的异步补全实现
        " 输入字符必须是 [A-Za-z_0-9] 才能触发
        if s:has_InsertCharPre
            augroup VIMCCC_AUGROUP
                autocmd! InsertEnter <buffer> call <SID>InitAucmPrevStat()
                autocmd! InsertCharPre <buffer> call VIMCCCAsyncComplete(1)
                autocmd! InsertLeave <buffer>
                        \ call <SID>Autocmd_InsertLeaveHandler()
            augroup END
        else
            augroup VIMCCC_AUGROUP
                autocmd! CursorMovedI <buffer> call VIMCCCAsyncComplete(0)
                autocmd! InsertLeave <buffer>
                        \ call <SID>Autocmd_InsertLeaveHandler()
                " NOTE: 事件顺序是先 InsertEnter 再 CursorMovedI
                autocmd! InsertEnter <buffer> call <SID>InitAucmPrevStat()
            augroup END
        endif
    endif

    if a:0 > 0 && a:1
        " 可控制不 '冷启动'
    else
        " '冷启动'
        py VIMCCCIndex.AsyncUpdateTranslationUnit(vim.eval("expand('%:p')"))
    endif

    " 调试用
    "inoremap <silent> <buffer> <A-n> <C-r>=VIMCCCLaunchCCThread()<Cr>
endfunction
"}}}
function! s:Autocmd_InsertLeaveHandler() "{{{2
    call s:ResetAucmPrevStat()
    " 清线程
    py g_SyncData.lock()
    py g_SyncData.clear_td()
    py g_SyncData.unlock()
endfunction
"}}}
" 启动一个新的补全线程
function! VIMCCCLaunchCCThread(nRow, nCol, sBase) "{{{2
    if v:servername ==# ''
        echoerr 'servername is null, can not start cc thread'
        return ''
    endif

    let sAppend = a:0 > 0 ? a:1 : ''

    let sFileName = expand('%:p')
    let sFileName = s:ToClangFileName(sFileName)
    let nRow = a:nRow
    let nCol = a:nCol
    let sBase = a:sBase
    let sVimProg = v:progname
    if has('win32') || has('win64')
        " Windows 下暂时这样获取
        let sVimProg = $VIMRUNTIME . '\' . sVimProg
    endif
    " 上锁然后开始线程
    py g_SyncData.lock()
    py g_SyncData.push_and_start_td(cc_thread(
            \   {'file': vim.eval('sFileName'),
            \    'row': int(vim.eval('nRow')),
            \    'col': int(vim.eval('nCol')),
            \    'us_files': [GetCurUnsavedFile()],
            \    'base': vim.eval("sBase"),
            \    'ic': vim.eval("g:VIMCCC_IgnoreCase") != '0',
            \    'flags': int(vim.eval("g:VIMCCC_CodeCompleteFlags")),
            \    'servername': vim.eval('v:servername')},
            \   vim.eval("sVimProg")))
    py g_SyncData.unlock()

    return ''
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
                " BUG: 返回 5 后，下次调用此函数是，居然 col('.') 返回 6
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
            call g:VLCalltips_UnkeepCursor()
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
            let sFileName = s:ToClangFileName(sFileName)
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
        call g:VLCalltips_KeepCursor()
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
    let sFileName = s:ToClangFileName(sFileName)
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

    let lArgs += VIMCCCGetArgs()
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
function! s:ToClangFileName(sFileName) "{{{2
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
function! VIMClangCodeCompletion(findstart, base) "{{{2
    if a:findstart
        "call vlutils#TimerStart() " 计时
        return VIMCCCSearchStartColumn(1)
    endif

    "===========================================================================
    " 补全操作开始
    "===========================================================================

    let b:base = a:base
    let sBase = a:base

    let sFileName = expand('%:p')
    let sFileName = s:ToClangFileName(sFileName)
    let nRow = line('.')
    let nCol = col('.') "列

    let bAsync = 0
    py if g_SyncDataResult: vim.command("let bAsync = 1")

    if bAsync
        " 异步触发
        py s_lResults = g_SyncDataResult.result
        py g_SyncDataResult = None
        " NOTE: 触发器已经提前检查了是否需要触发，所以无须再检查是否继续了
    else
        py s_lResults = VIMCCCIndex.GetVimCodeCompleteResults(
            \ vim.eval("sFileName"), 
            \ int(vim.eval("nRow")),
            \ int(vim.eval("nCol")),
            \ [GetCurUnsavedFile()],
            \ vim.eval("sBase"),
            \ vim.eval("g:VIMCCC_IgnoreCase") != '0',
            \ int(vim.eval("g:VIMCCC_CodeCompleteFlags")))
        "call vlutils#TimerEndEcho()
    endif

    py vim.command("let lResults = %s" % s_lResults)
    "call vlutils#TimerEndEcho()
    " 调试用
    "let g:lResults = lResults

    "call vlutils#TimerEndEcho()

    py del s_lResults
    return lResults
    "===========================================================================
    " 补全操作结束
    "===========================================================================
endfunction
" 更新本地当前窗口的 quickfix 列表
function! s:VIMCCCUpdateClangQuickFix(sFileName) "{{{2
    let sFileName = a:sFileName

    "py t = UpdateQuickFixThread(vim.eval("sFileName"),
                "\ [GetCurUnsavedFile()], True)
    "py t.start()
    "return

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
    let sFileName = s:ToClangFileName(sFileName)
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
    let sFileName = s:ToClangFileName(sFileName)
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
    let sLine = getline('.')
    if matchstr(sLine, '^\s*#\s*include') !=# ''
        " 跳转到包含的文件
        if exists(':VLWOpenIncludeFile') == 2
            VLWOpenIncludeFile
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
function! s:InitPythonInterfaces() "{{{2
    if !s:bFirstInit
        return
    endif

    py import sys
    py import vim
    py sys.path.append(vim.eval("g:VIMCCC_PythonModulePath"))
    py sys.argv = [vim.eval("g:VIMCCC_ClangLibraryPath")]
    "silent! exec 'pyfile ' . s:VIMCCC_PythonModulePath . '/VIMClangCC.py'
    py from VIMClangCC import *
python << PYTHON_EOF

#import threading
#class UpdateQuickFixThread(threading.Thread):
#    def __init__(self, sFileName, lUnsavedFiles = [], bReparse = False):
#        threading.Thread.__init__(self)
#        self.sFileName = sFileName
#        self.lUnsavedFiles = lUnsavedFiles
#        self.bReparse = bReparse
#
#    def run(self):
#        global VIMCCCIndex
#        VIMCCCIndex.UpdateTranslationUnit(self.sFileName, self.lUnsavedFiles,
#                                          self.bReparse)
#        vim.command("call setqflist(%s)" 
#                    % VIMCCCIndex.GetVimQucikFixListFromRecentTU())

UF_None = 0
UF_Related = 1
UF_RelatedPrepend = 2

def GetCurUnsavedFile(nFlags = UF_None):
    '''
    nFlags:     控制一些特殊补全场合，例如在头文件补全'''
    sFileName = vim.eval("expand('%:p')")
    sClangFileName = vim.eval("s:ToClangFileName('%s')" % sFileName)

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

# 本插件只操作这个实例，其他事都不管
VIMCCCIndex = VIMClangCCIndex()
PYTHON_EOF
endfunction
"}}}

" vim: fdm=marker fen et sts=4 fdl=1
