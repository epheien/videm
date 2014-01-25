#!/usr/bin/env python
# -*- encoding:utf-8 -*-

from xml.dom import minidom
import sys
import os
import os.path
import shutil
import XmlUtils

from VLProject import VLProject
from BuildMatrix import BuildMatrix
from BuildMatrix import ConfigMappingEntry
from Macros import WSP_PATH_SEP, WORKSPACE_FILE_SUFFIX, PROJECT_FILE_SUFFIX
from Misc import CmpIC, SplitSmclStr, GetMTime, DirSaver, IsWindowsOS, PosixPath
from Misc import Touch, ToUtf8

TYPE_WORKSPACE = 0
TYPE_PROJECT = 1
TYPE_VIRTUALDIRECTORY = 2
TYPE_FILE = 3
TYPE_INVALID = -1

EXPAND_PREFIX = '~'
FOLD_PREFIX = '+'
FILE_PREFIX = '-'
IGNORED_FILE_PREFIX = '#'

class WspCpbdData(object):
    '''剪切板数据对象'''
    def __init__(self, projname = '', data = None):
        self.projname = projname
        self.data = data

    def Dump(self):
        v = self.data
        if not isinstance(v, list):
            v = [v]
        for elem in v:
            print elem, elem.getAttribute('Name').encode('utf-8')

class WorkspaceClipboard(object):
    '''工作空间的剪切板，暂时只支持工作空间的虚拟目录节点和文件节点'''
    def __init__(self):
        self.container = []

    def Push(self, v):
        self.container.append(v)

    def Pop(self):
        if self.container:
            return self.container.pop(-1)
        return None

    def Peek(self):
        if self.container:
            return self.container[-1]
        return None

    def Dump(self):
        if not self.container:
            return
        v = self.Peek()
        v.Dump()

def ConvertWspFileToNewFormat(fileName):
    ins = VLWorkspace(fileName)
    ins.ConvertToNewFileFormat()
    del ins

def GetWspPathByNode(node):
    '''从 xml 节点获取工作区路径'''
    wspPathList = []
    while node:
        name = node.getAttribute('Name').encode('utf-8')
        if not name:
            return ''

        if node.nodeName == 'File':
            name = os.path.basename(name)

        wspPathList.insert(0, name)

        if node.nodeName == 'CodeLite_Project':
            break

        node = node.parentNode

    return WSP_PATH_SEP + WSP_PATH_SEP.join(wspPathList)

def Glob(sDir, filters):
    '''展开通配符的文件

    sDir: 所在的目录, 会添加到通配符前
    lFilters: 通配符字符串列表, 支持匹配无后缀名的文件('.')'''
    import glob
    lFiles = []
    lFilters = filters
    if isinstance(filters, str):
        lFilters = [i for i in SplitSmclStr(filters)]
    for sFilter in lFilters:
        if sFilter != '.':
            lFiles.extend(glob.glob(os.path.join(sDir, sFilter)))
        else:
            # 自定义的匹配无后缀名文件的模式 '.'
            sCurDir = sDir
            if not sCurDir:
                sCurDir = '.'
            for sFile in os.listdir(sCurDir):
                if not '.' in sFile:
                    lFiles.append(os.path.join(sDir, sFile))
    return lFiles

def DirectoryToXmlNode(sDir, filters,
                       relStartPath = os.path.realpath(os.path.curdir),
                       _doc = minidom.getDOMImplementation().createDocument(
                           None, None, None),
                       files = []):
    '''广度优先获取指定导入目录的文件'''
    if not sDir or not os.path.isdir(sDir):
        return

    doc = _doc
    xmlNode = doc.createElement('VirtualDirectory')
    xmlNode.setAttribute('Name', os.path.basename(sDir).decode('utf-8'))

    # 标识当前目录是否拥有至少一个子文件/目录以决定是否返回 None
    bHasChild = False

    if not sDir:
        lFileList = os.listdir('.')
    else:
        lFileList = os.listdir(sDir)
    for sFile in lFileList:
        sFile = os.path.join(sDir, sFile)
        if os.path.isdir(sFile):
            newXmlNode = DirectoryToXmlNode(sFile, filters, relStartPath,
                                            files=files)
            if newXmlNode:
                xmlNode.appendChild(newXmlNode)
                bHasChild = True

    lFiles = Glob(sDir, filters)
    # 防止重复文件
    filesSet = set(lFiles)
    lFiles = list(filesSet)
    lFiles.sort(CmpIC) # 排序不分大小写
    for sFile in lFiles:
        if not os.path.isfile(sFile):
            continue
        newXmlNode = doc.createElement('File')
        relpath = os.path.relpath(os.path.realpath(sFile), relStartPath)
        newXmlNode.setAttribute('Name', relpath.decode('utf-8'))
        xmlNode.appendChild(newXmlNode)
        bHasChild = True
        files.append(os.path.abspath(sFile))

    if not bHasChild:
        xmlNode = None

    return xmlNode

# 由列表生成前缀字符
# 1 表示有下一个兄弟节点， 0 表示没有，即为父节点最后的子节点
# 从项目算起，可由 list 的长度获得深度，项目的深度为 1
def MakeLevelPreStrDependList(list):
    nCount = len(list)
    string = ''
    if nCount == 0:
        return string

    if nCount == 1:
        if list[0] == 0:
            string += '`'
        else:
            string += '|'
        return string

    if list[0] == 0:
        string += ' '
    else:
        string += '|'

    for i in list[1:-1]:
        if i == 0:
            string += '  '
        else:
            string += ' |'

    if list[-1] == 0:
        string += ' `'
    else:
        string += ' |'

    return string

# 根据节点的标签名排序节点对象
def SortVirtualDirectoryByNode(lNode):
    dic = {}
    for i in lNode:
        dic[i.attributes['Name'].value] = i
    li = dic.keys()
    li.sort(CmpIC)
#    print li
    li = [dic[i] for i in li]
    return li

# 根据节点的的文件属性值排序节点对象
def SortFileByNode(lNode):
    dic = {}
    for i in lNode:
        dic[os.path.basename(i.attributes['Name'].value)] = i
    li = dic.keys()
    li.sort(CmpIC)
#    print li
    li = [dic[i] for i in li]
    return li

# 工作空间为第 1 行，第一个项目为第 2 行，而 data 索引为 0，所以固有偏移为 2
CONSTANT_OFFSET = 2

