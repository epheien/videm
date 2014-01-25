#!/usr/bin/env python
# -*- coding:utf-8 -*-

'''工作区的 python 例程，和对应的 vim 脚本是互相依赖的'''

import sys
import os
import os.path
import subprocess
import time
import tempfile
import shlex
import json
import vim

sys.path.append(vim.eval('g:VidemPyDir'))
import VLWorkspace
from VLWorkspace import VLWorkspaceST
from TagsSettings import TagsSettings
from TagsSettings import TagsSettingsST
from BuildSettings import BuildSettingsST
from BuilderManager import BuilderManagerST
from EnvVarSettings import EnvVar
from EnvVarSettings import EnvVarSettings
from EnvVarSettings import EnvVarSettingsST
from VLWorkspaceSettings import VLWorkspaceSettings
from VLProjectSettings import VLProjectSettings
import BuilderGnuMake
import IncludeParser

from GetTemplateDict import GetTemplateDict

import Utils
from Misc import SplitSmclStr, JoinToSmclStr, EscStr4DQ, IsWindowsOS, CmpIC
from Misc import DirSaver, PosixPath, ToVimEval, Touch, ToUtf8
from Utils import VPrint, \
                  IsVDirNameIllegal, \
                  IsFileNameIllegal
from Utils import IsCCppSourceFile, \
                  IsCppHeaderFile, \
                  ExpandAllVariables, \
                  ExpandAllVariables_SList
from Utils import IsCppSourceFile, GetIncludesFromArgs, GetMacrosFromArgs
from Macros import CPP_HEADER_EXT, C_SOURCE_EXT, CPP_SOURCE_EXT, WSP_PATH_SEP
from Macros import PROJECT_FILE_SUFFIX
from Notifier import Notifier
from VidemSession import VidemSession

# 这个变量仅用于后向兼容
VimLiteDir = vim.eval('g:VidemDir')
VidemDir = vim.eval('g:VidemDir')

def ToAbsPath(project, path):
    ds = DirSaver()
    os.chdir(project.dirName)
    return os.path.abspath(path)

def PrettyIgnoredFiles(projName, ignFiles):
    project = ws.VLWIns.FindProjectByName(projName)
    result = []
    for igf in ignFiles:
        wp = ws.VLWIns.GetWspFilePathByFileName(ToAbsPath(project, igf))
        if not wp:
            continue
        wp = wp.partition(WSP_PATH_SEP)[2].partition(WSP_PATH_SEP)[2]
        result.append(wp)
    return result

def GenerateMenuList(li):
    liLen = len(li)
    if liLen:
        l = len(str(liLen - 1))
        return [li[0]] + \
                [ str('%*d. %s' % (l, i, li[i])) for i in range(1, liLen) ]
    else:
        return []

def Executable(cmd):
    '''检查命令是否存在'''
    return vim.eval("executable(%s)" % ToVimEval(cmd)) == '1'

def UseVIMCCC():
    '''辅助函数
    
    判断是否使用 VIMCCC 补全引擎'''
    return vim.eval("g:VLWorkspaceCodeCompleteEngine").lower() == 'vimccc'

def ToVimStr(s):
    '''把单引号翻倍，用于安全把字符串传到 vim
    NOTE: vim.command 里面必须是 '%s' 的形式
    DEPRECATED: 用 ToVimEval() 代替，只须用 %s 形式即可'''
    return s.replace("'", "''")

