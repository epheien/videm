#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''这个模块需要感知Videm的所有东西和vim'''

import tempfile
import vim
import IncludeParser
from TagsSettings import TagsSettingsST
from Misc import DirSaver
from Misc import ToU
from Utils import IsCCppSourceFile, IsCppHeaderFile

def IndicateProgress(n, m):
    vim.command("echon 'Parsing files: '")
    vim.command("call vlutils#Progress(%d, %d)" % (n, m))

class VimOmniCxx(object):
    def __init__(self, tagmgr):
        self.tagmgr = tagmgr

    def ParseWorkspace(self, wsp, files = None, async = True, full = False,
                       deep = True, quiet = False, ignore_needless = True):
        '''
        files:  None  - 如果为非None列表, 则只parse列表中的文件, 否则为全部文件
        async:  True  - 异步, False - 同步
        full:   True  - 全部重新parse, False - 只parse必要的
        deep:   True  - 包括源文件包含的头文件
        quiet:  False - 如果为真, 则不打印任何信息
        ignore_needless: True - 若为False, 强制parse所有指定的文件'''
        if not quiet:
            vim.command("redraw")
            vim.command("echo 'Preparing...'")

        if full:
            self.tagmgr.RecreateDatabase()

        if files is None:
            files = wsp.VLWIns.GetAllFiles(True)
            # 从工作区获取的全部文件，先过滤不是c++的文件
            files = [f for f in files if IsCppHeaderFile(f) or IsCCppSourceFile(f)]
        else:
            # 制定文件的话, 不过滤源文件和头文件了, 可由外部处理
            pass

        parseFiles = files[:]
        extraMacros = []

        for project in wsp.VLWIns.projects.itervalues():
            # 保证激活的项目的预定义宏放到最后
            if project.GetName() != wsp.VLWIns.GetActiveProjectName():
                extraMacros.extend(
                    wsp.GetProjectPredefineMacros(project.GetName()))

        if deep:
            searchPaths = wsp.GetTagsSearchPaths()

            # 添加编译选项指定的搜索路径
            projIncludePaths = set()
            for project in wsp.VLWIns.projects.itervalues():
                for tmpPath in wsp.GetProjectIncludePaths(project.GetName()):
                    projIncludePaths.add(tmpPath)

            projIncludePaths = list(projIncludePaths)
            projIncludePaths.sort()
            searchPaths += projIncludePaths

            if not quiet:
                vim.command("redraw | "
                            "echo 'Scanning header files need to be parsed...'")
            for f in files:
                parseFiles += IncludeParser.GetIncludeFiles(f, searchPaths)
            if not quiet:
                vim.command("echo ''")

        # 当前激活状态的项目的预定义宏最优先
        extraMacros.extend(
            wsp.GetProjectPredefineMacros(wsp.VLWIns.GetActiveProjectName()))

        # 之前的 extraMacros 的格式不是标准的宏定义语句, 现在转换之
        for i in range(len(extraMacros)):
            extraMacros[i] = '#define %s' % extraMacros[i]

        parseFiles = [ToU(i) for i in set(parseFiles)]
        parseFiles.sort()
        if async:
            if not quiet:
                vim.command("redraw | echo 'Start asynchronous parsing...'")
            self._ParseFilesAsync(wsp, parseFiles, extraMacros=extraMacros,
                                  ignore_needless = ignore_needless)
        else:
            self._ParseFiles(wsp, parseFiles, extraMacros=extraMacros,
                             ignore_needless = ignore_needless)

    def _ParseFiles(self, wsp, files, indicate = True, extraMacros = [],
                    ignore_needless = True):
        ds = DirSaver()
        try:
            # 为了 macroFiles 中的相对路径有效
            os.chdir(wsp.VLWIns.dirName)
        except:
            pass

        macros = \
            TagsSettingsST.Get().tagsTokens + wsp.VLWSettings.tagsTokens
        macros.extend(extraMacros)
        #print '\n'.join(macros)
        tmpfd, tmpf = tempfile.mkstemp()
        macroFiles = [tmpf]
        macroFiles.extend(wsp.VLWSettings.GetMacroFiles())
        #print macroFiles
        with open(tmpf, 'wb') as f:
            f.write('\n'.join(macros))
        if indicate:
            vim.command("redraw")
            self.tagmgr.ParseFiles(files, macroFiles, IndicateProgress,
                                    ignore_needless)
            vim.command("redraw | echo 'Done.'")
        else:
            self.tagmgr.ParseFiles(files, macroFiles, None, ignore_needless)
        try:
            os.close(tmpfd)
            os.remove(tmpf)
        except:
            pass

    def _ParseFilesAsync(self, wsp, files, extraMacros = [],
                         ignore_needless = True):
        def RemoveTmp(arg):
            os.close(arg[0])
            os.remove(arg[1])
        macros = \
            TagsSettingsST.Get().tagsTokens + wsp.VLWSettings.tagsTokens
        macros.extend(extraMacros)
        tmpfd, tmpf = tempfile.mkstemp() # 在异步进程完成后才删除，使用回调机制
        with open(tmpf, 'wb') as f:
            f.write('\n'.join(macros))
        self.tagmgr.ParseFilesAsync(files, [tmpf], RemoveTmp,
                                     [tmpfd, tmpf], ignore_needless)

def main(argv):
    pass

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret is None:
        ret = 0
    sys.exit(ret)