# TODO: 处理工作空间节点
# NOTE: getAttribute() 等从 xml 获取的字符串全是 unicode 字符串, 
#       需要 encode('utf-8') 转为普通字符串以供 vim 解析
class VLWorkspace(object):
    '''工作空间对象，保存一个工作空间的数据结构'''

    STATUS_CLOSED   = 0x1
    STATUS_OPEN     = 0x2

    def __init__(self, fileName = ''):
        '''
        datum 是一个字典，保存一些内部数据

        deepFlag 为数结构缓存，列表，列表元素要么是0要么是1
          0 表示没有下一个兄弟结点，否则为 1，也可理解为，1表示有'|'，0无'|'
          如
             [0, 1, 1, 0]
          表示，项目是树中最后的项目，第一个虚拟目录和第二个虚拟目录都有下一个
          兄弟结点，自己本身没有下一个兄弟结点
        '''
        self.doc = None
        self.rootNode = None
        self.name = ''
        self.fileName = ''
        self.dirName = ''
        self.baseName = ''
        self.vimLineData = []
        # 从 vim 的行号转为 vimLineData 编号的偏移量
        self.lineOffset = CONSTANT_OFFSET
        # 保存工作空间包含的项目实例的字典，名字到实例的映射
        self.projects = {}
        self.activeProject = ''
        self.modifyTime = 0
        self.filesIndex = {} # 用于从文件名快速定位所在位置(项目，目录等)的数据
                             # {文件真实路径: xml 节点}
        self.fname2file = {} # 用于实现切换源文件/头文件
                             # {文件名: set(文件绝对路径)}

        # Build Matrix，实时缓存，用于提高访问效率，代价是载入变慢
        self.buildMatrix = None

        # 状态
        self.status = type(self).STATUS_CLOSED

        # 剪切板
        self.clipboard = WorkspaceClipboard()

        if fileName:
            try:
                self.doc = minidom.parse(fileName)
            except IOError:
                print 'IOError:', fileName
                raise IOError
            self.rootNode = XmlUtils.GetRoot(self.doc)
            self.name = XmlUtils.GetRoot(self.doc).getAttribute('Name')\
                    .encode('utf-8')
            self.fileName = os.path.abspath(fileName)
            # NOTE: 必须是真实路径（跟随符号链接）
            self.fileName = os.path.realpath(self.fileName)
            self.dirName, self.baseName = os.path.split(self.fileName)

            self.modifyTime = GetMTime(fileName)

            ds = DirSaver()
            os.chdir(self.dirName)
            for i in self.rootNode.childNodes:
                if i.nodeName == 'Project':
                    name = i.getAttribute('Name').encode('utf-8')
                    path = i.getAttribute('Path').encode('utf-8')
                    active = XmlUtils.ReadBool(i, 'Active')
                    if not os.path.isfile(path):
                        print 'Can not open %s, remove from workspace.' \
                                % (path,)
                        continue
                    if name:
                        self.projects[name] = VLProject(path)
                        if active:
                            self.activeProject = name

            deepFlag = [1]
            tmpList = []
            tmpDict = {}
            i = 0
            for k, v in self.projects.iteritems():
                datum = {}
                datum['node'] = v.rootNode
                datum['deepFlag'] = deepFlag[:]
                datum['expand'] = 0
                datum['project'] = v
                tmpDict[k] = datum
                tmpList.append(k)
                i += 1

            # sort
            tmpList.sort(CmpIC)
            for i in tmpList:
                self.vimLineData.append(tmpDict[i])

            # 修正最后的项目的 deepFlag
            if self.vimLineData:
                self.vimLineData[-1]['deepFlag'][0] = 0

            self.GenerateFilesIndex()

            # 载入 Build Matrix
            self.buildMatrix = BuildMatrix(
                XmlUtils.FindFirstByTagName(self.rootNode, 'BuildMatrix'))
            # 更新状态
            self._SetStatus(type(self).STATUS_OPEN)
        else:
            # 默认的工作空间, fileName 为空
            self.doc = minidom.parseString('''\
<?xml version="1.0" encoding="utf-8"?>
<CodeLite_Workspace Name="DEFAULT_WORKSPACE" Database="">
    <BuildMatrix>
        <WorkspaceConfiguration Name="Debug" Selected="yes"/>
    </BuildMatrix>
</CodeLite_Workspace>
''')
            self.rootNode = XmlUtils.GetRoot(self.doc)
            self.name = XmlUtils.GetRoot(self.doc).getAttribute('Name').encode('utf-8')
            self.dirName = os.getcwd()
            # 载入 Build Matrix
            self.buildMatrix = BuildMatrix(
                XmlUtils.FindFirstByTagName(self.rootNode, 'BuildMatrix'))
            # 更新状态
            self._SetStatus(type(self).STATUS_CLOSED)

    def IsIgnoredFile(self, datum):
        '''为了效率，不进行任何检查'''
        project = datum['project']
        buildMatrix = self.GetBuildMatrix()
        wspSelConfName = buildMatrix.GetSelectedConfigurationName()
        projSelConfName = buildMatrix.GetProjectSelectedConf(wspSelConfName,
                                                             project.GetName())
        settings = project.GetSettings()
        # 获取非副本
        bldConf = settings.GetBuildConfiguration(projSelConfName, False)

        #fileWspPath = GetWspPathByNode(datum['node'])
        #igfile = fileWspPath.partition(WSP_PATH_SEP)[2]\
                #.partition(WSP_PATH_SEP)[2]
        igfile = datum['node'].getAttribute('Name').encode('utf-8')

        if igfile in bldConf.ignoredFiles:
            return True
        else:
            return False

    def EnableFileByLineNum(self, lineNum, autoSave = True):
        '''启用行号指定的文件，成功返回行号，失败返回 0'''
        datum = self.GetDatumByLineNum(lineNum)
        nodeType = self.GetNodeTypeByLineNum(lineNum)
        if not datum or nodeType != TYPE_FILE:
            return 0

        #fileWspPath = GetWspPathByNode(datum['node'])
        #igfile = fileWspPath.partition(WSP_PATH_SEP)[2]\
                #.partition(WSP_PATH_SEP)[2]

        # 使用xml节点保存的名字
        igfile = datum['node'].getAttribute('Name').encode('utf-8')

        result = 0

        ignoredFiles = self.GetCurIgnoredFilesByDatum(datum)
        try:
            ignoredFiles.remove(igfile)
        except KeyError:
            result = 0
        else:
            result = lineNum

        if autoSave:
            datum['project'].Save()

        return result

    def DisableFileByLineNum(self, lineNum, autoSave = True):
        '''禁用行号指定的文件，成功返回行号，失败返回 0
        保存的就是 xml 节点的 "Name" 的属性的值'''
        datum = self.GetDatumByLineNum(lineNum)
        nodeType = self.GetNodeTypeByLineNum(lineNum)
        if not datum or nodeType != TYPE_FILE:
            return 0

        #fileWspPath = GetWspPathByNode(datum['node'])
        #igfile = fileWspPath.partition(WSP_PATH_SEP)[2]\
                #.partition(WSP_PATH_SEP)[2]
        igfile = datum['node'].getAttribute('Name').encode('utf-8')

        result = 0

        ignoredFiles = self.GetCurIgnoredFilesByDatum(datum)
        if igfile in ignoredFiles:
            result = 0
        else:
            ignoredFiles.add(igfile)
            result = lineNum

        if autoSave:
            datum['project'].Save()

        return result

    def SwapEnableFileByLineNum(self, lineNum, autoSave = True):
        datum = self.GetDatumByLineNum(lineNum)
        if not datum:
            return 0
        if self.IsIgnoredFile(datum):
            return self.EnableFileByLineNum(lineNum, autoSave)
        else:
            return self.DisableFileByLineNum(lineNum, autoSave)

    def GetCurIgnoredFilesByDatum(self, datum):
        project = datum['project']
        buildMatrix = self.GetBuildMatrix()
        wspSelConfName = buildMatrix.GetSelectedConfigurationName()
        projSelConfName = buildMatrix.GetProjectSelectedConf(wspSelConfName,
                                                             project.GetName())
        settings = project.GetSettings()
        # 获取非副本
        bldConf = settings.GetBuildConfiguration(projSelConfName, False)

        return bldConf.ignoredFiles

