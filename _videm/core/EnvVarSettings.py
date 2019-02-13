#!/usr/bin/env python
# -*- coding:utf-8 -*-

import pickle
import os.path
import json

from Macros import VIMLITE_DIR
from Utils import SplitVarDef, ExpandVariables
from Misc import GetMTime
from Misc import Obj2Dict, Dict2Obj

CONFIG_FILE = os.path.join(VIMLITE_DIR, 'config', 'EnvVarSettings.conf')

class EnvVar:
    '''代表一个环境变量'''
    def __init__(self, string = ''):
        self.key = ''
        self.value = ''
        self.string = string
        if string:
            self.__Expand()

    def ToDict(self):
        return Obj2Dict(self, set(['key', 'value']))

    def FromDict(self, d):
        Dict2Obj(self, d, set(['key', 'value']))
        self.__Expand()

    def __Expand(self):
        self.key, self.value = SplitVarDef(self.string)

    def GetKey(self):
        return self.key

    def GetValue(self):
        return self.value

    def GetString(self):
        return self.string

    def SetValue(self, val):
        self.value = val

    def SetKeyValue(self, key, val):
        self.key = key
        self.value = val

'''\
环境变量的选择机制是：
    每个工作区保存一个环境变量的激活项目名字
    每个工作区保存一个全局环境变量的实例
    载入或保存的时候，设置环境变量的激活项目名字
    然后所有需要环境变量的地方，直接获取全局环境变量即可

这个机制不失是一个好机制，只是跟自己的惯例不符而已，先用着，暂不修改
'''
class EnvVarSettings:
    '''环境变量设置'''
    def __init__(self, fileName = ''):
        self.fileName = ''
        self.envVarSets = {} # 名称: 列表(列表元素为 EnvVar 类)
        self.mtime = 0 # 最后修改时间

        # 当前激活项, 这个在外部需要时修改，理论上这个值不需要保存的
        self.activeSetName = 'Default'

        if fileName:
            self.Load(fileName)

    def ToDict(self):
        d = Obj2Dict(self, set(['fileName', 'activeSetName', 'envVarSets']))
        d['envVarSets'] = {}
        for key, val in self.envVarSets.iteritems():
            d['envVarSets'][key] = []
            for item in val:
                d['envVarSets'][key].append(item.ToDict())
        return d

    def FromDict(self, d):
        Dict2Obj(self, d, set(['fileName', 'activeSetName', 'envVarSets']))
        self.envVarSets.clear()
        for key, val in d['envVarSets'].iteritems():
            self.envVarSets[key] = []
            for item in val:
                env_var = EnvVar()
                env_var.FromDict(item)
                self.envVarSets[key].append(env_var)

    def SetFileName(self, fileName):
        self.fileName = fileName

    def SetActiveSetName(self, activeSetName):
        s1 = self.activeSetName
        self.activeSetName = activeSetName
        #if s1 != activeSetName:
            #self.Save()

    def GetActiveSetName(self):
        return self.activeSetName

    def GetActiveEnvVars(self):
        return self.GetEnvVars(self.GetActiveSetName())

    def GetEnvVars(self, setName):
        if self.envVarSets.has_key(setName):
            return self.envVarSets[setName]
        else:
            return []

    def NewEnvVarSet(self, setName):
        '''新建组, 若已存在, 不会清空已存在的组'''
        if not setName:
            return
        if not self.envVarSets.has_key(setName):
            self.envVarSets[setName] = []

    def DeleteEnvVarSet(self, setName):
        if self.envVarSets.has_key(setName):
            del self.envVarSets[setName]

    def DeleteAllEnvVarSets(self):
        self.envVarSets.clear()

    def AddEnvVar(self, setName, string):
        if self.envVarSets.has_key(setName) and string:
            self.envVarSets[setName].append(EnvVar(string))

    def ClearEnvVarSet(self, setName):
        if self.envVarSets.has_key(setName):
            del self.envVarSets[setName][:]

    def GetVarDict(self):
        d = {}
        for envVar in self.GetActiveEnvVars()[::-1]:
            d[envVar.GetKey()] = envVar.GetValue()
            #result = result.replace('$(%s)' % envVar.GetKey(),
                                    #envVar.GetValue())
        return d

    def ExpandVariables(self, expr, trim = False):
        return ExpandVariables(expr, self.GetVarDict(), trim)

    def GetModificationTime(self):
        return self.mtime

    def Print(self):
        for k, v in self.envVarSets.iteritems():
            print k + ':'
            for i in v:
                #print ' ' * 4 + i.GetKey(), '=', i.GetValue()
                print ' ' * 4 + i.string
        print '=== after expanded ==='
        for k, v in self.envVarSets.iteritems():
            print k + ':'
            for i in v:
                print ' ' * 4 + i.GetKey(), '=', i.GetValue()

    def _ExpandSelf(self):
        '''
        展开自身，具体来说就是展开 EnvVar.val
        内部使用，外部不应该使用这个方法'''
        for envVarName, envVarSet in self.envVarSets.iteritems():
            d = os.environ.copy() # 支持系统的环境变量的
            for envVar in envVarSet:
                key = envVar.GetKey()
                val = envVar.GetValue()
                val = ExpandVariables(val, d, True) # 清除未定义变量
                envVar.SetValue(val)
                d[key] = val

    def Load(self, fileName = ''):
        if not fileName and not self.fileName:
            return False
        if not fileName:
            fileName = self.fileName

        isjson = False
        ret = False
        obj = None
        try:
            f = open(fileName, 'rb')
            obj = pickle.load(f)
            f.close()
        except IOError:
            #print 'IOError:', fileName
            return False
        except:
            f.close()
            isjson = True

        if not isjson and obj:
            #self.fileName = obj.fileName
            self.envVarSets = obj.envVarSets
            #self.activeSetName = obj.activeSetName # 这个值只有临时保存，不需要
            self.mtime = GetMTime(fileName)
            del obj
            ret = True

        if isjson:
            try:
                f = open(fileName, 'rb')
                d = json.load(f)
                f.close()
                self.FromDict(d)
            except IOError:
                return False
            except:
                f.close()
                return False
            ret = True

        if ret:
            self._ExpandSelf()

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
            f = open(fileName, 'wb')
            json.dump(d, f, indent=4, sort_keys=True, ensure_ascii=True)
            f.close()
            self.mtime = GetMTime(fileName)
            ret = True
        except IOError:
            print 'IOError:', fileName
            return False
        except:
            #print d
            raise

        return ret