def System(cmd):
    '''更完备的 system，不会调用 shell，会比较快
    返回列表，[returncode, stdout, stderr]'''
    if isinstance(cmd, str):
        cmd = shlex.split(cmd)
    p = subprocess.Popen(cmd, shell=False,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()
    return [p.returncode, out, err]

class StartEdit:
    '''用于切换缓冲区可修改状态
    在需要作用的区域，必须保持一个引用！'''
    def __init__(self):
        self.bufnr = vim.eval("bufnr('%')")
        self.bak_ma = vim.eval("getbufvar(%s, '&modifiable')" % self.bufnr)
        vim.command("setlocal modifiable")
    
    def __del__(self):
        #vim.command("setlocal nomodifiable")
        vim.command("call setbufvar(%s, '&modifiable', %s)" 
            % (self.bufnr, self.bak_ma))

class videm(object):
    '''全局单例，暂时这样实现就够了'''
    # 工作空间
    wsp = None
    class org(object):
        '''构建器/组织插件，暂时只有c++的'''
        cpp = None

class VimLiteWorkspace(object):
    '''VimLite 工作空间对象，主要用于操作缓冲区和窗口
    
    所有操作假定已经在工作空间缓冲区'''
    # 结点类型
    NT_WORKSPACE = VLWorkspace.TYPE_WORKSPACE
    NT_PROJECT = VLWorkspace.TYPE_PROJECT
    NT_VIRTDIR = VLWorkspace.TYPE_VIRTUALDIRECTORY
    NT_FILE = VLWorkspace.TYPE_FILE

    # hooks，元素为 {'hook': hook, 'priority': 0, 'data': data}
    __addNodePostHooks = []
    __delNodePostHooks = []
    __rnmNodePostHooks = []

    # GetProjectCompileOptions() 成员函数的 flags 可用值，可用 & 和 | 操作
    ProjCmplOpts_Nothing = 0
    ProjCmplOpts_CCmplOpt = 1
    ProjCmplOpts_CppCmplOpt = 2
    ProjCmplOpts_IncludePaths = 4
    ProjCmplOpts_PrepdefMacros = 8 # 项目配置预定义宏控件里的值
    ProjCmplOpts_ExpdCCmplOpt = 16
    ProjCmplOpts_ExpdCppCmplOpt = 32
    ProjCmplOpts_ExpdCPrepdefMacros = 64 # 从编译选项里面提取，因为需要解析，慢
    ProjCmplOpts_ExpdCppPrepdefMacros = 128

    ### 各种通知链 ###
    # 事件包括：'open_pre', 'open_post', 'close_pre', 'close_post',
    #           'reload_pre', 'reload_post'
    wsp_ntf = Notifier('Workspace')

    # 工作空间右键菜单列表
    # menu_hook(wsp, data)
    popupMenuW = [
        'Please select an operation:',
        # ==========================
        'Create a New Project...',
        'Add an Existing Project...',
        '-Sep_Workspace-',
        'New Workspace...',
        'Open Workspace...',
        'Close Workspace',
        'Reload Workspace',
        '-Sep_Session-',
        'Load Session...',
        'Save Session...',
        '-Sep_BatchBuilds-',
        'Batch Builds',
        '-Sep_Symdb-',
        'Initialize Symbol Database',
        'Update Symbol Database',
        '-Sep_Settings-',
        'Workspace Build Configuration...',
        'Workspace Batch Build Settings...',
        'Workspace Settings...',
    ]

    # 'menu': [hook, priv]
    # hook(wsp, item, priv)
    __popupMenuW_mapping = {}

    @staticmethod
    def __InsertMenuItem(menu, item, index, mapping, hook, priv):
        if mapping.has_key(item):
            return -1
        menu.insert(index, item)
        mapping[item] = [hook, priv]
        return 0

    @staticmethod
    def __RemoveMenuItem(menu, item, mapping):
        if not mapping.has_key(item):
            return -1
        menu.remove(item)
        del mapping[item]
        return 0

    @staticmethod
    def InsertWMenu(index, item, hook, priv):
        ret = VidemWorkspace.__InsertMenuItem(
            VidemWorkspace.popupMenuW, item, index,
            VidemWorkspace.__popupMenuW_mapping, hook, priv)
        if ret == 0:
            VidemWorkspace.ReinstallPopupMenuW()
        return ret

    @staticmethod
    def RemoveWMenu(item):
        ret = VidemWorkspace.__RemoveMenuItem(
            VidemWorkspace.popupMenuW, item,
            VidemWorkspace.__popupMenuW_mapping)
        if ret == 0:
            VidemWorkspace.ReinstallPopupMenuW()
        return ret

    def __init__(self, fileName = ''):
        self.VLWIns = VLWorkspaceST.Get() # python VLWorkspace 对象实例
        # 构建器实例
        self.builder = BuilderManagerST.Get().GetActiveBuilderInstance()
        self.VLWSettings = VLWorkspaceSettings() # 工作空间设置实例

        # FIXME: 迟早要干掉这个变量，用 self.plug_data = {} 代替即可
        self.clangIndices = {} # 项目名字到 clang.cindex.Index 实例的字典

        # 标识任何跟构建相关的设置的最后修改时间，粗略算法，可能更新的场合有:
        # (1) 选择工作区构建设置
        # (2) 修改了工作区构建设置
        # (3) 修改了项目的构建设置
        # (4) 修改了全局的头文件搜索路径
        self.buildMTime = time.time()

        # 项目右键菜单列表
        self.popupMenuP = ['Please select an operation:', 
#            'Import Files From Directory... (Unrealized)', 
            'Build', 
            'Rebuild', 
            'Clean', 
#            'Stop Build (Unrealized)', 
            '-Sep1-', 
            'Export Makefile' ,
            '-Sep2-', 
            'Set As Active', 
            '-Sep3-', 
#            'Build Order... (Unrealized)', 
#            'Re-Tag Project (Unrealized)', 
#            'Sort Items (Unrealized)', 
            'Add a New File...', 
            'Add Existing Files...', 
            '-Sep7-',
            'New Virtual Folder...', 
            'Import Files From Directory...', 
            '-Sep4-', 
            'Enable Files (Non-Recursive)',
            'Disable Files (Non-Recursive)',
            'Swap Enabling (Non-Recursive)',
            '-Sep8-',
#            'Rename Project... (Unrealized)', 
            'Remove Project', 
            '-Sep5-', 
            'Edit PCH Header For Clang...', 
            '-Sep6-', 
            'Settings...' ]

        # PCH 貌似已经不需要了，因为用 libclang，PCH 反而添乱
        if not UseVIMCCC() or True:
            self.popupMenuP.remove('Edit PCH Header For Clang...')
            self.popupMenuP.remove('-Sep6-')

        # 虚拟目录右键菜单列表
        self.popupMenuV = ['Please select an operation:', 
            'Add a New File...', 
            'Add Existing Files...', 
            '-Sep1-',
            'New Virtual Folder...', 
            'Import Files From Directory...', 
#            'Sort Items (Unrealized)', 
            '-Sep2-',
            'Enable Files (Non-Recursive)',
            'Disable Files (Non-Recursive)',
            'Swap Enabling (Non-Recursive)',
            '-Sep3-',
            'Rename...', 
            'Remove Virtual Folder' ]

        # 文件右键菜单列表
        self.popupMenuF = ['Please select an operation:', 
                'Open', 
                #'-Sep1-',
                #'Compile (Unrealized)', 
                #'Preprocess (Unrealized)', 
                '-Sep2-',
                'Enable This File',
                'Disable This File',
                'Swap Enabling',
                '-Sep3-',
                'Rename...', 
                'Remove' ]

        # 当前工作区选择构建设置名字，缓存，用于快速访问
        # self.RefreshStatusLine() 可以刷新此缓存
        self.cache_confName = ''

        if fileName:
            self.OpenWorkspace(fileName)

        # 创建窗口
        self.CreateWindow()
        # 设置键位绑定。当前光标必须在需要设置键位绑定的缓冲区中
        vim.command("call s:SetupKeyMappings()")
        
        self.InstallPopupMenu()

        # 创建窗口后需要执行的一些动作
        self.SetupStatusLine()
        self.RefreshStatusLine()
        self.RefreshBuffer()
        self.SetupActiveProject()

        self.cache_predefineMacros = {} # <项目名, 宏列表> 的缓存
        self.ctime_predefineMacros = {} # <项目名，缓存时间>

        self.debug = None

    def CallAddNodePostHooks(self, nodepath, nodetype, files):
        for hook in self.__addNodePostHooks:
            hook['hook'](self, nodepath, nodetype, files, hook['data'])

    def CallDelNodePostHooks(self, nodepath, nodetype, files):
        for hook in self.__delNodePostHooks:
            hook['hook'](self, nodepath, nodetype, files, hook['data'])

    def CallRnmNodePostHooks(self, nodepath, nodetype, oldfile, newfile):
        for hook in self.__rnmNodePostHooks:
            hook['hook'](self, nodepath, nodetype, oldfile, newfile,
                         hook['data'])

    def CreateWindow(self):
        # 创建窗口
        vim.command("call s:CreateVLWorkspaceWin()")
        self.buffer = vim.current.buffer
        self.bufNum = self.buffer.number
        # 这个属性需要动态获取
        #self.window = vim.current.window

    @property
    def window(self):
        '''如果之前获取 self.window 的属性的时候，光标都是在工作区的窗口的话，
        这样做就不会有问题了'''
        return vim.current.window

    def OpenWorkspace(self, fileName):
        if not fileName:
            return
        VidemWorkspace.wsp_ntf.CallChain('open_pre', self)
        self.VLWIns.OpenWorkspace(fileName)
        self.VLWIns._SetStatus(type(self.VLWIns).STATUS_CLOSED)
        # 这里载入工作区设置的时候，工作区应该是CLOSE状态
        # 实现问题，因为获取配置文件需要先打开工作区
        self.LoadWspSettings()
        self.VLWIns._SetStatus(type(self.VLWIns).STATUS_OPEN)
        self.RefreshStatusLine()
        self.SetupActiveProject()
        VidemWorkspace.wsp_ntf.CallChain('open_post', self)
        vim.command('call s:AutoLoadSession()') # 会话处理

    def CloseWorkspace(self):
        if not self.IsOpen():
            return
        VidemWorkspace.wsp_ntf.CallChain('close_pre', self)
        # XXX: 这个自动命令需要更明确的语义，暂时未用
        #vim.command('doautocmd VLWorkspace VimLeave *')
        vim.command('call s:AutoSaveSession()') # 会话处理
        vim.command('redraw | echo ""') # 清理输出...
        vim.command('call s:CloseWorkspaceFiles()')
        self.VLWIns.CloseWorkspace()
        self.RefreshStatusLine()
        VidemWorkspace.wsp_ntf.CallChain('close_post', self)
        # 还原配置
        vim.command('call videm#wsp#WspConfRestore()')
        # 还原后缀设置
        Utils.CSrcExtReset()
        Utils.CppSrcExtReset()

    def ReloadWorkspace(self):
        VidemWorkspace.wsp_ntf.CallChain('reload_pre', self)
        fileName = self.VLWIns.fileName
        self.CloseWorkspace()
        self.OpenWorkspace(fileName)
        self.RefreshBuffer()
        VidemWorkspace.wsp_ntf.CallChain('reload_post', self)

    def UpdateBuildMTime(self):
        self.buildMTime = time.time()

    def LoadWspSettings(self):
        if self.VLWIns.fileName:
            # 读取配置文件
            settingsFile = os.path.splitext(self.VLWIns.fileName)[0] \
                + '.wspsettings'
            self.VLWSettings.SetFileName(settingsFile)
            self.VLWSettings.Load()
            # 通知全局环境变量设置当前选择的组别名字
            EnvVarSettingsST.Get().SetActiveSetName(
                self.VLWSettings.GetEnvVarSetName())
            # 设置全局源文件判断
            Utils.CSrcExtReset()
            Utils.CppSrcExtReset()
            for i in self.VLWSettings.cSrcExts:
                C_SOURCE_EXT.add(i)
            for i in self.VLWSettings.cppSrcExts:
                CPP_SOURCE_EXT.add(i)
            # 根据载入的工作区配置刷新全局的配置
            if self.VLWSettings.enableLocalConfig:
                vim.command("call videm#wsp#WspConfSetCurrFromText(%s)"
                            % ToVimEval(self.VLWSettings.GetLocalConfigText()))

    def SaveWspSettings(self):
        return self.VLWSettings.Save()

    def InstallPopupMenu(self):
        for idx, value in enumerate(self.popupMenuW):
            if idx == 0:
                continue
            elif value[:4] == '-Sep':
                # 菜单分隔符
                vim.command("an <silent> 100.%d ]VLWorkspacePopup.%s <Nop>" 
                    % (idx * 10, value))
            else:
                vim.command("an <silent> 100.%d ]VLWorkspacePopup.%s "\
                    ":call videm#wsp#MenuOperation('W_%s')<CR>" 
                    % (idx * 10, value.replace(' ', '\\ ').replace('.', '\\.'), 
                       value))
        for idx in range(1, len(self.popupMenuP)):
            value = self.popupMenuP[idx]
            if value[:4] == '-Sep':
                vim.command("an <silent> 100.%d ]VLWProjectPopup.%s <Nop>" 
                    % (idx * 10, value))
            else:
                vim.command("an <silent> 100.%d ]VLWProjectPopup.%s "\
                    ":call videm#wsp#MenuOperation('P_%s')<CR>" 
                    % (idx * 10, value.replace(' ', '\\ ').replace('.', '\\.'), 
                       value))
        for idx in range(1, len(self.popupMenuV)):
            value = self.popupMenuV[idx]
            if value[:4] == '-Sep':
                vim.command("an <silent> ]VLWVirtualDirectoryPopup.%s <Nop>" 
                    % value)
            else:
                vim.command("an <silent> ]VLWVirtualDirectoryPopup.%s "\
                    ":call videm#wsp#MenuOperation('V_%s')<CR>" 
                    % (value.replace(' ', '\\ ').replace('.', '\\.'), value))
        for idx in range(1, len(self.popupMenuF)):
            value = self.popupMenuF[idx]
            if value[:4] == '-Sep':
                vim.command("an <silent> ]VLWFilePopup.%s <Nop>" % value)
            else:
                vim.command("an <silent> ]VLWFilePopup.%s "\
                    ":call videm#wsp#MenuOperation('F_%s')<CR>" 
                    % (value.replace(' ', '\\ ').replace('.', '\\.'), value))

    @staticmethod
    def ReinstallPopupMenuW():
        '''Windows 下面的 popup 菜单有 bug，无法正常删除菜单'''
        vim.command("silent! aunmenu ]VLWorkspacePopup")
        for idx, value in enumerate(VidemWorkspace.popupMenuW):
            if idx == 0:
                continue
            elif value[:4] == '-Sep':
                # 菜单分隔符
                vim.command("an <silent> 100.%d ]VLWorkspacePopup.%s <Nop>" 
                    % (idx * 10, value))
            else:
                if IsWindowsOS() and value == 'Batch Builds':
                    '''Windows 下删除菜单有问题'''
                    continue
                vim.command("an <silent> 100.%d ]VLWorkspacePopup.%s "\
                    ":call videm#wsp#MenuOperation('W_%s')<CR>" 
                    % (idx * 10, value.replace(' ', '\\ ').replace('.', '\\.'), 
                       value))

    def ReinstallPopupMenuP(self):
        '''Windows 下面的 popup 菜单有 bug，无法正常删除菜单'''
        vim.command("silent! aunmenu ]VLWProjectPopup")
        for idx in range(1, len(self.popupMenuP)):
            value = self.popupMenuP[idx]
            if value[:4] == '-Sep':
                vim.command("an <silent> 100.%d ]VLWProjectPopup.%s <Nop>" 
                    % (idx * 10, value))
            else:
                vim.command("an <silent> 100.%d ]VLWProjectPopup.%s "\
                    ":call videm#wsp#MenuOperation('P_%s')<CR>" 
                    % (idx * 10, value.replace(' ', '\\ ').replace('.', '\\.'), 
                       value))

    def RefreshBuffer(self):
        '''根据内部数据刷新显示，必须保证内部数据是正确且完整的，否则没用
        只刷新工作区所属的行，其他行不刷新'''
        if not self.buffer or not self.window:
            return

        se = StartEdit()

        texts = self.VLWIns.GetAllDisplayTexts()
        self.buffer[self.VLWIns.GetRootLineNum()-1:] = texts

    def SetupStatusLine(self):
        vim.command('setlocal statusline=%!VLWStatusLine()')

    def RefreshStatusLine(self):
        #string = self.VLWIns.GetName() + '[' + \
            #self.VLWIns.GetBuildMatrix().GetSelectedConfigName() \
            #+ ']'
        #vim.command("call setwinvar(bufwinnr(%d), '&statusline', '%s')" 
            #% (self.bufNum, ToVimStr(string)))
        self.cache_confName = \
                self.VLWIns.GetBuildMatrix().GetSelectedConfigName()

    def GetSHSwapList(self, fileName):
        '''获取源/头文件切换列表'''
        if not fileName:
            return

        name = os.path.splitext(os.path.basename(fileName))[0]
        results = []

        if IsCCppSourceFile(fileName):
            for ext in CPP_HEADER_EXT:
                swapFileName = name + ext
                if self.VLWIns.fname2file.has_key(swapFileName):
                    results.extend(self.VLWIns.fname2file[swapFileName])
        elif IsCppHeaderFile(fileName):
            exts = C_SOURCE_EXT.union(CPP_SOURCE_EXT)
            for ext in exts:
                swapFileName = name + ext
                if self.VLWIns.fname2file.has_key(swapFileName):
                    results.extend(self.VLWIns.fname2file[swapFileName])
        else:
            pass

        results.sort(CmpIC)
        return results

    def SwapSourceHeader(self, fileName):
        '''切换源/头文件，仅对在工作区中的文件有效
        仅切换在同一项目中的文件
        
        fileName 必须是绝对路径，否则会直接返回'''
        project = self.VLWIns.GetProjectByFileName(fileName)
        if not os.path.isabs(fileName) or not project:
            return

        swapFiles = self.GetSHSwapList(fileName)
        for fn in swapFiles[:]:
            '''检查切换的两个文件是否在同一个项目'''
            if project is not self.VLWIns.GetProjectByFileName(fn):
                try:
                    swapFiles.remove(fn)
                except ValueError:
                    pass
        if not swapFiles:
            vim.command("echohl WarningMsg")
            vim.command("echo 'No matched file was found!'")
            vim.command("echohl None")
            return

        if len(swapFiles) == 1:
            vim.command("e %s" % swapFiles[0])
        else:
            choice = vim.eval("inputlist(%s)" 
                % GenerateMenuList(['Please select:'] + swapFiles))
            choice = int(choice) - 1
            if choice >= 0 and choice < len(swapFiles):
                vim.command("e %s" % swapFiles[choice])

    def FindFiles(self, matchName, noCase = False):
        if not matchName:
            return

        fnames = self.VLWIns.fname2file.keys()
        fnames.sort()
        results = []
        questionList = []
        for fname in fnames:
            fname2 = fname
            matchName2 = matchName
            if noCase:
                fname2 = fname.lower()
                matchName2 = matchName.lower()
            if matchName2 in fname2:
                tmpList = []
                for absFileName in self.VLWIns.fname2file[fname]:
                    results.append(absFileName)
                    tmpList.append('%s --> %s' % (fname, absFileName))
                # BUG: questionList 排序了，results 没有排序，不一致
                #tmpList.sort()
                questionList.extend(tmpList)

        if not results:
            vim.command('echohl WarningMsg')
            vim.command('echo "No matched file was found!"')
            vim.command('echohl None')
            return

        try:
            # 如果按 q 退出了, 会抛出错误
            choice = vim.eval("inputlist(%s)" 
                % GenerateMenuList(['Pleace select:'] + questionList))
            #echoList = GenerateMenuList(['Pleace select:'] + questionList)
            #vim.command('echo "%s"' % '\n'.join(echoList))
            #choice = vim.eval(
                #'input("Type number and <Enter> (empty cancels): ")')
            choice = int(choice) - 1
            if choice >= 0 and choice < len(questionList):
                vim.command("call s:OpenFile('%s')" % ToVimStr(results[choice]))
        except:
            pass


    #===========================================================================
    # 基本操作 ===== 开始
    #===========================================================================

    def FoldNode(self):
        se = StartEdit()
        lnum = self.window.cursor[0]
        ret = self.VLWIns.Fold(lnum)
        self.buffer[lnum-1] = self.VLWIns.GetLineText(lnum)
        if ret > 0:
            del self.buffer[lnum:lnum+ret]

    def ExpandNode(self):
        #vim.command("call vlutils#TimerStart()")
        se = StartEdit()
        lnum = self.window.cursor[0]
        if not self.VLWIns.IsNodeExpand(lnum):
            ret = self.VLWIns.Expand(lnum)
            texts = []
            for i in range(lnum+1, lnum+1+ret):
                texts.append(self.VLWIns.GetLineText(i))
            self.buffer[lnum-1] = self.VLWIns.GetLineText(lnum)
            if texts != []:
                self.buffer.append(texts, lnum)
        #vim.command("call vlutils#TimerEndEcho()")

    def OnMouseDoubleClick(self, key = ''):
        lnum = self.window.cursor[0]
        nodeType = self.VLWIns.GetNodeTypeByLineNum(lnum)
        if nodeType == VLWorkspace.TYPE_PROJECT \
             or nodeType == VLWorkspace.TYPE_VIRTUALDIRECTORY:
            if self.VLWIns.IsNodeExpand(lnum):
                self.FoldNode()
            else:
                self.ExpandNode()
        elif nodeType == VLWorkspace.TYPE_FILE:
            absFile = self.VLWIns.GetFileByLineNum(lnum, True).replace("'", "''")
            if not key or key == vim.eval("g:VLWOpenNodeKey"):
                vim.command('call s:OpenFile(\'%s\', 0)' % absFile)
            elif key == vim.eval("g:VLWOpenNode2Key"):
                vim.command('call s:OpenFile(\'%s\', 1)' % absFile)
            elif key == vim.eval("g:VLWOpenNodeInNewTabKey"):
                vim.command('call s:OpenFileInNewTab(\'%s\', 0)' % absFile)
            elif key == vim.eval("g:VLWOpenNodeInNewTab2Key"):
                vim.command('call s:OpenFileInNewTab(\'%s\', 1)' % absFile)
            elif key == vim.eval("g:VLWOpenNodeSplitKey"):
                vim.command('call s:OpenFileSplit(\'%s\', 0)' % absFile)
            elif key == vim.eval("g:VLWOpenNodeSplit2Key"):
                vim.command('call s:OpenFileSplit(\'%s\', 1)' % absFile)
            elif key == vim.eval("g:VLWOpenNodeVSplitKey"):
                vim.command('call s:OpenFileVSplit(\'%s\', 0)' % absFile)
            elif key == vim.eval("g:VLWOpenNodeVSplit2Key"):
                vim.command('call s:OpenFileVSplit(\'%s\', 1)' % absFile)
            else:
                pass
        elif nodeType == VLWorkspace.TYPE_WORKSPACE:
            vim.command('call s:ChangeBuildConfig()')
        else:
            pass

    def OnRightMouseClick(self):
        row, col = self.window.cursor
        nodeType = self.VLWIns.GetNodeTypeByLineNum(row)
        if nodeType == VLWorkspace.TYPE_FILE: #文件右键菜单
            vim.command("popup ]VLWFilePopup")
        elif nodeType == VLWorkspace.TYPE_VIRTUALDIRECTORY: #虚拟目录右键菜单
            vim.command("popup ]VLWVirtualDirectoryPopup")
        elif nodeType == VLWorkspace.TYPE_PROJECT: #项目右键菜单
            if IsWindowsOS():
                self.ReinstallPopupMenuP()
            vim.command(
                "silent! aunmenu ]VLWProjectPopup.Custom\\ Build\\ Targets")
            project = self.VLWIns.GetDatumByLineNum(row)['project']
            projName = project.GetName()
            matrix = self.VLWIns.GetBuildMatrix()
            wspSelConfName = matrix.GetSelectedConfigurationName()
            projSelConfName = matrix.GetProjectSelectedConf(wspSelConfName, 
                                                            projName)
            bldConf = self.VLWIns.GetProjBuildConf(projName, projSelConfName)
            if bldConf and bldConf.IsCustomBuild():
                targets = bldConf.GetCustomTargets().keys()
                targets.sort()
                for target in targets:
                    menuNumber = 25
                    try:
                        # BUG: Clean 为 30, 这里要 25 才能在 Clean 之后
                        menuNumber = self.popupMenuP.index('Clean') * 10 - 5
                        if IsWindowsOS():
                            menuNumber += 10
                    except ValueError:
                        pass
                    vim.command("an <silent> 100.%d ]VLWProjectPopup."
                        "Custom\\ Build\\ Targets.%s "
                        ":call videm#wsp#MenuOperation('P_C_%s')<CR>" 
                        % (menuNumber, 
                           target.replace(' ', '\\ ').replace('.', '\\.'), 
                           target))

            vim.command("popup ]VLWProjectPopup")
        elif nodeType == VLWorkspace.TYPE_WORKSPACE: #工作空间右键菜单
            if IsWindowsOS():
                VidemWorkspace.ReinstallPopupMenuW()
            # 先删除上次添加的菜单
            vim.command("silent! aunmenu ]VLWorkspacePopup.Batch\\ Builds")
            vim.command("silent! aunmenu ]VLWorkspacePopup.Batch\\ Cleans")
            names = self.VLWSettings.GetBatchBuildNames()
            if names:
                # 添加 Batch Build 和 Batch Clean 目标
                names.sort()
                for name in names:
                    menuNumber = 75
                    try:
                        menuNumber = self.popupMenuW.index('Batch Builds')
                        menuNumber = (menuNumber - 1) * 10 - 5
                        if IsWindowsOS():
                            menuNumber += 10
                    except ValueError:
                        pass
                    name2 = name.replace(' ', '\\ ').replace('.', '\\.')
                    vim.command("an <silent> 100.%d ]VLWorkspacePopup."
                        "Batch\\ Builds.%s "
                        ":call videm#wsp#MenuOperation('W_BB_%s')<CR>"
                        % (menuNumber, name2, name))
                    name2 = name.replace(' ', '\\ ').replace('.', '\\.')
                    vim.command("an <silent> 100.%d ]VLWorkspacePopup."
                        "Batch\\ Cleans.%s "
                        ":call videm#wsp#MenuOperation('W_BC_%s')<CR>"
                        % (menuNumber + 1, name2, name))

            vim.command("popup ]VLWorkspacePopup")
        else:
            pass

    def ChangeBuildConfig(self):
        choices = []
        names = []
        choices.append('Pleace select the configuration:')
        names.append('')

        matrix = self.VLWIns.GetBuildMatrix()
        selConfName = matrix.GetSelectedConfigurationName()
        x = 1
        curChoice = 0
        for i in matrix.GetConfigurations():
            pad = ' '
            if i.name == selConfName:
                pad = '*'
                curChoice = x
            choices.append("%s %d. %s" % (pad, x, ToUtf8(i.name)))
            names.append(i.name)
            x += 1

        choice = vim.eval('inputlist(%s)' % choices)
        choice = int(choice)

        if choice <= 0 or choice >= len(names) or choice == curChoice:
            return
        else:
            matrix.SetSelectedConfigurationName(names[choice])
            # NOTE: 所有有 ToXmlNode() 的类的保存方式都是通过 SetXXX 实现，
            # 而不是工作空间或项目的 Save()
            self.VLWIns.SetBuildMatrix(matrix)
            self.RefreshStatusLine()
            # 需要全部刷新，因为不同设置，忽略的文件不一样
            vim.command("call s:RefreshBuffer()")
            # 更新 buildMTime
            self.UpdateBuildMTime()

    def GotoParent(self):
        row, col = self.window.cursor
        parentRow = self.VLWIns.GetParentLineNum(row)
        if parentRow != row:
            vim.command("mark '")
            vim.command("exec %d" % parentRow)

    def GotoRoot(self):
        row, col = self.window.cursor
        rootRow = self.VLWIns.GetRootLineNum(row)
        if rootRow != row:
            vim.command("mark '")
            vim.command("exec %d" % rootRow)

    def GotoNextSibling(self):
        row, col = self.window.cursor
        lnum = self.VLWIns.GetNextSiblingLineNum(row)
        if lnum != row:
            vim.command("mark '")
            vim.command('exec %d' % lnum)

    def GotoPrevSibling(self):
        row, col = self.window.cursor
        lnum = self.VLWIns.GetPrevSiblingLineNum(row)
        if lnum != row:
            vim.command("mark '")
            vim.command('exec %d' % lnum)

    def AddFileNode(self, row, name):
        return self.AddFileNodes(row, [name])

    def AddFileNodes(self, row, names):
        if type(names) != type([]) or not names or not names[0]:
            return

        row = int(row)
        # 确保节点展开
        self.ExpandNode()

        se = StartEdit()
        # TODO: 同名的话，返回 0，可发出相应的警告
        for idx in range(len(names)):
            if idx == len(names) - 1:
                # 最后的，保存
                ret = self.VLWIns.AddFileNode(row, names[idx])
                # 强制保存
                try:
                    project = self.VLWIns.GetDatumByLineNum(row)['project']
                    project.Save()
                except:
                    print 'Save project filed after AddFileNodes()'
                    pass
            else:
                ret = self.VLWIns.AddFileNodeQuickly(row, names[idx])
            # 只需刷新添加的节点的上一个兄弟节点到添加的节点之间的显示
            ln = self.VLWIns.GetPrevSiblingLineNum(ret)
            if ln == ret:
                ln = row

            texts = []
            for i in range(ln, ret + 1):
                texts.append(self.VLWIns.GetLineText(i))
            if texts:
                self.buffer[ln - 1 : ret - 1] = texts

        # post action
        self.CallAddNodePostHooks(self.VLWIns.GetNodePathByLineNum(row),
                                  self.VLWIns.GetNodeTypeByLineNum(row), names)

    def AddVirtualDirNode(self, row, name):
        if not name:
            return

        row = int(row)
        # 确保节点展开
        self.ExpandNode()

        se = StartEdit()
        # TODO: 同名的话，返回 0，可发出相应的警告
        ret = self.VLWIns.AddVirtualDirNode(row, name)

        # 只需刷新添加的节点的上一个兄弟节点到添加的节点之间的显示
        ln = self.VLWIns.GetPrevSiblingLineNum(ret)
        if ln == ret:
            ln = row

        # 获取 n+1 行文本，替换原来的 n 行文本，也就是新增了 1 行文本
        texts = []
        for i in range(ln, ret + 1):
            texts.append(self.VLWIns.GetLineText(i))
        if texts:
            self.buffer[ln - 1 : ret - 1] = texts

        # post action
        self.CallAddNodePostHooks(self.VLWIns.GetNodePathByLineNum(row),
                                  self.VLWIns.GetNodeTypeByLineNum(row), [])

    def AddProjectNode(self, row, projFile):
        ext = os.path.splitext(projFile)[1]
        if ext != os.path.extsep + PROJECT_FILE_SUFFIX and ext != '.project':
            print 'Not a valid project file: %s' % projFile
            return

        row = int(row)

        s1 = set(self.VLWIns.GetProjectList())

        se = StartEdit()
        # TODO: 同名的话，返回 0，可发出相应的警告
        ret = self.VLWIns.AddProject(projFile)
        succeed = ret != 0
        if not succeed:
            return

        # 通过这种搓方法获取新添加的项目名字，没办法，不想改接口就只能这样了
        s2 = set(self.VLWIns.GetProjectList())
        s3 = s2 - s1
        projName = s3.pop()
        self.VLWIns.TouchProject(projName)

        # 只需刷新添加的节点的上一个兄弟节点到添加的节点之间的显示
        ln = self.VLWIns.GetPrevSiblingLineNum(ret)
        if ln == ret:
            ln = row

        # 获取 n+1 行文本，替换原来的 n 行文本，也就是新增了 1 行文本
        texts = []
        for i in range(ln, ret + 1):
            texts.append(self.VLWIns.GetLineText(i))
        if texts:
            self.buffer[ln - 1 : ret - 1] = texts

        # post action
        self.CallAddNodePostHooks(self.VLWIns.GetNodePathByLineNum(row),
                                  self.VLWIns.GetNodeTypeByLineNum(row),
                                  self.VLWIns.FindProjectByName(projName).\
                                    GetAllFiles(True))

    def ImportFilesFromDirectory(self, row, importDir, filters, files = []):
        '''
        files:  输出添加成功的文件列表，绝对路径'''
        if not importDir:
            return
        self.ExpandNode()
        ret = self.VLWIns.ImportFilesFromDirectory(row, importDir, filters,
                                                   files)
        if ret:
            # 只需刷新添加的节点的上一个兄弟节点到添加的节点之间的显示
            se = StartEdit()
            ln = self.VLWIns.GetPrevSiblingLineNum(ret)
            if ln == ret:
                ln = row
            texts = []
            for i in range(ln, ret + 1):
                texts.append(self.VLWIns.GetLineText(i))
            if texts:
                self.buffer[ln - 1 : ret - 1] = texts

        # post action
        self.CallAddNodePostHooks(self.VLWIns.GetNodePathByLineNum(row),
                                  self.VLWIns.GetNodeTypeByLineNum(row), files)

    def DeleteNode(self, row):
        '''返回删除的file列表，绝对路径'''
        row = int(row)
        prevLn = self.VLWIns.GetPrevSiblingLineNum(row)  #用于刷新操作
        nextLn = self.VLWIns.GetNextSiblingLineNum(row)  #用于刷新操作

        nodeType = self.VLWIns.GetNodeTypeByLineNum(row)
        nodePath = self.VLWIns.GetNodePathByLineNum(row)
        projName = ''
        if nodeType == VidemWorkspace.NT_FILE:
            files = [self.VLWIns.GetFileByLineNum(row, True)]
        elif nodeType == VidemWorkspace.NT_VIRTDIR:
            # TODO: 可优化
            s1 = set(self.VLWIns.GetAllFiles(True))
        elif nodeType == VidemWorkspace.NT_PROJECT:
            projName = self.VLWIns.GetDispNameByLineNum(row)
            files = self.VLWIns.FindProjectByName(projName).GetAllFiles(True)
        ret = self.VLWIns.DeleteNode(row)

        se = StartEdit()
        # 如果删除的节点没有下一个兄弟节点时，应刷新上一兄弟节点的所有子节点
        # TODO: 可用判断是否拥有下一个兄弟节点函数来优化
        if nextLn == row:
            # 刷新指定的数行
            self.RefreshLines(prevLn, row)
            #texts = []
            #for i in range(prevLn, row):
            #    texts.append(self.VLWIns.GetLineText(i))
            #self.buffer[prevLn-1:row-1] = texts

        del self.buffer[row-1:row-1+ret]

        # 当删除的项目为激活的项目, 需要进一步处理
        if projName == self.GetActiveProjectName():
            # 现在只需要刷新一次即可
            vim.command("call s:RefreshBuffer()")

        if nodeType == VidemWorkspace.NT_VIRTDIR:
            # 可优化
            s2 = set(self.VLWIns.GetAllFiles(True))
            files = list(s1 - s2)

        # post action
        self.CallDelNodePostHooks(nodePath, nodeType, files)

        return files

    def SetupActiveProject(self):
        '''这个函数的含义已经变了, 现在仅用于刷新指定配置'''
        hlname = vim.eval('videm#settings#Get(".videm.wsp.ActProjHlGroup")')
        vim.command("hi link VLWActiveProject %s" % hlname)

    def RefreshLines(self, start, end):
        '''刷新数行，不包括 end 行'''
        se = StartEdit()

        start = int(start)
        end = int(end)
        texts = []
        for i in range(start, end):
            texts.append(self.VLWIns.GetLineText(i))
        if texts:
            self.buffer[start-1:end-1] = texts

    def DebugProject(self, projName, hasProjFile = False, firstRun = True):
        if not self.VLWIns.FindProjectByName(projName):
            return

        ds = DirSaver()

        wspSelConfName = self.VLWIns.GetBuildMatrix()\
            .GetSelectedConfigurationName()
        confToBuild = self.VLWIns.GetBuildMatrix().GetProjectSelectedConf(
            wspSelConfName, projName)
        bldConf = self.VLWIns.GetProjBuildConf(projName, confToBuild)

        try:
            os.chdir(self.VLWIns.FindProjectByName(projName).dirName)
        except OSError:
            return
        wd = ExpandAllVariables(
            bldConf.workingDirectory, self.VLWIns, projName, confToBuild, '')
        try:
            if wd:
                os.chdir(wd)
        except OSError:
            return
        #print os.getcwd()

        prog = bldConf.GetCommand()
        if bldConf.useSeparateDebugArgs:
            args = bldConf.debugArgs
        else:
            args = bldConf.commandArguments
        prog = ExpandAllVariables(prog, self.VLWIns, projName, 
            confToBuild, '')
        #print prog
        args = ExpandAllVariables(args, self.VLWIns, projName, 
            confToBuild, '')
        #print args
        if firstRun and prog:
        # 第一次运行, 只要启动 pyclewn 即可
            # BUG: 在 python 中运行以下两条命令, 会出现同名但不同缓冲区的大问题!
            # 暂时只能由外部运行 Pyclewn
            #vim.command("silent cd %s" % os.getcwd())
            #vim.command("silent Pyclewn")
            if not hasProjFile:
                # NOTE: 不能处理目录名称的第一个字符为空格的情况
                # TODO: Cfile 要处理特殊字符，能处理多少是多少
                if IsWindowsOS():
                    vim.command("silent Ccd %s/" % PosixPath(os.getcwd()))
                    vim.command("Cfile '%s'" % PosixPath(prog))
                else:
                    vim.command("silent Ccd %s/" % os.getcwd())
                    vim.command("Cfile '%s'" % prog)
            if args:
                vim.command("Cset args %s" % args)
            #vim.command("silent cd -")
            #if not hasProjFile:
                #vim.command("Cstart")
        else:
        # 非第一次运行, 只要运行 Crun 即可
            # 为避免修改了程序参数, 需要重新设置程序参数, 即使为空, 也要设置
            vim.command("Cset args %s" % args)
            vim.command("Crun")

    def DebugActiveProject(self, hasProjFile = False, firstRun = True):
        actProjName = self.VLWIns.GetActiveProjectName()
        self.DebugProject(actProjName, hasProjFile, firstRun)

    def BuildProject(self, projName):
        '''构建成功返回 True，否则返回 False'''
        ds = DirSaver()
        try:
            os.chdir(self.VLWIns.dirName)
        except OSError:
            return False

        result = False

        cmd = self.builder.GetBuildCommand(projName, '')

        if cmd:
            if vim.eval("g:VLWorkspaceSaveAllBeforeBuild") != '0':
                vim.command("wa")
            tempFile = vim.eval('tempname()')
            if IsWindowsOS():
                #vim.command('!"%s >%s 2>&1"' % (cmd, tempFile))
                # 用 subprocess 模块代替
                p = subprocess.Popen('"C:\\WINDOWS\\system32\\cmd.exe" /c '
                    '"%s 2>&1 | tee %s && pause || pause"'
                    % (cmd, tempFile))
                p.wait()
            else:
                # 强制设置成英语 locale 以便 quickfix 处理
                cmd = "export LANG=en_US; " + cmd
                # NOTE: 这个命令无法返回 cmd 的执行返回值，蛋疼了...
                vim.command("!%s 2>&1 | tee %s" % (cmd, tempFile))
            vim.command('cgetfile %s' % tempFile)
            qflist = vim.eval('getqflist()')
            if qflist:
                lastLine = qflist[-1]['text']
                if lastLine.startswith('make: ***'): # make 出错标志
                    result = False
                else:
                    result = True

#           if False:
#               os.system("gnome-terminal -t 'make' -e "\
#                   "\"sh -c \\\"%s 2>&1 | tee '%s' "\
#                   "&& echo ========================================"\
#                   "&& echo -n This will close in 3 seconds... "\
#                   "&& read -t 3 i && echo Press ENTER to continue... "\
#                   "&& read i;"\
#                   "vim --servername '%s' "\
#                   "--remote-send '<C-\><C-n>:cgetfile %s "\
#                   "| echo \\\\\\\"Readed the error file.\\\\\\\"<CR>'\\\"\" &"
#                   % (cmd, tempFile, vim.eval('v:servername'), 
#                      tempFile.replace(' ', '\\ ')))

        return result

    def CleanProject(self, projName):
        ds = DirSaver()
        try:
            os.chdir(self.VLWIns.dirName)
        except OSError:
            return

        cmd = self.builder.GetCleanCommand(projName, '')

        if cmd:
            tempFile = vim.eval('tempname()')
            if IsWindowsOS():
                #vim.command('!"%s >%s 2>&1"' % (cmd, tempFile))
                p = subprocess.Popen('"C:\\WINDOWS\\system32\\cmd.exe" /c '
                    '"%s 2>&1 | tee %s && pause || pause"' % (cmd, tempFile))
                p.wait()
            else:
                # 强制设置成英语 locale 以便 quickfix 处理
                cmd = "export LANG=en_US; " + cmd
                vim.command("!%s 2>&1 | tee %s" % (cmd, tempFile))
            vim.command('cgetfile %s' % tempFile)

    def RebuildProject(self, projName):
        '''重构建项目，即先 Clean 再 Build'''
        ds = DirSaver()
        try:
            os.chdir(self.VLWIns.dirName)
        except OSError:
            return
        cmd = self.builder.GetCleanCommand(projName, '')
        if cmd:
            os.system("%s" % cmd)

        self.BuildProject(projName)

    def RunProject(self, projName):
        ds = DirSaver()

        projInst = self.VLWIns.FindProjectByName(projName)
        if not projInst:
            print 'Can not find a valid project!'
            return

        wspSelConfName = self.VLWIns.GetBuildMatrix()\
            .GetSelectedConfigurationName()
        confToBuild = self.VLWIns.GetBuildMatrix().GetProjectSelectedConf(
            wspSelConfName, projName)
        bldConf = self.VLWIns.GetProjBuildConf(projName, confToBuild)

        try:
            os.chdir(projInst.dirName)
        except OSError:
            print 'change directory failed:', projInst.dirName
            return
        wd = ExpandAllVariables(
            bldConf.workingDirectory, self.VLWIns, projName, confToBuild, '')
        try:
            if wd:
                os.chdir(wd)
        except OSError:
            print 'change directory failed:', wd
            return
        #print os.getcwd()

        prog = bldConf.GetCommand()
        args = bldConf.commandArguments
        prog = ExpandAllVariables(prog, self.VLWIns, projName, 
            confToBuild, '')
        #print prog
        args = ExpandAllVariables(args, self.VLWIns, projName, 
            confToBuild, '')
        #print args
        if prog:
            envs = ''
            envsDict = {}
            for envVar in EnvVarSettingsST.Get().GetActiveEnvVars():
                envs += envVar.GetString() + ' '
                envsDict[envVar.GetKey()] = envVar.GetValue()
            #print envs
            d = os.environ.copy()
            d.update(envsDict)
            global VidemDir
            if IsWindowsOS():
                vlterm = os.path.join(VidemDir, 'vlexec.py')
                if not prog.endswith('.exe'): prog += '.exe'
                prog = os.path.realpath(prog)
                if Executable('python'):
                    py = 'python'
                else:
                    py = os.path.join(sys.prefix, 'python.exe')
                    if not Executable(py):
                        print 'Can not find valid python interpreter'
                        print 'Please add python interpreter to "PATH"'
                        return
                p = subprocess.Popen([py, vlterm, prog] + shlex.split(args),
                                     env=d)
                p.wait()
            else:
                if vim.eval("has('gui_running')") == '1':
                    vlterm = os.path.join(VidemDir, 'vlterm')
                    # 理论上这种方式是最好的了，就是需要两个脚本 vlterm vlexec
                    p = subprocess.Popen([vlterm, prog] + shlex.split(args),
                                         env=d)
                    p.wait()
                else:
                    # 终端的vim下运行，相当难处理
                    argv = [prog] + shlex.split(args)
                    # NOTE: vim下面运行的话，只需要处理新增的环境变量就好了
                    #       这样的话，会受vim的环境变量影响
                    vim.command("call vlutils#RunCmd(%s, %s)"
                                    % (ToVimEval(argv), ToVimEval(envsDict)))

    def BuildActiveProject(self):
        actProjName = self.VLWIns.GetActiveProjectName()
        self.BuildProject(actProjName)

    def CleanActiveProject(self):
        actProjName = self.VLWIns.GetActiveProjectName()
        self.CleanProject(actProjName)

    def RunActiveProject(self):
        actProjName = self.VLWIns.GetActiveProjectName()
        self.RunProject(actProjName)

    def BuildAndRunProject(self, projName):
        if self.BuildProject(projName):
            # 构建成功
            self.RunProject(projName)

    def BuildAndRunActiveProject(self):
        actProjName = self.VLWIns.GetActiveProjectName()
        self.BuildAndRunProject(actProjName)

    def BatchBuild(self, batchBuildName, isClean = False):
        '''批量构建'''
        ds = DirSaver()
        try:
            os.chdir(self.VLWIns.dirName)
        except OSError:
            return

        buildOrder = self.VLWSettings.GetBatchBuildList(batchBuildName)
        matrix = self.VLWIns.GetBuildMatrix()
        wspSelConfName = matrix.GetSelectedConfigurationName()
        if isClean:
            cmd = self.builder.GetBatchCleanCommand(buildOrder, wspSelConfName)
        else:
            cmd = self.builder.GetBatchBuildCommand(buildOrder, wspSelConfName)

        if cmd:
            if not IsWindowsOS():
                # 强制设置成英语 locale 以便 quickfix 处理
                cmd = "export LANG=en_US; " + cmd
            if vim.eval("g:VLWorkspaceSaveAllBeforeBuild") != '0':
                vim.command("wa")
            tempFile = vim.eval('tempname()')
            vim.command("!%s 2>&1 | tee %s" % (cmd, tempFile))
            vim.command('cgetfile %s' % tempFile)

    def GetWorkspacePredefineMacros(self):
        '''获取全部项目的预定义宏，激活的项目的会放到最后'''
        extraMacros = []
        actProjName = self.VLWIns.GetActiveProjectName()
        for project in self.VLWIns.projects.itervalues():
            # 保证激活的项目的预定义宏放到最后
            if project.GetName() != actProjName:
                extraMacros.extend(
                    self.GetProjectPredefineMacros(project.GetName()))
        # 当前激活状态的项目的预定义宏最优先
        extraMacros.extend(self.GetProjectPredefineMacros(actProjName))
        return extraMacros

    def GetTagsSearchPaths(self):
        '''获取 tags 包含文件的搜索路径'''
        # 获取的必须是副本，不然可能会被修改
        globalPaths = TagsSettingsST.Get().includePaths[:]
        localPaths = self.VLWSettings.includePaths[:]
        results = []
        flag = self.VLWSettings.incPathFlag
        if flag == self.VLWSettings.INC_PATH_APPEND:
            results = globalPaths + localPaths
        elif flag == self.VLWSettings.INC_PATH_REPLACE:
            results = localPaths
        elif flag == self.VLWSettings.INC_PATH_PREPEND:
            results = localPaths + globalPaths
        elif flag == self.VLWSettings.INC_PATH_DISABLE:
            results = globalPaths
        else:
            pass

        return results

    def GetParserSearchPaths(self):
        '''获取用于parser的头文件搜索路径，这些路径*不*用于构建'''
        return self.GetTagsSearchPaths()

    def GetProjectIncludePaths4CodeComplete(self, projName, wspConfName = ''):
        '''获取用于代码补全的包含路径'''
        name = self.GetPorjectBuildConfigName(projName, wspConfName)
        bldConf = self.VLWIns.GetProjBuildConf(projName, name)
        if not bldConf:
            return []
        if bldConf.useSepCCEngArgs:
            # FIXME: 理论上应该先分割再展开，但可能有效率问题...
            #        只要展开的变量不存在';'就没有问题...
            return ExpandAllVariables_SList(
                    SplitSmclStr(ExpandAllVariables(bldConf.sepCCEngIncArgs)),
                    self.VLWIns, projName, name)
        else:
            return self.GetProjectIncludePaths(projName, wspConfName)

    def GetProjectPredefineMacros4CodeComplete(self, projName,
                                               wspConfName = ''):
        '''获取用于代码补全的预定义宏'''
        name = self.GetPorjectBuildConfigName(projName, wspConfName)
        bldConf = self.VLWIns.GetProjBuildConf(projName, name)
        if not bldConf:
            return []
        if bldConf.useSepCCEngArgs:
            return ExpandAllVariables_SList(
                    SplitSmclStr(bldConf.sepCCEngMacArgs),
                    self.VLWIns, projName, name)
        else:
            return self.GetProjectPredefineMacros(projName, wspConfName)

    def GetProjectIncludePaths(self, projName, wspConfName = ''):
        '''获取指定项目指定构建设置的头文件搜索路径，
        包括 C 和 C++ 的，并且会展开编译选项

        wspConfName 为空则获取当前激活的工作区构建设置
        
        返回绝对路径列表'''
        # 合并的结果
        cmplpaths = self.GetCompilerIncludePaths(projName,
                        self.GetPorjectBuildConfigName(projName, wspConfName))
        return cmplpaths + \
                self.GetProjectCompileOptions(projName, wspConfName, 4 | 16 | 32)

    def GetProjectPredefineMacros(self, projName, wspConfName = ''):
        '''返回预定义的宏的列表，
        包括 C 和 C++ 的，并且会展开编译选项'''
        if self.ctime_predefineMacros.get(projName, 0) >= self.buildMTime:
            return self.cache_predefineMacros.get(projName, [])
        else:
            # 合并的结果
            res = self.GetProjectCompileOptions(projName, wspConfName,
                                                8 | 64 | 128)
            # 缓存结果（副本）
            self.ctime_predefineMacros[projName] = time.time()
            self.cache_predefineMacros[projName] = res[:]
            return res

    def GetProjectCompileOptions(self, projName, wspConfName = '',
                                 flags = 2 | 4 | 8):
        '''获取编译选项，暂时只获取包含目录和预定义宏

        flags: 可用二进制的或操作
            0  -> 无
            1  -> C 编译器选项  (单个列表项目)
            2  -> C++ 编译器选项(单个列表项目)
            4  -> 包含路径
            8  -> 预定义宏
            16 -> 解析后的 C 编译器的包含路径（慢）
            32 -> 解析后的 C++ 编译器的包含路径（慢）
            64 -> 解析后的 C 编译器的预定义宏（慢）
            128-> 解析后的 C++ 编译器的预定义宏（慢）
        
        返回列表'''
        project = self.VLWIns.FindProjectByName(projName)
        if not project:
            return []

        matrix = self.VLWIns.GetBuildMatrix()
        if not wspConfName:
            wspConfName = matrix.GetSelectedConfigurationName()

        results = []
        cCompileOpts = []
        cppCompileOpts = []
        includePaths = []
        predefineMacros = []

        ds = DirSaver()
        try:
            os.chdir(project.dirName)
        except OSError:
            return []
        projConfName = matrix.GetProjectSelectedConf(wspConfName, project.name)
        if not projConfName:
            return []

        compiler = None
        cmplIncPaths = []

        # NOTE: 这个 bldConf 是已经合并了全局配置的一个副本，直接取值即可
        bldConf = self.VLWIns.GetProjBuildConf(project.name, projConfName)
        if not bldConf or bldConf.IsCustomBuild():
        # 这种情况直接不支持
            return []

        if bldConf and not bldConf.IsCustomBuild():
            compiler = BuildSettingsST().Get().GetCompilerByName(
                bldConf.GetCompilerType())
            if compiler:
                cmplIncPaths = SplitSmclStr(compiler.includePaths)
            tmpStr = bldConf.GetIncludePath()
            tmpIncPaths = cmplIncPaths + SplitSmclStr(tmpStr)
            tmpIncPaths = ExpandAllVariables_SList(tmpIncPaths, self.VLWIns,
                                                   projName, projConfName)
            for tmpPath in tmpIncPaths:
                if not tmpPath:
                    # NOTE: os.path.abspath('') 会返回当前目录
                    continue
                # 从 xml 里提取的字符串全部都是 unicode
                includePaths.append(os.path.abspath(tmpPath))

            tmpStr = bldConf.GetPreprocessor()
            predefineMacros += [i.strip()
                                for i in SplitSmclStr(tmpStr) if i.strip()]
            predefineMacros = ExpandAllVariables_SList(predefineMacros,
                                                       self.VLWIns, projName,
                                                       projConfName)

        # NOTE: 编译器选项是一个字符串，而不是列表
        optList = SplitSmclStr(bldConf.GetCCxxCompileOptions()) \
                + SplitSmclStr(bldConf.GetCCompileOptions())
        optList = ExpandAllVariables_SList(optList, self.VLWIns, projName,
                                           projConfName)
        cCompileOpts.append(' '.join(optList))
        optList = SplitSmclStr(bldConf.GetCCxxCompileOptions()) \
                + SplitSmclStr(bldConf.GetCxxCompileOptions())
        optList = ExpandAllVariables_SList(optList, self.VLWIns, projName,
                                           projConfName)
        cppCompileOpts.append(' '.join(optList))
        if flags & 1:
            # C 编译器选项
            results += cCompileOpts
        if flags & 2:
            # C++ 编译器选项
            results += cppCompileOpts
        if flags & 4:
            # 包含路径
            results += includePaths
        if flags & 8:
            # 预定义宏
            results += predefineMacros

        # 根据 switch 来解析命令行，只支持内置的编译器
        sw_map_inc = {
            'VC++': '/I',
            'clang': '-I',
            'clang++': '-I',
            'gnu gcc': '-I',
            'gnu g++': '-I',
        }
        sw_map_mac = {
            'VC++': '/D',
            'clang': '-D',
            'clang++': '-D',
            'gnu gcc': '-D',
            'gnu g++': '-D',
        }

        if flags & 16:
            # 解析后的 C 编译器的包含目录
            if compiler:
                sw = sw_map_inc.get(compiler.name, '')
                if sw:
                    tmpOpts = ' '.join(cCompileOpts)
                    tmp = GetIncludesFromArgs(tmpOpts, sw)
                    results += [os.path.abspath(i.lstrip(sw))
                                for i in tmp]
        if flags & 32:
            # 解析后的 C++ 编译器的包含目录
            if compiler:
                sw = sw_map_inc.get(compiler.name, '')
                if sw:
                    tmpOpts = ' '.join(cppCompileOpts)
                    tmp = GetIncludesFromArgs(tmpOpts, sw)
                    results += [os.path.abspath(i.lstrip(sw))
                                for i in tmp]
        if flags & 64:
            # 解析后的 C 编译器的预定义宏
            if compiler:
                sw = sw_map_mac.get(compiler.name, '')
                if sw:
                    tmpOpts = ' '.join(cCompileOpts)
                    tmp = GetMacrosFromArgs(tmpOpts, sw)
                    results += [i.lstrip(sw) for i in tmp]
        if flags & 128:
            # 解析后的 C++ 编译器的预定义宏
            if compiler:
                sw = sw_map_mac.get(compiler.name, '')
                if sw:
                    tmpOpts = ' '.join(cppCompileOpts)
                    tmp = GetMacrosFromArgs(tmpOpts, sw)
                    results += [i.lstrip(sw) for i in tmp]

        return results

    def GetActiveProjectIncludePaths(self, wspConfName = ''):
        actProjName = self.VLWIns.GetActiveProjectName()
        return self.GetProjectIncludePaths(actProjName, wspConfName)

    def GetWorkspaceIncludePaths(self, wspConfName = '', include_parser = True):
        '''
        include_parser: True, 包括用于parser的搜索路径'''
        incPaths = []
        if include_parser:
            incPaths += self.GetParserSearchPaths()
        for projName in self.VLWIns.projects.keys():
            incPaths += self.GetProjectIncludePaths(projName, wspConfName)
        guard = set()
        results = []
        # 过滤重复的项
        for path in incPaths:
            if not path in guard:
                results.append(path)
                guard.add(path)
        return results

    def ShowMenu(self):
        row, col = self.window.cursor
        nodeType = self.VLWIns.GetNodeTypeByLineNum(row)
        if nodeType == VLWorkspace.TYPE_WORKSPACE: #工作空间右键菜单
            popupMenuW = [i for i in self.popupMenuW if i[:4] != '-Sep']

            names = self.VLWSettings.GetBatchBuildNames()
            if names:
                try:
                    idx = popupMenuW.index('Batch Builds')
                    del popupMenuW[idx]
                except ValueError:
                    idx = len(popupMenuW)
                popupMenuW.insert(idx, 'Batch Cleans ->')
                popupMenuW.insert(idx, 'Batch Builds ->')

            choice = vim.eval("inputlist(%s)" 
                % GenerateMenuList(popupMenuW))
            choice = int(choice)
            if choice > 0 and choice < len(popupMenuW):
                if popupMenuW[choice].startswith('Batch Builds ->')\
                        or popupMenuW[choice].startswith('Batch Cleans ->'):
                    BBMenu = ['Please select an operation:']
                    for name in names:
                        BBMenu.append(name)
                    choice2 = vim.eval("inputlist(%s)" 
                        % GenerateMenuList(BBMenu))
                    choice2 = int(choice2)
                    if choice2 > 0 and choice2 < len(BBMenu):
                        if popupMenuW[choice].startswith('Batch Builds ->'):
                            self.MenuOperation('W_BB_%s' % BBMenu[choice2], False)
                        else:
                            self.MenuOperation('W_BC_%s' % BBMenu[choice2], False)
                else:
                    self.MenuOperation('W_' + popupMenuW[choice], False)
        elif nodeType == VLWorkspace.TYPE_PROJECT: #项目右键菜单
            popupMenuP = [i for i in self.popupMenuP if i[:4] != '-Sep']

            project = self.VLWIns.GetDatumByLineNum(row)['project']
            projName = project.GetName()
            matrix = self.VLWIns.GetBuildMatrix()
            wspSelConfName = matrix.GetSelectedConfigurationName()
            projSelConfName = matrix.GetProjectSelectedConf(wspSelConfName, 
                                                            projName)
            bldConf = self.VLWIns.GetProjBuildConf(projName, projSelConfName)
            if bldConf and bldConf.IsCustomBuild():
                try:
                    idx = popupMenuP.index('Clean') + 1
                except ValueError:
                    idx = len(popupMenuP)
                targets = bldConf.GetCustomTargets().keys()
                if targets:
                    popupMenuP.insert(idx, 'Custom Build Targets ->')

            choice = vim.eval("inputlist(%s)" 
                % GenerateMenuList(popupMenuP))
            choice = int(choice)
            if choice > 0 and choice < len(popupMenuP):
                menu = 'P_'
                if popupMenuP[choice].startswith('Custom Build Targets ->'):
                    targets = bldConf.GetCustomTargets().keys()
                    targets.sort()
                    if targets:
                        CBMenu = ['Please select an operation:']
                        for target in targets:
                            CBMenu.append(target)
                        choice2 = vim.eval("inputlist(%s)" 
                            % GenerateMenuList(CBMenu))
                        choice2 = int(choice2)
                        if choice2 > 0 and choice2 < len(CBMenu):
                            menu = 'P_C_' + CBMenu[choice2]
                else:
                    menu = 'P_' + popupMenuP[choice]
                self.MenuOperation(menu, False)
        elif nodeType == VLWorkspace.TYPE_VIRTUALDIRECTORY: #虚拟目录右键菜单
            popupMenuV = [i for i in self.popupMenuV if i[:4] != '-Sep']
            choice = vim.eval("inputlist(%s)" 
                % GenerateMenuList(popupMenuV))
            choice = int(choice)
            if choice > 0 and choice < len(popupMenuV):
                self.MenuOperation('V_' + popupMenuV[choice], False)
        elif nodeType == VLWorkspace.TYPE_FILE: #文件右键菜单
            popupMenuF = [i for i in self.popupMenuF if i[:4] != '-Sep']
            choice = vim.eval("inputlist(%s)" 
                % GenerateMenuList(popupMenuF))
            choice = int(choice)
            if choice > 0 and choice < len(popupMenuF):
                self.MenuOperation('F_' + popupMenuF[choice], False)
        else:
            pass

    def __MenuOper_ImportFilesFromDirectory(self, row, useGui = True):
        li = list(C_SOURCE_EXT.union(CPP_SOURCE_EXT, CPP_HEADER_EXT))
        li.sort()
        li2 = []
        for elm in li:
            if not elm: # 空，用 '.' 代替
                li2.append('.')
            else:
                li2.append('*' + elm)
        filters = JoinToSmclStr(li2)
        filters = vim.eval(
            'inputdialog("\nFile extension to import '\
            '(\\".\\" means no extension):\n", \'%s\', "None")' \
            % filters)
        if filters == 'None':
            return
        importDirs = []
        if useGui and vim.eval("executable('zenity')") == '1':
            # zenity 返回的是绝对路径
            names = vim.eval('system(\'zenity --file-selection ' \
                    '--multiple --directory --title="Import Files" ' \
                    '2>/dev/null\')')
            importDirs = names[:-1].split('|')
        else:
            li = vim.eval('vlutils#Inputs("\nImport Files:\n", "", "dir")')
            for d in li:
                if not os.path.isdir(d):
                    print '%s not found or not a directory, ignore' % d
                    continue
                importDirs.append(d)

        if not importDirs:
            return
        for d in importDirs:
            self.ImportFilesFromDirectory(row, d, filters)

    def __MenuOper_AddANewFile(self, row, useGui = True):
        project = self.VLWIns.GetDatumByLineNum(row)['project']
        # NOTE: gnome 3 中的这个函数已经无法输入文件名了，禁用掉
        if useGui and vim.eval('has("browse")') != '0' and False:
            name = vim.eval('browse("", "Add a New File...", "%s", "")' 
                % project.dirName)
            # 若返回相对路径, 是相对于当前工作目录的相对路径
            if IsFileNameIllegal(name):
                VPrint("'%s' is not a valid name" % name)
                return
            if name:
                name = os.path.abspath(name)
        else:
            name = vim.eval(
                'inputdialog("\nEnter the File Name to be created:\n'
                '(CWD is: ".%s.")\n")' % ToVimEval(project.dirName))

        if IsFileNameIllegal(name):
            VPrint("'%s' is not a valid name" % name)
            return

        ds = DirSaver()
        try:
            # 若文件不存在, 创建之
            if project.dirName:
                os.chdir(project.dirName)
            if not os.path.exists(name):
                fdir = os.path.dirname(name)
                if fdir and not os.path.isdir(fdir):
                    try:
                        os.makedirs(os.path.dirname(name))
                    except OSError:
                        VPrint('os.makedirs: cannot create directory %s' % fdir)
                        return
                #os.mknod(name, 0644)
                Touch(name)
        except:
            # 创建文件失败
            VPrint("Can not create the new file: '%s'" % name)
            return
        del ds
        self.AddFileNode(row, name)

    def __MenuOper_AddExistingFiles(self, row, useGui = True):
        project = self.VLWIns.GetDatumByLineNum(row)['project']
        ds = DirSaver()
        try:
            if project.dirName:
                os.chdir(project.dirName)
        except OSError:
            print "chdir failed, cwd is: %s" % os.getcwd()
        if useGui and vim.eval("executable('zenity')") == '1':
            # zenity 返回的是绝对路径
            names = vim.eval('system(\'zenity --file-selection ' \
                    '--multiple --title="Add Existing Files"' \
                    ' 2>/dev/null\')')
            names = names[:-1].split('|')
            self.AddFileNodes(row, names)
        else:
            names = vim.eval(
                'vlutils#Inputs("\nEnter the file name to be added:\n",'
                ' "", "file")')
            li = []
            for name in names:
                if not os.path.exists(name):
                    print '%s not found, ignore' % name
                    continue
                li.append(os.path.abspath(name))
            self.AddFileNodes(row, li)
        del ds

    def MenuOperation(self, menu, useGui = True):
        row, col = self.window.cursor
        nodeType = self.VLWIns.GetNodeTypeByLineNum(row)

        choice = menu[2:]
        if not choice:
            return

        # 先处理插件的菜单
        elem = None
        if   nodeType == VLWorkspace.TYPE_WORKSPACE:
            elem = VidemWorkspace.__popupMenuW_mapping.get(choice)
        elif nodeType == VLWorkspace.TYPE_PROJECT:
            pass
        elif nodeType == VLWorkspace.TYPE_VIRTUALDIRECTORY:
            pass
        elif nodeType == VLWorkspace.TYPE_FILE:
            pass
        if elem:
            return elem[0](self, choice, elem[1])

        if nodeType == VLWorkspace.TYPE_WORKSPACE: #工作空间右键菜单
            if choice == 'Create a New Project...':
                if self.VLWIns.name == 'DEFAULT_WORKSPACE':
                    vim.command('echohl WarningMsg')
                    vim.command('echo "Can not create new project'\
                        ' in the default workspace."')
                    vim.command('echohl None')
                else:
                    vim.command('call s:CreateProject()')
            elif choice == 'Add an Existing Project...':
                if useGui and vim.eval('has("browse")') != '0':
                    fileName = vim.eval(
                        'browse("", "Add Project", "%s", "")' 
                        % self.VLWIns.dirName)
                else:
                    fileName = vim.eval(
                        'input("\nPlease Enter the file name:\n", '\
                        '"%s/", "file")' % (os.getcwd(),))
                if fileName:
                    self.AddProjectNode(row, fileName)
            elif choice == 'New Workspace...':
                vim.command('call s:CreateWorkspace()')
            elif choice == 'Open Workspace...':
                if useGui and vim.eval('has("browse")') != '0':
                    fileName = vim.eval(
                        'browse("", "Open Workspace", getcwd(), "")')
                else:
                    fileName = vim.eval(
                        'input("\nPlease enter the file name:\n", '\
                        '"%s/", "file")' % (os.getcwd(),))
                if fileName:
                    self.CloseWorkspace()
                    self.OpenWorkspace(fileName)
                    self.RefreshBuffer()
            elif choice == 'Close Workspace':
                self.CloseWorkspace()
                self.RefreshBuffer()
            elif choice == 'Reload Workspace':
                self.ReloadWorkspace()
            elif choice == 'Load Session...':
                if useGui and vim.eval('has("browse")') != '0':
                    fileName = vim.eval(
                        'browse("", "Load Session", "%s", "")' 
                        % self.VLWIns.dirName)
                else:
                    fileName = vim.eval(
                        'input("\nPlease enter the session file name:\n", '\
                        '"%s/", "file")' % (os.getcwd(),))
                if fileName:
                    vim.command("call s:LoadSession(%s)" % ToVimEval(fileName))
            elif choice == 'Save Session...':
                # NOTE: gnome3中的browse()函数无法输入文件名，换inputdialog()
                name = vim.eval(
                    'inputdialog("\nEnter the session file name to be created:\n'
                    '(CWD is: ".%s.")\n")' % ToVimEval(self.VLWIns.dirName))
                if name:
                    vim.command("call s:SaveSession(%s)" % ToVimEval(
                                    os.path.join(self.VLWIns.dirName, name)))
            elif choice == 'Initialize Symbol Database':
                vim.command("call Videm_SymdbInit()")
            elif choice == 'Update Symbol Database':
                vim.command("call Videm_SymdbUpdate()")
            elif choice == 'Workspace Build Configuration...':
                vim.command("call s:WspBuildConfigManager()")
            elif choice == 'Workspace Batch Build Settings...':
                vim.command('call s:WspBatchBuildSettings()')
            elif choice == 'Workspace Settings...':
                vim.command("call s:WspSettings()")
            elif choice.startswith('BB_'):
                # Batch Builds
                batchBuildName = choice[3:]
                self.BatchBuild(batchBuildName)
            elif choice.startswith('BC_'):
                # Batch Cleans
                batchBuildName = choice[3:]
                self.BatchBuild(batchBuildName, True)
            else:
                pass
        elif nodeType == VLWorkspace.TYPE_PROJECT: #项目右键菜单
            project = self.VLWIns.GetDatumByLineNum(row)['project']
            projName = project.GetName()
            if choice == 'Build':
                vim.command("call s:BuildProject('%s')" % ToVimStr(projName))
            elif choice == 'Rebuild':
                vim.command("call s:RebuildProject('%s')" % ToVimStr(projName))
            elif choice == 'Clean':
                vim.command("call s:CleanProject('%s')" % ToVimStr(projName))
            elif choice == 'Export Makefile':
                self.builder.Export(projName, '', force = True)
            elif choice == 'Set As Active':
                self.VLWIns.SetActiveProjectByLineNum(row)
                vim.command("call s:RefreshBuffer()")
            elif choice == 'Add a New File...':
                self.__MenuOper_AddANewFile(row, useGui)
            elif choice == 'Add Existing Files...':
                self.__MenuOper_AddExistingFiles(row, useGui)
            elif choice == 'New Virtual Folder...':
                name = vim.eval(
                    'inputdialog("\nEnter the Virtual Directory Name:\n")')
                if IsVDirNameIllegal(name):
                    VPrint("'%s' is not a valid name" % name)
                    return
                if name:
                    self.AddVirtualDirNode(row, name)
            elif choice == 'Import Files From Directory...':
                ds = DirSaver()
                os.chdir(project.dirName)
                self.__MenuOper_ImportFilesFromDirectory(row, useGui)
                del ds
            elif choice == 'Enable Files (Non-Recursive)':
                self.SetEnablingOfVirDir(row, choice)
            elif choice == 'Disable Files (Non-Recursive)':
                self.SetEnablingOfVirDir(row, choice)
            elif choice == 'Swap Enabling (Non-Recursive)':
                self.SetEnablingOfVirDir(row, choice)
            elif choice == 'Remove Project':
                input = vim.eval('confirm("\nAre you sure to remove project '\
                '\\"%s\\" ?", ' '"&Yes\n&No\n&Cancel")' % EscStr4DQ(projName))
                if input == '1':
                    self.DeleteNode(row)
            elif choice == 'Edit PCH Header For Clang...':
                vim.command("call s:OpenFile('%s')" % ToVimStr(
                        os.path.join(project.dirName, projName + '_VLWPCH.h')))
                vim.command("au BufWritePost <buffer> "\
                    "call s:InitVLWProjectClangPCH('%s')"
                    % ToVimStr(projName))
            elif choice == 'Settings...':
                vim.command('call s:ProjectSettings("%s")' % projName)
            elif choice[:2] == 'C_':
                target = choice[2:]
                matrix = self.VLWIns.GetBuildMatrix()
                wspSelConfName = matrix.GetSelectedConfigurationName()
                projSelConfName = matrix.GetProjectSelectedConf(wspSelConfName, 
                                                                projName)
                bldConf = self.VLWIns.GetProjBuildConf(projName, 
                                                       projSelConfName)
                cmd = bldConf.customTargets[target]
                customBuildWd = bldConf.GetCustomBuildWorkingDir()
                # 展开变量(宏)
                customBuildWd = ExpandAllVariables(
                    customBuildWd, self.VLWIns, projName, projSelConfName)
                cmd = ExpandAllVariables(cmd, self.VLWIns, projName,
                                         projSelConfName)
                try:
                    ds = DirSaver()
                    if customBuildWd:
                        os.chdir(customBuildWd)
                except OSError:
                    print 'Can not enter Working Directory "%s"!' \
                        % customBuildWd
                    return
                if cmd:
                    tempFile = vim.eval('tempname()')
                    vim.command("!%s 2>&1 | tee %s" % (cmd, tempFile))
                    vim.command('cgetfile %s' % tempFile)
            else:
                pass
        elif nodeType == VLWorkspace.TYPE_VIRTUALDIRECTORY: #虚拟目录右键菜单
            project = self.VLWIns.GetDatumByLineNum(row)['project']
            projName = project.GetName()
            if choice == 'Add a New File...':
                self.__MenuOper_AddANewFile(row, useGui)
            elif choice == 'Add Existing Files...':
                self.__MenuOper_AddExistingFiles(row, useGui)
            elif choice == 'New Virtual Folder...':
                name = vim.eval(
                    'inputdialog("\nEnter the Virtual Directory Name:\n")')
                if IsVDirNameIllegal(name):
                    VPrint("'%s' is not a valid name" % name)
                    return
                if name:
                    self.AddVirtualDirNode(row, name)
            elif choice == 'Import Files From Directory...':
                ds = DirSaver()
                os.chdir(project.dirName)
                self.__MenuOper_ImportFilesFromDirectory(row, useGui)
                del ds
            elif choice == 'Rename...':
                oldName = self.VLWIns.GetDispNameByLineNum(row)
                newName = vim.eval('inputdialog("\nEnter new name:", "%s")' \
                    % oldName)
                if newName and newName != oldName:
                    self.VLWIns.RenameNodeByLineNum(row, newName)
                    self.RefreshLines(row, row + 1)
            elif choice == 'Remove Virtual Folder':
                input = vim.eval('confirm("\\"%s\\" and all its contents '\
                    'will be remove from the project. \nAre you sure?'\
                    '", ' '"&Yes\n&No\n&Cancel")' \
                    % self.VLWIns.GetDispNameByLineNum(row))
                if input == '1':
                    self.DeleteNode(row)
            elif choice == 'Enable Files (Non-Recursive)':
                self.SetEnablingOfVirDir(row, choice)
            elif choice == 'Disable Files (Non-Recursive)':
                self.SetEnablingOfVirDir(row, choice)
            elif choice == 'Swap Enabling (Non-Recursive)':
                self.SetEnablingOfVirDir(row, choice)
            else:
                pass
        elif nodeType == VLWorkspace.TYPE_FILE: #文件右键菜单
            if choice == 'Open':
                self.OnMouseDoubleClick()
            elif choice == 'Rename...': # TODO: 等于先删，再添加
                absFile = self.VLWIns.GetFileByLineNum(row, True) # 真实文件
                oldName = self.VLWIns.GetDispNameByLineNum(row)
                newName = vim.eval('inputdialog("\nEnter new name:", "%s")' 
                    % oldName)
                if newName != oldName and newName:
                    nodePath = self.GetNodePathByFileName(absFile)
                    self.VLWIns.RenameNodeByLineNum(row, newName)
                    self.RefreshLines(row, row + 1)
                    newAbsFile = os.path.join(os.path.dirname(absFile), newName)
                    # TODO: rename hook现在只在这里调用
                    self.CallRnmNodePostHooks(nodePath, VidemWorkspace.NT_FILE,
                                              absFile, newAbsFile)
            elif choice == 'Remove':
                absFile = self.VLWIns.GetFileByLineNum(row, True) # 真实文件
                input = vim.eval('confirm("\nAre you sure to remove file' \
                    ' \\"%s\\" ?", ' '"&Yes\n&No\n&Cancel")' \
                        % self.VLWIns.GetDispNameByLineNum(row))
                if input == '1':
                    self.DeleteNode(row)
            elif choice == 'Enable This File':
                ret = self.VLWIns.EnableFileByLineNum(row)
                if ret:
                    self.RefreshLines(row, row + 1)
            elif choice == 'Disable This File':
                ret = self.VLWIns.DisableFileByLineNum(row)
                if ret:
                    self.RefreshLines(row, row + 1)
            elif choice == 'Swap Enabling':
                ret = self.VLWIns.SwapEnableFileByLineNum(row)
                if ret:
                    self.RefreshLines(row, row + 1)
            else:
                pass
        else:
            pass

    #===========================================================================
    # Helper Functions
    #===========================================================================
    def SetEnablingOfVirDir(self, lnum, choice):
        ''''''
        if choice == 'Enable Files (Non-Recursive)':
            f = self.VLWIns.EnableFileByLineNum
        elif choice == 'Disable Files (Non-Recursive)':
            f = self.VLWIns.DisableFileByLineNum
        elif choice == 'Swap Enabling (Non-Recursive)':
            f = self.VLWIns.SwapEnableFileByLineNum
        else:
            return

        # 强制展开
        vim.command("call s:ExpandNode()")

        rootVDNodeDepth = self.VLWIns.GetNodeDepthByLineNum(lnum)
        startLnum = lnum + 1
        endLnum = self.VLWIns.GetLastChildrenLineNum(lnum)
        if endLnum == lnum:
            # 本虚拟目录没有任何子节点
            return
        for i in range(startLnum, endLnum + 1):
            if self.VLWIns.GetNodeDepthByLineNum(i) == rootVDNodeDepth + 1:
            # 是虚拟目录的直接子节点
                # 函数会自动忽略不合要求的节点
                f(i, False)

        # Swap 的时候，要调用两次...
        f(startLnum, False)
        f(startLnum, True) # 保存

        #print startLnum, endLnum + 1
        # 简单处理，刷新遍历过的全部节点
        self.RefreshLines(startLnum, endLnum + 1)

    def GetProjectCurrentConfigName(self, projName):
        # Project Settings 包含数个 Project/Build Config，这里直接叫 Config 即可
        '''获取当前工作区设置下项目选择的对应的设置名字'''
        matrix = self.VLWIns.GetBuildMatrix()
        wspConfName = matrix.GetSelectedConfigName()
        projConfName = matrix.GetProjectSelectedConfigName(wspConfName, projName)
        return projConfName

    def GetProjectConfigDict(self, projName, projConfName = ''):
        # Project Settings 包含数个 Project/Build Config，这里直接叫 Config 即可
        '''获取指定名字的项目设置的字典，不包括全局设置
        如果 projConfName 为空，则返回当前所选的设置'''
        matrix = self.VLWIns.GetBuildMatrix()
        projInst = self.VLWIns.FindProjectByName(projName)
        if not projConfName:
            wspConfName = matrix.GetSelectedConfigurationName()
            projConfName = matrix.GetProjectSelectedConf(wspConfName, projName)
        settings = projInst.GetSettings()
        bldCnf = settings.GetBuildConfiguration(projConfName, False)
        return bldCnf.ToDict()

    def GetProjectConfigList(self, projName):
        projInst = self.VLWIns.FindProjectByName(projName)
        settings = projInst.GetSettings()
        li = settings.configs.keys()
        li.sort()
        return li

    def GetProjectGlbCnfDict(self, projName):
        projInst = self.VLWIns.FindProjectByName(projName)
        settings = projInst.GetSettings()
        return settings.GetGlobalSettings().ToDict()

    def SaveProjectSettings(self, projName, projConfName, confDict, glbCnfDict):
        '''从两个字典保存项目设置'''
        matrix = self.VLWIns.GetBuildMatrix()
        projInst = self.VLWIns.FindProjectByName(projName)
        settings = projInst.GetSettings()
        bldCnf = settings.GetBuildConfiguration(projConfName, False)
        bldCnf.FromDict(confDict)
        settings.SetBuildConfiguration(bldCnf)
        settings.globalSettings.FromDict(glbCnfDict)
        projInst.SetSettings(settings)

    def CutNodes(self, row, length):
        ret, err = self.VLWIns._SanityCheck4CutNodes(row, length)
        if not ret:
            print err
            return

        # 如果节点已经展开，先折叠
        if self.VLWIns.IsNodeExpand(row):
            self.FoldNode()

        ret = self.VLWIns.CutNodes(row, length)
        #print 'row = %d, length = %d, ret = %d' % (row, length, ret)
        if ret > 0:
            # 剪切操作的刷新比较麻烦，暂时如此处理
            vim.command("call s:RefreshBuffer()")

    def PasteNodes(self, row):
        ret, err = self.VLWIns._SanityCheck4PasteNodes(row)
        if not ret:
            print err
            return

        ret = self.VLWIns.PasteNodes(row)
        #print 'row = %d, ret = %d' % (row, ret)
        if ret == 0:
            print 'Invalid Operation'
        elif ret == -1:
            print 'Name Conflict'
        elif ret > 0:
            vim.command("call s:RefreshBuffer()")
            # 粘贴成功的话，顺便展开
            self.ExpandNode()

    #===========================================================================
    # 基本操作 ===== 结束
    #===========================================================================

    #===========================================================================
    # DEV API
    #===========================================================================
    @staticmethod
    def RegAddNodePostHook(hook, priority, data):
        item = {'hook': hook, 'priority': priority, 'data': data}
        VidemWorkspace.__addNodePostHooks.append(item)
        return 0

    @staticmethod
    def RegDelNodePostHook(hook, priority, data):
        item = {'hook': hook, 'priority': priority, 'data': data}
        VidemWorkspace.__delNodePostHooks.append(item)
        return 0

    @staticmethod
    def RegRnmNodePostHook(hook, priority, data):
        item = {'hook': hook, 'priority': priority, 'data': data}
        VidemWorkspace.__rnmNodePostHooks.append(item)
        return 0

    @staticmethod
    def UnregAddNodePostHook(hook, priority):
        for idx, d in enumerate(VidemWorkspace.__addNodePostHooks):
            if d['hook'] is hook and d['priority'] == priority:
                VidemWorkspace.__addNodePostHooks.pop(idx)
                return 0
        return -1

    @staticmethod
    def UnregDelNodePostHook(hook, priority):
        for idx, d in enumerate(VidemWorkspace.__delNodePostHooks):
            if d['hook'] is hook and d['priority'] == priority:
                VidemWorkspace.__delNodePostHooks.pop(idx)
                return 0
        return -1

    @staticmethod
    def UnregRnmNodePostHook(hook, priority):
        for idx, d in enumerate(VidemWorkspace.__rnmNodePostHooks):
            if d['hook'] is hook and d['priority'] == priority:
                VidemWorkspace.__rnmNodePostHooks.pop(idx)
                return 0
        return -1

    def IsOpen(self):
        return self.VLWIns.IsOpen()

    def GetNodePathByFileName(self, fileName):
        '''
        fileName:   必须是绝对路径
        return:     出错返回空字符串'''
        return self.VLWIns.GetNodePathByFileName(fileName)

    def GetActiveProjectName(self):
        return self.VLWIns.GetActiveProjectName()

    def GetProjectNameList(self):
        return self.VLWIns.GetProjectList()

    def GetProjectInstance(self, projName):
        return self.VLWIns.FindProjectByName(projName)

    def GetActiveBuildConfigName(self):
        matrix = self.VLWIns.GetBuildMatrix()
        return matrix.GetSelectedConfigurationName()

    def GetBuildConfigNameList(self):
        matrix = self.VLWIns.GetBuildMatrix()
        result = []
        for i in matrix.configurationList:
            result.append(i.name)
        return result

    def GetPorjectBuildConfigName(self, projName, wspBldCnfName = ''):
        matrix = self.VLWIns.GetBuildMatrix()
        if not wspBldCnfName:
            wspBldCnfName = matrix.GetSelectedConfigurationName()
        return matrix.GetProjectSelectedConf(wspBldCnfName, projName)

    ##### ========================================
    # TODO: 这些要放到 videm.org.cpp
    def GetCompileOptions_C(self, projname, confname):
        '''返回原始信息，不添加任何的额外处理'''
        bldcnf = self.VLWIns.GetProjBuildConf(projname, confname)
        if not bldcnf or bldcnf.IsCustomBuild():
            return []
        result = []
        tmpstr = bldcnf.GetCCxxCompileOptions()
        result += ExpandAllVariables_SList(SplitSmclStr(tmpstr),
                                           self.VLWIns, projname, confname)
        tmpstr = bldcnf.GetCCompileOptions()
        result += ExpandAllVariables_SList(SplitSmclStr(tmpstr),
                                           self.VLWIns, projname, confname)
        return result

    def GetCompileOptions_Cpp(self, projname, confname):
        '''返回原始信息，不添加任何的额外处理'''
        bldcnf = self.VLWIns.GetProjBuildConf(projname, confname)
        if not bldcnf or bldcnf.IsCustomBuild():
            return []
        result = []
        tmpstr = bldcnf.GetCCxxCompileOptions()
        result += ExpandAllVariables_SList(SplitSmclStr(tmpstr),
                                           self.VLWIns, projname, confname)
        tmpstr = bldcnf.GetCxxCompileOptions()
        result += ExpandAllVariables_SList(SplitSmclStr(tmpstr),
                                           self.VLWIns, projname, confname)
        return result

    def GetCompileOptions_IncludePaths(self, projname, confname,
                                       abspath = False):
        '''返回原始信息，不添加任何的额外处理'''
        bldcnf = self.VLWIns.GetProjBuildConf(projname, confname)
        if not bldcnf or bldcnf.IsCustomBuild():
            return []
        tmpstr = bldcnf.GetIncludePath()
        result = ExpandAllVariables_SList(SplitSmclStr(tmpstr),
                                          self.VLWIns, projname, confname)
        if abspath:
            projinst = self.GetProjectInstance(projname)
            for idx, path in enumerate(result):
                if not os.path.isabs(path):
                    result[idx] = os.path.join(projinst.dirName, path)
                result[idx] = os.path.normpath(result[idx])
        return result

    def GetCompileOptions_PredefMacros(self, projname, confname):
        '''返回原始信息，不添加任何的额外处理'''
        bldcnf = self.VLWIns.GetProjBuildConf(projname, confname)
        if not bldcnf or bldcnf.IsCustomBuild():
            return []
        tmpstr = bldcnf.GetPreprocessor()
        return ExpandAllVariables_SList(SplitSmclStr(tmpstr),
                                        self.VLWIns, projname, confname)

    def GetCompilerName(self, projname, confname):
        bldcnf = self.VLWIns.GetProjBuildConf(projname, confname)
        if not bldcnf or bldcnf.IsCustomBuild():
            return ''
        return bldcnf.GetCompilerType()

    def GetCompilerIncludePaths(self, projname, confname):
        cmplname = self.GetCompilerName(projname, confname)
        cmpl = BuildSettingsST.Get().GetCompilerByName(cmplname)
        if not cmpl:
            return []
        return SplitSmclStr(cmpl.includePaths)

    def GetCompilerLibraryPaths(self, projname, confname):
        cmplname = self.GetCompilerName(projname, confname)
        cmpl = BuildSettingsST.Get().GetCompilerByName(cmplname)
        if not cmpl:
            return []
        return SplitSmclStr(cmpl.libraryPaths)
    ##### ----------------------------------------

# 为换名作准备
VidemWorkspace = VimLiteWorkspace