#===============================================================================
# 内部用接口，Do 开头
#===============================================================================

    def DoSetLineOffset(self, offset):
        '''设置索引偏移量

        offset 为相对于首行的偏移量，若在首行，即为 0'''
        self.lineOffset = CONSTANT_OFFSET + offset

    def DoGetTypeOfNode(self, node):
        if not node:
            return TYPE_INVALID

        if node.nodeName == 'CodeLite_Project':
            return TYPE_PROJECT
        elif node.nodeName == 'VirtualDirectory':
            return TYPE_VIRTUALDIRECTORY
        elif node.nodeName == 'File':
            return TYPE_FILE
        elif node.nodeName == 'CodeLite_Workspace':
            return TYPE_WORKSPACE
        else:
            return TYPE_INVALID

    def DoGetTypeByIndex(self, index):
        return self.DoGetTypeOfNode(self.vimLineData[index]['node'])

    def DoGetDispTextOfDatum(self, datum):
        type = self.DoGetTypeOfNode(datum['node'])
        text = ''

        expandText = 'x'
        if type == TYPE_FILE:
            expandText = FILE_PREFIX
            if self.IsIgnoredFile(datum):
                expandText = IGNORED_FILE_PREFIX
        elif type == TYPE_VIRTUALDIRECTORY or type == TYPE_PROJECT:
            if datum['expand']:
                expandText = EXPAND_PREFIX
            else:
                expandText = FOLD_PREFIX

        name = os.path.basename(datum['node'].getAttribute('Name').encode('utf-8'))
        text = MakeLevelPreStrDependList(datum['deepFlag']) + expandText + name
            
        # 当前激活的项目需要特殊标记 on 2013-01-25
        if self.DoGetTypeOfNode(datum['node']) == TYPE_PROJECT \
           and name == self.GetActiveProjectName():
            text += '*' # 暂时使用这个作为标记

        return text

    def DoGetDispTextByIndex(self, index):
        return self.DoGetDispTextOfDatum(self.vimLineData[index])

    def DoIsHasNextSibling(self, index):
        return self.vimLineData[index]['deepFlag'][-1] == 1

    def DoIsHasChild(self, index):
        node = self.vimLineData[index]
        type = self.DoGetTypeByIndex(index)
        if type == TYPE_PROJECT or type == TYPE_VIRTUALDIRECTORY:
            for i in node.childNodes:
                if node.nodeName == 'File' \
                   or node.nodeName == 'VirtualDirectory':
                    return True
        else:
            return False

    def DoGetIndexByLineNum(self, lineNum):
        index = lineNum - self.lineOffset
        # FIXME: 需要兼容 workspace
        #if index < 0:
            #index = -1
        return index

    def DoGetLineNumByIndex(self, index):
        lineNum = index + self.lineOffset
        return lineNum

    def DoInsertChild(self, lineNum, datum):
        '''按照排序顺序插入子节点到相应的位置，虚拟目录和文件忽略大小写差异，
        这和项目名字不同

        return: 插入成功返回插入的行号(>0)，否则返回 0'''
        parentType = self.GetNodeType(lineNum)
        parentIndex = self.DoGetIndexByLineNum(lineNum)
        if parentType == TYPE_FILE or parentType == TYPE_INVALID or not datum:
            return 0

        parentDeep = self.GetNodeDepthByLineNum(lineNum)
        parent = self.GetDatumByLineNum(lineNum)
        if not self.IsNodeExpand(lineNum):
            self.Expand(lineNum)

        s1 = os.path.basename(datum['node'].getAttribute('Name').encode('utf-8'))
        newType = self.DoGetTypeOfNode(datum['node'])
        newDeep = parentDeep + 1

        # 基本方法是顺序遍历 vimLineData，
        # 一路修改 deepFlag，一路比较，如合适，即插入
        for i in range(parentIndex + 1, len(self.vimLineData)):
            curDeep = len(self.vimLineData[i]['deepFlag'])
            if curDeep > parentDeep:
                # 备份原来的flag
                save_flag = self.vimLineData[i]['deepFlag'][newDeep - 1]
                # 预先设置deepFlag，如果插入失败的话，需要还原
                self.vimLineData[i]['deepFlag'][newDeep - 1] = 1

                # 当前节点为兄弟节点的子节点，跳过
                if curDeep > newDeep:
                    continue

                s2 = os.path.basename(
                    self.vimLineData[i]['node'].getAttribute('Name').encode('utf-8'))
                if cmp(s1.lower(), s2.lower()) > 0:
                    # 如果 datum 为 VirtualDirectory 当前位置为 File，插入之
                    if newType == TYPE_VIRTUALDIRECTORY \
                             and self.DoGetTypeByIndex(i) == TYPE_FILE:
                        # 先还原flag
                        self.vimLineData[i]['deepFlag'][newDeep - 1] = save_flag

                        datum['deepFlag'] = parent['deepFlag'][:]
                        datum['deepFlag'].append(1)
                        self.vimLineData.insert(i, datum)
                        return self.DoGetLineNumByIndex(i)

                    continue
                elif cmp(s1.lower(), s2.lower()) < 0:
                    # 如果 datum 为 File，当前位置为 VirtualDirectory，跳过之
                    if newType == TYPE_FILE \
                          and self.DoGetTypeByIndex(i) == TYPE_VIRTUALDIRECTORY:
                        continue

                    # 先还原flag
                    self.vimLineData[i]['deepFlag'][newDeep - 1] = save_flag

                    # 插在中间
                    datum['deepFlag'] = parent['deepFlag'][:]
                    datum['deepFlag'].append(1)
                    self.vimLineData.insert(i, datum)
                    return self.DoGetLineNumByIndex(i)
                else:
                    # 无论如何都要先还原flag的了，因为即使要插入都是插在前面
                    self.vimLineData[i]['deepFlag'][newDeep - 1] = save_flag
                    if cmp(s1, s2) != 0:
                        # 仅大小写不同
                        # TODO: 暂不支持文件名和虚拟目录仅大小写不同的情形
                        # TODO: 至少需要检查是否和虚拟目录名字相近...
                        pass
                    return 0
            else:
                # 到达了深度小于或等于父节点的节点，要么是兄弟，要么是祖先的兄弟
                # 插在父节点最后
                datum['deepFlag'] = parent['deepFlag'][:]
                datum['deepFlag'].append(0)
                self.vimLineData.insert(i, datum)
                return self.DoGetLineNumByIndex(i)
        # 父节点是显示的最后的节点或者
        # 父节点是显示的最后的节点且新数据本应插在最后。
        # 插在最后
        datum['deepFlag'] = parent['deepFlag'][:]
        datum['deepFlag'].append(0)
        self.vimLineData.insert(self.GetLastLineNum() + 1, datum)
        return self.GetLastLineNum()

    def DoInsertProject(self, lineNum, datum):
        '''按照排序顺序插入子节点到相应的位置，项目名字大小写敏感，这个虚拟目录
        以及文件不同

        return: 插入成功返回插入的行号(>0)，否则返回 0'''
        parentType = self.GetNodeType(lineNum)
        if parentType != TYPE_WORKSPACE or not datum:
            return 0

        parentDeep = self.GetNodeDepthByLineNum(lineNum)
        parent = self.GetDatumByLineNum(lineNum)
        if not self.IsNodeExpand(lineNum):
            self.Expand(lineNum)

        parentIndex = -1
        parentDeep = 0
        parent = {'deepFlag' : []}

        s1 = os.path.basename(datum['node'].getAttribute('Name').encode('utf-8'))
        newType = self.DoGetTypeOfNode(datum['node'])
        newDeep = parentDeep + 1

        # 基本方法是顺序遍历 vimLineData，
        # 一路修改 deepFlag，一路比较，如合适，即插入
        for i in range(parentIndex + 1, len(self.vimLineData)):
            curDeep = len(self.vimLineData[i]['deepFlag'])
            if curDeep > parentDeep:
                # 备份原来的flag
                save_flag = self.vimLineData[i]['deepFlag'][newDeep - 1]
                # 预先设置deepFlag，如果插入失败的话，需要还原
                self.vimLineData[i]['deepFlag'][newDeep - 1] = 1

                # 当前节点为兄弟节点的子节点，跳过
                if curDeep > newDeep:
                    continue

                s2 = os.path.basename(
                    self.vimLineData[i]['node'].getAttribute('Name').encode('utf-8'))
                if cmp(s1.lower(), s2.lower()) > 0:
                    continue
                elif cmp(s1.lower(), s2.lower()) < 0:
                    # 先还原flag
                    self.vimLineData[i]['deepFlag'][newDeep - 1] = save_flag
                    # 插在中间
                    datum['deepFlag'] = parent['deepFlag'][:]
                    datum['deepFlag'].append(1)
                    self.vimLineData.insert(i, datum)
                    return self.DoGetLineNumByIndex(i)
                else:
                    # 无论如何都要先还原flag的了，因为即使要插入都是插在前面
                    self.vimLineData[i]['deepFlag'][newDeep - 1] = save_flag
                    # 区分大小写，但是排序的时候不区分大小写...
                    if cmp(s1, s2) != 0:
                        # 先还原flag
                        self.vimLineData[i]['deepFlag'][newDeep - 1] = save_flag
                        # 插入到前面
                        datum['deepFlag'] = parent['deepFlag'][:]
                        datum['deepFlag'].append(1)
                        self.vimLineData.insert(i, datum)
                        return self.DoGetLineNumByIndex(i)

                    return 0
            else:
                # 到达了深度比父节点小的节点，
                # 要么是兄弟，要么是祖先的兄弟。插在父节点最后
                datum['deepFlag'] = parent['deepFlag'][:]
                datum['deepFlag'].append(0)
                self.vimLineData.insert(i, datum)
                return self.DoGetLineNumByIndex(i)
        # 父节点是显示的最后的节点
        # 或者父节点是显示的最后的节点且新数据本应插在最后。插在最后
        datum['deepFlag'] = parent['deepFlag'][:]
        datum['deepFlag'].append(0)
        self.vimLineData.insert(self.GetLastLineNum() + 1, datum)
        return self.GetLastLineNum()

    def DoAddVdirOrFileNode(self, lineNum, nodeType, name, save = True,
                            insertingNode = None):
        '''会自动修正 name 为正确的相对路径，返回节点添加后所在的行号。
        如无法插入，如存在同名，则返回 0

        insertingNode: 指定插入的 xml 节点'''
        index = self.DoGetIndexByLineNum(lineNum)
        type = self.GetNodeType(lineNum)
        if index < 0 or type == TYPE_FILE or type == TYPE_INVALID \
           or type == TYPE_WORKSPACE:
            return 0

        parentDatum = self.vimLineData[index]
        parentNode = self.vimLineData[index]['node']
        newDatum = {}
        if nodeType == TYPE_FILE:
            if not os.path.isabs(name):
                # 若非绝对路径，必须相对于项目的目录
                name = os.path.join(parentDatum['project'].dirName, name)
            # 修改 name 为相对于项目文件目录的路径
            try:
                # 需要跟随链接
                name = os.path.relpath(os.path.realpath(os.path.abspath(name)), 
                                       parentDatum['project'].dirName)
            except ValueError, e:
                # 在 Windows 下，不同分区的的文件无法以相对路径访问
                # 不支持组织不同分区的文件于同一项目中
                print 'Error:',
                print e
                return 0
            newNode = self.doc.createElement('File')
        elif nodeType == TYPE_VIRTUALDIRECTORY:
            newNode = self.doc.createElement('VirtualDirectory')
        else:
            return 0

        # NOTE: 统一使用 posix 风格
        if IsWindowsOS():
            name = PosixPath(name)

        newNode.setAttribute('Name', name.decode('utf-8'))
        if insertingNode:
            # 若指定了 xml 节点，替换之
            newNode = insertingNode

        newDatum['node'] = newNode
        newDatum['expand'] = 0
        newDatum['project'] = parentDatum['project']

        # 更新 vimLineData
        ret = self.DoInsertChild(lineNum, newDatum)
        # 插入失败（同名冲突），返回
        if not ret:
            print 'Name Conflict: %s' % name
            return 0

        parentNode.appendChild(newNode)

        if nodeType == TYPE_FILE:
            # 添加此 filesIndex
            key = os.path.abspath(os.path.join(parentDatum['project'].dirName,
                                               name))
            fikey = os.path.realpath(key)
            self.filesIndex[fikey] = newNode
            # 添加此 fname2file
            key2 = os.path.basename(key)
            if not self.fname2file.has_key(key2):
                self.fname2file[key2] = set()
            self.fname2file[key2].add(key)

        # 保存
        if save:
            newDatum['project'].Save()

        return ret

    def DoCheckNameConflict(self, parentNode, checkName):
        '''检测是否存在名字冲突，如存在返回 True，否则返回 False'''
        for node in parentNode.childNodes:
            if node.nodeType != node.ELEMENT_NODE:
                continue

            name = node.getAttribute('Name').encode('utf-8')
            if not name:
                continue

            if os.path.basename(name) == os.path.basename(checkName):
                return True
            else:
                continue
        return False


