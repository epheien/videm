" Vim's common async complete framework
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-12-13
" Change:   2013-12-15

" 基本使用说明:
"
" ============================================================================
" 这是最原始的接口, 理论上只要此接口即可用
" ============================================================================
" function! asynccompl#Register(config)
" @config = {}
" @config.ignorecase                : 参考 'ignorecase', default &ignorecase
" @config.smartcase                 : 参考 'smartcase',  default &smartcase
" @config.manu_popup_pattern        : 匹配时无条件直接启动补全, default ''
" @config.auto_popup_pattern        : 不匹配这个模式的时直接忽略
" @config.auto_popup_base_pattern   : 自动弹出补全时需要提取的字串模式
" @config.auto_popup_char_count     : 触发异步补全时, 光标前的最小要求的单词字符数,
"                                     最小 2, default 2
" @config.item_select_mode          : 参考 omnicxx 相关说明, default 2
" @config.omnifunc                  : 0 - &completefunc, 1 - &omnifunc, default 0
" @config.bufnr                     : default -1
"
" @config.ManualPopupCheck          : (char) - 返回 0 表示终止, 否则表示继续
"                                     只有 manu_popup_pattern 非空时才有用
" @config.SearchStartColumnHook     : (void) - 搜索补全起始列号, 返回起始列号
" @config.LaunchComplThreadHook     : (row, col, base, icase, scase, join=0) - 无返回值
" @config.FetchComplResultHook      : (base) - 返回补全结果, 形如 [0|1, result]
"                                     0表示未完成, 1表示完成, result可能为[]或{}
"
" LaunchComplThreadHook 可使用通用的 CommonLaunchComplThread
" FetchComplResultHook  可使用通用的 CommonFetchComplResult
"
" 对于Cxx, SearchStartColumnHook 可使用 CxxSearchStartColumn
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
"   CommonCompleteHookRegister(CommonCompleteHook, priv)
"   CommonCompleteArgsHookRegister(CommonCompleteArgsHook, priv)
" NOTE: 这个函数是在后台线程运行, 绝不能在此函数内对vim进行操作
" ============================================================================
" 这个函数接受三个参数, 并最终返回补全结果
" def CommonCompleteHook(acthread, args)
" @acthread - AsyncComplThread 实例
" @args     - 参数, 是一个字典, 自动生成, CommonLaunchComplThread 定义的键值包括
"   'text'  : '\n'.join(vim.current.buffer)
"   'file'  : vim.eval('expand("%:p")')
"   'row'   : int(vim.eval('row'))
"   'col'   : int(vim.eval('col'))
"   'base'  : vim.eval('base')
"   'icase' : int(vim.eval('icase'))
"   'scase' : int(vim.eval('scase'))
"   'priv'  : 注册的时候指定的参数
" @return   - 补全列表, 直接用于补全结果, 参考 complete-items
"
" 这个函数用于动态生成 CommonCompleteHook 的 args 字典参数, 若不使用的话, args
" 字典参数自动生成, 参考上面的说明
" def CommonCompleteArgsHook(args)
" @args     - 字典, 至少包含以下键值
"   'row'   : 行
"   'col'   : 列
"   'base'  : 光标前关键词
"   'icase' : 忽略大小写
"   'scase' : smartcase
"   'priv'  : 注册的时候指定的参数
" @return   - args 字典, 参考上面的说明, 最终给予 CommonCompleteHook 使用

" 初始化每缓冲区的变量
" 无参数或<=0 - 初始化当前缓冲区，> 0 初始化指定缓冲区
" 这个函数是内部的，参数设计可以简单化
function! s:InitBuffVars(...) "{{{2
    let bufnr = get(a:000, 0, 0)
    if bufnr <= 0
        let bufnr = bufnr('%')
    endif

    let bufvar = getbufvar(bufnr, 'config')
    if !empty(bufvar)
        " 已经初始化过了
        return
    endif

    let config = {}
    let config.ignorecase = &ignorecase
    let config.smartcase = &smartcase
    let config.manu_popup_pattern = ''
    let config.auto_popup_pattern = '[A-Za-z_0-9]'
    let config.auto_popup_base_pattern = '[A-Za-z_]\w*$'
    let config.auto_popup_char_count = 2
    let config.item_select_mode = 2
    let config.omnifunc = 0
    let config.bufnr = bufnr

    let config.ManualPopupCheck = function('empty')
    let config.SearchStartColumnHook = function('empty')
    let config.LaunchComplThreadHook = function('empty')
    let config.FetchComplResultHook = function('empty')

    " 定时器机制使用, 超时时间, 单位毫秒
    let config.timer_timeout = 100

    call setbufvar(bufnr, 'config', config)
