" Vim's common async complete framework
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-12-13
" Change:   2013-12-13

" 基本使用说明:
"
" ============================================================================
" 这是最原始的接口, 理论上只要此接口即可用
" ============================================================================
" function! AsyncComplRegister(ignorecase, complete_pattern,
"         \                    valid_char_pattern, substring_pattern,
"         \                    trigger_char_count,
"         \                    SearchStartColumnHook, LaunchComplThreadHook,
"         \                    FetchComplResultHook)
" @ignorecase - 是否忽略大小写
" @complete_pattern - 匹配时直接启动补全
" @valid_char_pattern - 不匹配这个模式的时候, 直接忽略
" @substring_pattern - 在光标前的字符串中提取 base 用, 一般需要 '$' 结尾
" @trigger_char_count - 触发异步补全时, 光标前的最小要求的单词字符数
" @SearchStartColumnHook() - 搜索补全起始列号, 返回起始列号
" @LaunchComplThreadHook(row, col, base, icase, join = 0) - 无返回值
" @FetchComplResultHook(base) - 返回补全结果, 形如 [0|1, result]
"                               0表示未完成, 1表示完成, result可能为[]或{}
"
" @LaunchComplThreadHook 可使用通用的 CommonLaunchComplThread
" @FetchComplResultHook 可使用通用的 CommonFetchComplResult
"
" 对于Cxx, @SearchStartColumnHook 可使用 CxxSearchStartColumn
"
" ===== 一般流程 =====
" 1. 根据输入字符检查, 如不需要继续, 则直接返回
" 2. call SearchStartColumnHook()
" 3. call LaunchComplThreadHook()
" 4. hold定时器循环检查 FetchComplResultHook() 返回值, 直到返回结果为止(可为空结果)
" 
" ============================================================================
" 比原始接口更高层次的框架, 以下两个hook无须修改:
"   @LaunchComplThreadHook 使用 CommonLaunchComplThread
"   @FetchComplResultHook 使用 CommonFetchComplResult
" @SearchStartColumnHook 根据需要修改, 一般可直接用 CxxSearchStartColumn
" 最后只需要定义类似下列的python hook, 并注册即可
"   CommonCompleteHookRegister(CommonCompleteHook, data)
"   CommonCompleteArgsHookRegister(CommonCompleteArgsHook, data)
" NOTE: 这个函数是在后台线程运行, 绝不能在此函数内对vim进行操作
" ============================================================================
" 这个函数接受三个参数, 并最终返回补全结果
" def CommonCompleteHook(acthread, args, data)
" @acthread - AsyncComplThread 实例
" @args     - 参数, 是一个字典, 自动生成, CommonLaunchComplThread 定义的键值包括
"               'text':     '\n'.join(vim.current.buffer),
"               'file':     vim.eval('expand("%:p")'),
"               'row':      int(vim.eval('row')),
"               'col':      int(vim.eval('col')),
"               'base':     vim.eval('base'),
"               'icase':    int(vim.eval('icase'))}
" @data     - 注册的时候指定的参数
" @return   - 补全列表, 直接用于补全结果, 参考 complete-items
"
" 这个函数用于动态生成 CommonCompleteHook 的 args 字典参数, 若不使用的话, args
" 字典参数自动生成, 参考上面的说明
" def CommonCompleteArgsHook(data)
" @row      - 行
" @col      - 列
" @base     - 光标前关键词
" @icase    - 忽略大小写
" @data     - 注册的时候指定的参数
" @return   - args 字典, 参考上面的说明, 最终给予 CommonCompleteHook 使用

" 初始化每个缓冲区的变量
function! s:InitBuffVars() "{{{2
    if exists('b:config')
        return
    endif

    let b:config = {}
    let b:config.ignorecase = 0
    " 匹配这个模式的时候, 直接启动补全搜索线程
    let b:config.complete_pattern = '\.\|>\|:'
    " 非指定完成的字符串模式, 即如果输入字符不匹配这个字符串的时候, 忽略处理
    let b:config.valid_char_pattern = '[A-Za-z_0-9]'
    " 补全支持的子串模式
    let b:config.substring_pattern = '[A-Za-z_]\w*$'
    " 最小支持2, 为1的话可能有各种问题
    let b:config.trigger_char_count = 2
    let b:config.SearchStartColumnHook = function('empty')
    " 启动搜索线程, None (row, col, base, icase)
    let b:config.LaunchComplThreadHook = function('empty')
    " 获取结果的回调, [] (base)
    let b:config.FetchComplResultHook = function('empty')
    " 定时器机制使用, 超时时间, 单位毫秒
    let b:config.timer_timeout = 100
    " 补全菜单选择模式, 同vimccc的定义
    let b:config.item_select_mode = 2