#===============================================================================
# 外部用接口 ===== 开始
#===============================================================================
    #===========================================================================
    # Vim 操作接口 ===== 开始
    #===========================================================================
    def SetWorkspaceLineNum(self, lineNum):
        '''设置工作空间名称在 vim 显示时所在的行号以便修正索引'''
        if lineNum < 1:
            lineNum = 1
        self.DoSetLineOffset(lineNum - 1)

    def GetDatumByLineNum(self, lineNum):
        index = self.DoGetIndexByLineNum(lineNum)
        if index < 0 or index >= len(self.vimLineData):
            return None
        else:
            return self.vimLineData[index]

    def Expand(self, lineNum):#
        '''返回展开后增加的行数'''
        index = self.DoGetIndexByLineNum(lineNum)
        if index < 0: return 0
        rootDatum = self.vimLineData[index]
        node = self.vimLineData[index]['node']
        type = self.DoGetTypeByIndex(index)

        # 已经展开，无须操作
        if rootDatum['expand']:
            return 0

        # 修改展开前缀
        self.vimLineData[index]['expand'] = 1

        vdList = []
        vdDict = {}
        fileList = []
        fileDict = {}
        if type == TYPE_VIRTUALDIRECTORY or type == TYPE_PROJECT:
            # 如果有上次的缓存，直接用缓存
            # NOTE: 每次使用缓存的时候都要修正 deepFlag
            if rootDatum.has_key('children'):
                li = rootDatum['children']
                nDepth = len(rootDatum['deepFlag'])
                # 用根节点的 'deepFlag' 覆盖子节点的 'deepFlag'
                for dCacheDatum in li:
                    dCacheDatum['deepFlag'][: nDepth] = rootDatum['deepFlag']
                self.vimLineData[index+1:index+1] = li
                del rootDatum['children']
                return len(li)
            else:
                for i in node.childNodes:
                    if i.nodeName == 'VirtualDirectory':
                        deepFlag = rootDatum['deepFlag'][:]
                        deepFlag.append(1)
                        datum = {}
                        datum['node'] = i
                        datum['deepFlag'] = deepFlag[:]
                        datum['expand'] = 0
                        datum['project'] = rootDatum['project']
                        name = i.getAttribute('Name').encode('utf-8')
                        vdList.append(name)
                        vdDict[name] = datum
                    elif i.nodeName == 'File':
                        deepFlag = rootDatum['deepFlag'][:]
                        deepFlag.append(1)
                        datum = {}
                        datum['node'] = i
                        datum['deepFlag'] = deepFlag[:]
                        datum['expand'] = 0
                        datum['project'] = rootDatum['project']
                        name = i.getAttribute('Name').encode('utf-8')
                        fileList.append(os.path.basename(name))
                        fileDict[os.path.basename(name)] = datum
                li = []
                if vdList:
                    vdList.sort(CmpIC)
                    for i in vdList:
                        li.append(vdDict[i])
                if fileList:
                    fileList.sort(CmpIC)
                    for i in fileList:
                        li.append(fileDict[i])
                if li:
                    li[-1]['deepFlag'][-1] = 0
                self.vimLineData[index+1:index+1] = li
                return len(li)
        return 0

    def ExpandR(self, lineNum):#
        index = self.DoGetIndexByLineNum(lineNum)
        if index < 0: return 0
        datum = self.vimLineData[index]
        deep = len(datum['deepFlag'])

        count = 0
        i = lineNum
        while True:
            count += self.Expand(i)
            i += 1
            if self.GetNodeDepthByLineNum(i) <= deep:
                break
        return count

    def ExpandAll(self):#
        if not self.vimLineData:
            return

        i = self.GetRootLineNum(1) + 1
        while True:
            self.ExpandR(i)
            next = self.GetNextSiblingLineNum(i)
            if next == i:
                break
            i = next

    def Fold(self, lineNum):
        index = self.DoGetIndexByLineNum(lineNum)
        if index < 0: return 0
        rootDatum = self.vimLineData[index]
        node = rootDatum['node']
        type = self.DoGetTypeByIndex(index)

        # 已经是 fold 状态，无须操作
        if rootDatum['expand'] == 0:
            return 0

        rootDatum['expand'] = 0

        deep = len(rootDatum['deepFlag'])
        count = 0
        for i in range(index+1, len(self.vimLineData)):
            if len(self.vimLineData[i]['deepFlag']) <= deep:
                break
            else:
                count += 1
        rootDatum['children'] = self.vimLineData[index+1:index+1+count]
        del self.vimLineData[index+1:index+1+count]
        return count

    def FoldR(self, lineNum):
        index = self.DoGetIndexByLineNum(lineNum)
        if index < 0: return 0
        rootDatum = self.vimLineData[index]
        node = rootDatum['node']
        type = self.DoGetTypeByIndex(index)

        # 已经是 fold 状态，无须操作
        if rootDatum['expand'] == 0:
            return 0

        rootDatum['expand'] = 0

        deep = len(rootDatum['deepFlag'])
        count = 0
        for i in range(index+1, len(self.vimLineData)):
            if len(self.vimLineData[i]['deepFlag']) <= deep:
                break
            else:
                count += 1
        del self.vimLineData[index+1:index+1+count]
        return count

    def FoldAll(self):
        if not self.vimLineData:
            return

        i = self.GetRootLineNum(1) + 1
        while True:
            self.FoldR(i)
            next = self.GetNextSiblingLineNum(i)
            if next == i:
                break
            i = next

    def ClearAllVimLineDataChildrenCache(self):
        '''清除所有折叠后保存在父节点的字节点信息(缓存)
        主要用于避免, 在添加了新节点后, 缓存的 deepFlag 信息不同步问题'''
        for dLine in self.vimLineData:
            try:
                del dLine['children']
            except:
                pass

    def GetRootLineNum(self, lineNum = 0):#
        '''获取根节点的行号, 参数仅仅用于保持形式, 除此以外别无他用'''
        return 1 + self.lineOffset - 2

    def GetParentLineNum(self, lineNum):#
        '''如没有，返回相同的 lineNum，项目的父节点应为工作空间，但暂未实现'''
        deep = self.GetNodeDepthByLineNum(lineNum)
        if deep == 0: return lineNum

        if self.GetNodeType(lineNum) == TYPE_PROJECT:
            return self.GetRootLineNum(lineNum)

        for i in range(1, lineNum):
            j = lineNum - i
            curDeep = self.GetNodeDepthByLineNum(j)
            if curDeep == deep - 1:
                return j

        return lineNum

    def GetNextSiblingLineNum(self, lineNum):#
        '''如没有，返回相同的 lineNum'''
        deep = self.GetNodeDepthByLineNum(lineNum)
        if deep == 0: return lineNum

        for i in range(lineNum + 1, self.GetLastLineNum() + 1):
            curDeep = self.GetNodeDepthByLineNum(i)
            if curDeep < deep:
                break
            elif curDeep == deep:
                return i

        return lineNum

    def GetPrevSiblingLineNum(self, lineNum):#
        '''如没有，返回相同的 lineNum'''
        deep = self.GetNodeDepthByLineNum(lineNum)
        if deep == 0: return lineNum

        for i in range(1, lineNum):
            j = lineNum - i
            curDeep = self.GetNodeDepthByLineNum(j)
            if curDeep < deep:
                break
            elif curDeep == deep:
                return j

        return lineNum

    def GetLastChildrenLineNum(self, lineNum):
        '''获取展开的当前节点的最后个孩子的行号，
        如没有，返回原来的 lineNum'''
        deep = self.GetNodeDepthByLineNum(lineNum)
        if deep == 0: return lineNum

        result = lineNum

        for i in range(lineNum + 1, self.GetLastLineNum() + 1):
            curDeep = self.GetNodeDepthByLineNum(i)
            if curDeep > deep:
                result = i
            else:
                break

        return result

    def GetAllDisplayTexts(self):#
        texts = []
        texts.append(ToUtf8(self.name))
        for i in range(len(self.vimLineData)):
            texts.append(self.DoGetDispTextByIndex(i))
        return texts

    def GetXmlNode(self, lineNum):#
        index = self.DoGetIndexByLineNum(lineNum)
        if index < 0 or index >= len(self.vimLineData):
            return None
        else:
            return self.vimLineData[index]['node']

    def GetNodeType(self, lineNum):#
        index = self.DoGetIndexByLineNum(lineNum)
        if index < 0 or index >= len(self.vimLineData):
            if lineNum == self.GetRootLineNum(lineNum):
                return TYPE_WORKSPACE
            else:
                return TYPE_INVALID
        else:
            return self.DoGetTypeOfNode(self.vimLineData[index]['node'])

    def GetNodeTypeByLineNum(self, lineNum):
        return self.GetNodeType(lineNum)

    def GetNodeDepthByLineNum(self, lineNum):#
        '''返回节点的深度，如 lineNum 越界，返回 0'''
        index = self.DoGetIndexByLineNum(lineNum)
        if index < 0 or index >= len(self.vimLineData):
            return 0
        else:
            return len(self.vimLineData[index]['deepFlag'])

    def IsNodeExpand(self, lineNum):
        index = self.DoGetIndexByLineNum(lineNum)
        if index < 0: return False

        if self.vimLineData[index]['expand']:
            return True
        else:
            return False

    def GetLineText(self, lineNum):
        if lineNum == self.GetRootLineNum(lineNum):
            return self.name

        index = self.DoGetIndexByLineNum(lineNum)
        if index < 0: return ''

        return self.DoGetDispTextByIndex(index)

    def GetLastLineNum(self):
        return self.lineOffset + len(self.vimLineData) - 1

    def GetFileByLineNum(self, lineNum, absPath = False):
        '''这里是否获取文件名的唯一入口？'''
        datum = self.GetDatumByLineNum(lineNum)
        if not datum or self.GetNodeType(lineNum) != TYPE_FILE:
            return ''

        xmlNode = datum['node']
        file = xmlNode.getAttribute('Name').encode('utf-8')
        if absPath:
            ds = DirSaver()
            os.chdir(datum['project'].dirName)
            file = os.path.abspath(file)
        return os.path.normpath(file)

    def GetDispNameByLineNum(self, lineNum):
        datum = self.GetDatumByLineNum(lineNum)
        type = self.GetNodeType(lineNum)

        if type == TYPE_INVALID:
            return self.GetName()
        elif not datum:
            return ''

        xmlNode = datum['node']
        dispName = xmlNode.getAttribute('Name').encode('utf-8')
        return os.path.basename(dispName)

    def RenameNodeByLineNum(self, lineNum, newName):
        '''重命名节点，暂支持虚拟目录和文件'''
        datum = self.GetDatumByLineNum(lineNum)
        type = self.GetNodeType(lineNum)
        if type != TYPE_VIRTUALDIRECTORY and type != TYPE_FILE:
            return

        xmlNode = datum['node']
        project = datum['project']
        oldName = xmlNode.getAttribute('Name').encode('utf-8')
        if oldName == newName:
            return
        if self.DoCheckNameConflict(xmlNode.parentNode, newName):
            print 'Name Conflict: %s' % name
            return
        if type == TYPE_FILE:
            absOldFile = self.GetFileByLineNum(lineNum, True)
            dirName = os.path.dirname(absOldFile)
            absNewFile = os.path.join(dirName, newName)
            if os.path.exists(absNewFile):
                print 'Exists a same file'
                return
            elif os.path.exists(absOldFile):
                #print absOldFile
                #print absNewFile
                os.rename(absOldFile, absNewFile)
            else:
                pass

            # 修正 filesIndex
            oldKey = os.path.realpath(absOldFile)
            newKey = os.path.realpath(absNewFile)
            self.filesIndex[newKey] = self.filesIndex[oldKey]
            del self.filesIndex[oldKey]

            # 修正 fname2file
            oldKey = os.path.basename(absOldFile)
            self.fname2file[oldKey].remove(absOldFile)
            if not self.fname2file[oldKey]:
                del self.fname2file[oldKey]
            newKey = os.path.basename(absNewFile)
            if not self.fname2file.has_key(newKey):
                self.fname2file[newKey] = set()
            self.fname2file[newKey].add(absNewFile)

        xmlNode.setAttribute('Name', 
                             os.path.join(os.path.dirname(oldName),
                                          newName).decode('utf-8'))
        project.Save()

        #TODO: 重新排序

    def DeleteNode(self, lineNum, save = True):
        '''返回删除的行数，也即为 Vim 显示中减少的行数。
        支持项目、虚拟目录、文件'''
        index = self.DoGetIndexByLineNum(lineNum)
        if index < 0:
            return 0

        type = self.GetNodeType(lineNum)
        if type != TYPE_VIRTUALDIRECTORY and type != TYPE_FILE \
                   and type != TYPE_PROJECT:
            return 0

        # 若删除的节点为父节点的最后的子节点，需特殊处理
        if not self.DoIsHasNextSibling(index):
            ln = self.GetPrevSiblingLineNum(lineNum)
            if ln != lineNum:
                # 修正上一个兄弟节点到删除节点之间的所有节点的 deepFlag
                delDeep = self.GetNodeDepthByLineNum(lineNum)
                for i in range(ln, lineNum):
                    datum = self.GetDatumByLineNum(i)
                    datum['deepFlag'][delDeep - 1] = 0

        datum = self.GetDatumByLineNum(lineNum)
        delNode = datum['node']
        project = datum['project']
        deep = self.GetNodeDepthByLineNum(lineNum)

        # 计算删除的行数
        delLineCount = 1
        for i in range(lineNum + 1, self.GetLastLineNum() + 1):
            if deep < self.GetNodeDepthByLineNum(i):
                delLineCount += 1
            else:
                break

        if type == TYPE_FILE:
            # 删除此 filesIndex
            key = os.path.abspath(os.path.join(project.dirName,
                                               delNode.getAttribute('Name').encode('utf-8')))
            fikey = os.path.realpath(key)
            if self.filesIndex.has_key(fikey):
                del self.filesIndex[fikey]
            # 删除此 fname2file
            try:
                self.fname2file[os.path.basename(key)].remove(key)
            except KeyError:
                pass
        # 删除 xml 节点
        if type == TYPE_PROJECT:
            self.RemoveProject(project.name)
        else:
            delNode.parentNode.removeChild(delNode)

        # 直接重建好了，因为删除多少个文件难定
        if type == TYPE_VIRTUALDIRECTORY:
            self.GenerateFilesIndex()

        # 删除 vimLineData 相应数据
        del self.vimLineData[ index : index + delLineCount ]

        # 保存改变
        if save:
            if type == TYPE_PROJECT:
                self.Save()
            else:
                project.Save()

        return delLineCount

    def AddVirtualDirNode(self, lineNum, name):
        '''添加虚拟目录并保存'''
        return self.DoAddVdirOrFileNode(lineNum, TYPE_VIRTUALDIRECTORY, name)

    def AddFileNode(self, lineNum, name):
        '''添加文件节点并保存'''
        return self.DoAddVdirOrFileNode(lineNum, TYPE_FILE, name)

    def AddFileNodeQuickly(self, lineNum, name):
        '''添加文件节点，不保存'''
        return self.DoAddVdirOrFileNode(lineNum, TYPE_FILE, name, False)

    def ImportFilesFromDirectory(self, lineNum, directory, filters, files = []):
        '''从指定目录递归导入指定匹配的文件

        lineNum: 请求操作的行号，一般只允许在项目和虚拟目录节点时请求
        directory: 需要导入的目录
        filters: 匹配的文件，如 "*.cpp;*.cc;*.cxx;*.h;*.hpp;*.c;*.c++;*.tcc"
        '''
        # 为了实现的简单性，directory 不允许是已经存在的虚拟目录
        datum = self.GetDatumByLineNum(lineNum)
        type = self.GetNodeType(lineNum)
        if not datum or type == TYPE_INVALID or type == TYPE_FILE \
           or type == TYPE_WORKSPACE or not os.path.isdir(directory):
            return 0

        directory = os.path.abspath(directory)
        project = datum['project']
        rootNode = datum['node']
        xmlNode = DirectoryToXmlNode(directory, filters, project.dirName,
                                     files=files)
        if xmlNode:
            #print directory
            #print xmlNode.toprettyxml()
            ret = self.DoAddVdirOrFileNode(lineNum, TYPE_VIRTUALDIRECTORY,
                                           os.path.basename(directory),
                                           insertingNode = xmlNode)
            if not ret:
                return 0
            #if self.DoCheckNameConflict(rootNode, os.path.basename(directory)):
                #print 'Name Conflict: %s' % os.path.basename(directory)
                #return 0
            #rootNode.appendChild(xmlNode)
            #project.Save()
            self.GenerateFilesIndex()
            return ret

        return 0

    def SetActiveProjectByLineNum(self, lineNum):
        type = self.GetNodeType(lineNum)
        if type != TYPE_PROJECT:
            return False

        xmlNode = XmlUtils.FindNodeByName(
            self.rootNode, 'Project', self.activeProject)
        # 可能是刚加进来，根本没有上一个已激活的项目
        if xmlNode:
            xmlNode.setAttribute('Active', 'No')

        datum = self.GetDatumByLineNum(lineNum)
        xmlNode = XmlUtils.FindNodeByName(
            self.rootNode, 'Project', datum['project'].name)
        self.activeProject = datum['project'].name
        xmlNode.setAttribute('Active', 'Yes')

        self.Save()

    #===========================================================================
    # Vim 操作接口 ===== 结束
    #===========================================================================

