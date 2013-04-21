#!/usr/bin/env python
# -*- encoding:utf-8 -*-

import random
import unittest
import sys
sys.path.append('..')
import XmlUtils

from BuildSettingsConfig import BuildSettingsConfig
from BuildSettingsConfig import BuildSettingsConfigST

class TestBuildSettingsConfig(unittest.TestCase):
    def setUp(self):
        #self.ins = BuildSettingsConfig()
        self.ins = BuildSettingsConfigST.Get()
        ins = self.ins
        #print ins
        #print ins.doc.toxml()
        #self.ins.Load('2.0.6', 'build_settings.xml')
        #print ins.GetCompilerNode('gnu gcc').toprettyxml()
        #print '-' * 80
        #print ins.GetCompiler('gnu gcc').ToXmlNode().toprettyxml()

    def testST(self):
        self.assertTrue(self.ins is BuildSettingsConfigST.Get())
        #print self.ins
        #print BuildSettingsConfigST.Get()

    def testLoad(self):
        self.assertEqual(self.ins.fileName, 'build_settings.xml.orig')
        root = XmlUtils.GetRoot(self.ins.doc)
        self.assertEqual(root.nodeName, 'BuildSettings')
        self.assertEqual(XmlUtils.ReadString(root, 'Version'), '2.0.7')
        #print XmlUtils.ReadString(root, 'Version')
        
    def testGetCompilerNode(self):
        self.ins.Load('2.0.6', 'build_settings.xml.orig')
        self.assertFalse(self.ins.GetCompilerNode('gnn gcc'))
        node = self.ins.GetCompilerNode('gnu g++')
        self.assertEqual(XmlUtils.ReadString(node, 'Name'), 'gnu g++')
        node = self.ins.GetCompilerNode('cobra')
        self.assertEqual(XmlUtils.ReadString(node, 'Name'), 'cobra')
        #with open('BuildSettingsConfigTest.xml', 'wb') as f:
        #    self.ins.doc.writexml(f)
    
    def testSetNGetCompiler(self):
        #TODO: assert 
        self.ins.Load('2.0.7', 'build_settings.xml.orig')
        cmp1 = self.ins.GetFirstCompiler()
        cmp2 = self.ins.GetNextCompiler()
        cmp3 = self.ins.GetCompiler('gnu gcc')
        self.assertEqual(cmp1.name, 'cobra')
        self.assertEqual(cmp2.name, 'gnu g++')
        self.assertEqual(cmp3.name, 'gnu gcc')
        self.ins.Load('3', 'build_settings.xml')
        self.ins.DeleteCompiler('gnu gcc')
        self.ins.DeleteCompiler('cobra')
        self.ins.DeleteCompiler('gnu g++')
        self.assertFalse(self.ins.GetFirstCompiler())
        self.ins.SetCompiler(cmp1)
        self.ins.SetCompiler(cmp2)
        self.ins.SetCompiler(cmp3)
        #self.ins.Set
        
    
    def testDeleteCompiler(self):
        #self.ins.Load('2.0.6', 'build_settings.xml')
        #self.ins.DeleteCompiler('gnu gcc')
        #self.ins.DeleteCompiler('cobra')
        #self.ins.DeleteCompiler('gnu g++')
        #print self.ins.doc.toxml()
        pass
    
    def testGetFirstNNextNIsExist(self):
        self.ins.Load('2.0.6', 'build_settings.xml.orig')
        self.assertEqual(self.ins.GetFirstCompiler().name, 'cobra')
        self.assertEqual(self.ins.GetNextCompiler().name, 'gnu g++')
        self.assertEqual(self.ins.GetFirstCompiler().name, 'cobra')
        self.assertEqual(self.ins.GetNextCompiler().name, 'gnu g++')
        self.assertEqual(self.ins.GetNextCompiler().name, 'gnu gcc')
        self.assertEqual(self.ins.GetNextCompiler(), None)
        
        self.assertTrue(self.ins.IsCompilerExist('gnu gcc'))
        self.assertFalse(self.ins.IsCompilerExist('gnu gccc'))
        
    def testGetBuilderConfig(self):
        self.ins.Load('2.0.6', 'build_settings.xml.orig')
        self.assertFalse(self.ins.GetBuilderConfig('helloworld'))
        bs1 = self.ins.GetBuilderConfig('GNU makefile for g++/gcc')
        self.assertEqual(bs1.name, 'GNU makefile for g++/gcc')
        self.assertEqual(bs1.toolPath, 'make')
        self.assertEqual(bs1.toolOptions, '-f')
        self.assertEqual(bs1.toolJobs, '4')
        self.assertEqual(bs1.GetIsActive(), True)
        bs1.SetIsActive(False)
        self.assertEqual(bs1.GetIsActive(), False)
        bs2 = self.ins.GetBuilderConfig('GNU makefile onestep build')
        self.assertEqual(bs2.name, 'GNU makefile onestep build')
        self.assertEqual(bs2.toolPath, 'make')
        self.assertEqual(bs2.toolOptions, '-f')
        self.assertEqual(bs2.toolJobs, '1')
        self.assertEqual(bs2.GetIsActive(), False)
        bs2.SetIsActive(True)
        self.assertEqual(bs2.GetIsActive(), True)
        
        self.assertEqual(self.ins.GetSelectedBuildSystem(), 'GNU makefile for g++/gcc')


if __name__ == '__main__':
    unittest.main()