endfunction
"}}}

" 保存状态信息, 如有键位映射的缓冲区等等
let s:status = {}
" bufnr: 1
let s:status.buffers = {}

" 补全结果, 理论上最好是每缓冲区变量,
" 但是考虑到复杂度和vim脚本的单线程特征, 直接用一个全局变量即可
let s:async_compl_result = {}

" Just For Debug
let s:compl_count = 0

" Just For Debug
function! asynccompl#ComplCount() "{{{2
    return s:compl_count
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
function! CxxSearchStartColumn() "{{{2
    let bInCC = 0
    let nRow = line('.')
    let nCol = col('.')
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

            if bInCC
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
" 获取异步补全状态数据结构
function! s:GetCSDict() "{{{2
    if !exists('b:aucm_prev_stat')
        let b:aucm_prev_stat =
            \ {'ccrow': 0, 'cccol': 0, 'base': '', 'pumvisible': 0, 'init': 0}
    endif
    return b:aucm_prev_stat
endfunction
"}}}
" 初始化
function! s:InitAucmPrevStat() "{{{2
    let aucm_prev_stat = s:UpdateAucmPrevStat(0, 0, '', 0)
    let aucm_prev_stat['init'] = 1
endfunction
"}}}
" 重置状态
function! s:ResetAucmPrevStat() "{{{2
    let aucm_prev_stat = s:UpdateAucmPrevStat(0, 0, '', 0)
    let aucm_prev_stat['init'] = 0
endfunction
"}}}
" 更新状态
function! s:UpdateAucmPrevStat(nRow, nCol, sBase, pumv) "{{{2
    let aucm_prev_stat = s:GetCSDict()
    let aucm_prev_stat['ccrow'] = a:nRow
    let aucm_prev_stat['cccol'] = a:nCol
    let aucm_prev_stat['base'] = a:sBase
    let aucm_prev_stat['pumvisible'] = a:pumv
    return aucm_prev_stat
endfunction
"}}}
" 这个函数名字要尽量短, 因为是用于 <C-r>= 的
function! CCByChar() "{{{2
    let aucm_prev_stat = s:GetCSDict()
    let row = aucm_prev_stat['ccrow']
    let col = aucm_prev_stat['cccol']
    let base = aucm_prev_stat['base']
    let icase = b:config.ignorecase
    " 启动线程
    call b:config.LaunchComplThreadHook(row, col, base, icase)
    " 启动定时器
    call AsyncComplTimer()
    return ''
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
function! CommonAsyncComplete() "{{{2
    if pumvisible() " 不重复触发
        return ''
    endif

    let sChar = v:char
    let icase = b:config.ignorecase

    " 处理无条件指定触发补全的输入, 如C++中的::, ->, .
    if !empty(b:config.complete_pattern) && sChar =~# b:config.complete_pattern
        let nRow = line('.')
        " +1的原因是, 要把即将输入的字符也算进去
        let nCol = col('.') + 1
        let sBase = ''
        " 更新状态
        call s:UpdateAucmPrevStat(nRow, nCol, sBase, pumvisible())
        " 因为现时的补全环境不完整(v:char还没有被插入), 所以如此实现
        call feedkeys("\<C-r>=CCByChar()\<CR>", 'n')
        return ''
    endif

    " 输入的字符不是有效的补全字符, 直接返回
    if sChar !~# b:config.valid_char_pattern
        " 需要清补全状态吧? 不需要, 只要 b:config.trigger_char_count > 1
        "call s:ResetAucmPrevStat()
        return ''
    endif

    "call vlutils#TimerStart()

    let nTriggerCharCount = b:config.trigger_char_count
    let nCol = col('.')
    let sLine = getline('.')
