#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''这个模块用于提取typedef代码中的标识符, 用于把这些标识符替换为其他标识符'''

import re

pat = r'(?P<nonid>\W+)|(?P<id0>[a-zA-Z_]\w*)|(?P<id1>[^a-zA-Z_]\w*)'
re_token = re.compile(pat)

def Escape(string, chars = '"\\'):
    result = ''
    for char in string:
        if char in chars:
            # 转义之
            result += '\\' + char
        else:
            result += char
    return result

class CIDToken(object):
    KIND_ID = 0
    KIND_NONID = 1
    def __init__(self, kind, text):
        self.kind = kind
        self.text = text

    def __repr__(self):
        return '{"kind": %d, "text": "%s"}' % (self.kind, Escape(self.text))

    def IsID(self):
        return self.kind == type(self).KIND_ID

def JoinTokens(toks, sep):
    li = []
    for tok in toks:
        li.append(tok.text)
    return sep.join(li)

def CIDTokenize(tex):
    result = []
    for m in re_token.finditer(tex):
        if m.lastgroup:
            text = m.group(m.lastgroup)
            kind = CIDToken.KIND_NONID
            if m.lastgroup == 'id0':
                kind = CIDToken.KIND_ID
            result.append(CIDToken(kind, text))

    return result

def test():
    cases = [
        ' 0x333 03xb03 03 xb03 A03A::B::C<X, Y> ',
        ' "snkgeg,e \\" s\nn"se"',
    ]

    for case in cases:
        li = CIDTokenize(case)
        assert JoinTokens(li, '') == case

def main(argv):
    test()
    print 'test ok'

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret is None:
        ret = 0
    sys.exit(ret)
