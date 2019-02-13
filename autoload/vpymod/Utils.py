#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''工具集。多数为和Macros.py关联的常数的例程'''

import sys
import os
import os.path
import time
import re
import getpass
import subprocess
import shlex
from Macros import *

'''\
源文件的判断是全局的，并且任何人都可以随时修改
不能替换 C_XXX_EXT 系列变量的实例，只能原地更新，因为有不同的地方引用着它们
'''

def VPrint(*args, **kargs):
    '''
    #define KERN_EMERG      "<0>"   /* system is unusable                   */
    #define KERN_ALERT      "<1>"   /* action must be taken immediately     */
    #define KERN_CRIT       "<2>"   /* critical conditions                  */
    #define KERN_ERR        "<3>"   /* error conditions                     */
    #define KERN_WARNING    "<4>"   /* warning conditions                   */
    #define KERN_NOTICE     "<5>"   /* normal but significant condition     */
    #define KERN_INFO       "<6>"   /* informational                        */
    #define KERN_DEBUG      "<7>"   /* debug-level messages                 */
    '''
    #from __future__ import print_function
    lv = kargs.get('lv', 6)
    sep = kargs.get('sep', ' ')
    end = kargs.get('end', '\n')
    file = kargs.get('file', sys.stdout)
    for arg in args:
        print arg
    #print(value, *args, sep=sep, end=end, file=file)

def IsVDirNameIllegal(name):
    '''虚拟目录不带任何路径'''
    if not name:
        return True
    if '/' in name or '\\' in name:
        return True
    if name == '.' or name == '..':
        return True

    return False

def IsFileNameIllegal(name):
    '''文件名可以带路经，但是不能以'/'结尾'''
    if not name:
        return True
    if name.endswith('/') or name.endswith('\\'):
        return True
    basename = os.path.basename(name)
    if '/' in basename or '\\' in basename:
        return True
    if basename == '.' or basename == '..':
        return True

    return False

def CSrcExtReset():
    global C_SOURCE_EXT
    C_SOURCE_EXT.clear()
    C_SOURCE_EXT.update(DEFAULT_C_SOURCE_EXT)

def CppSrcExtReset():
    global CPP_SOURCE_EXT
    CPP_SOURCE_EXT.clear()
    CPP_SOURCE_EXT.update(DEFAULT_CPP_SOURCE_EXT)

def CSrcExtSet(exts):
    global C_SOURCE_EXT
    C_SOURCE_EXT.clear()
    C_SOURCE_EXT.update(exts)

def CppSrcExtSet(exts):
    global CPP_SOURCE_EXT
    CPP_SOURCE_EXT.clear()
    CPP_SOURCE_EXT.update(exts)

def IsCSourceFile(fileName, default=False):
    '''default为真时，表示使用通用的判断'''
    ext = os.path.splitext(fileName)[1]
    exts = C_SOURCE_EXT
    if default:
        exts = DEFAULT_C_SOURCE_EXT
    if ext in exts:
        return True
    else:
        return False

def IsCppSourceFile(fileName, default=False):
    ext = os.path.splitext(fileName)[1]
    exts = CPP_SOURCE_EXT
    if default:
        exts = DEFAULT_CPP_SOURCE_EXT
    if ext in exts:
        return True
    else:
        return False

def IsCCppSourceFile(fileName, default=False):
    return IsCSourceFile(fileName, default) or IsCppSourceFile(fileName, default)

def IsCppHeaderFile(fileName, default=False):
    ext = os.path.splitext(fileName)[1]
    # NOTE: cpp头文件后缀名暂不支持定制
    exts = CPP_HEADER_EXT
    if default:
        exts = CPP_HEADER_EXT
    if ext in exts:
        return True
    else:
        return False

def StripVariablesForShell(sExpr):
    '''剔除所有 $( name ) 形式的字符串, 防止被 shell 解析'''
    p = re.compile(r'(\$\(\s*[a-zA-Z_]\w*\s*[^)]*\))')
    return p.sub('', sExpr)

def SplitVarDef(string):
    '''按照 gnu make 的方式分割变量，返回 key, val'''
    key = ''
    val = ''
    # TODO: 虽然这样已经处理绝大多数情况了
    key, op, val = string.partition('=')
    if not op: # 语法错误的话
        key = ''
        val = ''
    key = key.strip()
    val = val.lstrip()
    return key, val

