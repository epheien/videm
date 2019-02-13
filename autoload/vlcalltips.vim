" Description:  vim script for display function calltips
" Maintainer:   fanhe <fanhed@163.com>
" Create:       2011 Jun 18
" License:      GPLv2

" 正常来说，只需要注册一个回调函数并且只需调用导出的接口即可

if exists('g:loaded_vlcalltips')
    finish
endif
let g:loaded_vlcalltips = 1

function! vlcalltips#Init()
    return 1
endfunction

" 这个插件的类
let s:VLCalltips = {}
let s:VLCalltips.keepCursor = 1 " 不自动结束没有参数的函数 calltips

function! s:InitVariable(varName, defaultVal) "{{{2
    if !exists(a:varName)
        let {a:varName} = a:defaultVal
        return 1
    endif
    return 0
endfunction
"}}}

call s:InitVariable('g:VLCalltips_IndicateArgument', 1)
call s:InitVariable('g:VLCalltips_EnableSyntaxTest', 0)

call s:InitVariable('g:VLCalltips_DispCalltipsKey', '<A-p>')
call s:InitVariable('g:VLCalltips_NextCalltipsKey', '<A-j>')
call s:InitVariable('g:VLCalltips_PrevCalltipsKey', '<A-k>')

function! vlcalltips#InitBuffKeymap() "{{{2
    " just for test
    "exec 'inoremap <silent> <buffer> ' . g:VLCalltips_DispCalltipsKey 
                "\. ' <C-r>=<SID>Test()<CR>'
    exec 'inoremap <silent> <buffer> ' . g:VLCalltips_DispCalltipsKey 
                \. ' <C-r>=vlcalltips#Start()<CR>'
    exec 'inoremap <silent> <buffer> ' . g:VLCalltips_NextCalltipsKey 
                \. ' <C-r>=<SID>HighlightNextCalltips()<CR>'
    exec 'inoremap <silent> <buffer> ' . g:VLCalltips_PrevCalltipsKey 
                \. ' <C-r>=<SID>HighlightPrevCalltips()<CR>'
endfunction
"}}}

let s:lCalltips = [] "保存函数原型或者原型形参信息的列表(C++ 重载)
let s:nCurIndex = 0 "当前函数原型的索引
let s:nArgIndex = 0 "当前形参索引, 0 开始

" just for test
function! s:Test() "{{{2
    let lLi = []
    call add(lLi, 'int printf(const char *fmt, ...)')
    call add(lLi, 'int printf(const char *fmt, int a, int b)')
    call s:DisplayVLCalltips(lLi, 0)

    return ''
endfunction
"}}}
" 接口函数，注册回调函数
" 回调函数必须接受一个参数，并且必须返回一个列表，项目为函数的完整声明（如上）
" hook(data) -> [tip1, tip2, ...]
function! vlcalltips#Register(func, data) "{{{2
    if type(a:func) == type("")
        let Cbk = function(a:func)
    else
        let Cbk = a:func
    endif
    silent! unlet s:VLCalltips.callback
    let s:VLCalltips.callback = Cbk
    silent! unlet s:VLCalltips.callbackData
    let s:VLCalltips.callbackData = a:data
endfunction
"}}}
function! vlcalltips#Unregister(func) "{{{2
    silent! unlet s:VLCalltips.callback
    let s:VLCalltips.callback = 0
    silent! unlet s:VLCalltips.callbackData
    let s:VLCalltips.callbackData = 0
endfunction
"}}}
function! vlcalltips#Start() "{{{2
    if !empty(get(s:VLCalltips, 'callback'))
        let lCalltips = s:VLCalltips.callback(s:VLCalltips.callbackData)
        call s:DisplayVLCalltips(lCalltips, 0)
    endif
    return ''
endfunction
"}}}
" 不允许私自移动光标
function! vlcalltips#KeepCursor() "{{{2
    let s:VLCalltips.keepCursor = 1
endfunction
"}}}
function! vlcalltips#UnkeepCursor() "{{{2
    let s:VLCalltips.keepCursor = 0