endfunction
"}}}

" 保存状态信息, 如有键位映射的缓冲区等等
let s:status = {}
" bufnr: 1
let s:status.buffers = {}

" 补全结果, 理论上最好是每缓冲区变量,
" 但是考虑到复杂度和vim脚本的单线程特征, 直接用一个全局变量即可
let s:async_compl_result = []

" 最近一次的补全结果, 有各种用途
let s:latest_compl_result = []

" Just For Debug
let s:compl_count = 0

" 实现方式: 1.定时器; 2.clientserver. 默认使用定时器实现方式
let s:timer_mode = 1

" 异步请求ID
let s:async_compl_ident = -1

let s:has_noexpand = 0

" 载入自身
function! asynccompl#Init() "{{{2
    return 0
endfunction
"}}}

" Just For Debug
function! asynccompl#ComplCount() "{{{2
    return s:compl_count
endfunction
"}}}
function! asynccompl#IsTimerMode() "{{{2
    return s:timer_mode
endfunction
"}}}
" 这个是返回当前环境的标识结构, 字典
function! asynccompl#CurrentIdent() "{{{2
    let d = {}
    let d['mode'] = mode()
    let d['buff'] = bufnr('%')
    let d['acid'] = s:async_compl_ident
    return d
endfunction
"}}}
" 返回Ident标识, 数字
function! s:GetAsyncComplIdent() "{{{2
    let s:async_compl_ident += 1
    if s:async_compl_ident >= 10000
        let s:async_compl_ident = 0
    endif
    return s:async_compl_ident
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
function! s:GetCSDict(...) "{{{2
    let bufnr = get(a:000, 0, -1)
    if bufnr <= 0
        let bufnr = bufnr('%')
    endif

    if empty(getbufvar(bufnr, 'aucm_prev_stat'))
        " 不存在变量就新建
        let aucm_prev_stat =
            \ {'ccrow': 0, 'cccol': 0, 'base': '', 'pumvisible': 0, 'init': 0}
        call setbufvar(bufnr, 'aucm_prev_stat', aucm_prev_stat)
    else
        " 存在变量就直接返回
        let aucm_prev_stat = getbufvar(bufnr, 'aucm_prev_stat')
    endif
    return aucm_prev_stat
endfunction
"}}}
function! asynccompl#GetStat(...) "{{{2
    return s:GetCSDict(get(a:000, 0, -1))
endfunction
"}}}
function! asynccompl#StatSimilar(s0, s1, ...) "{{{2
    let icase = get(a:000, 0, &ignorecase)
    return s:ComplStateSimilar(a:s0, a:s1, icase)
endfunction
"}}}
" 返回0表示状态不同, 需要启动新的补全, 否则返回非0
" s0 表示旧的状态, s1 表示新的状态
function! s:ComplStateSimilar(s0, s1, ...) "{{{2
    let s0 = a:s0
    let s1 = a:s1
    let icase = get(a:000, 0, &ignorecase)

    let ret = 0

    " 补全起始位置一样就不需要再次启动了
    " 1. 起始行和上次相同
    " 2. 起始列和上次相同
    " 3. 上次的 base 是光标前的字符串的前缀
    " 1 && 2 && 3 则忽略请求
    let save_ic = &ignorecase
    let &ignorecase = icase
    if get(s1, 'ccrow') == get(s0, 'ccrow')
            \ && get(s1, 'cccol') == get(s0, 'cccol')
            \ && get(s1, 'base', '') =~ '^'.get(s0, 'base', '')
        let ret = 1
    endif
    let &ignorecase = save_ic

    return ret
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
    let scase = b:config.smartcase
    " 启动线程
    call b:config.LaunchComplThreadHook(row, col, base, icase, scase)
    " 启动定时器
    call AsyncComplTimer()
    return ''
endfunction
"}}}
" 填充补全结果
function! asynccompl#FillResult(result) "{{{2
    let result = a:result
    let s:async_compl_result = result
    let s:latest_compl_result = result
endfunction
"}}}
" 弹出补全结果
function! asynccompl#PopResult() "{{{2
    " 清空 s:async_compl_result 是为了辨别同步请求补全还是异步请求补全
    let result = s:async_compl_result
    let s:async_compl_result = []
    return result