def ExpandVariables(sString, dVariables, bTrimVar = False):
    '''单次(非递归)展开 $(VarName) 形式的变量
    只要确保 dVariables 字典的值是最终展开的值即可
    bTrimVar 为真时，未定义的变量会用空字符代替，否则就保留原样
             默认值是为了兼容'''
    if not sString or not dVariables:
        return sString

    p = re.compile(r'(\$+\([a-zA-Z_]\w*\))')

    nStartIdx = 0
    sResult = ''
    while True:
        m = p.search(sString, nStartIdx)
        if m:
            # 例如 $$(name) <- 这不是要求展开变量
            sResult += sString[nStartIdx : m.start(1)]
            n = m.group(1).find('$(')
            if not n & 1: # $( 前面的 $ 的数目是双数，需要展开
                sVarName = m.group(1)[n+2:-1]
                if bTrimVar:
                    sVarVal = str(dVariables.get(sVarName, ''))
                    sResult += '$' * n
                    sResult += sVarVal
                else:
                    if dVariables.has_key(sVarName):
                        # 成功展开变量的时候，前面的 $ 全数保留
                        sResult += '$' * n
                        sResult += str(dVariables[sVarName])
                    else: # 不能展开的，保留原样，$ 全数保留
                        sResult += m.group(1)
            else:
                #sResult += '$' * ((n - 1) / 2)
                #sResult += m.group(1)[n:]
                sResult += m.group(1)
            nStartIdx = m.end(1)
        else:
            sResult += sString[nStartIdx :]
            break

    return sResult

def ExpandBacktick(exp):
    # 展开所有命令表达式
    # 只支持 `` 内的表达式, 不支持 $(shell ) 形式
    # 因为经常用到在 Makefile 里面的变量, 为了统一, 无法支持 $(shell ) 形式
    # TODO: 用以下正则匹配脱字符包含的字符串 r'`(?:[^`]|(?<=\\)`)*`'
    tmpExp = ''
    i = 0
    while i < len(exp):
        c = exp[i]
        if c == '`':
            backtick = ''
            found = False
            i += 1
            while i < len(exp):
                if exp[i] == '`':
                    found = True
                    break
                backtick += exp[i]
                i += 1

            if not found:
                print "Syntax error in exp: %s, expecting '`'" % exp
                return exp
            else:
                output = os.popen(backtick).read()
                tmp = ' '.join([x for x in output.split('\n') if x])
                tmpExp += tmp
        else:
            tmpExp += c
        i += 1

    return tmpExp

def ExpandAllVariables_SList(exprList, workspace, projName, projConfName = '',
                             fileName = ''):
    '''批量展开，经常用到'''
    from EnvVarSettings import EnvVarSettingsST
    # 先批量展开内部宏
    exprList = ExpandAllInterMacros(exprList, workspace, projName,
                                    projConfName, fileName)
    result = []
    for exp in exprList:
        # 再展开环境变量
        exp = EnvVarSettingsST.Get().ExpandVariables(exp, trim=True)
        # 最后展开``
        exp = ExpandBacktick(exp)
        # 最最后处理转义的 '$'
        result.append(exp.replace('$$', '$'))
    return result

def ExpandAllVariables(expression, workspace, projName, projConfName = '', 
                       fileName = ''):
    '''展开所有变量，所有变量引用的形式都会被替换
    会展开脱字符(`)的表达式，但是，不展开 $(shell ) 形式的表达式

    先展开内部的变量，再展开环境变量，最后展开 `` 的表达式
    只作一次展开，不会递归展开

    expression      - 需要展开的表达式, 可为空
    workspace       - 工作区实例, 可为空
    projName        - 项目名字, 可为空
    projConfName    - 项目构建设置名称, 可为空
    fileName        - 文件名字, 要求为绝对路径, 可为空

    RETURN          - 展开后的表达式'''
    from EnvVarSettings import EnvVarSettingsST

    exp = expression
    # 先展开内置宏
    exp = ExpandAllInterMacros(exp, workspace, projName, projConfName, fileName)
    # 再展开环境变量
    exp = EnvVarSettingsST.Get().ExpandVariables(exp, trim=True)
    # 最后展开``
    exp = ExpandBacktick(exp)
    # 最最后处理转义的 '$'
    return exp.replace('$$', '$')

