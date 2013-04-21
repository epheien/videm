#!/usr/bin/env python
# -*- encoding:utf-8 -*-

import random
import unittest
import sys
import os
import os.path
import shutil
sys.path.append('..')
import XmlUtils
from VLWorkspace import VLWorkspace
from VLProject import VLProject

output1=''' 1
     2
         3
             4
             5
         6
     7
         8
             9
     10
         11'''

expandAll = [u'C++', u'|~CTest', u'| `~src', u'|   `-main.c', u'`~JustTest', u'  `~src', u'    `-main.cpp']
foldAll = [u'C++', u'|+CTest', u'`+JustTest']

resultFoldAll = [u'LiteEditor', u'|+abbreviation', u'|+CodeFormatter', u'|+CodeLite', u'|+ContinuousBuild', u'|+Copyright', u'|+CppChecker', u'|+Cscope', u'|+DebuggerGDB', u'|+ExternalTools', u'|+git', u'|+Gizmos', u'|+Interfaces', u'|+LiteEditor', u'|+MacBundler', u'|+plugin_sdk', u'|+QMakePlugin', u'|+snipwiz', u'|+sqlite3', u'|+Subversion2', u'|+SymbolView', u'|+UnitTestPP', u'|+wxFormBuilder', u'|+wxscintilla', u'`+wxsqlite3']

result1 = [u'LiteEditor', u'|+abbreviation', u'|+CodeFormatter', u'|+CodeLite', u'|+ContinuousBuild', u'|+Copyright', u'|+CppChecker', u'|+Cscope', u'|+DebuggerGDB', u'|+ExternalTools', u'|+git', u'|+Gizmos', u'|+Interfaces', u'|+LiteEditor', u'|+MacBundler', u'|+plugin_sdk', u'|+QMakePlugin', u'|+snipwiz', u'|+sqlite3', u'|+Subversion2', u'|+SymbolView', u'|+UnitTestPP', u'|+wxFormBuilder', u'|~wxscintilla', u'| |~src', u'| | `~scintilla', u'| |   |~include', u'| |   | |-ILexer.h', u'| |   | |-Platform.h', u'| |   | |-SciLexer.h', u'| |   | |-Scintilla.h', u'| |   | `-ScintillaWidget.h', u'| |   |+lexers', u'| |   |+lexlib', u'| |   `+src', u'| `~wxScintilla', u'|   |~include', u'|   | `-wxscintilla.h', u'|   `~src', u'|     |-gtkstring.h', u'|     |-PlatWX.cpp', u'|     |-PlatWX.h', u'|     |-ScintillaWX.cpp', u'|     |-ScintillaWX.h', u'|     `-wxscintilla.cpp', u'`+wxsqlite3']