endfunction
"}}}
function! asynccompl#GetLatestResult() "{{{2
    return s:latest_compl_result
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
    let sChar = v:char
    let icase = b:config.ignorecase
    let scase = b:config.smartcase

    " 处理无条件指定触发补全的输入, 如C++中的::, ->, .
    if !empty(b:config.manu_popup_pattern) && sChar =~# b:config.manu_popup_pattern
        if !b:config.ManualPopupCheck(sChar)
            call s:ResetAucmPrevStat()
            return ''
        endif
        " 补全完毕后, 菜单没有消失, 这是来一个无条件补全, 需要把补全菜单干掉
        " clientserver模式下无此问题, 看起来是vim的BUG
        if s:timer_mode && pumvisible()
            " NOTE: 只要 v:char 不是 <C-?> 和 s 就没问题, <C-x>s 是拼写建议
            "call feedkeys("\<C-x>", "n")
            " NOTE: 这是另一种没有副作用的方案, 比较曲线, 可用
            call feedkeys("\<C-x>\<BS>".sChar)
            " 会再次进入这里, 所以这里直接返回, 方案二专用
            return ''
        endif

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

    " 不重复触发
    if pumvisible()
        return ''
    endif

    " 输入的字符不是有效的补全字符, 直接返回
    if sChar !~# b:config.auto_popup_pattern
        " 需要清补全状态, 因为在获取到结果的时候, 需要跟这个状态比较
        call s:ResetAucmPrevStat()
        return ''
    endif

    "call vlutils#TimerStart()

    let nRow = line('.')
    let nCol = col('.')
    let sLine = getline('.')
" ============================================================================
" 利用前状态和当前状态优化
    " 前状态
    let dPrevStat = s:GetCSDict()

    if nCol < 2
        " 光标在第一列打了一个字符
        let sPrevWord = sChar
    else
        let sPrevWord = matchstr(sLine[: nCol-2],
                \                b:config.auto_popup_base_pattern) . sChar
    endif
    if len(sPrevWord) < b:config.auto_popup_char_count
        " 重置状态
        call s:ResetAucmPrevStat()
        "call vlutils#TimerEnd()
        "call vlutils#TimerEndEcho()
        return ''
    endif

    " complete start column
    let scol = b:config.SearchStartColumnHook()

    " 现在的需求都是 sBase = sPrevWord
    let sBase = sPrevWord

    if s:ComplStateSimilar(dPrevStat,
            \              {'ccrow': nRow, 'cccol': scol, 'base': sBase},
            \              icase)
        " 状态相近, 无须继续
        call s:UpdateAucmPrevStat(nRow, scol, sBase, pumvisible())
        "call vlutils#TimerEnd()
        "call vlutils#TimerEndEcho()
        return ''
    endif
" ============================================================================
    " ok，启动
    call b:config.LaunchComplThreadHook(nRow, scol, sBase, icase, scase)
    let s:compl_count += 1

    " 更新状态
    call s:UpdateAucmPrevStat(nRow, scol, sBase, pumvisible())
    "call vlutils#TimerEnd()
    "call vlutils#TimerEndEcho()

" ============================================================================
    if s:timer_mode
    " 定时器机制
        " NOTE: 如果使用定时器机制的话, 这里也需要检查补全结果, 
        "       不然在一直打字的情况下, 补全菜单无法弹出
        call AsyncComplTimer()
    endif

    return ''
endfunction
"}}}
" 主动停止所有后台正在异步(挤压)的线程
" 现时没有主动停止的机制, 但是由于所有的异步回调都检查了补全状态才继续,
" 所以没问题, 主动停止机制可以用作优化, 并且只有在定期器模式才有优化效果
function! s:StopAsyncComplete() "{{{2
    if s:timer_mode
        call holdtimer#DelTimerI('AsyncComplTimer')
    else
        " NOTE: clientserver模式无太大的优化效果, 忽略即可
    endif
endfunction
"}}}
function! asynccompl#Dump()
    echo s:status
