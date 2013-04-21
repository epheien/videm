#!/usr/bin/env python
# -*- encoding:utf-8 -*-

import random
import unittest
import sys
sys.path.append('..')

from ProjectSettings import ProjectSettings


ouput_default='''<Settings Type="Static Library"><GlobalSettings><Compiler C_Options="" Options=""><IncludePath Value="."/></Compiler><Linker Options=""><LibraryPath Value="."/></Linker><ResourceCompiler Options=""/></GlobalSettings><Configuration BuildCmpWithGlobalSettings="append" BuildLnkWithGlobalSettings="append" BuildResWithGlobalSettings="append" CompilerType="cobra" DebuggerType="GNU gdb debugger" Name="Debug" Type="Executable"><Compiler C_Options="-g;-Wall" Options="-g;-Wall" PreCompiledHeader="" Required="yes"><IncludePath Value="."/></Compiler><Linker Options="-O0" Required="yes"><LibraryPath Value="."/><LibraryPath Value="Debug"/></Linker><ResourceCompiler Options="" Required="no"/><General Command="" CommandArguments="" DebugArguments="" IntermediateDirectory="./Debug" OutputFile="" PauseExecWhenProcTerminates="yes" UseSeparateDebugArgs="no" WorkingDirectory="./Debug"/><Environment DbgSetName="&lt;Use Global Settings&gt;" EnvVarSetName="&lt;Use Workspace Settings&gt;"/><Debugger DebuggerPath="" IsRemote="no" RemoteHostName="" RemoteHostPort=""><StartupCommands/><PostConnectCommands/></Debugger><PreBuild/><PostBuild/><CustomBuild Enabled="no"><WorkingDirectory/><ThirdPartyToolName/><MakefileGenerationCommand/><SingleFileCommand/><PreprocessFileCommand/><BuildCommand/><CleanCommand/><RebuildCommand/></CustomBuild><AdditionalRules><CustomPreBuild/><CustomPostBuild/></AdditionalRules></Configuration></Settings>'''



class TestTree(unittest.TestCase):
    def setUp(self):
        pass

        
    def testInit(self):
        '''覆盖 __init__, Clone, ToXmlNode'''
        ins = ProjectSettings()
        
        node = ins.ToXmlNode()
        cloned = ins.Clone()
        # 测试初始化与 Clone()
        self.assertEqual(node.toxml(), cloned.ToXmlNode().toxml())
        #print node.toprettyxml()
        #print '-' * 40
        #print cloned.ToXmlNode().toprettyxml()
        # 测试默认的配置
        self.assertEqual(ins.ToXmlNode().toxml(), ouput_default)
        #print node.toprettyxml()
        
    def testGetBuildConfiguration(self):
        ins = ProjectSettings()
        n1 = ins.ToXmlNode()
        n2 = ins.GetBuildConfiguration('Debug')
        self.assertFalse(ins.GetBuildConfiguration('gnn'))
        self.assertEqual(ins.configs['Debug'].ToXmlNode().toxml(), n2.ToXmlNode().toxml())
        self.assertEqual(n1.childNodes[1].toxml(), n2.ToXmlNode().toxml())
        
        # TODO: 测试归并全局配置
        #n3 = ins.GetBuildConfiguration('Debug', True).ToXmlNode()
        #print n3.toprettyxml()
        
        self.assertEqual(ins.GetProjectType(''), 'Static Library')
        self.assertEqual(ins.GetProjectType('Debug'), 'Executable')
        
        pass


if __name__ == '__main__':
    unittest.main()