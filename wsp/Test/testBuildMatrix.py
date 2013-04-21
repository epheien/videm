#!/usr/bin/env python
# -*- encoding:utf-8 -*-

import random
import unittest
import sys
sys.path.append('..')
from xml.dom import minidom
import XmlUtils

from BuildMatrix import BuildMatrix


class TestTree(unittest.TestCase):
    def setUp(self):
        pass
        
    def testInit(self):
        doc = minidom.parse('CodeLite/LiteEditor.workspace')
        rootNode = XmlUtils.GetRoot(doc)
        bmNode = XmlUtils.FindFirstByTagName(rootNode, 'BuildMatrix')
        #print bmNode.toxml()
        bm = BuildMatrix(bmNode)
        self.assertEqual(len(bm.configurationList), 5)
        nameList = []
        for i in bm.configurationList:
            nameList.append(i.name)
        self.assertEqual(nameList, [u'Win Release Unicode', u'Win Debug Unicode', u'Unix_Custom_Makefile', u'Mac_Custom_Makefile', u'Win_wxWidgets_29'])
        self.assertEqual(bm.GetSelectedConfigurationName(), 'Win Release Unicode')
        self.assertEqual(bm.GetProjectSelectedConf('Unix_Custom_Makefile', 'LiteEditor'), 'Unix_Make_J')
        #print bm.ToXmlNode().toprettyxml()


if __name__ == '__main__':
    unittest.main()