def ExpandAllInterMacros(expression, workspace, projName, projConfName = '',
                         fileName = ''):
    '''展开所有内部变量

    expression      - 需要展开的表达式, 可为空，可为列表[str1, str2, ...]
    workspace       - 工作区实例, 可为空
    projName        - 项目名字, 可为空
    projConfName    - 项目构建设置名称, 可为空
    fileName        - 文件名字, 要求为绝对路径, 可为空
    
    支持的变量有:
    $(User)
    $(Date)
    $(CodeLitePath)

    $(WorkspaceName)
    $(WorkspacePath)

    $(ProjectName)
    $(ProjectPath)
    $(ConfigurationName)
    - 这两个个变量可能嵌套
    - 支持嵌套上面的宏，其他的则不支持
    $(IntermediateDirectory)
    $(OutDir)

    $(ProjectFiles)
    $(ProjectFilesAbs)

    $(CurrentFileName)
    $(CurrentFileExt)
    $(CurrentFilePath)
    $(CurrentFileFullPath)
    '''
    if not expression:
        return expression

    exprList = []
    if isinstance(expression, list):
        # 字符串列表
        exprList = expression
        expression = exprList[0]
    else:
        # 字符串
        if not '$' in expression:
            return expression

    dVariables = {}

    dVariables['User'] = getpass.getuser()
    dVariables['Date'] = time.strftime('%Y-%m-%d', time.localtime())
    dVariables['CodeLitePath'] = os.path.expanduser('~/.codelite')

    if workspace:
        dVariables['WorkspaceName'] = workspace.GetName()
        dVariables['WorkspacePath'] = workspace.dirName
        project = workspace.FindProjectByName(projName)
        if project:
            dVariables['ProjectName'] = project.GetName()
            dVariables['ProjectPath'] = project.dirName

            bldConf = workspace.GetProjBuildConf(project.GetName(), projConfName)
            if bldConf:
                dVariables['ConfigurationName'] = bldConf.GetName()
                imd = bldConf.GetIntermediateDirectory()
                # 先展开中间目录的变量
                # 中间目录不能包含自身和自身的别名 $(OutDir)
                # 可包含的变量为此之前添加的变量
                #imd = EnvVarSettingsST.Get().ExpandVariables(imd)
                imd = ExpandVariables(imd, dVariables)
                dVariables['IntermediateDirectory'] = imd
                dVariables['OutDir'] = imd

            # NOTE: 是必定包含忽略的文件的
            if '$(ProjectFiles)' in expression or exprList:
                dVariables['ProjectFiles'] = \
                        ' '.join([ '"%s"' % i for i in project.GetAllFiles()])
            if '$(ProjectFilesAbs)' in expression or exprList:
                dVariables['ProjectFilesAbs'] = \
                        ' '.join([ '"%s"' % i for i in project.GetAllFiles(True)])

    if fileName:
        dVariables['CurrentFileName'] = \
                os.path.splitext(os.path.basename(fileName))[0]
        dVariables['CurrentFileExt'] = \
                os.path.splitext(os.path.basename(fileName))[1][1:]
        dVariables['CurrentFilePath'] = \
                NormalizePath(os.path.dirname(fileName))
        dVariables['CurrentFileFullPath'] = NormalizePath(fileName)

    if dVariables.has_key('OutDir'): # 这个变量由于由用户定义，所以可以嵌套变量
        imd = dVariables['OutDir']
        del dVariables['OutDir']
        del dVariables['IntermediateDirectory']
        imd = ExpandVariables(imd, dVariables, False)
        # 再展开环境变量
        #imd = EnvVarSettingsST.Get().ExpandVariables(imd, True)
        dVariables['OutDir'] = imd
        dVariables['IntermediateDirectory'] = dVariables['OutDir']

    if exprList:
        result = [ExpandVariables(e, dVariables, False) for e in exprList]
    else:
        result = ExpandVariables(expression, dVariables, False)

    return result

#===============================================================================
# shell 命令展开工具
#===============================================================================
# DEPRECATED
def __ExpandShellCmd(s):
    p = re.compile(r'\$\(shell +(.+?)\)')
    return p.sub(ExpandCallback, s)

def GetIncludesFromArgs(s, sw = '-I'):
    #return filter(lambda x: x.startswith(sw),
                  #GetIncludesAndMacrosFromArgs(s, incSwitch = sw))
    return GetOptsFromArgs(s, sw)

def GetMacrosFromArgs(s, sw = '-D'):
    '''返回的结果带 switch'''
    #return filter(lambda x: x.startswith(sw),
                  #GetIncludesAndMacrosFromArgs(s, defSwitch = sw))
    return GetOptsFromArgs(s, sw)

