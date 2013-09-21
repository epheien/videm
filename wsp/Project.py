#!/usr/bin/env python
# -*- encoding:utf-8 -*-

import os, sys
import os.path
from xml.dom import minidom

import XmlUtils
from ProjectSettings import ProjectSettings
from Macros import WSP_PATH_SEP, PROJECT_FILE_SUFFIX
from Misc import GetMTime, DirSaver, IsWindowsOS

# 项目配置文件的版本
PROJECT_VERSION = 100

def _GetNodeByIgnoredPath(project, path):
    ps = path.split('/')
    node = project.rootNode
    # 遍历路径
    for idx, p in enumerate(ps[:-1]):
        # 逐个路径寻找
        for child in node.childNodes:
            if child.nodeName == 'VirtualDirectory' or child.nodeName == 'File':
                name = child.getAttribute('Name')
                if name == p:
                    node = child
                    #print name
                    break
        else:
            # 遍历完毕都找不到的话，就是找不到
            return None

    if node is project.rootNode or node.nodeName == 'File':
        return None

    # 叶子节点的查找
    for child in node.childNodes:
        if child.nodeName == 'File':
            # 详细检查
            if os.path.basename(child.getAttribute('Name')) == ps[-1]:
                #print 'OK,', child.getAttribute('Name')
                return child
    else:
        return None

def _ConvertIgnoredFiles(project, ignoredFiles):
    '''转换，用于兼容老的配置方式'''
    cp = ignoredFiles.copy()
    ignoredFiles.clear()
    for elem in cp:
        # 人肉转，因为要减少依赖
        node = _GetNodeByIgnoredPath(project, elem)
        if node:
            ignoredFiles.add(node.getAttribute('Name').encode('utf-8'))

def _CleanupIgnoredFiles(project, ignoredFiles):
    '''清理无效的条目'''
    if not ignoredFiles:
        return
    cp = ignoredFiles.copy()
    ignoredFiles.clear()
    s = set(project.GetAllFiles())
    for elem in cp:
        if elem in s:
            ignoredFiles.add(elem)

def JoinWspPath(a, *p):
    """Join two or more pathname components, inserting WSP_PATH_SEP as needed.
    If any component is an absolute path, all previous path components
    will be discarded."""
    path = a
    for b in p:
        if b.startswith(WSP_PATH_SEP):
            path = b
        elif path == '' or path.endswith(WSP_PATH_SEP):
            path +=  b
        else:
            path += WSP_PATH_SEP + b
    return path


class ProjectData:
    '''包含 Project 的数据结构，用于管理一个项目'''
    def __init__(self):
        self.name = ''
        self.path = ''
        self.project = None
        self.cmpType = ''   # Project compiler type


