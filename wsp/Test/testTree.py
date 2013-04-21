#!/usr/bin/env python
# -*- encoding:utf-8 -*-

import random
import unittest
import sys
sys.path.append('..')

from Tree import Tree

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


class TestTree(unittest.TestCase):
    def setUp(self):
        self.tree = Tree(10, 13)
        self.t = Tree(1, 10)
        self.n1 = self.t.GetRoot()
        
        self.n2 = self.t.AddChild(2,20, self.n1)
        self.n7 = self.t.AddChild(7,70, self.n1)
        self.n10 = self.t.AddChild(10,100, self.n1)
        
        
        self.n3 = self.t.AddChild(3,30, self.n2)
        self.n4 = self.t.AddChild(4,40, self.n3)
        self.n5 = self.t.AddChild(5,50, self.n3)
        
        self.n6 = self.t.AddChild(6,60, self.n2)
        
        self.n8 = self.t.AddChild(8,80, self.n7)
        self.n9 = self.t.AddChild(9,90, self.n8)
        
        self.n11 = self.t.AddChild(11, 110, self.n10)
        
        #print self.t.nodes
        
    def testInit(self):
        self.assertEqual(self.tree.root.key, 10)
        self.assertEqual(self.tree.root.data, 13)
        self.assertEqual(self.tree.nodes, {})
        self.assertFalse(self.tree.nodes)
    
    def testAddChild(self):
        self.assertTrue(len(self.t.nodes.keys()) == 10)
        self.t.Print()
        print self.t.ToList()
        self.assertEqual(self.t.ToList(), self.t.ToVector())
        self.assertEqual(self.t.nodes.keys(), range(2, 12))
    
    def testFind(self):
        self.assertTrue(self.t.Find(5))
        self.assertFalse(self.t.Find(12))
    
    def testReomve(self):
        self.t.Remove(3)
        self.assertEqual(len(self.t.ToList()), 11 - 3)
        self.assertEqual(len(self.t.nodes), 11 - 3 - 1)
        self.assertFalse(self.t.Find(3))
        self.assertFalse(self.t.Find(4))
        self.assertFalse(self.t.Find(5))
        
    def testCompare(self):
        #TODO:
        pass 


if __name__ == '__main__':
    unittest.main()