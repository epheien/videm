#!/usr/bin/env python
# -*- encoding:utf-8 -*-

class Comment:
    def __init__(self, comment = '', file = '', line = 0):
        self.comment = comment
        self.file = file
        self.line = line
        if self.comment:
            self.comment = self.comment.rstrip()

    def GetComment(self):
        return self.comment

    def GetFile(self):
        return self.file

    def GetLine(self):
        return self.line