" ============================================================================
" 利用前状态和当前状态优化
    " 前状态
    let dPrevStat = s:GetCSDict()

    let sPrevWord = matchstr(sLine[: nCol-2], b:config.substring_pattern) . sChar
    if len(sPrevWord) < nTriggerCharCount
        " 如果之前补全过就重置状态
        if get(dPrevStat, 'cccol', 0) > 0
            call s:ResetAucmPrevStat()
        endif
        "call vlutils#TimerEnd()
        "call vlutils#TimerEndEcho()
        return ''
    endif

    " 获取当前状态
    let nRow = line('.')
    let nCol = b:config.SearchStartColumnHook()
    let sBase = getline('.')[nCol-1 : col('.')-2] . sChar

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
    let &ignorecase = icase
    if get(dPrevStat, 'ccrow', 0) == nRow
            \ && get(dPrevStat, 'cccol', 0) == nCol
            \ && len(sPrevWord) >= nTriggerCharCount
            \ && sBase =~ '^'.get(dPrevStat, 'base', '')
        call s:UpdateAucmPrevStat(nRow, nCol, sBase, pumvisible())
        let &ignorecase = save_ic
        "call vlutils#TimerEnd()
        "call vlutils#TimerEndEcho()
        return ''
    endif
    let &ignorecase = save_ic
" ============================================================================
    " ok，启动
    call b:config.LaunchComplThreadHook(nRow, nCol, sBase, icase)
    let s:compl_count += 1

    " 更新状态
    call s:UpdateAucmPrevStat(nRow, nCol, sBase, pumvisible())
    "call vlutils#TimerEnd()
    "call vlutils#TimerEndEcho()

" ============================================================================
" 定时器机制
    " NOTE: 如果使用定时器机制的话, 这里也需要检查补全结果, 
    "       不然在一直打字的情况下, 补全菜单无法弹出
    call AsyncComplTimer()
endfunction
"}}}
" 这个初始化是每个缓冲区都要调用一次的
function! asynccompl#Init() "{{{2
    call s:InitPyIf()
    call s:InitBuffVars()

    let output = vlutils#GetCmdOutput('autocmd CursorHoldI')
    let lines = split(output, '\n')
    if !empty(lines) && lines[-1] !=# '--- Auto-Commands ---'
        echohl WarningMsg
        echomsg "=== Warning by asynccompl ==="
        echomsg "There are other CursorHoldI autocmds in your Vim."
        echomsg "Asynccompl works with CursorHoldI autocmd,"
        echomsg "and will cause other CursorHoldI autocmds run frequently."
        echomsg "Please confirm by running ':autocmd CursorHoldI' or disable asynccompl."
        echomsg "Press any key to continue..."
        call getchar()
        echohl None
    endif

    let s:status.buffers[bufnr('%')] = 1
    augroup AsyncCompl
        autocmd! InsertCharPre  <buffer> call CommonAsyncComplete()
        autocmd! InsertEnter    <buffer> call s:AutocmdInsertEnter()
        autocmd! InsertLeave    <buffer> call s:AutocmdInsertLeave()
        " NOTE: 添加销毁python的每缓冲区变量的时机
        "       暂时不需要, 只要每缓冲区的变量都是先初始化再使用的话, 无须清理
    augroup END
    setlocal completefunc=asynccompl#Driver
endfunction
"}}}
function! s:AutocmdInsertEnter() "{{{2
    call s:InitAucmPrevStat()
    call holdtimer#DelTimerI('AsyncComplTimer')
endfunction
"}}}
function! s:AutocmdInsertLeave() "{{{2
    call s:ResetAucmPrevStat()
    call holdtimer#DelTimerI('AsyncComplTimer')
endfunction
"}}}
" 清理函数
function! asynccompl#Exit() "{{{2
    setlocal completefunc=
    augroup AsyncCompl
        for i in keys(s:status.buffers)
            exec printf('autocmd! InsertCharPre    <buffer=%d>', i)
            exec printf('autocmd! InsertEnter      <buffer=%d>', i)
            exec printf('autocmd! InsertLeave      <buffer=%d>', i)
        endfor
    augroup END
    call filter(s:status.buffers, 0)
