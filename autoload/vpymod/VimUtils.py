#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''需要vim模块的例程'''

import traceback
import StringIO
import os.path
import subprocess
import threading
import vim

# 方便使用, 外部程序使用这个接口即可
def PrintS(*args, **kwargs):
    '''安全地打印, 主要用于后台线程打印信息'''
    VimExcHdr.Init()
    for arg in args:
        VimExcHdr.Print(arg)

# 方便使用, 外部程序使用这个接口即可
def PrintExcept():
    VimExcHdr.Init()
    VimExcHdr.PrintExcept()

class VimExcHdr:
    '''这个类设计得不好, 用上面两个函数隐藏掉这个类'''
    _init = False
    vim_has_gui_running = True
    vim_servername = ''
    vim_progname = 'vim'
    _main_thread = threading.current_thread()

    @staticmethod
    def Init(force = False):
        # 快速的防止重复初始化
        if not force and VimExcHdr._init:
            return

        VimExcHdr._init = True
        VimExcHdr.vim_has_gui_running = vim.eval("has('gui_running')") == '1'
        VimExcHdr.vim_servername = vim.eval("v:servername")
        VimExcHdr.vim_progname = vim.eval("v:progname")
        # 判断线程是否主线程用, 暂时未想到其他好办法
        VimExcHdr._main_thread = threading.current_thread()
        if vim.eval("vlutils#IsWindowsOS()") == '1':
            VimExcHdr.vim_progname = os.path.join(vim.eval("$VIMRUNTIME"),
                                                  VimExcHdr.vim_progname)

    @staticmethod
    def VimPrint(msg):
        '''DEPRECATED'''
        VimExcHdr.Print(msg)

    @staticmethod
    def Print(msg):
        if not VimExcHdr.vim_has_gui_running:
            # 终端下直接打印
            print msg
            print "There are some warning messages! Please run ':messages' for details."
        elif VimExcHdr.vim_servername:
            if threading.current_thread() is VimExcHdr._main_thread:
                vim.command("call vlutils#EchoMsgx('%s')" % msg.replace("'", "''"))
            else:
                # 通过 clientserver 打印出错信息
                prog = VimExcHdr.vim_progname
                servername = VimExcHdr.vim_servername
                vimcs_eval_expr(servername,
                                "vlutils#EchoMsgx('%s')" % msg.replace("'", "''"),
                                prog)
        else:
            # TODO
            # 不能打印的情况的话，只能写出错文件了？
            pass

    @staticmethod
    def VimRaise():
        '''DEPRECATED'''
        VimExcHdr.PrintExcept()

    @staticmethod
    def PrintExcept():
        '''打印出错信息'''
        sio = StringIO.StringIO()
        traceback.print_exc(file=sio)
        errmsg = sio.getvalue()
        if not errmsg:
            return
        VimExcHdr.Print(errmsg)

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

def TestHook(*args, **kwargs):
    #VimExcHdr.Init()
    #VimExcHdr.Print('hello world')
    #VimExcHdr.PrintExcept()
    PrintS("hello world")
    try:
        assert False
    except:
        PrintExcept()
        #VimExcHdr.PrintExcept()
    #print args

def TestInVim():
    import threading
    args= ['hello']
    timeout = 3
    timer = threading.Timer(timeout, TestHook, args)
    timer.start()

def main(argv):
    try:
        assert None
    except:
        VimRaise()

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret is None:
        ret = 0
    sys.exit(ret)