endfunction
"}}}
function! s:DisplayVLCalltips(lCalltips, nCurIndex) "{{{2
    if empty(a:lCalltips)
        return ''
    endif

    "let bKeepCursor = a:0 > 0 ? a:1 : 0
    let bKeepCursor = s:VLCalltips.keepCursor

    call s:StopCalltips()
    if type(a:lCalltips) == type('')
        let s:lCalltips = [a:lCalltips]
        let s:nCurIndex = 0
    else
        let s:lCalltips = copy(a:lCalltips)
        let s:nCurIndex = a:nCurIndex
    endif

    if !empty(s:lCalltips)
        augroup DispCalltipsGroup
            autocmd!
            autocmd CursorMovedI <buffer> call <SID>AutoUpdateCalltips()
            autocmd InsertLeave  <buffer> call <SID>StopCalltips()
        augroup END

        "设置必要的选项
        let s:bak_showmode = &showmode
        let s:bak_ruler = &ruler
        let s:bak_cmdheight = &cmdheight
        set noshowmode
        set noruler

        let s:nArgIndex = s:GetArgIndex()

        "如果函数无参数, 自动结束
        if !bKeepCursor && len(s:lCalltips) == 1 
                    \&& s:lCalltips[0] =~# '(\s*)\|(\s*void\s*)'
            call s:StopCalltips()
            call search(')', 'Wc')
            normal! l
        else
            call s:DisplayCalltips()
        endif
    endif

    return ''
endfunction

function! s:AutoUpdateCalltips() "{{{2
    "函数无参数，自动结束
    "if len(s:lCalltips) == 1 && s:lCalltips[0] =~# '()\|(\s*void\s*)'
        "call s:StopCalltips()
        "call search(')', 'Wc')
        "normal! l
    "endif

    "精确模式
    let nIdx = s:GetArgIndex()
    if nIdx == -2
        "不在括号内, 停止
        call s:StopCalltips()
    elseif nIdx == -1
        "没有找到函数名称, 可能在括号内输入了括号
        "TODO: 如果开始位置前于初始化时的开始位置, 必定停止
    elseif nIdx >= 0
        let s:nArgIndex = nIdx
        call s:DisplayCalltips()
    endif

    return ''
endfunction

function! s:StopCalltips() "{{{2
    call filter(s:lCalltips, 0)
    let s:nCurIndex = 0
    let s:nArgIndex = 0

    silent! autocmd! DispCalltipsGroup
    if exists('s:bak_showmode')
        let &showmode = s:bak_showmode
        let &ruler = s:bak_ruler
        let &cmdheight = s:bak_cmdheight
        unlet s:bak_showmode
        unlet s:bak_ruler
        unlet s:bak_cmdheight

        "目的在于刷新
        echo ""
    endif
endfunction

function! s:HighlightNextCalltips() "{{{2
    let nLen = len(s:lCalltips)
    let s:nCurIndex = (s:nCurIndex + 1) % nLen
    call s:DisplayCalltips()
    return ''
endfunction

function! s:HighlightPrevCalltips() "{{{2
    let nLen = len(s:lCalltips)
    let s:nCurIndex = (s:nCurIndex - 1 + nLen) % nLen
    call s:DisplayCalltips()
    return ''
endfunction

