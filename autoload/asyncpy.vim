" Async Command Framework
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-12-15
" Change:   2013-12-15

" 额外依赖:
" * VimUtils

let s:sfile = expand('<sfile>')
if !has('python')
    echohl Error
    echo 'Error: Asyncpy need Vim compiled with +python feature'
    echohl None
    finish
endif

if !has('clientserver')
    echohl Error
    echo 'Error: Asyncpy need Vim compiled with +clientserver feature'
    echohl None
    finish
endif

" === 基本使用说明 ===
" 这是外部用唯一接口
" AsyncPython(async_hook, async_args, callback, callback_args)
"
" 返回:
"   异步线程实例
"
" 其中:
"   async_hook(异步线程实例, async_args)
"       在后台运行, 不能操作vim
"
"   callback(异步线程实例, callback_args)
"       在前台运行, 可以操作vim
"       其中async_hook的返回值保存在异步线程实例的async_return成员中

function! asyncpy#Init() "{{{2
    return 0
endfunction
"}}}
function! asyncpy#GetProgName() "{{{2
    let sVimProg = v:progname
    if has('win32') || has('win64') || has('win32unix')
        " Windows 下暂时这样获取
        let sVimProg = $VIMRUNTIME . '\' . sVimProg
    endif
    return sVimProg
endfunction
"}}}
" ident为字符串, 即线程的ident
function! asyncpy#Callback(ident) "{{{2
    py AsyncpyCallback(vim.eval("a:ident"))
    " Windows 下面会在前端显示返回结果, 所以需要返回空字符串
    return ''
endfunction
"}}}
let s:pyif_init = 0
function! s:InitPyIf() "{{{2
    if s:pyif_init
        return
    endif
    let s:pyif_init = 1
python << PYTHON_EOF
import sys
import vim

import threading
import subprocess

from VimUtils import PrintS, PrintExcept

def vimcs_eval_expr(servername, expr, vimprog='vim'):
    '''在vim服务器上执行表达式expr，返回输出——字符串
    NOTE: 这个函数不能让主线程对自身的服务器调用，否则死锁！
    @return: (return, stdout, stderr)'''
    if not expr or not vimprog:
        return None, None, None
    cmd = [vimprog, '--servername', servername, '--remote-expr', expr]
    p = subprocess.Popen(cmd, shell=False,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()

    return p.returncode, out, err

class AsyncpyThread(threading.Thread):
    # 公共锁, 用于所有异步线程互斥, 一般不用
    # 具体业务的例程使用自己的全局锁即可
    _common_lock = threading.Lock()

    def __init__(self, async_hook, async_args, callback, callback_args,
                 servername = '', vimprog = ''):
        threading.Thread.__init__(self)
        self.async_hook = async_hook
        self.async_args = async_args
        self.callback = callback
        self.callback_args = callback_args
        self.async_return = None

        self.servername = servername
        self.vimprog = vimprog

    def CommonLock(self):
        '''公共互斥锁'''
        AsyncpyThread._common_lock.acquire()

    def CommonUnlock(self):
        '''公共互斥锁'''
        AsyncpyThread._common_lock.release()

    def run(self):
        try:
            self.async_return = self.async_hook(self, self.async_args)

            if not self.servername or not self.vimprog:
                PrintS('AsyncpyThread Error: servername=%s, vimprog=%s'
                            % (self.servername, self.vimprog))
                return

            # 通过clientserver机制回调
            ret, out, err = \
                vimcs_eval_expr(self.servername,
                                "asyncpy#Callback('%s')" % str(self.ident),
                                self.vimprog)
        except:
            PrintExcept()

# 全局变量, 保存已经启动的异步线程实例
g__asyncmd_data = {}

# async_hook(异步线程实例, async_args)
# callback(异步线程实例, async_hook的返回值, callback_args)
def AsyncPython(async_hook, async_args, callback, callback_args):
    '''导出的接口'''
    global g__asyncmd_data
    td = AsyncpyThread(async_hook, async_args, callback, callback_args,
                       vim.eval("v:servername"),
                       vim.eval("asyncpy#GetProgName()"))
    # 必须先启动才有ident的值
    td.start()
    g__asyncmd_data[td.ident] = td
    return td

def AsyncpyCallback(ident):
    '''回调触发函数'''
    ident = int(ident)
    if g__asyncmd_data.has_key(ident):
        td = g__asyncmd_data[ident]
        if td.callback:
            try:
                td.callback(td, td.callback_args)
            except:
                PrintExcept()
        # 清理掉
        # NOTE: 这个函数是通过线程调用进来的, 这个时候线程的run函数还没有返回
        del g__asyncmd_data[ident]
    else:
        print 'Thread %d not found' % ident
PYTHON_EOF
endfunction
"}}}

function! asyncpy#Test() "{{{2
python << PYTHON_EOF
def async_hook(*args):
    import time
    time.sleep(3)
    return 'hello world'

def hello_callback(*args):
    td = args[0]
    print args
    print td.async_return
PYTHON_EOF
    py AsyncPython(async_hook, 'hello', hello_callback, 'world')
endfunction
"}}}

" 初始化基础设施
call s:InitPyIf()

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