endfunction
" 这个初始化是每个缓冲区都要调用一次的
" 无参数或<=0表示仅处理本缓冲区，其他正数值表示指定的缓冲区
function! asynccompl#BuffInit(...) "{{{2
    let bufnr = get(a:000, 0, -1)
    if bufnr <= 0
        let bufnr = bufnr('%')
    endif

    " 防止重复初始化
    if has_key(s:status.buffers, bufnr)
        return 0
    endif

    if !exists('##InsertCharPre')
        echohl ErrorMsg
        echomsg 'Vim does not support InsertCharPre autocmd, so asynccompl can not work'
        echomsg 'Please update your Vim to version 7.3.196 or later'
        echohl None
        return -1
    endif

    call s:InitPyIf()

    if !empty(v:servername)
        " 有clientserver支持的话就不用定时器模式了
        let s:timer_mode = 0
    endif

    if s:timer_mode
        "let output = vlutils#GetCmdOutput('autocmd CursorHoldI')
        "let lines = split(output, '\n')
        "if !empty(lines) && lines[-1] !=# '--- Auto-Commands ---'
        if exists('#CursorHoldI')
            echohl WarningMsg
            echomsg "=== Warning by asynccompl ==="
            echomsg "There are other CursorHoldI autocmds in your Vim."
            echomsg "Asynccompl works with CursorHoldI autocmd,"
            echomsg "and will cause other CursorHoldI autocmds run frequently."
            echomsg "Please confirm by running ':autocmd CursorHoldI' ".
                    \   "or disable asynccompl."
            echomsg "Press any key to continue..."
            call getchar()
            echohl None
        endif
    else
        " 初始化CS模式的基础设施
        call asyncpy#Init()
        call s:InitCsPyif()
    endif

    call s:InitBuffVars(bufnr)
    let s:status.buffers[bufnr] = 1
    augroup AsyncCompl
        exec 'autocmd! InsertCharPre <buffer='.bufnr.'> call CommonAsyncComplete()'
        exec 'autocmd! InsertEnter   <buffer='.bufnr.'> call s:AutocmdInsertEnter()'
        exec 'autocmd! InsertLeave   <buffer='.bufnr.'> call s:AutocmdInsertLeave()'
        exec 'autocmd! BufUnload     <buffer='.bufnr.'> call s:AutocmdBufUnload()'
        " NOTE: 添加销毁python的每缓冲区变量的时机
        "       暂时不需要, 只要每缓冲区的变量都是先初始化再使用的话, 无须清理
    augroup END
    if s:timer_mode
        if b:config.omnifunc
            call setbufvar(bufnr, '&omnifunc', 'asynccompl#Driver')
        else
            call setbufvar(bufnr, '&completefunc', 'asynccompl#Driver')
        endif
    else
        if b:config.omnifunc
            call setbufvar(bufnr, '&omnifunc', 'asynccompl#CSDriver')
        else
            call setbufvar(bufnr, '&completefunc', 'asynccompl#CSDriver')
        endif
    endif
endfunction
"}}}
function! s:AutocmdInsertEnter() "{{{2
    call s:InitAucmPrevStat()
    if s:timer_mode
        call holdtimer#DelTimerI('AsyncComplTimer')
    endif
endfunction
"}}}
function! s:AutocmdInsertLeave() "{{{2
    call s:ResetAucmPrevStat()
    if s:timer_mode
        call holdtimer#DelTimerI('AsyncComplTimer')
    endif
endfunction
"}}}
function! s:AutocmdBufUnload() "{{{2
    call s:AutocmdInsertLeave()
    " NOTE: 对于 BufUnload 事件, 执行 :bw 时, bufnr('%') != expand('<abuf>')
    "       实测(7.3.923), bufnr('%') 为轮换的缓冲区, expand('<abuf>') 才正确
    "call asynccompl#BuffExit(bufnr('%'))
    call asynccompl#BuffExit(str2nr(expand('<abuf>')))
endfunction
"}}}
" 清理函数
" 无参数表示仅处理本缓冲区，0 - 表示处理全部缓冲区，其他正数值表示指定的缓冲区
" 由于是清理函数，所以参数处理比较复杂，可以理解
function! asynccompl#BuffExit(...) "{{{2
    let bufnr = get(a:000, 0, -1)
    if bufnr < 0
        let bufs = [bufnr('%')]
    elseif bufnr == 0
        " 字典的键总是字符串类型的
        let bufs = map(keys(s:status.buffers), 'str2nr(v:val)')
    else
        let bufs = [bufnr]
    endif

    for bufnr in bufs
        exec printf('autocmd! AsyncCompl InsertCharPre    <buffer=%d>', bufnr)
        exec printf('autocmd! AsyncCompl InsertEnter      <buffer=%d>', bufnr)
        exec printf('autocmd! AsyncCompl InsertLeave      <buffer=%d>', bufnr)
        exec printf('autocmd! AsyncCompl BufUnload        <buffer=%d>', bufnr)

        " NOTE: :bd 之后, 局部于缓冲区的选项会被重置, 但是自动命令不会被重置
        if !bufexists(bufnr)
            continue
        endif

        if getbufvar(bufnr, 'config')['omnifunc']
            call setbufvar(bufnr, '&omnifunc', '')
        else
            call setbufvar(bufnr, '&completefunc', '')
        endif
    endfor
    call filter(s:status.buffers, 'index(bufs, str2nr(v:key)) == -1')
