#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''需要vim模块的例程'''

import traceback
import StringIO
import os.path
import subprocess
import vim

# FIXME: 还不可用
class VimExcHdr:
    vim_has_gui_running = True
    vim_servername = ''
    vim_progname = 'vim'

    @staticmethod
    def Init():
        VimExcHdr.vim_has_gui_running = vim.eval("has('gui_running')") == '1'
        VimExcHdr.vim_servername = vim.eval("v:servername")
        VimExcHdr.vim_progname = vim.eval("v:progname")
        if vim.eval("vlutils#IsWindowsOS()") == '1':
            VimExcHdr.vim_progname = os.path.join(vim.eval("$VIMRUNTIME"),
                                                  VimExcHdr.vim_progname)

    @staticmethod
    def VimPrint(msg):
        print msg
        return
        if not VimExcHdr.vim_has_gui_running:
            # 终端下直接打印
            print msg
        elif VimExcHdr.vim_servername:
            # 通过 clientserver 打印出错信息
            prog = VimExcHdr.vim_progname
            servername = VimExcHdr.vim_servername
            vimcs_eval_expr(servername,
                            "vlutils#EchoErrMsg('%s')" % msg.replace("'", "''"),
                            prog)
            #vimcs_eval_expr(servername, "vlutils#EchoErrMsg('%s')" % msg, prog)
        else:
            # TODO
            # 不能打印的情况的话，只能写出错文件了？
            pass

    @staticmethod
    def VimRaise():
        sio = StringIO.StringIO()
        traceback.print_exc(file=sio)
        errmsg = sio.getvalue()
        VimExcHdr.VimPrint(errmsg)

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
