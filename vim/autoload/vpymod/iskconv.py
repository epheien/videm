#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''转换vim的iskeyword选项到python的re模块用的模式'''

import re

isfname = '@,48-57,/,.,-,_,+,,,#,$,%,~,='
iskeyword = '@,48-57,_,192-255,:,#'
tc0 = "@,48-57,/,\,.,-,_,+,,,#,$,%,{,},[,],:,@-@,!,~,="
tc1 = "@,48-57,/,.,-,_,+,,,$,:"
tc2 = "@,48-57,/,.,-,_,+,,,#,$,%,<,>,[,],:,;,~"
tc3 = "@,240-249,/,.,-,_,+,,,#,$,%,~,="
tc4 = "@,48-57,/,.,-,_,+,,,#,$,%,~,="
tc5 = "@,48-57,_,128-167,224-235"
tc6 = "@,48-57,_,192-255"
tc7 = "@,48-57,_"

testcases = \
    [
     '!-~,^*,^|,^",192-255',
     isfname, iskeyword, tc0, tc1, tc3, tc4, tc5, tc6, tc7,
     "_,-,128-140,#-43",
     "^a-z,#,^",
     "@,^a-z",
     "a-z,A-Z,@-@",
     "48-57,,,_",
     " -~,^,,9",
]

def Conv2PattList(opt, ascii_only = False):
    li = SplitOptions(opt)
    return Conv2PyrePat(li, ascii_only)

class TokensReader:
    def __init__(self, tokens, null = None):
        '''tokens 必须是列表'''
        self.tokens = tokens[::-1]
        self.popeds = [] # 已经被弹出去的 token，用于支持 _PrevToken()
        self.null = null # 代表无值状态

    def GetToken(self):
        '''获取下一个 token，若到尾部，返回 self.null'''
        if self.tokens:
            tok = self.tokens.pop(-1)
            self.popeds.append(tok)
            return tok
        else:
            # popeds 数据结构也要加上这个，以便统一处理
            if self.popeds and not self.popeds[-1] is self.null:
                self.popeds.append(self.null)
            return self.null

    def UngetToken(self, token):
        '''反推 token，外部负责 token 的正确性'''
        self.tokens.append(token)
        if self.popeds:
            self.popeds.pop(-1)

    def PeekToken(self):
        if self.tokens:
            return self.tokens[-1]
        else:
            return self.null

    def _PrevToken(self):
        if len(self.popeds) >= 2:
            return self.popeds[-2]
        else:
            return self.null

def GetNumberItem(chrrdr):
    item = ''
    # 取完全部数字
    while chrrdr.PeekToken():
        if chrrdr.PeekToken().isdigit():
            item += chrrdr.GetToken()
            continue
        break
    return item