endfunction
"}}}
function! s:Funcref(Func) "{{{2
    if type(a:Func) == type('')
        return function(a:Func)
    endif
    return a:Func
endfunction
"}}}
function! asynccompl#Register(config) "{{{2
    " NOTE: 这个变量是基础, 需要首先获取和初始化
    let bufnr = get(a:config, "bufnr", 0)
    if bufnr <= 0
        let bufnr = bufnr('%')
    endif

    call s:InitBuffVars(bufnr)
    let config = getbufvar(bufnr, 'config')
    let config.ignorecase = get(a:config, 'ignorecase', &ignorecase)
    let config.smartcase = get(a:config, 'smartcase', &smartcase)
    let config.manu_popup_pattern = get(a:config, 'manu_popup_pattern', '')
    let config.auto_popup_pattern = get(a:config, 'auto_popup_pattern', '[A-Za-z_0-9]')
    let config.auto_popup_base_pattern = get(a:config, 'auto_popup_base_pattern', '[A-Za-z_]\w*$')
    let config.auto_popup_char_count = get(a:config, 'auto_popup_char_count', 2)
    let config.item_select_mode = get(a:config, 'item_select_mode', 2)
    let config.omnifunc = get(a:config, 'omnifunc', 0)
    let config.bufnr = bufnr

    let config.ManualPopupCheck = s:Funcref(
            \   get(a:config, 'ManualPopupCheck', 'len'))
    let config.SearchStartColumnHook = s:Funcref(
            \   get(a:config, 'SearchStartColumnHook', 'CommonSearchStartColumn'))
    let config.LaunchComplThreadHook = s:Funcref(
            \   get(a:config, 'LaunchComplThreadHook', 'CommonLaunchComplThread'))
    let config.FetchComplResultHook = s:Funcref(
            \   get(a:config, 'FetchComplResultHook', 'CommonFetchComplResult'))

    " 修正不正确的选项
    if config.auto_popup_char_count < 2
        let config.auto_popup_char_count =2
    endif
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

    " 清空 s:async_compl_result 是为了辨别同步请求补全还是异步请求补全
    let result = asynccompl#PopResult()

    " 处理同步请求
    if empty(result)
        " 进入这里肯定是同步请求, 因为异步请求的时候, result非空
        let row = line('.')
        let col = col('.')
        let base = a:base
        let icase = b:config.ignorecase
        let scase = b:config.smartcase
        " 为了一致性, 这里需要更新状态
        call s:UpdateAucmPrevStat(row, col, base, pumvisible())
        call b:config.LaunchComplThreadHook(row, col, base, icase, scase, 1)

        " 没有定时器帮忙取结果, 所以只能自己取结果
        " 这里直接获取结果, 不用检查done了
        let [done, result] = b:config.FetchComplResultHook(base)
    endif

    return result
endfunction
"}}}
function! asynccompl#CSDriver(findstart, base) "{{{2
    if a:findstart
        let ret = b:config.SearchStartColumnHook()
        if ret != -1
            " NOTE: 需要-1才正确, 这个是一个BUG
            return ret - 1
        endif
        return ret
    endif

    " 清空 s:async_compl_result 是为了辨别同步请求补全还是异步请求补全
    let result = asynccompl#PopResult()

    " 处理同步请求
    if empty(result)
        " 进入这里肯定是同步请求, 因为异步请求的时候, result非空
        let row = line('.')
        let col = col('.')
        let base = a:base
        let icase = b:config.ignorecase
        let scase = b:config.smartcase
        call s:UpdateAucmPrevStat(row, col, base, pumvisible())
        call b:config.LaunchComplThreadHook(row, col, base, icase, scase, 1)

        " 再取一次结果
        let result = asynccompl#PopResult()
    endif

    return result
endfunction
"}}}
" 临时启用选项函数
function! s:SetOpts() "{{{2
    let s:bak_cot = &completeopt
    let s:bak_lz = &lazyredraw

    "set lazyredraw

    if     b:config.item_select_mode == 0 " 不选择
        set completeopt-=menu
        set completeopt-=longest
        set completeopt+=menuone
    elseif b:config.item_select_mode == 1 " 选择并插入文本
        set completeopt-=menuone
        set completeopt-=longest
        set completeopt+=menu
    elseif b:config.item_select_mode == 2 " 选择但不插入文本
        if s:has_noexpand
            " 支持 noexpand 就最好了
            set completeopt+=noexpand
        endif
        set completeopt-=menu
        set completeopt-=longest
        set completeopt+=menuone
    else
        set completeopt-=menu
        set completeopt+=menuone,longest
    endif

    return ''
