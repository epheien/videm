#!/usr/bin/env python
# -*- encoding:utf-8 -*-

import pickle
import os.path
import json
from Misc import ConfTree
from Misc import Obj2Dict, Dict2Obj

class VLWorkspaceSettings:
    '''工作空间设置'''
    # 这个设置中的头文件搜索路径和全局设置中的头文件搜索路径的关系
    INC_PATH_APPEND = 0     # 添加到全局的后面
    INC_PATH_REPLACE = 1    # 只用这个设置的
    INC_PATH_PREPEND = 2    # 添加到全局的前面
    INC_PATH_DISABLE = 3    # 只用全局设置的

    # 与上面的标志对应的字符串
    INC_PATH_FLAG_WORDS = [
        "Append",
        "Replace",
        "Prepend",
        "Disable",
    ]

    def __init__(self, fileName = ''):
        '''fileName 只在内部使用，并不会保存这个信息到硬盘文件里面'''
        if not fileName:
            self.fileName = ''
        else:
            self.fileName = os.path.abspath(fileName)
        self.includePaths = []
        self.excludePaths = []
        self.tagsTokens = [] # 宏处理符号
        self.tagsTypes = [] # 类型映射符号

        # 2012-07-19: 默认是添加到全局的后面
        self.incPathFlag = VLWorkspaceSettings.INC_PATH_APPEND

        self.envVarSetName = 'Default' # 选择的环境变量组, 默认为 'Default'

        # 2011-09-06: 批量构建数据, 保存的是"名字"到"有序的项目名称"的字典
        # 2011-09-16: 为了实现简单, 默认必须有一组空的"名字"
        self.batchBuild = {'Default': []}

        # 2012-04-22: 添加预设的 namespace 信息，
        #             因为一些恶劣的代码在头文件使用名空间
        self.nsinfo = {'nsalias': {}, 'using': {}, 'usingns': []}

        # 2012-04-22: 作为全局宏的文件
        self.macroFiles = []

        # 2012-09-09: 工作区文件的编辑器选项，实现上是一个 vim 脚本
        # 每个项目是一个 vim Ex 命令
        self.editorOptions = []

        # 2012-10-06: 源文件扩展名设置，约定扩展名是包括 '.' 的，例如 .c, .cpp
        self.cSrcExts = []
        self.cppSrcExts = []

        # 2013-01-23: 工作区配置信息，每个工作区可有自己的配置，覆盖全局配置
        self.enableLocalConfig = False  # 是否使用工作区自己的配置
        # 工作区配置信息
        # 废弃的选项，仅用于后向兼容
        #self.localConfig = {}
        # 裸配置样，例的文本
        self.localConfigText = """\
# Code Complete Engine
videm.cc.Current    = 'vimccc'
# Symbol Database
videm.symdb.Current = 'gtags'"""

        # 统一的配置视图 on 2013-05-19
        # 路径示例:
        # omnicpp   -> videm.plugin.omnicpp
        # vimccc    -> videm.plugin.vimccc
        # pyclewn   -> videm.plugin.pyclewn
        # gtags     -> videm.plugin.gtags
        # cscope    -> videm.plugin.cscope
        self.conf = ConfTree()

        # 如果指定了 fileName, 从文件载入, 不论成功与否
        self.Load()

    def ToDict(self):
        return Obj2Dict(self, set(['conf', 'fileName']))

    def FromDict(self, d):
        Dict2Obj(self, d, set(['conf', 'fileName', 'localConfig']))
        # 处理后向兼容的选项
        if 'localConfig' in d:
            self._UpdateLocalConfigTextFromDict(d['localConfig'])

    def SetFileName(self, fileName):
        self.fileName = fileName

    def AddTagsToken(self, tagsToken):
        self.tagsTokens.append(tagsToken)

    def RemoveTagsToken(self, index):
        try:
            del self.tagsTokens[index]
        except IndexError:
            return

    def AddTagsType(self, tagsType):
        self.tagsTypes.append(tagsType)

    def RemoveTagsType(self, index):
        try:
            del self.tagsTypes[index]
        except IndexError:
            return

    def AddIncludePath(self, path):
        self.includePaths.append(path)

    def RemoveIncludePath(self, index):
        try:
            del self.includePaths[index]
        except IndexError:
            return

    def AddExcludePath(self, path):
        self.excludePaths.append(path)

    def RemoveExcludePath(self, index):
        try:
            del self.excludePaths[index]
        except IndexError:
            return

    def GetEnvVarSetName(self):
        return self.envVarSetName

    def SetEnvVarSetName(self, envVarSetName):
        self.envVarSetName = envVarSetName

    def GetBatchBuildList(self, name):
        if name in self.batchBuild:
            return self.batchBuild[name]
        else:
            return []

    def SetBatchBuildList(self, name, order):
        self.batchBuild[name] = order

    def GetBatchBuildNames(self):
        li = list(self.batchBuild.keys())
        li.sort()
        return li

    def RenameProject(self, oldName, newName):
        if not newName or oldName == newName:
            return
        for key, val in enumerate(self.batchBuild):
            for idx, name in enumerate(val):
                if name == oldName:
                    val[idx] = newName
                    return

    def GetUsingNamespace(self):
        return self.nsinfo['usingns']

    def SetUsingNamespace(self, usingns):
        self.nsinfo['usingns'] = usingns

    def GetMacroFiles(self):
        return self.macroFiles

    def SetMacroFiles(self, macroFiles):
        self.macroFiles = macroFiles

    def GetEditorOptions(self):
        return self.editorOptions

    def SetEditorOptions(self, editorOptions):
        if isinstance(editorOptions, str):
            editorOptions = editorOptions.splitlines()
        self.editorOptions = editorOptions

    def GetIncPathFlagWords(self):
        return self.INC_PATH_FLAG_WORDS

    def GetCurIncPathFlagWord(self):
        return self.INC_PATH_FLAG_WORDS[self.incPathFlag]

    def GetLocalConfigText(self):
        return self.localConfigText

    def SetLocalConfigText(self, text):
        self.localConfigText = text

    def _UpdateLocalConfigTextFromDict(self, di):
        '''把字典转为可读的文本形式，并覆盖更新 self.localConfigText'''
        li = []

        minlen = 1
        for k in di.keys():
            if len(k) > minlen:
                minlen = len(k)

        for k, v in di.items():
            if isinstance(v, str):
                li.append("%-*s = '%s'" % (minlen, k, v.replace("'", "''")))
            else:
                li.append("%-*s = %d" % (minlen, k, v))

        li.sort()
        self.localConfigText = '\n'.join(li)

    def SetIncPathFlag(self, flag):
        if isinstance(flag, str):
            if flag in self.INC_PATH_FLAG_WORDS:
                self.incPathFlag = self.INC_PATH_FLAG_WORDS.index(flag)
        else: # 整数
            self.incPathFlag = flag

    def Load(self, fileName = ''):
        if not fileName and not self.fileName:
            return False

        if not fileName:
            fileName = self.fileName

        isjson = False
        ret = False
        obj = None
        try:
            f = open(fileName, 'rt', encoding='utf-8')
            obj = pickle.load(f)
            f.close()
        except IOError:
            #print 'IOError:', fileName
            return False
        except:
            f.close()
            isjson = True

        if not isjson and obj:
            #self.fileName = obj.fileName # 不需要保存文件名信息
            self.includePaths = obj.includePaths
            self.excludePaths = obj.excludePaths
            self.tagsTokens = obj.tagsTokens
            self.tagsTypes = obj.tagsTypes
            try:
                self.envVarSetName = obj.envVarSetName
                self.batchBuild = obj.batchBuild
                self.nsinfo = obj.nsinfo
                self.macroFiles = obj.macroFiles
                self.incPathFlag = obj.incPathFlag
                self.editorOptions = obj.editorOptions
                self.cSrcExts = obj.cSrcExts
                self.cppSrcExts = obj.cppSrcExts
                self.enableLocalConfig = obj.enableLocalConfig
                if obj.localConfig and \
                   list(obj.localConfig.keys())[0].startswith('videm'):
                    #self.localConfig = obj.localConfig
                    self._UpdateLocalConfigTextFromDict(obj.localConfig)
                self.conf = obj.conf
            except:
                pass
            del obj
            ret = True

        if isjson:
            try:
                f = open(fileName, 'rt', encoding='utf-8')
                d = json.load(f)
                f.close()
                self.FromDict(d)
            except IOError:
                return False
            except:
                f.close()
                return False
            ret = True

        return ret

    def Save(self, fileName = ''):
        if not fileName and not self.fileName:
            return False
        if not fileName:
            fileName = self.fileName

        ret = False
        d = self.ToDict()
        dirName = os.path.dirname(fileName)

        try:
            if not os.path.exists(dirName):
                os.makedirs(dirName)
        except:
            return False

        try:
            f = open(fileName, 'wt', encoding='utf-8')
            json.dump(d, f, indent=4, sort_keys=True, ensure_ascii=True)
            f.close()
            ret = True
        except IOError:
            print('IOError:', fileName)
            return False

        return ret



if __name__ == '__main__':
    ins = VLWorkspaceSettings('temp.wspsettings')
    print(ins.includePaths)
    print(ins.excludePaths)
    ins.AddExcludePath('age')
    ins.AddIncludePath('aenkjle')
    print(ins.includePaths)
    print(ins.excludePaths)
    #print ins.Save()
    #print ins.Load()
    print(ins.includePaths)
    print(ins.excludePaths)
    print(ins.fileName)
    print(ins.GetIncPathFlagWords())
    print(ins.GetCurIncPathFlagWord())