endfunction
"}}}
function! s:Funcref(Func) "{{{2
    if type(a:Func) == type('')
        return function(a:Func)
    endif
    return a:Func
endfunction
"}}}
function! asynccompl#Register(ignorecase, complete_pattern,
        \                     valid_char_pattern, substring_pattern,
        \                     trigger_char_count,
        \                     SearchStartColumnHook, LaunchComplThreadHook,
        \                     FetchComplResultHook) "{{{2
    call s:InitBuffVars()
    let b:config.ignorecase = a:ignorecase
    let b:config.complete_pattern = a:complete_pattern
    let b:config.valid_char_pattern = a:valid_char_pattern
    let b:config.substring_pattern = a:substring_pattern
    let b:config.trigger_char_count = a:trigger_char_count
    let b:config.SearchStartColumnHook = s:Funcref(a:SearchStartColumnHook)
    let b:config.LaunchComplThreadHook = s:Funcref(a:LaunchComplThreadHook)
    let b:config.FetchComplResultHook = s:Funcref(a:FetchComplResultHook)
endfunction
"}}}
function! asynccompl#Driver(findstart, base) "{{{2
    if a:findstart
        let ret = b:config.SearchStartColumnHook()
        if ret != -1
            " NOTE: 需要-1才正确, 这个是一个BUG
            return ret - 1
        endif
        return ret
    endif

    " 处理同步请求
    if empty(s:async_compl_result)
        " 进入这里肯定是同步请求, 因为异步请求的时候, s:async_compl_result非空
        let row = line('.')
        let col = col('.')
        let base = a:base
        let icase = b:config.ignorecase
        call b:config.LaunchComplThreadHook(row, col, base, icase, 1)
        " 这里直接获取结果, 不用检查done了
        let [done, result] = b:config.FetchComplResultHook(base)
        return result
    endif

    " 清空 s:async_compl_result 是为了辨别同步请求补全还是异步请求补全
    let result = s:async_compl_result
    if type(s:async_compl_result) == type([])
        let s:async_compl_result = []
    else
        let s:async_compl_result = {}
    endif

    return result
endfunction
"}}}
" 临时启用选项函数
function! s:SetOpts() "{{{2
    let s:bak_cot = &completeopt
    let s:bak_lz = &lazyredraw

    "set lazyredraw

    let s:has_noexpand = 0

    if     b:config.item_select_mode == 0 " 不选择
        set completeopt-=menu,longest
        set completeopt+=menuone
    elseif b:config.item_select_mode == 1 " 选择并插入文本
        set completeopt-=menuone,longest
        set completeopt+=menu
    elseif b:config.item_select_mode == 2 " 选择但不插入文本
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
"}}}
" 还原临时选项函数
function s:RestoreOpts() "{{{2
    if exists('s:bak_cot') && exists('s:bak_lz')
        let &completeopt = s:bak_cot
        unlet s:bak_cot
        "let &lazyredraw = s:bak_lz
        unlet s:bak_lz
    else
        return ""
    endif

    let sRet = ""

    if pumvisible()
        if     b:config.item_select_mode == 0 " 不选择
            let sRet = "\<C-p>"
        elseif b:config.item_select_mode == 1 " 选择并插入文本
            let sRet = ""
        elseif b:config.item_select_mode == 2 " 选择但不插入文本
            if !s:has_noexpand
                let sRet = "\<C-p>\<Down>"
            endif
        else
            " 'completeopt' 有 longest
            let sRet = "\<Down>"
        endif
    endif

    return sRet
endfunction
"}}}
function! Acpre() "{{{2
    call s:SetOpts()
    return ''
endfunction
"}}}
function! Acpost() "{{{2
    return s:RestoreOpts()
