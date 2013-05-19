" Vim Script
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-01-15
" Change:   2013-01-15

if exists('s:loaded')
    finish
endif
let s:loaded = 1

" 当前的服务器名字
let s:servername = v:servername

function! InitVimcsPyif()
python << PYTHON_EOF
import subprocess
import threading
import time
import vim

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

def vimcs_send_keys(servername, keys):
    '''发送按键到vim服务器'''
    if not servername:
        return -1
    cmd = ['vim', '--servername', servername, '--remote-send', keys]
    p = subprocess.Popen(cmd, shell=False,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()
    return p.returncode

def vimcs_eval_expr(servername, expr):
    '''在vim服务器上执行表达式expr，返回输出——字符串
    FIXME: 这个函数不能对自身的服务器调用，否则死锁！'''
    if not expr:
        return ''
    cmd = ['vim', '--servername', servername, '--remote-expr', expr]
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

class vim_server:
    def __init__(self, servername):
        self.servername = servername

    def send_keys(self, keys):
        '''发送按键到服务器'''
        return vimcs_send_keys(self.servername, keys)

    def eval_expr(self, expr):
        '''在服务器上执行表达式'''
        return vimcs_eval_expr(self.servername, expr)

g_list = []

class vim_thread(threading.Thread):
    def __init__(self, servername):
        threading.Thread.__init__(self)
        self.vs = vim_server(servername)

    def run(self):
        global g_list
        mons = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"
        for mon in mons.split():
            item = {
                'word': mon,
                #'abbr': mon[0],
                'menu': mon,
                'kind': 'w',
                'icase': 1,
                'dup': 0,
            }
            g_list.append(item)
        time.sleep(3)
        mode = self.vs.eval_expr('mode()')
        if mode == 'i' or mode == 'R': # 插入或者替换模式下才发送按键
            self.vs.send_keys('<C-x><C-u><C-p><Down>')

PYTHON_EOF
    " 然后导出vim版本的函数
    function! VimcsSendKeys(servername, keys)
        py vim.command("return %s" % ToVimEval(
            \ vimcs_send_keys(vim.eval('a:servername'), vim.eval('a:keys'))))
    endfunction

    function! VimcsEvalExpr(servername, expr)
        py vim.command("return %s" % ToVimEval(
            \ vimcs_eval_expr(vim.eval('a:servername'), vim.eval('a:expr'))))
    endfunction
endfunction

function! AsyncComplete(findstart, base)
    if a:findstart
        return col('.') - 2
    endif

    " 第二次调用
    py vim.command("let result = %s" % ToVimEval(g_list))
    return result
endfunction

function! LauchAsyncComplete()
    py vim_thread(vim.eval("v:servername")).start()
endfunction

function! InitAsyncComplete()
    call InitVimcsPyif()
    set completefunc=AsyncComplete
endfunction

call InitAsyncComplete()

" vim: fdm=marker fen et sts=4 fdl=1
