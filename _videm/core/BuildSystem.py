#!/usr/bin/env python
# -*- encoding:utf-8 -*-

from xml.dom import minidom
import XmlUtils

class BuildSystem:
    '''代表一个构建系统，例如 gnu make，ms nmake'''
    def __init__(self, node = None):
        self.name = ''
        self.toolPath = ''
        self.toolOptions = ''
        self.toolJobs = ''
        self.isActive = False

        # added on 2011-12-10: 替代 toolPath, toolOptions, toolJobs，为了泛用
        self.command = ''
        
        if node:
            self.name = XmlUtils.ReadString(node, 'Name')
            self.toolPath = XmlUtils.ReadString(node, 'ToolPath')
            self.toolOptions = XmlUtils.ReadString(node, 'Options')
            self.toolJobs = XmlUtils.ReadString(node, 'Jobs', '1')
            self.isActive = XmlUtils.ReadBool(node, 'Active', self.isActive)

            self.command = node.getAttribute('Command')
            if not self.command:
                self.command = "%s %s" % (self.toolPath, self.toolOptions)
        
    def SetActive(self, isActive):
        self.isActive = isActive
    
    def IsActive(self):
        return self.isActive
    
    def ToXmlNode(self):
        node = minidom.Document().createElement('BuildSystem')
        node.setAttribute('Name', self.name)
        node.setAttribute('ToolPath', self.toolPath)
        node.setAttribute('Options', self.toolOptions)
        node.setAttribute('Jobs', self.toolJobs)

        node.setAttribute('Command', self.command)
        
        if self.isActive:
            node.setAttribute('Active', 'yes')
        else:
            node.setAttribute('Active', 'no')
        
        return node

    def GetCommand(self):
        return self.command

    def SetCommand(self, command):
        self.command = command


if __name__ == '__main__':
    xmlStr = '''<BuildSystem Name="GNU makefile for g++/gcc" ToolPath="make" Options="-f" Jobs="4" Active="yes"/>'''
    xmlStr2 = '''<BuildSystem Name="GNU makefile onestep build" ToolPath="make" Options="-f" Jobs="1" Active="no"/>'''
    doc = minidom.parseString(xmlStr)
    #print doc.firstChild.toxml()
    doc2 = minidom.parseString(xmlStr2)
    #print doc.toxml()
    
    bs = BuildSystem(doc2.firstChild)
    print bs.ToXmlNode().toxml()
    
