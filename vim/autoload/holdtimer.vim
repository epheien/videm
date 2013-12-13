" Cursor Hold Timer
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-12-13
" Change:   2013-12-13

" NOTE: 这个叫CursorHoldTimer的东西，不等于常规的定时器，这个定时器只在没有输入
"       的时候才开始正式执行，当一直有输入的时候，这个定时器是不工作的！

augroup CursorHoldTimer
    autocmd!
augroup END

let Stack = {}
let Stack.stack = []
" class Stack {{{2
function! Stack.New()
    let new = copy(self)
    let new.stack = []
    return new
endfunction

function! Stack.Push(obj)
    call add(self.stack, a:obj)
endfunction

function! Stack.Size()
    return len(self.stack)
endfunction

function! Stack.Empty()
    return empty(self.stack)
endfunction

function! Stack.Pop(...)
    let none = get(a:000, 0, 0)
    if self.Empty()
        return none
    endif
    return remove(self.stack, -1)
endfunction
"}}}
let s:option_stack = Stack.New()
let s:option_stackI = Stack.New()

let s:Hook = function('empty')
let s:data = 0
let s:delay = 0

let s:HookI = function('empty')
let s:dataI = 0
let s:delayI = 0

" delay 单位为毫秒
function! holdtimer#AddTimer(Hook, data, delay) "{{{2
    if type(a:Hook) == type('')
        let s:Hook = function(a:Hook)
    else
        let s:Hook = a:Hook
    end
    let s:data = a:data
    let s:delay = a:delay

    if s:delay > 0
        call s:option_stack.Push(&updatetime)
        let &updatetime = s:delay
        autocmd! CursorHoldTimer CursorHold * call holdtimer#TimerHandler()

        " 这个是重复触发定时器的关键语句
        call feedkeys("f\e", 'n')
    endif
endfunction
"}}}
function! holdtimer#TimerHandler() "{{{2
    " 恢复选项
    let &updatetime = s:option_stack.Pop()
    " 删除自动命令
    autocmd! CursorHoldTimer CursorHoldI

    " 这里调用hook，如果需要重复执行定时器，则应该在hook里面主动调用AddTimer
    call s:Hook(s:data)
endfunction
"}}}
" delay 单位为毫秒
function! holdtimer#AddTimerI(Hook, data, delay) "{{{2
    if type(a:Hook) == type('')
        let s:HookI = function(a:Hook)
    else
        let s:HookI = a:Hook
    end
    let s:dataI = a:data
    let s:delayI = a:delay

    if s:delayI > 0
        call s:option_stackI.Push(&updatetime)
        let &updatetime = s:delayI
        autocmd! CursorHoldTimer CursorHoldI * call holdtimer#TimerHandlerI()

        " 这个是重复触发定时器的关键语句
        call feedkeys("\<C-r>=''\<Cr>", 'n')
    endif
endfunction
"}}}
" 销毁定时器
function! holdtimer#DelTimerI(Hook) "{{{2
    if type(a:Hook) == type('')
        let Hook = function(a:Hook)
    else
        let Hook = a:Hook
    endif

    " 只在匹配的时候才继续
    if Hook isnot s:HookI
        return
    endif

    " 恢复选项
    if !s:option_stackI.Empty()
        let &updatetime = s:option_stackI.Pop()
    endif
    " 删除自动命令
    autocmd! CursorHoldTimer CursorHoldI
endfunction
"}}}
function! holdtimer#TimerHandlerI() "{{{2
    " 恢复选项
    if !s:option_stackI.Empty()
        let &updatetime = s:option_stackI.Pop()
    endif
    " 删除自动命令
    autocmd! CursorHoldTimer CursorHoldI

    " 这里调用hook，如果需要重复执行定时器，则应该在hook里面主动调用AddTimer
    call s:HookI(s:data)
endfunction
"}}}

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
