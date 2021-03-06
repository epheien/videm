#!/usr/bin/env python
# -*- encoding:utf-8 -*-

from xml.dom import minidom
import BuildConfig
import XmlUtils
# 本模块由 Project 导入的话，下行语句可省略
#from Project import Project
import Project

class ProjectSettings:
    '''项目设置，代表一个 xxx.project 的 Settings 元素'''
    
    def __init__(self, node = None):
        self.configs = {}           # 构建设置，即 xml 中的 Configuration 元素
        self.globalSettings = None  # 全局构建设置，一个 BuildConfigCommon
        self.projectType = ''       # 项目类型，可运行、静态库、动态库三种

        ### 文件自动导入的设置 ###
        # 实际目录路径(相对) -> 项目虚拟目录路径
        self.direList = []
        # 通配模式, ; 相隔, ;; 表示单个分号
        self.inclGlob = '*.c;*.cpp;*.cxx;*.c++;*.cc;*.h;*.hpp;*.hxx;Makefile'
        # 同上
        self.exclGlob = '*.mod.c'

        # 示例
        self.direList.append({'Enable': 1, 'Recursive': 0,
                              'RealPath': '.', 'VirtPath': '.'})
        
        if node:
            # load configurations
            self.projectType = XmlUtils.ReadString(node, 'Type')
            for i in node.childNodes:
                if i.nodeName == 'Configuration':
                    configName = XmlUtils.ReadString(i, 'Name')
                    self.configs[configName] = BuildConfig.BuildConfig(i)
                    # 若此设置的项目类型为空, 赋值为项目总的类型, 以免为空
                    if not self.configs[configName].projectType:
                        self.configs[configName].projectType = self.projectType
                elif i.nodeName == 'GlobalSettings':
                    self.globalSettings = BuildConfig.BuildConfigCommon(
                        i, 'GlobalSettings')
                elif i.nodeName == 'FileImportGlob':
                    self.inclGlob = XmlUtils.ReadString(i, 'IncludeGlob')
                    self.exclGlob = XmlUtils.ReadString(i, 'ExcludeGlob')
                    del self.direList[:]
                    for j in i.childNodes:
                        if j.nodeName == 'Directory':
                            d = {}
                            d['Enable'] = int(XmlUtils.ReadBool(j, 'Enable'))
                            d['Recursive'] = int(XmlUtils.ReadBool(j, 'Recursive'))
                            d['RealPath'] = XmlUtils.ReadString(j, 'RealPath')
                            d['VirtPath'] = XmlUtils.ReadString(j, 'VirtPath')
                            self.direList.append(d)
        else:
            # create new settings with default values
            # 默认为可运行类型项目
            #self.projectType = str(Project.Project.STATIC_LIBRARY)
            self.projectType = str(Project.Project.EXECUTABLE)
            self.configs['Debug'] = BuildConfig.BuildConfig()
        
        # Create global settings if it's not been loaded or by default
        if not self.globalSettings:
            self.globalSettings = BuildConfig.BuildConfigCommon(
                None, 'GlobalSettings')
        
        
    def Clone(self):
        node = self.ToXmlNode()
        cloned = ProjectSettings(node)
        return cloned
    
    def ToXmlNode(self):
        node = minidom.Document().createElement('Settings')
        node.setAttribute('Type', str(self.projectType))
        node.appendChild(self.globalSettings.ToXmlNode())
        for k, v in list(self.configs.items()):
            node.appendChild(v.ToXmlNode())

        fnode = minidom.Document().createElement('FileImportGlob')
        fnode.setAttribute('IncludeGlob', self.inclGlob)
        fnode.setAttribute('ExcludeGlob', self.exclGlob)
        for item in self.direList:
            dnode = minidom.Document().createElement('Directory')
            dnode.setAttribute('Enable', 'yes' if item['Enable'] else 'no')
            dnode.setAttribute('Recursive', 'yes' if item['Recursive'] else 'no')
            dnode.setAttribute('RealPath', item['RealPath'])
            dnode.setAttribute('VirtPath', item['VirtPath'])
            fnode.appendChild(dnode)
        node.appendChild(fnode)

        return node
    
    def GetBuildConfiguration(self, configName = '', merge = False):
        '''Find the first build configuration by name
        
        configName: build configuration name to find
        merge: merge with global settings or not'''
        buildConf = None
        if configName in self.configs:
            buildConf = self.configs[configName]

        if not merge or not buildConf:
            return buildConf
        
        # Need to merge configuration and global settings
        # FIXME: 有冗余
        buildConfMerged = buildConf.Clone()
        if buildConfMerged.GetBuildCmpWithGlobalSettings() == BuildConfig.BuildConfig.PREPEND_GLOBAL_SETTINGS:
            buildConfMerged.SetCompileOptions(buildConf.GetCompileOptions() + ';' + self.globalSettings.GetCompileOptions() )
            buildConfMerged.SetCCompileOptions(buildConf.GetCCompileOptions() + ';' + self.globalSettings.GetCCompileOptions() )
            buildConfMerged.SetCCxxCompileOptions(
                buildConf.GetCCxxCompileOptions() + ';' \
                + self.globalSettings.GetCCxxCompileOptions() )
            buildConfMerged.SetPreprocessor(buildConf.GetPreprocessor() + ';' + self.globalSettings.GetPreprocessor() )
            buildConfMerged.SetIncludePath(buildConf.GetIncludePath() + ';' + self.globalSettings.GetIncludePath() )
        elif buildConfMerged.GetBuildCmpWithGlobalSettings() == BuildConfig.BuildConfig.APPEND_TO_GLOBAL_SETTINGS:
            buildConfMerged.SetCompileOptions(self.globalSettings.GetCompileOptions() + ";" + buildConf.GetCompileOptions());
            buildConfMerged.SetCCompileOptions(self.globalSettings.GetCCompileOptions() + ";" + buildConf.GetCCompileOptions());
            buildConfMerged.SetCCxxCompileOptions(
                self.globalSettings.GetCCxxCompileOptions() + ";" \
                + buildConf.GetCCxxCompileOptions());
            buildConfMerged.SetPreprocessor(self.globalSettings.GetPreprocessor() + ";" + buildConf.GetPreprocessor());
            buildConfMerged.SetIncludePath(self.globalSettings.GetIncludePath() + ";" + buildConf.GetIncludePath());
        
        if buildConfMerged.GetBuildLnkWithGlobalSettings() == BuildConfig.BuildConfig.PREPEND_GLOBAL_SETTINGS:
            buildConfMerged.SetLinkOptions(buildConf.GetLinkOptions() + ";" + self.globalSettings.GetLinkOptions());
            buildConfMerged.SetLibraries(buildConf.GetLibraries() + ";" + self.globalSettings.GetLibraries());
            buildConfMerged.SetLibPath(buildConf.GetLibPath() + ";" + self.globalSettings.GetLibPath());
        
        elif buildConfMerged.GetBuildLnkWithGlobalSettings() == BuildConfig.BuildConfig.APPEND_TO_GLOBAL_SETTINGS:
            buildConfMerged.SetLinkOptions(self.globalSettings.GetLinkOptions() + ";" + buildConf.GetLinkOptions());
            buildConfMerged.SetLibraries(self.globalSettings.GetLibraries() + ";" + buildConf.GetLibraries());
            buildConfMerged.SetLibPath(self.globalSettings.GetLibPath() + ";" + buildConf.GetLibPath());
        
        if buildConfMerged.GetBuildResWithGlobalSettings() == BuildConfig.BuildConfig.PREPEND_GLOBAL_SETTINGS:
            buildConfMerged.SetResCmpOptions(buildConf.GetResCompileOptions() + ";" + self.globalSettings.GetResCompileOptions());
            buildConfMerged.SetResCmpIncludePath(buildConf.GetResCmpIncludePath() + ";" + self.globalSettings.GetResCmpIncludePath());
        
        elif buildConfMerged.GetBuildResWithGlobalSettings() == BuildConfig.BuildConfig.APPEND_TO_GLOBAL_SETTINGS:
            buildConfMerged.SetResCmpOptions(self.globalSettings.GetResCompileOptions() + ";" + buildConf.GetResCompileOptions());
            buildConfMerged.SetResCmpIncludePath(self.globalSettings.GetResCmpIncludePath() + ";" + buildConf.GetResCmpIncludePath());
        
        return buildConfMerged
        
    
    def GetFirstBuildConfiguration(self):
        self.configsIterator = iter(self.configs.values())
        return next(self.configsIterator)
    
    def GetNextBuildConfiguration(self):
        try:
            result = next(self.configsIterator)
        except:
            return None
        else:
            return result
    
    def SetBuildConfiguration(self, buildConfig):
        self.configs[buildConfig.name] = buildConfig
    
    def RemoveConfiguration(self, configName):
        '''Remove build configuration from the project settings.'''
        if configName in self.configs:
            del self.configs[configName]

    def GetGlobalSettings(self):
        return self.globalSettings
    
    def SetGlobalSettings(self, buildConfigCommon):
        self.globalSettings = buildConfigCommon
    
    def GetProjectType(self, configName):
        '''尝试返回指定名字的设置的项目类型，如没有，返回整个项目的类型'''
        if configName:
            if configName in self.configs:
                bc = self.configs[configName]
                type = bc.projectType
                if not type:
                    type = self.projectType
                return type
        return self.projectType
    
    def SetProjectType(self, type):
        self.projectType = type



if __name__ == '__main__':
    print('hello')
