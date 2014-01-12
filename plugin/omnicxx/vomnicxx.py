#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''这个模块需要感知Videm的所有东西和vim'''

import tempfile
import vim
import IncludeParser
from TagsSettings import TagsSettingsST
from Misc import DirSaver
from Misc import ToU
from Utils import IsCppSourceFile, IsCppHeaderFile

def IndicateProgress(n, m):
    vim.command("echon 'Parsing files: '")
    vim.command("call vlutils#Progress(%d, %d)" % (n, m))

class OmniCpp:
    def __init__(self, tagmgr):
        self.tagmgr = tagmgr

    def ParseWorkspace(self, wsp, async = True, full = False, deep = True):
        '''
        async:  是否异步
        full:   是否解析工作区的所有文件
        deep:   包括源文件包含的头文件'''
        vim.command("redraw")
        vim.command("echo 'Preparing...'")

        if full:
            self.tagmgr.RecreateDatabase()

        files = wsp.VLWIns.GetAllFiles(True)
        parseFiles = files[:]
        extraMacros = []

        searchPaths = wsp.GetTagsSearchPaths()

        if True:
            '添加编译选项指定的搜索路径'
            projIncludePaths = set()
            matrix = wsp.VLWIns.GetBuildMatrix()
            wspSelConfName = matrix.GetSelectedConfigurationName()
            for project in wsp.VLWIns.projects.itervalues():
                # 保证激活的项目的预定义宏放到最后
                if project.GetName() != wsp.VLWIns.GetActiveProjectName():
                    extraMacros.extend(
                        wsp.GetProjectPredefineMacros(project.GetName()))
                for tmpPath in wsp.GetProjectIncludePaths(project.GetName()):
                    projIncludePaths.add(tmpPath)

            projIncludePaths = list(projIncludePaths)
            projIncludePaths.sort()
            searchPaths += projIncludePaths

        # 从工作区获取的全部文件，先过滤不是c++的文件
        files = [f for f in files if IsCppHeaderFile(f) or
                                     IsCppSourceFile(f)]

        if deep:
            vim.command(
                "redraw | echo 'Scanning header files need to be parsed...'")
            for f in files:
                parseFiles += IncludeParser.GetIncludeFiles(f, searchPaths)

        # 当前激活状态的项目的预定义宏最优先
        extraMacros.extend(
            wsp.GetProjectPredefineMacros(wsp.VLWIns.GetActiveProjectName()))

        for i in range(len(extraMacros)):
            extraMacros[i] = '#define %s' % extraMacros[i]

        #parseFiles = list(set(parseFiles))
        parseFiles = [ToU(i) for i in set(parseFiles)]
        parseFiles.sort()
        if async:
            vim.command("redraw | echo 'Start asynchronous parsing...'")
            self.AsyncParseFiles(wsp, parseFiles, extraMacros=extraMacros)
        else:
            self.ParseFiles(wsp, parseFiles, extraMacros=extraMacros)

    def ParseFiles(self, wsp, files, indicate = True, extraMacros = [],
                   filterNotNeed = True):
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
                                   filterNotNeed)
            vim.command("redraw | echo 'Done.'")
        else:
            self.tagmgr.ParseFiles(files, macroFiles, None, filterNotNeed)
        try:
            os.close(tmpfd)
            os.remove(tmpf)
        except:
            pass

    def AsyncParseFiles(self, wsp, files, extraMacros = [],
                        filterNotNeed = True):
        def RemoveTmp(arg):
            os.close(arg[0])
            os.remove(arg[1])
        macros = \
            TagsSettingsST.Get().tagsTokens + wsp.VLWSettings.tagsTokens
        macros.extend(extraMacros)
        tmpfd, tmpf = tempfile.mkstemp() # 在异步进程完成后才删除，使用回调机制
        with open(tmpf, 'wb') as f:
            f.write('\n'.join(macros))
        self.tagmgr.AsyncParseFiles(files, [tmpf], RemoveTmp,
                                    [tmpfd, tmpf], filterNotNeed)

def main(argv):
    pass

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret is None:
        ret = 0
    sys.exit(ret)