class EnvVarSettingsST:
    __ins = None

    @staticmethod
    def Get():
        if not EnvVarSettingsST.__ins:
            EnvVarSettingsST.__ins = EnvVarSettings()
            # 创建默认设置
            if not EnvVarSettingsST.__ins.Load(CONFIG_FILE):
                # 文件不存在, 新建默认配置文件
                GenerateDefaultEnvVarSettings()
                EnvVarSettingsST.__ins.Save(CONFIG_FILE)
            EnvVarSettingsST.__ins.SetFileName(CONFIG_FILE)
        return EnvVarSettingsST.__ins

    @staticmethod
    def Free():
        del EnvVarSettingsST.__ins
        EnvVarSettingsST.__ins = None


def GenerateDefaultEnvVarSettings():
    # 预设值
    ins = EnvVarSettingsST.Get()
    ins.NewEnvVarSet('Default')
    ins.AddEnvVar('Default', 'CodeLiteDir=/usr/share/codelite')
    ins.AddEnvVar('Default', 'VimLiteDir=~/.vimlite')
    ins.SetActiveSetName('Default')


if __name__ == '__main__':
    ins = EnvVarSettingsST.Get()
    ins.DeleteAllEnvVarSets()
    ins.NewEnvVarSet('Default')
    ins.AddEnvVar('Default', 'CodeLiteDir=/usr/share/codelite')
    ins.AddEnvVar('Default', 'VimLiteDir=$(CodeLiteDir)')
    ins.AddEnvVar('Default', 'abc=ABC')
    ins.Print()
    ins._ExpandSelf()
    ins.Print()
    print ins.GetModificationTime()
    print ins.ExpandVariables("$(CodeLiteDir) + $(VimLiteDir) = $(abc)")