function! s:DisplayCalltips() "{{{2
    if empty(s:lCalltips)
        return ''
    endif

    let nCalltipsCount = len(s:lCalltips)
    let sCurCalltips = s:lCalltips[s:nCurIndex]
    let nArgStartIdx = stridx(sCurCalltips, '(') + 1
    let nArgEndIdx = strridx(sCurCalltips, ')') - 1

    if !g:VLCalltips_IndicateArgument
        let sContent = sCurCalltips
                    \. ' ('. (s:nCurIndex + 1) . '/' . nCalltipsCount . ')'

        " 12 很诡异...
        let nHeight = len(sContent) / (&columns - 12) + 1
        let &cmdheight = nHeight

        echohl Type
        echo sContent[: nArgStartIdx-1]
        echohl SpecialChar
        echon sContent[nArgStartIdx : nArgEndIdx]
        echohl Type
        echon sContent[nArgEndIdx+1 :]
        echohl None

        return ''
    endif

    let nHlStartIdx = nArgStartIdx
    let i = 0
    while i < s:nArgIndex
        let nHlStartIdx = stridx(sCurCalltips, ',', nHlStartIdx)
        if nHlStartIdx != -1
            let nHlStartIdx += 1
        else
            "指定的参数超过了该函数的参数数量
            let nHlStartIdx = nArgEndIdx + 1
            break
        endif
        let i += 1
    endwhile

    let nHlStopIdx = nArgEndIdx
    let nHlStopIdx = stridx(sCurCalltips, ',', nHlStartIdx)
    if nHlStopIdx != -1
        "vim 的子串索引包括尾端，和 python 不一致！
        let nHlStopIdx -= 1
    else
        "当前参数索引是最后的参数，所以 nHlStopIdx 为 -1
        let nHlStopIdx = nArgEndIdx
    endif

    let sContent = sCurCalltips
                \. ' ('. (s:nCurIndex + 1) . '/' . nCalltipsCount . ')'

    " 12 很诡异...
    let nHeight = len(sContent) / (&columns - 12) + 1
    let &cmdheight = nHeight

    "处理可变参数
    let nVaArgIdx = match(sCurCalltips, '\V...)')
    if nVaArgIdx != -1 && nHlStartIdx > nVaArgIdx
        "存在可变参数，且参数索引到达最后了，锁定为最后的参数
        let nHlStartIdx = nVaArgIdx
    endif

    echohl Type
    echo sContent[: nHlStartIdx-1]
    echohl SpecialChar
    echon sContent[nHlStartIdx : nHlStopIdx]
    echohl Type
    echon sContent[nHlStopIdx + 1 :]
    echohl None
endfunction

function! s:GetArgIndex() "{{{2
    " 精确地确定光标所在位置所属的函数参数索引
    " 不在括号内，返回 -2，函数名为空，返回 -1

    " 确定函数括号开始的位置
    if g:VLCalltips_EnableSyntaxTest
        let sSkipExpr = 'synIDattr(synID(line("."), col("."), 0), "name") '
                    \. '=~? "string\\|character"'
    else
        let sSkipExpr = ''
    endif
    let lStartPos = searchpairpos('(', '', ')', 'nWb', sSkipExpr)
    " 如果刚好在括号内，加 'c' 参数
    let lEndPos = searchpairpos('(', '', ')', 'nWc', sSkipExpr)
    let lCurPos = [line('.'), col('.')]

    " 不在括号内
    if lStartPos[0] == 0 && lStartPos[1] == 0
        return -2
    else
        if !g:VLCalltips_IndicateArgument
            return 0
        endif
    endif

    "let lines = getline(lStartPos[0], lEndPos[0])

    " 获取函数名称和名称开始的列，暂时只处理 '(' "与函数名称同行的情况，
    " 允许之间有空格
    " TODO: 处理更复杂的情况: 1.函数名称与 ( 不在同行 2.函数名称前有逗号
    let sStartLine = getline(lStartPos[0])
    let sFuncName = matchstr(sStartLine[: lStartPos[1]-1], '\w\+\ze\s*($')
    let nFuncIdx = match(sStartLine[: lStartPos[1]-1], '\w\+\ze\s*($')

    let nArgIdx = -1
    if sFuncName != ''
        " 计算光标所在的位置所属的函数参数索引(从 0 开始)
        let nArgIdx = 0

        for nLine in range(lStartPos[0], lCurPos[0])
            let sLine = getline(nLine)
            let nStart = 0
            let nEnd = len(sLine)

            if nLine == lCurPos[0]
                " 光标所在行
                let nEnd = lCurPos[1] - 1 "(a,b|,c)
            endif

            while nStart < nEnd
                let nStart = stridx(sLine, ',', nStart)
                if nStart != -1 && nStart < nEnd
                    " 确保不是字符串里的逗号
                    if !(g:VLCalltips_EnableSyntaxTest 
                                \&& synIDattr(synID(nLine, nStart + 1, 0), 
                                \             "name") =~? 'string\|character')
                        let nArgIdx += 1
                    endif
                else
                    break
                endif
                let nStart += 1
            endwhile
        endfor
    endif

    return nArgIdx
endfunction


" vim: fdm=marker fen et sw=4 sts=4 fdl=1