#===============================================================================

    #===========================================================================
    # 常规操作接口 ===== 开始
    #===========================================================================
    def GetName(self):
        return self.name

    def GetWorkspaceFileName(self):
        return self.fileName

    def GetWorkspaceFileLastModifiedTime(self):
        return GetMTime(self.fileName)

    def GetWorkspaceLastModifiedTime(self):
        return self.modifyTime

    def SetWorkspaceLastModifiedTime(self, modTime):
        self.modifyTime = modTime

    def GetFileLastModifiedTime(self):
        return GetMTime(self.fileName)

    def GetActiveProjectName(self):
        return self.activeProject

    def SetActiveProject(self, name):
        xmlNode = XmlUtils.FindNodeByName(
            self.rootNode, 'Project', self.activeProject)
        xmlNode2 = XmlUtils.FindNodeByName(self.rootNode, 'Project', name)
        if not xmlNode2:
            return False

        if xmlNode:
            xmlNode.setAttribute('Active', 'No')

        self.activeProject = name
        xmlNode2.setAttribute('Active', 'Yes')
        self.Save()

    def GetBuildMatrix(self):
        return self.buildMatrix

    def SetBuildMatrix(self, buildMatrix, autoSave = True):
        '''此为保存 BuildMatrix 的唯一方式！'''
        oldBm = XmlUtils.FindFirstByTagName(self.rootNode, 'BuildMatrix')
        if oldBm:
            self.rootNode.removeChild(oldBm)

        self.rootNode.appendChild(buildMatrix.ToXmlNode())
        if autoSave:
            self.Save()
        self.buildMatrix = buildMatrix

        # force regeneration of makefiles for all projects
        for i in self.projects.itervalues():
            i.SetModified(True)

    def DisplayAll(self, dispLn = False, stream = sys.stdout):
        ln = 1
        if dispLn:
            stream.write('%02d ' % (ln,))
            ln += 1
        stream.write(self.name + '\n')
        for i in range(len(self.vimLineData)):
            if dispLn:
                stream.write('%02d ' % (ln,))
                ln += 1
            stream.write(self.DoGetDispTextByIndex(i) + '\n')

    def GetAllFiles(self, absPath = False):
        files = []
        for k, v in self.projects.iteritems():
            files.extend(v.GetAllFiles(absPath))
        return files

    def GenerateFilesIndex(self):
        self.filesIndex.clear()
        for k, v in self.projects.iteritems():
            self.filesIndex.update(v.GetFilesIndex())
        # 重建 fname2file
        self.fname2file.clear()
        for k in self.GetAllFiles(True):
            key2 = os.path.basename(k)
            if not self.fname2file.has_key(key2):
                self.fname2file[key2] = set()
            self.fname2file[key2].add(k)

    def GetProjectByFileName(self, fileName):
        '''从绝对路径的文件名中获取文件所在的项目实例'''
        fileName = os.path.realpath(fileName)
        if not self.filesIndex.has_key(fileName):
            return None

        node = self.filesIndex[fileName]
        projName = self.GetProjectNameByNode(node)

        return self.FindProjectByName(projName)

    def GetProjectNameByNode(self, node):
        while node:
            if node.nodeName == 'CodeLite_Project':
                return node.getAttribute('Name').encode('utf-8')
            node = node.parentNode
        return ''

    def GetProjectNameByLineNum(self, lineNum):
        '''返回某行所属的项目名字'''
        datum = self.GetDatumByLineNum(lineNum)
        if not datum:
            return ''
        return self.GetProjectNameByNode(datum['node'])

    def GetWspPathByLineNum(self, lineNum):
        '''根据行号获取工作区路径'''
        datum = self.GetDatumByLineNum(lineNum)
        if datum:
            return GetWspPathByNode(datum['node'])
        else:
            return ''

    def GetNodePathByLineNum(self, lineNum):
        nodepath = self.GetWspPathByLineNum(lineNum)
        if nodepath:
            return WSP_PATH_SEP + self.name + nodepath
        return nodepath

    def GetNodePathByFileName(self, fileName):
        nodepath = self.GetWspFilePathByFileName(fileName)
        # NOTE: 开始的时候没设计好，路径应该包括工作区名字，不改了
        if nodepath:
            return WSP_PATH_SEP + self.name + nodepath
        return nodepath

    def GetWspFilePathByFileName(self, fileName):
        '''从绝对路径的文件名中获取文件在工作空间的绝对路径

        从工作空间算起，如 /项目名/虚拟目录/文件显示名'''
        fileName = os.path.realpath(fileName)
        if not self.filesIndex.has_key(fileName):
            return ''

        node = self.filesIndex[fileName]
        return GetWspPathByNode(node)

    def IsWorkspaceFile(self, fileName):
        '''判断一个文件是否属于工作区'''
        if not fileName:
            return False
        fileName = os.path.realpath(fileName)
        return self.filesIndex.has_key(fileName)

    def TouchAllProjectFiles(self):
        '''更新本工作区包含的所有项目的项目文件，
        主要目的是另它们重建 Makefile'''
        for project in self.projects.itervalues():
            Touch(project.fileName)

    def TouchProject(self, projName):
        project = self.FindProjectByName(projName)
        if project:
            Touch(project.fileName)