class TestTree(unittest.TestCase):
    def setUp(self):
        pass
        
    def testFoldNExpand(self):
        '''覆盖了所有 expand 和 fold 的函数，并覆盖 GetRoot... GetParent... GetxxxSibling...'''
        ins = VLWorkspace('C++/C++.workspace')
        self.assertEqual(ins.activeProject, 'CTest')
        #print ins.modifyTime
        #ins.DisplayAll(True)
        self.assertEqual(ins.GetAllDisplayTexts(), foldAll)
        ins.Expand(2)
        ins.Expand(3)
        ins.Expand(5)
        ins.Expand(6)
        ins.Expand(7)
        self.assertEqual(ins.GetAllDisplayTexts(), expandAll)
        ins.Fold(2)
        self.assertEqual(ins.GetAllDisplayTexts(), [u'C++', u'|+CTest', u'`~JustTest', u'  `~src', u'    `-main.cpp'])
        ins.Expand(2)
        self.assertEqual(ins.GetAllDisplayTexts(), expandAll)

        ins = VLWorkspace('CodeLite/LiteEditor.workspace')
        self.assertEqual(ins.GetAllDisplayTexts(), resultFoldAll)
        ins.Expand(24)
        ins.Expand(25)
        ins.Expand(26)
        ins.Expand(31)
        ins.Expand(32)
        ins.Expand(27)
        ins.Expand(27)
        ins.Expand(28)
        ins.Expand(39)
        self.assertEqual(ins.GetAllDisplayTexts(), result1)
        ins.Fold(36)
        ins.Expand(36)
        self.assertEqual(ins.GetAllDisplayTexts(), result1)
        ins.FoldR(36)
        ins.Expand(36)
        self.assertNotEqual(ins.GetAllDisplayTexts(), result1)
        
        #print ins.Expand(38)
        #ins.DisplayAll(True)
        #print '-' * 80
        #print ins.GetFileByLineNum(28)
        #print ins.GetFileByLineNum(28, True)
        #print ins.GetFileByLineNum(29, True)
        #print '\n'.join(ins.GetAllFiles(True))
        #print ins.DeleteNode(25)
        
        #print
        #print ins.AddFileNode(36, 'abcdefg.c')
        #print ins.AddVirtualDirNode(24, 'zabcdefg.c')
        #print ins.AddVirtualDirNode(24, 'abcdefg.c')
        #print ins.AddVirtualDirNode(48, 'zbc defg.c')
        #ins.DisplayAll(True)
        
        self.assertEqual(ins.GetPrevSiblingLineNum(33), 27)
        self.assertEqual(ins.GetPrevSiblingLineNum(27), 27)
        self.assertEqual(ins.GetPrevSiblingLineNum(36), 25)
        self.assertEqual(ins.GetNextSiblingLineNum(27), 33)
        self.assertEqual(ins.GetNextSiblingLineNum(38), 38)
        self.assertEqual(ins.GetNextSiblingLineNum(24), 39)
        
        self.assertEqual(ins.GetParentLineNum(32), 27)
        self.assertEqual(ins.GetParentLineNum(27), 26)
        self.assertEqual(ins.GetParentLineNum(26), 25)
        self.assertEqual(ins.GetParentLineNum(25), 24)
        self.assertEqual(ins.GetParentLineNum(24), 1)
        self.assertEqual(ins.GetRootLineNum(39), 1)
        self.assertEqual(ins.GetParentLineNum(35), 26)
        
        #ins.ExpandR(2)
        ins.ExpandAll()
        with open('result.txt') as f:
            li = ins.GetAllDisplayTexts()
            for i in range(len(li)):
                self.assertEqual(f.readline(), li[i] + '\n')
                self.assertEqual(li[i], ins.GetLineText(i + 1))
        self.assertEqual(ins.GetLastLineNum(), 1472)
        ins.FoldAll()
        self.assertEqual(ins.GetAllDisplayTexts(), resultFoldAll)
        
    def testAddNDel(self):
        return
        if os.path.exists('CodeLite_test'):
            shutil.rmtree('CodeLite_test')
        shutil.copytree('CodeLite', 'CodeLite_test')
        ins = VLWorkspace('CodeLite_test/LiteEditor.workspace')
        ins.Expand(24)
        ins.Expand(25)
        ins.Expand(26)
        ins.Expand(31)
        ins.Expand(32)
        ins.Expand(27)
        ins.Expand(27)
        ins.Expand(28)
        ins.Expand(39)
        ins.DisplayAll(True)
        
        self.assertEqual(ins.GetFileByLineNum(28), 'src/scintilla/include/ILexer.h')
        self.assertEqual(ins.GetFileByLineNum(28, True), os.path.join(os.getcwd(), 'CodeLite_test/sdk/wxscintilla/src/scintilla/include/ILexer.h'))
        self.assertEqual(ins.GetFileByLineNum(29, True), os.path.join(os.getcwd(), 'CodeLite_test/sdk/wxscintilla/src/scintilla/include/Platform.h'))
        ##print '\n'.join(ins.GetAllFiles(True))
        
        print ins.DeleteNode(25)

        print ins.AddFileNode(28, 'abcdefg.c')
        ins.DisplayAll(True)

        #print ins.AddVirtualDirNode(24, 'zabcdefg.c')
        #print ins.AddVirtualDirNode(24, 'abcdefg.c')
        #print ins.AddVirtualDirNode(48, 'zbc defg.c')
        #ins.DisplayAll(True)
    
    def testAddProj(self):
        return
        #ins = VLWorkspace('CodeLite_test/LiteEditor.workspace')
        #ins.Expand(2)
        #ins.Expand(4)
        #ins.DisplayAll(True)
        #return
        if os.path.exists('CodeLite_test'):
            shutil.rmtree('CodeLite_test')
        shutil.copytree('CodeLite', 'CodeLite_test')
        ins = VLWorkspace('CodeLite_test/LiteEditor.workspace')
        ins.DisplayAll()
        ins.CreateProject('TEST', '.', VLProject.EXECUTABLE)
        ins.DisplayAll()
        ins.CreateProject('AA', '.', VLProject.EXECUTABLE)
        ins.DisplayAll()
        ins.CreateProject('ZZ', '.', VLProject.EXECUTABLE)
        ins.DisplayAll()

    def testCreateProjectFromTemplate(self):
        ins = VLWorkspace('CodeLite_test/LiteEditor.workspace')
        ins.DisplayAll(True)
        ins.CreateProjectFromTemplate(
            'zzzzz',
            '/home/eph/Desktop/VimLite/WorkspaceMgr/Test/CodeLite_test/ttt',
            '/home/eph/.codelite/templates/projects/executable-gcc/executable-gcc.project')
        ins.DisplayAll(True)
        

if __name__ == '__main__':
    unittest.main()