endfunction
"}}}
" 还原临时选项函数
function! s:RestoreOpts() "{{{2
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
    " NOTE: 不用使用 feedkeys()，因为 "\<C-r>=Acpost()\<Cr>"
    "       后有个时间窗口，可能有了其他的输入，所以这里必须直接返回输入，
    "       唯一存在的问题是返回的字符可能被重映射了
    return s:RestoreOpts()
endfunction
"}}}
" 定时器检查补全结果
function! AsyncComplTimer(...) "{{{2
    " 防止调用错误
    if !s:timer_mode
        return
    endif

    " ret: [0, []]
    " ret[0]: 0 - 还未得到结果, 1 - 已经得到结果
    " ret[1]: [] 补全结果, 可能为空
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

    call asynccompl#FillResult(result)
    " 有结果的时候, 弹出补全菜单
    let keys  = "\<C-r>=Acpre()\<CR>"
    if b:config.omnifunc
        let keys .= "\<C-x>\<C-o>"
    else
        let keys .= "\<C-x>\<C-u>"
    endif
    let keys .= "\<C-r>=Acpost()\<CR>"
    call feedkeys(keys, 'n')

    " NOTE: 这里可以更新状态以表示这一轮的补全已经完成, 不是太必要

    " 以防万一, 这里需要销毁定时器
    call holdtimer#DelTimerI('AsyncComplTimer')
endfunction
"}}}

let s:test_result = []
" 通用启动线程函数, 使用内置实现
function! CommonLaunchComplThread(row, col, base, icase, scase, ...) "{{{2
    "let s:test_result = ['abc', 'def', 'ghi', 'jkl', 'mno', 'abc']

    let row = a:row
    let col = a:col
    let base = a:base
    let icase = a:icase
    let scase = a:scase
    let join = get(a:000, 0, 0)

    let custom_args = 0
    py if g_AsyncComplBVars.b.get('CommonCompleteArgsHook'):
            \ vim.command("let custom_args = 1")

    if s:timer_mode
        if custom_args
            py g_asynccompl.PushThreadAndStart(
                \   AsyncComplThread(
                \       g_AsyncComplBVars.b.get('CommonCompleteHook'),
                \       g_AsyncComplBVars.b.get('CommonCompleteArgsHook')(
                \           {
                \               'row'   : int(vim.eval('row')),
                \               'col'   : int(vim.eval('col')),
                \               'base'  : vim.eval('base'),
                \               'icase' : int(vim.eval('icase')),
                \               'scase' : int(vim.eval('scase')),
                \               'priv'  : g_AsyncComplBVars.b.get('CommonCompleteArgsHookData'),
                \           }
                \       ),
                \       g_AsyncComplBVars.b.get('CommonCompleteHookData')
                \   )
                \ )
        else
            " 默认情况下
            py g_asynccompl.PushThreadAndStart(
                \   AsyncComplThread(
                \       g_AsyncComplBVars.b.get('CommonCompleteHook'),
                \       {
                \           'text': '\n'.join(vim.current.buffer),
                \           'file': vim.eval('expand("%:p")'),
                \           'row': int(vim.eval('row')),
                \           'col': int(vim.eval('col')),
                \           'base': vim.eval('base'),
                \           'icase': int(vim.eval('icase')),
                \           'scase': int(vim.eval('scase')),
                \       },
                \       g_AsyncComplBVars.b.get('CommonCompleteHookData')
                \   )
                \ )
        endif

        if join
            py g_asynccompl.Join()
        endif
    else
    " clientserver模式下的处理
        " 这个状态从参数新建
        let stat = {'ccrow': row, 'cccol': col, 'base': base}
        " 启动异步补全线程
        if custom_args
            py g_asynccompl.PushThread(
                \   AsyncPython(
                \       AsyncCompl_AsyncHook,
                \       {
                \           'hook': g_AsyncComplBVars.b.get('CommonCompleteHook'),
                \           'args': g_AsyncComplBVars.b.get('CommonCompleteArgsHook')(
                \               {
                \                   'row'   : int(vim.eval('row')),
                \                   'col'   : int(vim.eval('col')),
                \                   'base'  : vim.eval('base'),
                \                   'icase' : int(vim.eval('icase')),
                \                   'scase' : int(vim.eval('scase')),
                \                   'priv'  : g_AsyncComplBVars.b.get('CommonCompleteArgsHookData'),
                \               }),
                \           'data': g_AsyncComplBVars.b.get('CommonCompleteHookData'),
                \       },
                \
                \       AsyncCompl_Callback,
                \       {
                \           'stat': vim.eval("stat"),
                \           'join': int(vim.eval('join')),
                \           'icase': int(vim.eval('icase')),
                \           'bufnr': int(vim.eval('bufnr("%")')),
                \       }
                \   )
                \ )
        else
            py g_asynccompl.PushThread(
                \   AsyncPython(
                \       AsyncCompl_AsyncHook,
                \       {
                \           'hook': g_AsyncComplBVars.b.get('CommonCompleteHook'),
                \           'args': {
                \               'text' : '\n'.join(vim.current.buffer),
                \               'file' : vim.eval('expand("%:p")'),
                \               'row'  : int(vim.eval('row')),
                \               'col'  : int(vim.eval('col')),
                \               'base' : vim.eval('base'),
                \               'icase': int(vim.eval('icase')),
                \               'scase': int(vim.eval('scase')),
                \           },
                \           'data': g_AsyncComplBVars.b.get('CommonCompleteHookData'),
                \       },
                \
                \       AsyncCompl_Callback,
                \       {
                \           'stat': vim.eval("stat"),
                \           'join': int(vim.eval('join')),
                \           'icase': int(vim.eval('icase')),
                \           'bufnr': int(vim.eval('bufnr("%")')),
                \       }
                \   )
                \ )
        endif

        if join
            call asynccompl#JoinLatestThread()
        endif
    endif
