#!/usr/bin/env python
# -*- encoding:utf-8 -*-

import random
import unittest
import sys
import os
sys.path.append('..')
import XmlUtils

from Project import Project


class TestProject(unittest.TestCase):
    def setUp(self):
        pass
        
    def testInit(self):
        ins = Project()
        self.assertFalse(ins.name)
        self.assertFalse(ins.fileName)
        self.assertFalse(ins.dirName)
        self.assertFalse(ins.baseName)
        self.assertFalse(ins.isModified)
        self.assertFalse(ins.tranActive)
        self.assertEqual(ins.modifyTime, 0)
        self.assertFalse(ins.vdCache)
        ins.Load('test.project.orig')
        cwd = os.getcwd()
        self.assertEqual(ins.GetName(), 'abbreviation')
        self.assertEqual(ins.GetFileName(), os.path.join(cwd, ins.baseName))
        self.assertEqual(ins.dirName, cwd)
        self.assertEqual(ins.modifyTime, int(os.path.getmtime('test.project.orig')))
        self.assertTrue(ins.IsModified())
        ins.SetModified(False)
        self.assertFalse(ins.IsModified())
        ins.SetModified(True)
        self.assertTrue(ins.IsModified())
        
        ins = Project('test.project.orig')
        self.assertEqual(ins.GetName(), 'abbreviation')
        self.assertEqual(ins.GetFileName(), os.path.join(cwd, ins.baseName))
        self.assertEqual(ins.dirName, cwd)
        self.assertEqual(ins.modifyTime, int(os.path.getmtime('test.project.orig')))
        
        # TODO
        #print ins.GetSettings().ToXmlNode().toprettyxml()
        
    def testCreate(self):
        result='''<?xml version="1.0" ?><Codelite_Project Name="helloworld"><Description>firsttest</Description><VirtualDirectory Name="src"/><VirtualDirectory Name="include"/><Dependencies/><Settings Type="Static Library"><GlobalSettings><Compiler C_Options="" Options=""><IncludePath Value="."/></Compiler><Linker Options=""><LibraryPath Value="."/></Linker><ResourceCompiler Options=""/></GlobalSettings><Configuration BuildCmpWithGlobalSettings="append" BuildLnkWithGlobalSettings="append" BuildResWithGlobalSettings="append" CompilerType="cobra" DebuggerType="GNU gdb debugger" Name="Debug" Type="Executable"><Compiler C_Options="-g;-Wall" Options="-g;-Wall" PreCompiledHeader="" Required="yes"><IncludePath Value="."/></Compiler><Linker Options="-O0" Required="yes"><LibraryPath Value="."/><LibraryPath Value="Debug"/></Linker><ResourceCompiler Options="" Required="no"/><General Command="" CommandArguments="" DebugArguments="" IntermediateDirectory="./Debug" OutputFile="" PauseExecWhenProcTerminates="yes" UseSeparateDebugArgs="no" WorkingDirectory="./Debug"/><Environment DbgSetName="&lt;Use Global Settings&gt;" EnvVarSetName="&lt;Use Workspace Settings&gt;"/><Debugger DebuggerPath="" IsRemote="no" RemoteHostName="" RemoteHostPort=""><StartupCommands/><PostConnectCommands/></Debugger><PreBuild/><PostBuild/><CustomBuild Enabled="no"><WorkingDirectory/><ThirdPartyToolName/><MakefileGenerationCommand/><SingleFileCommand/><PreprocessFileCommand/><BuildCommand/><CleanCommand/><RebuildCommand/></CustomBuild><AdditionalRules><CustomPreBuild/><CustomPostBuild/></AdditionalRules></Configuration></Settings><Settings Type="Static Library"><GlobalSettings><Compiler C_Options="" Options=""><IncludePath Value="."/></Compiler><Linker Options=""><LibraryPath Value="."/></Linker><ResourceCompiler Options=""/></GlobalSettings><Configuration BuildCmpWithGlobalSettings="append" BuildLnkWithGlobalSettings="append" BuildResWithGlobalSettings="append" CompilerType="cobra" DebuggerType="GNU gdb debugger" Name="Debug" Type="Executable"><Compiler C_Options="-g;-Wall" Options="-g;-Wall" PreCompiledHeader="" Required="yes"><IncludePath Value="."/></Compiler><Linker Options="-O0" Required="yes"><LibraryPath Value="."/><LibraryPath Value="Debug"/></Linker><ResourceCompiler Options="" Required="no"/><General Command="" CommandArguments="" DebugArguments="" IntermediateDirectory="./Debug" OutputFile="" PauseExecWhenProcTerminates="yes" UseSeparateDebugArgs="no" WorkingDirectory="./Debug"/><Environment DbgSetName="&lt;Use Global Settings&gt;" EnvVarSetName="&lt;Use Workspace Settings&gt;"/><Debugger DebuggerPath="" IsRemote="no" RemoteHostName="" RemoteHostPort=""><StartupCommands/><PostConnectCommands/></Debugger><PreBuild/><PostBuild/><CustomBuild Enabled="no"><WorkingDirectory/><ThirdPartyToolName/><MakefileGenerationCommand/><SingleFileCommand/><PreprocessFileCommand/><BuildCommand/><CleanCommand/><RebuildCommand/></CustomBuild><AdditionalRules><CustomPreBuild/><CustomPostBuild/></AdditionalRules></Configuration></Settings></Codelite_Project>'''
        ins = Project()
        ins.Create('helloworld', 'firsttest', os.getcwd(), Project.EXECUTABLE)
        self.assertEqual(ins.doc.toxml(), result)
        self.assertEqual(ins.GetDescription(), 'firsttest')
    
    def testGetAllFiles(self):
        ins = Project('test.project.orig')
        result = [u'abbreviation.cpp', u'abbreviationentry.cpp', u'abbreviationentry.h', u'abbreviation.h', u'abbreviationssettingsbase.cpp', u'abbreviationssettingsbase.h', u'abbreviationssettingsdlg.h', u'abbreviationssettingsdlg.cpp', u'abbreviationssettingsbase.fbp']
        root = XmlUtils.GetRoot(ins.doc)
        self.assertEqual(ins.GetFilesOfNode(root), result)
        self.assertEqual(ins.GetAllFiles(), result)
        self.assertEqual(ins.DoFindFile(XmlUtils.GetRoot(ins.doc), 'abbreviationentry.h').toxml(), '<File Name="abbreviationentry.h"/>')
        
        absFile = ins.GetAllFiles(True)
        for index in range(len(absFile)):
            self.assertEqual(os.path.join(os.getcwd(), result[index]), absFile[index])
        
        for i in result:
            self.assertTrue(ins.IsFileExists(i))
            self.assertFalse(ins.IsFileExists(i+'x'))

    def testDependencies(self):
        ins = Project('test.project.orig')
        self.assertFalse(ins.GetDependencies(''))
        
        ins.Load('LiteEditor.project.orig')
        self.assertEqual(ins.GetDependencies('scripts'), ins.GetDependencies(''))
        result = [u'wxscintilla', u'sqlite3', u'wxsqlite3', u'CodeLite', u'plugin_sdk', u'CodeFormatter', u'DebuggerGDB', u'Gizmos', u'Cscope', u'Copyright', u'UnitTestPP', u'ContinuousBuild', u'ExternalTools', u'CppChecker', u'QMakePlugin', u'Subversion2', u'SymbolView', u'abbreviation', u'snipwiz', u'wxFormBuilder']
        self.assertEqual(ins.GetDependencies('Win_wxWidgets_29'), result)
        
        #TODO: test SetDependencies

if __name__ == '__main__':
    unittest.main()