def GetOptsFromArgs(s, sw):
    if len(sw) != 2: raise ValueError('Invalid function parameter: %s' % sw)
    # 使用内建的方法，更好
    li = shlex.split(s)
    idx = 0
    result = []
    while idx < len(li):
        elm = li[idx]
        if elm.startswith(sw):
            if elm == sw: # '-D abc' 形式
                if idx + 1 < len(li):
                    result.append(sw + li[idx+1])
                    idx += 1
                else: # 这里是参数错误了
                    pass
            else:
                result.append(elm)
        idx += 1
    return result

# = DEPRECATED =
def _GetIncludesAndMacrosFromArgs(s, incSwitch = '-I', defSwitch = '-D'):
    '''不支持 -I /usr/include 形式，只支持 -I/usr/include
    返回的结果带 switch'''
    results = []
    p = re.compile(r'(?:' + incSwitch + r'"((?:[^"]|(?<=\\)")*)")'
                   + r'|' + incSwitch + r'((?:\\ |\S)+)'
                   + r'|(' + defSwitch + r'[a-zA-Z_][a-zA-Z_0-9]*)')
    for m in p.finditer(s):
        if m.group(1):
            # -I""
            results.append(incSwitch + m.group(1).replace('\\', ''))
        if m.group(2):
            # -I\ \ a 和 -Iabc
            results.append(incSwitch + m.group(2).replace('\\', ''))
        if m.group(3):
            # -D_DEBUG
            results.append(m.group(3))

    return results

def GetCmdOutput(cmd):
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
    return p.stdout.read().rstrip()

def ExpandCallback(m):
    return GetCmdOutput(m.group(1))

#===============================================================================

if __name__ == '__main__':
    import unittest
    import getopt

    class test(unittest.TestCase):
        def testGetArgs(self):
            s = r'-I/usr/include -I"/usr/local/include" -I\ \ /us\ r/include'
            s += ' -D_DEBUG'
            res = _GetIncludesAndMacrosFromArgs(s)
            #print res
            self.assertTrue(res[0] == '-I/usr/include')
            self.assertTrue(res[1] == '-I/usr/local/include')
            self.assertTrue(res[2] == '-I  /us r/include')
            self.assertTrue(res[3] == '-D_DEBUG')

            res = GetIncludesFromArgs(s)
            self.assertTrue(res[0] == '-I/usr/include')
            self.assertTrue(res[1] == '-I/usr/local/include')
            self.assertTrue(res[2] == '-I  /us r/include')

            res = GetMacrosFromArgs(s)
            self.assertTrue(res[0] == '-D_DEBUG')

        def testIsCppSourceFile(self):
            self.assertFalse(IsCppSourceFile('/a.c'))
            self.assertTrue(IsCSourceFile('/a.c'))
            self.assertTrue(IsCppSourceFile('./a.cxx'))
            self.assertTrue(not IsCppSourceFile('./a.cx'))

        def testIsCppHeaderFile(self):
            self.assertTrue(IsCppHeaderFile('b.h'))
            self.assertTrue(IsCppHeaderFile('/homt/a.hxx'))
            self.assertFalse(IsCppHeaderFile('iostream'))
            self.assertTrue(not IsCppHeaderFile('iostream.a'))

        def testStripVariablesForShell(self):
            self.assertTrue(
                StripVariablesForShell(' sne $(CodeLitePath) , $( ooxx  )')
                 == ' sne  , ')
            self.assertTrue(StripVariablesForShell('') == '')

        def testExpandVariables(self):
            d = {'name': 'aa', 'value': 'bb', 'temp': 'cc'}
            s = '  $$$(name), $$(value), $(temp) $$$(x) '
            print ExpandVariables(s, d)
            self.assertTrue(ExpandVariables(s, d, True) 
                            == '  $$aa, $$(value), cc $$ ')
            self.assertTrue(ExpandVariables(s, d, False) 
                            == '  $$aa, $$(value), cc $$$(x) ')

    s = r'-I/usr/include -I"/usr/local/include" -I\ \ /us\ r/include'
    s += ' -D_DEBUG'
    s += ' -I /usr/xxx/include'
    li = shlex.split(s)
    print s
    print li
    optlist, args = getopt.getopt(li, 'I:D:')
    print optlist
    print args
    print '-' * 10
    print GetIncludesFromArgs(s)
    print GetMacrosFromArgs(s)

    print StripVariablesForShell('a $(shell wx-config --cxxflags) b')

    print '= unittest ='
    unittest.main() # 跑这个函数会直接退出，所以后面的语句会全部跑不了