endfunction
"}}}
" 通用补全开始位置搜索函数
function! CommonSearchStartColumn() "{{{2
    let row = line('.')
    let col = col('.')

    " 光标在第一列, 不能补全
    if col <= 1
        return -1
    endif

    let cursor_prechar = getline('.')[col-2 : col-2]

    " 光标前的字符不是关键字, 不能补全
    if cursor_prechar !~# '\k'
        return -1
    endif

    " NOTE: 光标下的字符应该不算在内
    let [srow, scol] = searchpos('\<\k', 'bn', row)

    let start_column = scol

    return start_column
endfunction
"}}}
" 通用获取补全结果函数, 使用内置实现
function! CommonFetchComplResult(base) "{{{2
    "return [1, s:test_result]

    " 根据当前补全状态可知, 当前无等待补全结果的需求, 直接返回即可
    let stat = s:GetCSDict()
    if get(stat, 'ccrow') == 0
        return [1, {}]
    endif


    py if not g_asynccompl.IsThreadDone():
        \ vim.command('return [0, {}]')

    " 补全完成了, 但是没有结果, 结束
    py if g_asynccompl.LatestThread().result is None:
        \ vim.command('return [1, {}]')

    " 补全完成了, 也有结果, 但是这个结果不一定是现在需要的, 需要检查
    py vim.command("let row = %d" % g_asynccompl.LatestThread().args.get('row', 0))
    py vim.command("let col = %d" % g_asynccompl.LatestThread().args.get('col', 0))
    py vim.command("let icase = %d" % g_asynccompl.LatestThread().args.get('icase', 0))
    py vim.command("let base = %s" % ToVimEval(
            \           g_asynccompl.LatestThread().args.get('base', '')))
    " NOTE: stat 的状态是最新的, 这个顺序很重要!
    if !s:ComplStateSimilar({'ccrow': row, 'cccol': col, 'base': base}, stat,
            \               icase)
        " 这个补全不是现在所需要的, 直接结束
        return [1, {}]
    endif

    " 到达这里表示已经有结果了
    py vim.command("let result = %s"
            \      % ToVimEval(g_asynccompl.LatestThread().result))
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
    let s:__temp = &completeopt
    let s:has_noexpand = 1
    try
        set completeopt+=noexpand
    catch /.*/
        let s:has_noexpand = 0
    endtry
    let &completeopt = s:__temp
    unlet s:__temp
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

def GetCurBufKws(base = '', ignorecase = False, smartcase = False,
                 buffer = vim.current.buffer, kw_re = keyword_re):
    if isinstance(buffer, str):
        li = GetAllKeywords(buffer, kw_re)
    else:
        li = GetAllKeywords('\n'.join(buffer), kw_re)
    if base:
        if smartcase and re.search('[A-Z]', base):
            ignorecase = False
        if ignorecase:
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

    def Join(self, timeout = None):
        '''如果有线程的话, 等待它完成'''
        if self.__thread:
            return self.__thread.join(timeout)

    def JoinS(self):
        '''循环忙等, 这是为了在clientserver模式下不死锁'''
        if not self.__thread:
            return
        while True:
            self.__thread.join(0.1)
            if not self.__thread.is_alive():
                return