#=====
    def CreateWorkspace(self, name, path):
        # If we have an open workspace, close it
        if self.rootNode:
            self.Save()

        if not name:
            print 'Invalid workspace name'
            return False

        # Create new
        self.fileName = os.path.abspath(os.path.join(path, name + os.extsep 
                                                     + WORKSPACE_FILE_SUFFIX))

        #ds = DirSaver()
        #os.chdir(path)
        dbFileName = './' + name + '.tags'
        # TagsManagerST.Get().OpenDatabase(dbFileName)

        self.doc = minidom.Document()
        self.rootNode = self.doc.createElement('CodeLite_Workspace')
        self.doc.appendChild(self.rootNode)
        self.rootNode.setAttribute('Name', name.decode('utf-8'))
        self.rootNode.setAttribute('Database', dbFileName.decode('utf-8'))

        self.Save()
        self.__init__(self.fileName)
        # create an empty build matrix
        self.SetBuildMatrix(BuildMatrix())
        return True

    def OpenWorkspace(self, fileName):
        # lineOffset 需要一直保持
        lineOffset = self.lineOffset
        self.__init__(fileName)
        self.lineOffset = lineOffset

    def CloseWorkspace(self):
        if self.rootNode:
            self.Save()
            lineOffset = self.lineOffset
            self.__init__()
            self.lineOffset = lineOffset

    def ReloadWorkspace(self):
        self.OpenWorkspace(self.fileName)

    def CreateProject(self, name, path, type, cmpType = '', 
                      addToBuildMatrix = True):
        if not self.rootNode:
            print 'No workspace open'
            return False

        if self.projects.has_key(name):
            print 'A project with the same name already exists in the '\
                    'workspace!'
            return False

        project = VLProject()
        project.Create(name, '', path, type)
        self.projects[name] = project

        if cmpType:
            settings = project.GetSettings()
            settings.GetBuildConfiguration('Debug').SetCompilerType(cmpType)
            project.SetSettings(settings)

        node = self.doc.createElement('Project')
        node.setAttribute('Name', name.decode('utf-8'))

        # make the project path to be relative to the workspace
        projFile = os.path.join(path, name + os.extsep + PROJECT_FILE_SUFFIX)
        # 跟随链接
        projFile = os.path.realpath(os.path.abspath(projFile))
        relFile = os.path.relpath(projFile, self.dirName)
        node.setAttribute('Path', relFile.decode('utf-8'))

        self.rootNode.appendChild(node)

        if len(self.projects) == 1:
            self.SetActiveProject(project.GetName())

        self.Save()
        if addToBuildMatrix:
            self.AddProjectToBuildMatrix(project)

        datum = {}
        datum['node'] = XmlUtils.GetRoot(project.doc)
        datum['expand'] = 0
        datum['project'] = project
        return self.DoInsertProject(self.GetRootLineNum(0), datum)

    def CreateProjectFromTemplate(self, name, path, templateFile, cmpType = ''):
        '''从模版创建项目，若 cmpType 未指定，使用模版默认值'''
        if not self.rootNode:
            print 'No workspace open'
            return False

        if self.projects.has_key(name):
            print 'A project with the same name already exists in the '\
                    'workspace!'
            return False

        if os.path.exists(path) and not os.path.isdir(path):
            print 'Invalid Path'
            return False

        projFile = os.path.join(path, name + os.extsep + PROJECT_FILE_SUFFIX)
        if os.path.exists(projFile):
            print 'The target project file already exists on the disk, '\
                    'just add the project to workspace instead.'
            return False

        errmsg = ''

        if not os.path.exists(path):
            os.makedirs(path)
        shutil.copy(templateFile, projFile)

        project = VLProject()
        project.Load(templateFile)

        for srcFile in project.GetAllFiles(True):
            # TODO: 如果有嵌套的文件夹呢？
            templateDir = os.path.dirname(templateFile)
            relSrcFile = os.path.relpath(srcFile, templateDir)
            dstFile = os.path.join(path, relSrcFile)
            # 只有目标文件不存在时才复制, 否则使用已存在的文件
            if not os.path.exists(dstFile):
                if not os.path.exists(srcFile):
                    # 如果支持用户自定义模板的话，就可能有这个错误了
                    errmsg += '%s not found\n' % srcFile
                else:
                    if not os.path.exists(os.path.dirname(dstFile)):
                        os.makedirs(os.path.dirname(dstFile))
                    shutil.copy(srcFile, dstFile)
        project.SetName(name)
        project.fileName = projFile
        if cmpType:
            settings = project.GetSettings()
            settings.GetBuildConfiguration('Debug').SetCompilerType(cmpType)
            project.SetSettings(settings)
        project.Save()

        del project
        return self.AddProject(projFile)

    def GetStringProperty(self, propName):
        if not self.rootNode:
            print 'No workspace open'
            return ''

        return self.rootNode.getAttribute(propName).encode('utf-8')

    def FindProjectByName(self, projName):
        '''返回 VLProject 实例'''
        if self.projects.has_key(projName):
            return self.projects[projName]
        else:
            return None

    def GetProjectList(self):
        '''返回工作空间包含的项目的名称列表'''
        li = self.projects.keys()
        li.sort(CmpIC)
        return li

    def AddProject(self, projFile):
        if not self.rootNode or not os.path.isfile(projFile):
            print 'No workspace open or file does not exist!'
            return False

        project = VLProject()
        project.Load(projFile)

        # 项目名称区分大小写
        if not self.projects.has_key(project.GetName()):
            # No project could be find, add it to the workspace
            self.projects[project.GetName()] = project
            relFile = os.path.relpath(project.fileName, self.dirName)
            node = self.doc.createElement('Project')
            node.setAttribute('Name', project.GetName().decode('utf-8'))
            node.setAttribute('Path', relFile.decode('utf-8'))
            node.setAttribute(
                'Active', len(self.projects) == 1 and 'Yes' or 'No')

            self.rootNode.appendChild(node)
            self.Save()
            self.AddProjectToBuildMatrix(project)

            # 仅有一个项目时，自动成为激活项目
            if len(self.projects) == 1:
                self.SetActiveProject(project.GetName())

            # 更新 filesIndex
            projectFilesIndex = project.GetFilesIndex()
            self.filesIndex.update(projectFilesIndex)
            # 更新 fname2file
            for k in project.GetAllFiles(True):
                key2 = os.path.basename(k)
                if not self.fname2file.has_key(key2):
                    self.fname2file[key2] = set()
                self.fname2file[key2].add(k)

            # 更新 vimLineData
            datum = {}
            datum['node'] = XmlUtils.GetRoot(project.doc)
            datum['expand'] = 0
            datum['project'] = project
            return self.DoInsertProject(self.GetRootLineNum(0), datum)
        else:
            print "A project with a similar name " \
                    "'%s' already exists in the workspace" % (project.GetName(),)
            return False

    def RemoveProject(self, name):
        '''仅仅在 .workspace 文件中清除，不操作项目依赖，改为 Export 时忽略'''
        project = self.FindProjectByName(name)
        if not project:
            return False

        # remove the associated build configuration with this project
        self.RemoveProjectFromBuildMatrix(project)

        del self.projects[project.GetName()]

        # update the xml file
        for i in self.rootNode.childNodes:
            if i.nodeName == 'Project' and i.getAttribute('Name').encode('utf-8') == name:
                if i.getAttribute('Active').lower() == 'Yes'.lower():
                    # the removed project was active
                    # select new project to be active
                    if self.projects:
                        self.SetActiveProject(self.GetProjectList()[0])
                self.rootNode.removeChild(i)
                break

        # FIXME: 可不删除，而是添加的时候覆盖，生成 makefile 的时候忽略
        # go over the dependencies list of each project and remove the project
        #for i in self.projects.itervalues():
        #    #
        #    settings = i.GetSettings()
        #    if settings:
        #        configs = []
        #        for j in settings.configs.itervalues():
        #            configs.append(j.GetName())
        #
        #    # update each configuration of this project
        #    for k in configs:
        #        deps = i.GetDependencies(k)
        #        try:
        #            index = deps.index(name)
        #        except ValueError:
        #            pass
        #        else:
        #            del deps[index]
        #        
        #        # update the configuration
        #        i.SetDependencies(deps, k)

        self.Save()
        return True

    def GetProjBuildConf(self, projectName, confName = ''):
        '''获取名称为 projectName 的项目构建设置实例。可方便地直接获取项目设置。
        此函数获取的是构建设置的副本！主要用于创建 makefile'''
        matrix = self.GetBuildMatrix()
        projConf = confName

        # 如果 confName 为空，从 BuildMatrix 中获取默认的值
        if not projConf:
            wsConfig = matrix.GetSelectedConfigurationName()
            projConf = matrix.GetProjectSelectedConf(wsConfig, projectName)

        project = self.FindProjectByName(projectName)
        if project:
            settings = project.GetSettings()
            if settings:
                # 获取副本，用于构建
                return settings.GetBuildConfiguration(projConf, True)
        return None

    def AddProjectToBuildMatrix(self, project):
        if not project:
            return

        # 获取当先的工作空间构建设置
        matrix = self.GetBuildMatrix()
        selConfName = matrix.GetSelectedConfigurationName()

        wspList = matrix.GetConfigurations()
        # 遍历所有 BuildMatrix 设置，分别添加 project 的构建设置进去
        for i in wspList:
            # 获取 WorkspaceConfiguration 的列表（顺序不重要）
            prjList = i.GetMapping()
            wspCnfName = i.GetName()

            settings = project.GetSettings()
            if not settings.configs:
                # the project does not have any settings, 
                # create new one and add it
                # 凡是有 ToXmlNode 方法的类的保存方法都是添加到有 doc 属性的类中
                project.SetSettings(settings)
                settings = project.GetSettings()
                prjBldConf = settings.configs(settings.configs.keys()[0])
                matchConf = prjBldConf
            else:
                prjBldConf = settings.configs[settings.configs.keys()[0]]
                matchConf = prjBldConf

                # try to locate the best match to add to the workspace
                # 尝试寻找 Configuration 名字和 WorkspaceConfiguration 的名字
                # 相同的添加进去
                for k, v in settings.configs.iteritems():
                    if wspCnfName == v.GetName():
                        matchConf = v
                        break

            entry = ConfigMappingEntry(project.GetName(), matchConf.GetName())
            prjList.append(entry)
            # prjList 为引用，可不需设置
            #i.SetConfigMappingList(prjList)
            # i 也为引用，可不需设置
            #matrix.SetConfiguration(i)

        # and set the configuration name.
        matrix.SetSelectedConfigurationName(selConfName)
        self.SetBuildMatrix(matrix)

    def RemoveProjectFromBuildMatrix(self, project):
        matrix = self.GetBuildMatrix()
        selConfName = matrix.GetSelectedConfigurationName()

        wspList = matrix.GetConfigurations()
        for i in wspList:
            prjList = i.GetMapping()
            for j in prjList:
                if j.project == project.GetName():
                    prjList.remove(j)
                    break

        matrix.SetSelectedConfigurationName(selConfName)
        self.SetBuildMatrix(matrix)

    def _SanityCheck4CutNodes(self, lineNum, length):
        '''无问题，返回True，否则返回False'''
        baseNodeType = self.GetNodeTypeByLineNum(lineNum)
        baseNodeDepth = self.GetNodeDepthByLineNum(lineNum)

        errmsg = ''

        if length <= 0:
            errmsg = 'Invalid operation'
            return False, errmsg

        # 暂时只支持剪切目录和文件
        if not (baseNodeType == TYPE_VIRTUALDIRECTORY or baseNodeType == TYPE_FILE):
            errmsg = 'Invalid operation'
            return False, errmsg

        # 现时最简单的处理，只支持剪切同类型同深度的节点
        for i in range(1, length):
            ln = lineNum + i
            nodeType = self.GetNodeTypeByLineNum(ln)
            nodeDepth = self.GetNodeDepthByLineNum(ln)
            if not (nodeType == baseNodeType and nodeDepth == baseNodeDepth):
                errmsg = 'Invalid operation'
                return False, errmsg
        else:
            return True, errmsg

    def _SanityCheck4PasteNodes(self, lineNum):
        '''
        NOTE: 会访问剪切板

        * 现时只支持同一个项目内剪切粘贴

        * 剪切板内容为单个或多个文件节点
            # 只允许在项目、目录下粘贴

        * 剪切板内容为单个或多个目录节点
            # 只允许在项目、目录下粘贴
        
        '''
        errmsg = ''
        if not self.clipboard.Peek():
            errmsg = 'Clipboard is empty'
            return False, errmsg

        cpbdData = self.clipboard.Peek()
        projName = self.GetProjectNameByLineNum(lineNum)
        if projName != cpbdData.projname:
            errmsg = 'Can not cut and paste nodes via different projects'
            return False, errmsg

        nodeType = self.GetNodeTypeByLineNum(lineNum)
        if nodeType == TYPE_VIRTUALDIRECTORY or nodeType == TYPE_PROJECT:
            return True, errmsg
        else:
            return False, errmsg

    def CutNodes(self, lineNum, length):
        '''返回剪切成功的行数'''
        ret, err = self._SanityCheck4CutNodes(lineNum, length)
        if not ret:
            return 0

        projName = self.GetProjectNameByLineNum(lineNum)
        result = 0
        delNodes = []
        for i in range(length):
            save = False
            if i == length - 1:
                save = True

            # 删除的索引是一直不变的，因为节点一直往上推
            datum = self.GetDatumByLineNum(lineNum)
            # 保存的节点
            delNodes.append(datum['node'])
            # 实际的删除操作
            result += self.DeleteNode(lineNum, save)

        if length > 1:
            self.clipboard.Push(WspCpbdData(projName, delNodes))
        else:
            self.clipboard.Push(WspCpbdData(projName, delNodes[0]))

        return result

    def PasteNodes(self, lineNum):
        '''返回粘贴成功的行数
        0:  非法操作
        -1: 存在名字冲突'''
        ret, err = self._SanityCheck4PasteNodes(lineNum)
        if not ret:
            return 0

        cpbdData = self.clipboard.Peek()
        v = cpbdData.data
        if not isinstance(v, list):
            v = [v]

        datum = self.GetDatumByLineNum(lineNum)
        parentNode = datum['node']
        # 要检查名字冲突...
        for node in v:
            # 每个节点分别检查名字冲突
            name = node.getAttribute('Name').encode('utf-8')
            if self.DoCheckNameConflict(parentNode, name):
                return -1

        # 清掉
        self.clipboard.Pop()

        result = 0
        # ok，所有检查已经过关，粘贴
        nodeType = self.DoGetTypeOfNode(v[0])
        if   nodeType == TYPE_FILE:
            vlen = len(v)
            for idx, node in enumerate(v):
                save = False
                if idx == vlen - 1:
                    save = True
                name = node.getAttribute('Name').encode('utf-8')
                result += self.DoAddVdirOrFileNode(lineNum, nodeType, name,
                                                   save, insertingNode = node)
        elif nodeType == TYPE_VIRTUALDIRECTORY:
            vlen = len(v)
            for idx, node in enumerate(v):
                save = False
                if idx == vlen - 1:
                    save = True
                name = node.getAttribute('Name').encode('utf-8')
                result += self.DoAddVdirOrFileNode(lineNum, nodeType, name,
                                                   save, insertingNode = node)
        else:
            pass

        # FIXME: 现在这个返回值毫无意义
        return result