class Project:
    # 尽量不用整数，不然转为 xml 的时候会有麻烦
    STATIC_LIBRARY = 'Static Library';
    DYNAMIC_LIBRARY = 'Dynamic Library';
    EXECUTABLE = 'Executable';

    def __init__(self, fileName = ''):
        self.doc = minidom.Document()
        self.rootNode = XmlUtils.GetRoot(self.doc)
        self.name = ''
        self.fileName = ''  # 绝对路径
        self.dirName = ''   # 绝对路径
        self.baseName = ''  # 项目文件名
        # 用于判断是否重新生成 makefile，此标志为真时，必重新生成 makefile
        # FIXME: 如果此标志为真，但是此时关闭工作区，下次启动时不会重建 makefile
        self.isModified = False
        self.tranActive = False
        self.modifyTime = 0
        self.settings = None

        self.version = 0

        if fileName:
            try:
                self.doc = minidom.parse(fileName)
            except IOError:
                print 'Invalid fileName:', fileName
                raise IOError
            self.rootNode = XmlUtils.GetRoot(self.doc)
            self.name = self.rootNode.getAttribute('Name').encode('utf-8')

            # 添加版本号
            if self.rootNode.hasAttribute('Version'):
                self.version = int(self.rootNode.getAttribute('Version'))

            # 绝对路径
            self.fileName = os.path.abspath(fileName)
            # NOTE: 还必须是真实路径
            self.fileName = os.path.realpath(self.fileName)
            self.dirName, self.baseName = os.path.split(self.fileName) #绝对路径
            self.modifyTime = GetMTime(fileName)
            self.settings = ProjectSettings(XmlUtils.FindFirstByTagName(
                self.rootNode, 'Settings'))

            self._ConvertSettings()
            self._CleanupSettings()

    def _CleanupSettings(self):
        bldConf = self.settings.GetFirstBuildConfiguration()
        while bldConf:
            # 清掉无效的条目
            _CleanupIgnoredFiles(self, bldConf.ignoredFiles)
            bldConf = self.settings.GetNextBuildConfiguration()

    def _ConvertSettings(self):
        '''兼容处理'''
        if self.version < 100:
            bldConf = self.settings.GetFirstBuildConfiguration()
            while bldConf:
                _ConvertIgnoredFiles(self, bldConf.ignoredFiles)
                bldConf = self.settings.GetNextBuildConfiguration()
        # 更新版本号，不保存，除非明确要求
        self.version = PROJECT_VERSION
        self.rootNode.setAttribute('Version', str(self.version))

    def GetName(self):
        '''Get project name'''
        return self.name

    def GetFileName(self):
        return self.fileName

    def SetFiles(self, projectIns):
        '''copy files (and virtual directories) from src project to this project
        note that this call replaces the files that exists under this project'''
        # first remove all the virtual directories from this project
        # Remove virtual folders
        vdNode = XmlUtils.FindFirstByTagName(XmlUtils.GetRoot(self.doc), 
                                             'VirtualDirectory')
        while vdNode:
            XmlUtils.GetRoot(self.doc).removeChild(vdNode)
            vdNode = XmlUtils.FindFirstByTagName(XmlUtils.GetRoot(self.doc), 
                                                 'VirtualDirectory')

        # copy the virtual directories from the src project
        for i in XmlUtils.GetRoot(self.doc).childNodes:
            if i.nodeName == 'VirtualDirectory':
                # FIXME: deep?
                newNode = i.cloneNode(1)
                XmlUtils.GetRoot(self.doc).appendChild(newNode)

        self.DoSaveXmlFile()

    def SetName(self, name):
        '''设置项目的名称，不改变关联的 .project 文件'''
        self.name = name
        self.rootNode.setAttribute('Name', name.decode('utf-8'))

    def GetDescription(self):
        rootNode = XmlUtils.GetRoot(self.doc)
        if rootNode:
            node = XmlUtils.FindFirstByTagName(rootNode, 'Description')
            if node:
                return XmlUtils.GetNodeContent(node)
        return ''

    def Load(self, fileName):
        self.__init__(fileName)
        self.SetModified(True)

    def Create(self, name, description, path, projectType):
        self.name = name
        self.fileName = os.path.join(
            path, name + os.extsep + PROJECT_FILE_SUFFIX)
        self.fileName = os.path.abspath(self.fileName)
        self.dirName, self.baseName = os.path.split(self.fileName)

        self.doc = minidom.Document()
        rootNode = self.doc.createElement('CodeLite_Project')
        self.doc.appendChild(rootNode)
        rootNode.setAttribute('Name', name.decode('utf-8'))

        descNode = self.doc.createElement('Description')
        XmlUtils.SetNodeContent(descNode, description)
        rootNode.appendChild(descNode)

        # Create the default virtual directories
        srcNode = self.doc.createElement('VirtualDirectory')
        srcNode.setAttribute('Name', 'src')
        rootNode.appendChild(srcNode)
        headNode = self.doc.createElement('VirtualDirectory')
        headNode.setAttribute('Name', 'include')
        rootNode.appendChild(headNode)

        # creae dependencies node
        depNode = self.doc.createElement('Dependencies')
        rootNode.appendChild(depNode)

        self.DoSaveXmlFile()

        # create a minimalist build settings
        settings = ProjectSettings()
        settings.SetProjectType(projectType)
        self.SetSettings(settings)
        self.SetModified(True)

    def GetAllFiles(self, absPath = False, projConfName = ''):
        '''
        如果 projConfName 为空，返回结果会包含被忽略的文件，也就是全部文件
        如果 projConfName 非空，排除 projConfName 配置指定忽略的文件
        NOTE: 暂时只有在构建的时候才需要排除忽略的文件
        '''
        ignoredFiles = set()
        if projConfName:
            settings = self.GetSettings()
            bldConf = settings.GetBuildConfiguration(projConfName)
            if bldConf:
                ignoredFiles = bldConf.ignoredFiles.copy()
        if absPath:
            ds = DirSaver()
            os.chdir(self.dirName)
            files = self.GetFilesOfNode(XmlUtils.GetRoot(self.doc), True,
                                        '', ignoredFiles)
                                        #WSP_PATH_SEP + self.name)
        else:
            files = self.GetFilesOfNode(XmlUtils.GetRoot(self.doc), False,
                                        '', ignoredFiles)
                                        #WSP_PATH_SEP + self.name)
        return files

    def GetFilesOfNode(self, node, absPath = False,
                       curWspPath = '', ignoredFiles = set()):
        if not node:
            return []

        files = []
        for i in node.childNodes:
            if i.nodeName == 'File':
                fileName = i.getAttribute('Name').encode('utf-8')
                if absPath:
                    fileName = os.path.abspath(fileName)

                #igfile = JoinWspPath(curWspPath, os.path.basename(fileName))
                igfile = i.getAttribute('Name')
                if igfile in ignoredFiles:
                    #ignoredFiles.remove(igfile)
                    pass
                else:
                    files.append(fileName)
            elif i.nodeName == 'VirtualDirectory':
                pathName = i.getAttribute('Name').encode('utf-8')
                # 递归遍历所有文件
                if i.hasChildNodes():
                    files.extend(
                        self.GetFilesOfNode(
                            i, absPath, JoinWspPath(curWspPath, pathName),
                            ignoredFiles))
            else:
                pass
        return files

    def GetSettings(self):
        '''获取项目的设置实例'''
        return self.settings

    def SetSettings(self, settings, autoSave = True):
        '''设置项目设置，并保存xml文件'''
        oldSettings = XmlUtils.FindFirstByTagName(XmlUtils.GetRoot(self.doc), 
                                                  'Settings')
        if oldSettings:
            oldSettings.parentNode.removeChild(oldSettings)
        XmlUtils.GetRoot(self.doc).appendChild(settings.ToXmlNode())
        if autoSave:
            self.DoSaveXmlFile()
        self.settings = settings

    def SetGlobalSettings(self, globalSettings):
        settingsNode = XmlUtils.FindFirstByTagName(XmlUtils.GetRoot(self.doc),
                                                   'Settings')
        oldSettings = XmlUtils.FindFirstByTagName(settingsNode,
                                                  'GlobalSettings')
        if oldSettings:
            oldSettings.parentNode.removeChild(oldSettings)
        settingsNode.appendChild(globalSettings.ToXmlNode())
        self.DoSaveXmlFile()
        self.settings = ProjectSettings(settingsNode)

    def GetDependencies(self, configuration):
        '''返回依赖的项目的名称列表（构建顺序）'''
        result = [] # 依赖的项目名称列表
        # dependencies are located directly under the root level
        rootNode = XmlUtils.GetRoot(self.doc)
        if not rootNode:
            return result

        for i in rootNode.childNodes:
            if i.nodeName == 'Dependencies' \
               and i.getAttribute('Name') == configuration:
                # have found it
                for j in i.childNodes:
                    if j.nodeName == 'Project':
                        result.append(XmlUtils.ReadString(j, 'Name'))
                return result

        # if we are here, it means no match for the given configuration
        # return the default dependencies
        node = XmlUtils.FindFirstByTagName(rootNode, 'Dependencies')
        if node:
            for i in node.childNodes:
                if i.nodeName == 'Project':
                    result.append(XmlUtils.ReadString(i, 'Name'))
        return result

    def SetDependencies(self, deps, configuration):
        '''设置依赖

        deps: 依赖的项目名称列表
        configuration: 本依赖的名称'''
        # first try to locate the old node
        rootNode = XmlUtils.GetRoot(self.doc)
        for i in rootNode.childNodes:
            if i.nodeName == 'Dependencies' \
               and i.getAttribute('Name') == configuration:
                rootNode.removeChild(i)
                break

        # create new dependencies node
        node = self.doc.createElement('Dependencies')
        node.setAttribute('Name', configuration.decode('utf-8'))
        rootNode.appendChild(node)
        for i in deps:
            child = self.doc.createElement('Project')
            child.setAttribute('Name', i.decode('utf-8'))
            node.appendChild(child)

        # save changes
        self.DoSaveXmlFile()
        self.SetModified(True)

    def IsFileExists(self, fileName):
        '''find the file under this node.
        Convert the file path to be relative to the project path'''
        ds = DirSaver()

        os.chdir(self.dirName)
        # fileName relative to the project path
        relFileName = os.path.relpath(fileName, self.dirName)

        files = self.GetAllFiles()
        for i in files:
            if IsWindowsOS():
                if os.path.abspath(i).lower() \
                   == os.path.abspath(relFileName).lower():
                    return True
            else:
                if os.path.abspath(i) == os.path.abspath(relFileName):
                    return True
        return False

    def IsModified(self):
        return self.isModified

    def SetModified(self, mod):
        self.isModified = mod

    def BeginTranscation(self):
        self.tranActive = True

    def CommitTranscation(self):
        self.Save()

    def IsInTransaction(self):
        return self.tranActive

    def SetProjectInternalType(self, interType):
        XmlUtils.GetRoot(self.doc).setAttribute('InternalType',
                                                interType.decode('utf-8'))

    def GetProjectInternalType(self):
        return XmlUtils.GetRoot(self.doc).getAttribute('InternalType')

    def GetProjFileLastModifiedTime(self):
        return GetMTime(self.fileName)

    def GetProjectLastModifiedTime(self):
        return self.modifyTime

    def SetProjectLastModifiedTime(self, time):
        self.modifyTime = time

    def Save(self, fileName = ''):
        self.tranActive = False
        if XmlUtils.GetRoot(self.doc):
            self.SetSettings(self.settings, False)
            self.DoSaveXmlFile(fileName)

    # internal methods
    #===========================================================================    
    def DoFindFile(self, parentNode, fileName):
        '''返回 xml 节点，fileName 为 xml 显示的文件名'''
        for i in parentNode.childNodes:
            if i.nodeName == 'File' and i.getAttribute('Name') == fileName:
                return i

            if i.nodeName == 'VirtualDirectory':
                # 递归查找
                n = self.DoFindFile(i, fileName)
                if n:
                    return n

        return None

    def DoSaveXmlFile(self, fileName = ''):
        try:
            if not fileName:
                fileName = self.fileName
            dirName = os.path.dirname(fileName)
            if not os.path.exists(dirName):
                os.makedirs(dirName)
            f = open(fileName, 'wb')
            #self.doc.writexml(f, encoding = 'utf-8')
            f.write(XmlUtils.ToPrettyXmlString(self.doc))
            self.SetProjectLastModifiedTime(self.GetProjFileLastModifiedTime())
            f.close()
        except IOError:
            print 'IOError:', fileName
            raise IOError


if __name__ == '__main__':
    print 'Hello World!'
    p = Project(sys.argv[1])
    print p.doc.toxml()
    pass