endfunction
"}}}
" 定时器检查补全结果
function! AsyncComplTimer(...) "{{{2
    " ret: [0, {}|[]]
    " ret[0]: 0 - 还未得到结果, 1 - 已经得到结果
    " ret[1]: {}|[] 补全结果, 可能为空
    let ret = b:config.FetchComplResultHook(get(s:GetCSDict(), 'base', ''))
    let done = ret[0]
    let result = ret[1]

    if !done
        " 轮询结果, 需要重试次数?
        call holdtimer#AddTimerI('AsyncComplTimer', 0, b:config.timer_timeout)
        return
    endif

    " 结果为空的话, 就无须继续了
    if empty(result)
        return
    endif

    if type(result) != type(s:async_compl_result)
        unlet s:async_compl_result
    endif
    let s:async_compl_result = result
    " 有结果的时候, 弹出补全菜单
    let keys  = "\<C-r>=Acpre()\<CR>"
    let keys .= "\<C-x>\<C-u>"
    let keys .= "\<C-r>=Acpost()\<CR>"
    call feedkeys(keys, 'n')

    " NOTE: 这里可以更新状态以表示这一轮的补全已经完成, 不是太必要

    " 以防万一, 这里需要销毁定时器
    call holdtimer#DelTimerI('AsyncComplTimer')
endfunction
"}}}

let s:test_result = []
" 通用启动线程函数, 使用内置实现
function! CommonLaunchComplThread(row, col, base, icase, ...) "{{{2
    "let s:test_result = ['abc', 'def', 'ghi', 'jkl', 'mno', 'abc']

    let row = a:row
    let col = a:col
    let base = a:base
    let icase = a:icase
    let join = get(a:000, 0, 0)

    let custom_args = 0
    py if g_AsyncComplBVars.b.get('CommonCompleteArgsHook'):
            \ vim.command("let custom_args = 1")
    if custom_args
        py g_asynccompl.PushThreadAndStart(
            \ AsyncComplThread(
            \   g_AsyncComplBVars.b.get('CommonCompleteHook'),
            \   g_AsyncComplBVars.b.get('CommonCompleteArgsHook')(
            \       int(vim.eval('row')), int(vim.eval('col')),
            \       vim.eval('base'), int(vim.eval('icase')),
            \       g_AsyncComplBVars.b.get('CommonCompleteArgsHookData')),
            \   g_AsyncComplBVars.b.get('CommonCompleteHookData')))
    else
        " 默认情况下
        py g_asynccompl.PushThreadAndStart(
                \ AsyncComplThread(g_AsyncComplBVars.b.get('CommonCompleteHook'),
                \                  {'text': '\n'.join(vim.current.buffer),
                \                   'file': vim.eval('expand("%:p")'),
                \                   'row': int(vim.eval('row')),
                \                   'col': int(vim.eval('col')),
                \                   'base': vim.eval('base'),
                \                   'icase': int(vim.eval('icase'))},
                \                  g_AsyncComplBVars.b.get('CommonCompleteHookData')))
    endif

    if join
        " 有下列语句的话, 就是同步方式了
        py g_asynccompl.LatestThread().join()
    endif
endfunction
"}}}
" 通用获取补全结果函数, 使用内置实现
function! CommonFetchComplResult(base) "{{{2
    "return [1, s:test_result]

    py if not g_asynccompl.IsThreadDone():
        \ vim.command('return [0, {}]')

    " 补全完成了, 但是没有结果, 结束
    py if g_asynccompl.LatestThread().result is None:
        \ vim.command('return [1, {}]')

    " 到达这里表示已经有结果了
    py vim.command("let result = %s"
        \           % ToVimEval(g_asynccompl.LatestThread().result))
    let g:result = result
    return [1, result]
endfunction
"}}}

" Just For Debug
"let g:acconfig = b:config
"let g:acstatus = s:status
"let g:actest_result = s:test_result
"let g:acasync_compl_result = s:async_compl_result

let s:pyif_init = 0
function! s:InitPyIf() "{{{2
    if s:pyif_init
        return
    endif
    let s:pyif_init = 1
python << PYTHON_EOF
import re
import vim
import threading
import StringIO
import traceback

keyword_re = re.compile(r'\b\w{2,}\b')

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

def GetAllKeywords(s, kw_re = keyword_re):
    return kw_re.findall(s)

def GetCurBufKws(base = '', ignorecase = False, buffer = vim.current.buffer,
                 kw_re = keyword_re):
    if isinstance(buffer, str):
        li = GetAllKeywords(buffer, kw_re)
    else:
        li = GetAllKeywords('\n'.join(buffer), kw_re)
    if base:
        if ignorecase and base:
            pat = ''.join(["\\x%2x" % ord(c) for c in base])
            w = re.compile(pat, re.I)
            li = [i for i in li if w.match(i)]
        else:
            li = [i for i in li if i.startswith(base)]
    return li