#=====

    def Save(self, fileName = ''):
        '''保存 .workspace 文件，如果是默认工作空间，不保存'''
        if not fileName and not self.fileName:
            return

        self.SetBuildMatrix(self.buildMatrix, False)

        try:
            if not fileName:
                fileName = self.fileName
            dirName = os.path.dirname(fileName)
            if not os.path.exists(dirName):
                os.makedirs(dirName)
            f = open(fileName, 'wb')
        except IOError:
            print 'IOError:', fileName
            raise IOError
        #f.write(self.doc.toxml('utf-8'))
        f.write(XmlUtils.ToPrettyXmlString(self.doc))
        f.close()

    def SaveAll(self, fileName = ''):
        '''保存 .workspace 文件以及所有项目的 .project 文件，
        如果是默认工作空间，不保存'''
        if not fileName and not self.fileName:
            return

        self.Save(fileName)

        for i in self.projects.itervalues():
            i.Save()

    def ConvertToNewFileFormat(self):
        if not self.fileName:
            return

        # 修改工作区文件中关于项目路径的文本
        for i in self.rootNode.childNodes:
            if i.nodeName == 'Project':
                path = i.getAttribute('Path').encode('utf-8')
                newPath = os.path.splitext(path)[0] + os.extsep \
                        + PROJECT_FILE_SUFFIX
                i.setAttribute('Path', newPath.decode('utf-8'))

        newFileName = os.path.splitext(self.fileName)[0] + os.extsep \
                + WORKSPACE_FILE_SUFFIX
        self.Save(newFileName)

        for i in self.projects.itervalues():
            newFileName = os.path.splitext(i.fileName)[0] + os.extsep \
                    + PROJECT_FILE_SUFFIX
            i.Save(newFileName)

    def _SetStatus(self, status):
        self.status = status

    #===========================================================================
    # 常规操作接口 ===== 结束
    #===========================================================================

    def IsOpen(self):
        return self.status == type(self).STATUS_OPEN

