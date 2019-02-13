#!/usr/bin/env python
# -*- coding: utf-8 -*-

import tarfile
import tempfile
import os
import os.path
# required vim module
import vim
from Misc import ToVimEval
from Misc import DirSaver

_session_file = 'vimsess.dat'
_viminfo_file = 'viminfo.dat'

class VimSession(object):
    '''vim session'''
    def __init__(self):
        global _session_file
        global _viminfo_file
        self.session_file = _session_file
        self.viminfo_file = _viminfo_file

    def Load(self, filename):
        if not filename:
            return -1

        ret = 0

        dtmp = tempfile.mkdtemp()
        try:
            # extract tar
            tar = tarfile.open(filename, 'r:gz')
            names = tar.getnames()
            tar.extractall(dtmp)
            tar.close()
        except:
            os.rmdir(dtmp)
            return -1

        ds = DirSaver()
        #os.chdir(dtmp)
        session_file = os.path.join(dtmp, self.session_file)
        viminfo_file = os.path.join(dtmp, self.viminfo_file)
        try:
            # load session
            vim.command("exec 'source' fnameescape(%s)" % ToVimEval(session_file))
            vim.command("exec 'rviminfo' fnameescape(%s)" % ToVimEval(viminfo_file))
        except:
            ret = -1
        finally:
            # cleanup
            for name in names:
                os.remove(os.path.join(dtmp, name))
            del ds
            os.rmdir(dtmp)

        return ret

    def Save(self, filename):
        if not filename:
            return -1

        ret = 0

        # 取绝对路径
        filename = os.path.abspath(filename)

        dtmp = tempfile.mkdtemp()
        session_file = os.path.join(dtmp, self.session_file)
        viminfo_file = os.path.join(dtmp, self.viminfo_file)

        try:
            # save session
            vim.command("exec 'mksession!' fnameescape(%s)"
                        % ToVimEval(session_file))
            vim.command("exec 'wviminfo!' fnameescape(%s)"
                        % ToVimEval(viminfo_file))
        except:
            os.rmdir(dtmp)
            return -1

        ds = DirSaver()
        os.chdir(dtmp)
        try:
            # tar
            tar = tarfile.open(filename, 'w:gz')
            tar.add(self.session_file)
            tar.add(self.viminfo_file)
            tar.close()
        except:
            ret = -1
        finally:
            # cleanup
            os.remove(session_file)
            os.remove(viminfo_file)
            del ds
            os.rmdir(dtmp)

        return ret

class VidemSession(VimSession):
    '''Videm 的会话类'''
    def __init__(self):
        VimSession.__init__(self)