class AsyncComplData(object):
    '''保持异步补全过程的一些数据结构'''
    def __init__(self):
        self.__lock = threading.Lock()
        # 最新触发的异步补全线程
        self.__thread = None

    def Lock(self):
        return self.__lock.acquire()

    def Unlock(self):
        return self.__lock.release()

    def LatestThread(self):
        return self.__thread

    def PushThread(self, thread):
        self.__thread = thread

    def IsThreadDone(self):
        if not self.__thread:
            return False
        return not self.__thread.is_alive()

    def IsThreadAlive(self):
        if self.__thread:
            return self.__thread.is_alive()
        return False

    def PushThreadAndStart(self, thread):
        self.Lock()
        self.PushThread(thread)
        self.Unlock()
        thread.start()

class AsyncComplThread(threading.Thread):
    # 自身锁, 不一定需要
    _lock = threading.Lock()

    def __init__(self, hook, args, data = None, parent = None):
        threading.Thread.__init__(self)
        self.hook = hook
        self.args = args # 这个参数是自动生成的
        self.data = data # 这个是注册时指定的
        self.result = None
        self.name = 'AsyncComplThread-' + self.name
        # 这个一般指向 AsyncComplData 实例, 用于和自身检查
        self.parent = parent

    def Lock(self):
        '''公共互斥锁'''
        AsyncComplThread._lock.acquire()

    def Unlock(self):
        '''公共互斥锁'''
        AsyncComplThread._lock.release()

    def run(self):
        try:
            if not self.hook:
                return

            result = self.hook(self, self.args, self.data)
            if result is None:
                return

            # 如果可以的话, 检查parent当前指向的最新的线程是否自己
            # 如果不是的话, 就没必要继续了
            if self.parent:
                brk = True
                self.parent.Lock()
                if self.parent.LatestThread() is self:
                    brk = False
                self.parent.Unlock()
                if brk:
                    return

            self.result = result

            # 可以的话, 这里异步通知
            # 暂时用定时器实现了

        except:
            # 把异常信息显示给用户
            sio = StringIO.StringIO()
            print >> sio, "Exception in user code:"
            print >> sio, '-' * 60
            traceback.print_exc(file=sio)
            print >> sio, '-' * 60
            errmsg = sio.getvalue()
            sio.close()
            #print errmsg

class BufferVariables(object):
    '''python模拟vim的 b: 变量'''
    def __init__(self):
        # {bufnr: {varname: varvalue, ...}, ...}
        self.buffvars = {}

    @property
    def b(self):
        bufnr = int(vim.eval('bufnr("%")'))
        if not self.buffvars.has_key(bufnr):
            self.buffvars[bufnr] = {}
        return self.buffvars.get(bufnr)

    def _Destroy(self, bufnr = int(vim.eval('bufnr("%")'))):
        '''删除指定缓冲区的所有变量'''
        if self.buffvars.has_key(bufnr):
            del self.buffvars[bufnr]

# 全局变量
g_AsyncComplBVars = BufferVariables()

# 通用补全hook注册, 外知的接口
def CommonCompleteHookRegister(hook, data):
    global g_AsyncComplBVars
    g_AsyncComplBVars.b['CommonCompleteHook'] = hook
    g_AsyncComplBVars.b['CommonCompleteHookData'] = data

# 通用补全hook注册, 外知的接口
def CommonCompleteArgsHookRegister(hook, data):
    global g_AsyncComplBVars
    g_AsyncComplBVars.b['CommonCompleteArgsHook'] = hook
    g_AsyncComplBVars.b['CommonCompleteArgsHookData'] = data

# 本模块持有的全局变量, 保存最新的补全线程的信息
g_asynccompl = AsyncComplData()
PYTHON_EOF
endfunction
"}}}
function! s:ThisInit() "{{{2
    call s:InitPyIf()
endfunction
"}}}

" 公共设施初始化
call s:ThisInit()
" vim: fdm=marker fen et sw=4 sts=4 fdl=1