#===============================================================================
# 外部用接口 ===== 结束
#===============================================================================


class VLWorkspaceST:
    __ins = None

    @staticmethod
    def Get():
        if not VLWorkspaceST.__ins:
            VLWorkspaceST.__ins = VLWorkspace()
        return VLWorkspaceST.__ins

    @staticmethod
    def Free():
        VLWorkspaceST.__ins = None



#===============================================================================

if __name__ == '__main__':
    import BuilderGnuMake
    bd = BuilderGnuMake.BuilderGnuMake()
    ws = VLWorkspaceST.Get()
    ws.OpenWorkspace(sys.argv[1])
    #print ws.activeProject
    #print ws.vimLineData
    #print ws.projects
    #print ws.modifyTime
    #print ws.name
    #print ws.DoGetDispTextByIndex(0)
    #print ws.DoGetDispTextByIndex(1)
    ws.DisplayAll(True)
    print '-'*80
    #print ws.filesIndex
    print ws.GetProjectByFileName(
        '/home/eph/Desktop/VimLite/WorkspaceMgr/Test/C++/CTest/main.c')
    #bd.Export(ws.GetDatumByLineNum(9)['project'].name, '')
    #ws.SetActiveProjectByLineNum(2)
    #ws.Expand(2)
    #ws.Expand(3)
    #ws.Expand(11)
    #ws.Fold(2)
    #ws.DisplayAll(True)
    #print '-'*80
    #ws.Expand(2)
    #ws.DisplayAll(True)
    #print '-'*80
    #ws.Expand(3)
    #ws.DisplayAll(True)
    #ws.Expand(5)
    #ws.Expand(6)
    #ws.Expand(7)
    #ws.DisplayAll(True)
    #ws.Fold(2)
    #ws.DisplayAll(True)
    #ws.Expand(2)
    #ws.DisplayAll(True)

    #print '-' * 80
    #print os.getcwd()
    #print '\n'.join(ws.GetAllDisplayTexts())
    #print ws.GetAllDisplayTexts()