def SplitOptions(seq):
    li = []
    '''
    该选项的格式为逗号分隔的部分的列表。每个部分是单个字符数值或者一个范
    围。范围包括两个字符数值，中间以 '-' 相连。字符数值可以是一个 0 到 255
    的十进制数，或者是 ASCII 字符自身 (不包括数字字符)。例如:
    '''
    chrrdr = TokensReader(list(seq), '')
    while True:
        # 每一轮需要完成一个部分的解析
        item = ''
        char = chrrdr.GetToken()
        if not char:
            break

        '''
        如果一个部分以 '^' 开始，则后面的字符数值或范围从选项里被排除。选项
        的解释从左到右。排除的字符应放在包含该字符的范围之后。要包含 '^' 自
        身，让它成为选项的最后一个字符，或者成为范围的结尾。
        '''
        if char == '^':
            item += char
            char = chrrdr.GetToken()
            # 如果是最后那个, 则直接结束即可
            if chrrdr.PeekToken() is chrrdr.null:
                li.append(item)
                break

        if char == ',':
            item += char
            li.append(item)
            chrrdr.GetToken() # 丢掉分隔符','
            continue
        elif char.isdigit():
            item += char
            item += GetNumberItem(chrrdr)

            nextchar = chrrdr.GetToken()
            if nextchar == ',':
                # 本条目完成, 开始下一条目
                li.append(item)
                continue
            elif nextchar == '-':
                # 本条目是一个范围
                item += nextchar
                nextchar = chrrdr.GetToken()
                if nextchar.isdigit():
                    # 取完数字
                    item += nextchar
                    item += GetNumberItem(chrrdr)
                else:
                    # ASCII码本字
                    item += nextchar
                li.append(item)
                chrrdr.GetToken() # 丢掉分隔符','
                continue
            elif nextchar is chrrdr.null:
                li.append(item)
                # 处理完毕了
                break
            else:
                print 'Syntax Error:', ','.join(li), chrrdr.PeekToken()
                break
        else:
            # ASCII码本义
            item += char
            nextchar = chrrdr.GetToken()
            if nextchar == ',':
                li.append(item)
                continue
            elif nextchar == '-':
                item += nextchar
                nextchar = chrrdr.GetToken()
                if nextchar.isdigit():
                    item += nextchar
                    item += GetNumberItem(chrrdr)
                else:
                    item += nextchar
                li.append(item)
                chrrdr.GetToken() # 丢掉分隔符','
                continue
            elif nextchar is chrrdr.null:
                li.append(item)
                # 处理完毕了
                break
            else:
                print 'Syntax Error:', ','.join(li), chrrdr.PeekToken()
                break
        # endif
    return li

def ToPatHex(s):
    if s.isdigit():
        # 不能大于255, 这里不检查
        return "\\x%02x" % int(s)
    return "\\x%2x" % ord(s)

def ToOrd(s):
    if s.isdigit():
        return int(s)
    return ord(s)

def Conv2PyrePat(optlst, ascii_only = False):
    result = ''

    codelist = []
    excllist = []
    for idx, item in enumerate(optlst):
        code = ''
        if item == '@':
            #codelist.append(item)
            # TODO: 这是一个特殊值, 暂时如此处理应该够用
            codelist.append('A-Za-z')
        elif item == '^':
            # 这里不检查item是否最后的条目
            code += ToPatHex(item)
            codelist.append(code)
        elif item.startswith('^'):
            tmp = item[1:]
            if len(tmp) == 1:
                if ascii_only and ToOrd(tmp) > 127:
                    continue
                excllist.append(ToPatHex(tmp))
            else:
                # 一定是范围
                li = tmp.split('-', 1)
                c0 = ToPatHex(li[0])
                c1 = ToPatHex(li[1])
                if ascii_only:
                    if ToOrd(li[0]) > 127:
                        continue
                    if ToOrd(li[1]) > 127:
                        c1 = ToPatHex('127')
                excllist.append(c0 + '-' + c1)
        else:
            if len(item) == 1:
                if ascii_only and ToOrd(item) > 127:
                    continue
                codelist.append(ToPatHex(item))
            else:
                li = item.split('-', 1)
                c0 = ToPatHex(li[0])
                c1 = ToPatHex(li[1])
                if ascii_only:
                    if ToOrd(li[0]) > 127:
                        continue
                    if ToOrd(li[1]) > 127:
                        c1 = ToPatHex('127')
                codelist.append(c0 + '-' + c1)

    return [codelist, excllist]

def main(argv):
    #print isfname
    #print SplitOptions(isfname)
    #print iskeyword
    #print SplitOptions(iskeyword)
    for case in testcases:
        try:
            li = SplitOptions(case)
            a, b = Conv2PyrePat(li)
            #print '=' * 40
            #print case
            #print a
            #print b
            assert case == ','.join(li) == case
            assert re.compile('[%s]' % ''.join(a))
            if b:
                assert re.compile('[^%s]' % ''.join(b))

            Conv2PattList(case, True)
            Conv2PattList(case)
        except AssertionError:
            print 'assert failed:', case, '==', ','.join(li)
            #raise

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret is None:
        ret = 0
    sys.exit(ret)