class AsyncComplThread(threading.Thread):
    # 自身锁, 公用, 不一定需要
    _lock = threading.Lock()

    def __init__(self, hook, args, data = None, parent = None):
        threading.Thread.__init__(self)
        self.hook = hook
        self.args = args # 这个参数是自动生成的
        #self.data = data # 这个是注册时指定的
        # 把 data 合并进 args
        self.args['priv'] = data
        self.result = None
        self.name = 'AsyncComplThread-' + self.name
        # 这个一般指向 AsyncComplData 实例, 用于和自身检查
        self.parent = parent

    def CommonLock(self):
        '''公共互斥锁'''
        AsyncComplThread._lock.acquire()

    def CommonUnlock(self):
        '''公共互斥锁'''
        AsyncComplThread._lock.release()

    def run(self):
        try:
            if not self.hook:
                return

            result = self.hook(self, self.args)
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
def CommonCompleteHookRegister(hook, priv):
    global g_AsyncComplBVars
    g_AsyncComplBVars.b['CommonCompleteHook'] = hook
    g_AsyncComplBVars.b['CommonCompleteHookData'] = priv

# 通用补全hook注册, 外知的接口
def CommonCompleteArgsHookRegister(hook, priv):
    global g_AsyncComplBVars
    g_AsyncComplBVars.b['CommonCompleteArgsHook'] = hook
    g_AsyncComplBVars.b['CommonCompleteArgsHookData'] = priv

# 本模块持有的全局变量, 保存最新的补全线程的信息
g_asynccompl = AsyncComplData()
PYTHON_EOF
endfunction
"}}}
function! s:ThisInit() "{{{2
    call s:InitPyIf()
endfunction
"}}}

let s:cspyif_init = 0
" clientserver模式使用到的一些基础设施
function! s:InitCsPyif() "{{{2
    if s:cspyif_init
        return
    endif
    let s:cspyif_init = 1
python << PYTHON_EOF
def AsyncCompl_AsyncHook(td, priv):
    '''这个函数会在作为后台线程运行, _不_要操作vim'''
    # 1.根据输入参数进行补全搜索
    # 2.搜索完毕后, 返回结果
    hook = priv.get('hook')
    args = priv.get('args')
    # 把 data 合并进 args
    args['priv'] = priv.get('data')
    result = hook(td, args)
    #print result
    return result

def AsyncCompl_Callback(td, priv):
    #print td, priv

    join = priv.get('join')

    # 1.取出结果, 如果有结果继续
    result = td.async_return
    if not result:
        return

    mode = vim.eval("mode()")
    # 只在插入模式, 替换模式, 虚拟替换模式下才继续
    if mode != 'i' and mode != 'R' and mode != 'Rv':
        return

    # 2.检查最新请求是否为当前线程, 如果是才继续
    # NOTE: 不需要检查线程了, 直接执行步骤2检查ident结构即可

    bufnr = priv.get('bufnr')
    icase = priv.get('icase', 0)
    stat = priv.get('stat')
    stat['ccrow'] = int(stat['ccrow'])
    stat['cccol'] = int(stat['cccol'])
    # 同步模式不需要检查
    if not join and vim.eval("asynccompl#StatSimilar(%s, asynccompl#GetStat(%d), %d)"
                % (ToVimEval(stat), bufnr, icase)) == '0':
        # 状态不相似, 直接结束
        return

    # 3. 把结果返回
    vim.command("call asynccompl#FillResult(%s)" % ToVimEval(result))

    # 4. 需要的话, 主动弹出补全菜单
    if not join:
        # 弹出补全菜单
        if int(vim.eval("b:config.omnifunc")):
            trigger_key = r'\<C-x>\<C-o>'
        else:
            trigger_key = r'\<C-x>\<C-u>'
        vim.command(r'call feedkeys("\<C-r>=Acpre()\<CR>'
                                   + trigger_key +
                                   r'\<C-r>=Acpost()\<CR>", "n")')
PYTHON_EOF
endfunction
"}}}

function! asynccompl#JoinLatestThread() "{{{2
    while 1
        let is_alive = 1
        " 这里等待10ms
        py g_asynccompl.Join(0.01)
        py if not g_asynccompl.IsThreadAlive(): vim.command("let is_alive = 0")
        if !is_alive
            return
        endif
        " 这里就睡眠100ms
        sleep 100m
    endwhile
endfunction
"}}}

" 公共设施初始化
call s:ThisInit()
" vim: fdm=marker fen et sw=4 sts=4 fdl=1
