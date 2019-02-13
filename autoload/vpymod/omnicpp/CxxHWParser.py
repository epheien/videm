#!/usr/bin/env python
# -*- coding:utf-8 -*-

"""手写的 C++ 语法分析器"""

from CppTokenizer import CxxTokenize, CxxToken

# 例如 li = []; SkipToMatch(trd, "(", ")", li)
# 返回结束时获取的 token
def SkipToMatch(trd, left, right, collector = None):
    nestLv = 1
    tok = CxxToken()
    while True:
        tok = trd.GetToken()
        if not tok.IsValid():
            break
        if collector:
            collector.append(tok)

        if tok.text == left:
            nestLv += 1
        elif tok.text == right:
            nestLv -= 1

        if nestLv == 0:
            break

    return tok

def JoinTokensToString(toks):
    if not toks:
        return ""
    li = [tok.text for tok in toks]
    return " ".join(li)

def CxxParseTil(arg):
    if isinstance(arg, list):
        toks = arg
    else:
        assert False
    if not toks or toks[0].text != "<":
        return []
    result = []
    strli = []
    nestLv = 1
    for tok in toks[1:]:
        if tok.IsOP() and tok.text == "<":
            nestLv += 1
        elif tok.IsOP() and tok.text == ">":
            nestLv -= 1
            if nestLv == 0:
                result.append(" ".join(strli))
                strli = []
        elif tok.IsOP() and tok.text == ",":
            if nestLv == 1:
                result.append(" ".join(strli))
                strli = []
                continue

        # 收集字符串
        if nestLv >= 1:
            strli.append(tok.text)

    return result

class TokenReader:
    def __init__(self, tokens):
        '''tokens 必须是列表'''
        self.__tokens = tokens
        self.tokens = self.__tokens[::-1] # 副本，翻转顺序，考虑 list 的效率

    def GetToken(self):
        '''获取下一个 token，若到尾部，返回 CPP_EOF 类型的 CxxToken'''
        if self.tokens:
            tok = self.tokens.pop(-1)
            return tok
        else:
            return CxxToken() # 默认构造是 CPP_EOF 类型的 token

    def UngetToken(self, token):
        '''反推 token，外部负责 token 的正确性'''
        self.tokens.append(token)

    def PeekToken(self):
        if self.tokens:
            return self.tokens[-1]
        else:
            return CxxToken()

    def GetOrigTokens(self):
        return self.__tokens


class CxxOmniInfo:
    '''对应 Vim 的 OmniInfo'''
    def __init__(self):
        '''当有 precast 的时候，omniss[0] 无须解析，precast 就是结果'''
        self.omniss = [] # 元素为 CxxOmniScope
        # this 和 <global> 貌似不应该归类到这里...
        self.precast = "" # this | <global> | {decl string}

class CxxOmniScope:
    def __init__(self, text = "", op = ""):
        self.text = text # 单元类型的文本
        self.til = [] # 模板初始化列表
        self.preops = [] # op 前的操作符，例如 '[]' 和 '()' 可以多个
        self.op = op # 操作符，例如 '->', '.', '::'
        self.tag = {} # 解析的时候用
        self.typeinfo = {} # 解析的时候用

    def Print(self):
        print "text: %s" % self.text
        print "til: %s" % self.til
        print "preops: %s" % self.preops
        print "op: %s" % self.op

# case01. A::B C<X, Y<Z> >::D::|
# case02. A::B()->C().|    orig: A::B::C(" a(\")z ", '(').|
# case03. A::B().C->|
# case04. A->B().|
# case05. A->B.|
# case06. Z Y = ((A*)B)->C.|
# case07. (A*)B()->C.|
# case08. static_cast<A*>(B)->C.|      -> 处理成标准 C 的形式 ((A*)B)->C.|
# case09. A(B.C()->|)
# case10. ::A->|
# case11. A(::B.|)
# case12. (A**)::B.|
def CxxParseOmniInfo(stmt):
    trd = TokenReader(CxxTokenize(stmt)[::-1]) # 翻转顺序来解析
    omniInfo = CxxOmniInfo

    # CxxOmniInfo 的 precast
    precast = ""
    # CxxOmniInfo 的 omniss
    rOmniss = []

    while True:
        curTok = trd.GetToken()
        if not curTok.IsValid():
            break

        if curTok.IsOP() and curTok.text in set(['->', '.']):
            op = curTok.text
            di = {")": "(", "]": "["}
            preops = []
            collToks = []
            while trd.PeekToken().IsOP() and (trd.PeekToken().text == ")"
                                              or trd.PeekToken().text == "]"):
                curTok = trd.GetToken()
                rText = di[curTok.text]
                collToks = [curTok]
                ret = SkipToMatch(trd, curTok.text, rText, collToks)
                if not (ret.text == "(" or ret.text == "["):
                    trd.UngetToken(curTok) # 令下一个 if 判断失败而结束解析
                    break
                preops.insert(0, rText + curTok.text)
            if not trd.PeekToken().IsWord():
                # 处理 case06 case08
                if trd.PeekToken().IsOP() and trd.PeekToken().text == ">":
                    needContinue = False
                    # case08. static_cast<A*>(B)->C.|
                    # NOTE: B 有可能是 A::B<X, Y>::c 这样的形式
                    #       但是，由于有 precast, B 是什么形式已经不重要了
                    if len(collToks) < 3 or not collToks[1].IsWord():
                        break # 非法语法，直接结束
                    omniScope = CxxOmniScope(collToks[1].text, op)
                    collToks = [trd.GetToken()]
                    ret = SkipToMatch(trd, ">", "<", collToks)
                    if ret.text != "<":
                        break
                    peekTok = trd.PeekToken()
                    if peekTok.IsKeyword() \
                       and peekTok.text in set(
                           ["static_cast", "dynamic_cast",
                            "reinterpret_cast", "const_cast"]):
                        # C++ 方式的 cast，具体类型在 <> 里面
                        precast = JoinTokensToString(collToks[1:-1][::-1])
                        if preops: # (B) 被当成了 preops，所以 pop 掉
                            preops.pop(0)
                    elif peekTok.IsWord():
                        # caseXX: X::Y<M, N>(B)->C.|
                        #            ^
                        omniScope = CxxOmniScope(peekTok.text, op)
                        omniScope.til = CxxParseTil(collToks[::-1])
                        trd.GetToken() # 扔掉
                        needContinue = True # 继续分析
                    omniScope.preops = preops
                    rOmniss.append(omniScope)
                    if needContinue:
                        continue
                else:
                    # case06. Z Y = ((A*)B)->C.|
                    # NOTE: B 有可能是 A::B<X, Y>::c 这样的形式
                    #       但是，由于有 precast, B 是什么形式已经不重要了
                    # ((A*)B) 在最近的 collToks 里面
                    if collToks:
                        trd = TokenReader(collToks)
                        trd.GetToken()
                    if not trd.PeekToken().IsWord():
                        break # 非法语法，直接结束
                    omniScope = CxxOmniScope(trd.PeekToken().text, op)
                    trd.GetToken() # 扔掉
                    # 看看有没有 precast
                    if trd.PeekToken().IsOP() and trd.PeekToken().text == ")":
                        collToks = [trd.PeekToken()]
                        trd.GetToken() # 扔掉
                        ret = SkipToMatch(trd, ")", "(", collToks)
                        if ret.text != "(":
                            break # 非法语法，直接结束
                        # 获取 precast
                        precast = JoinTokensToString(collToks[1:-1][::-1])
                    rOmniss.append(omniScope)
                break # 结束
            # 到这里可以预测成功获取一个 CxxOmniScope 了
            curTok = trd.GetToken()
            omniScope = CxxOmniScope()
            omniScope.text = curTok.text
            omniScope.op = op
            omniScope.preops = preops
            rOmniss.append(omniScope)
        elif curTok.IsOP() and curTok.text == '::':
            op = curTok.text
            # A<B<C, D> >::|
            collToks = []
            if trd.PeekToken().text == ">":
                collToks.append(trd.GetToken())
                SkipToMatch(trd, ">", "<", collToks)
            if not trd.PeekToken().IsWord():
                precast = "<global>"
                break # 结束
            curTok = trd.GetToken()
            omniScope = CxxOmniScope()
            omniScope.text = curTok.text
            omniScope.op = op
            omniScope.til = CxxParseTil(collToks[::-1])
            rOmniss.append(omniScope)
#        elif curTok.IsOP() and curTok.text == ')':
#            collToks = [curTok]
#            SkipToMatch(trd, ")", "(", collToks)
#            if not trd.PeekToken().IsWord():
#                break
#            op = "()"
#            curTok = trd.GetToken()
#            omniScope = CxxOmniScope()
#            omniScope.text = curTok.text
#            omniScope.op = op
#            rOmniss.append(omniScope)
#        elif curTok.IsOP() and curTok.text == "]":
#            collToks = [curTok]
#            SkipToMatch(trd, "]", "[", collToks)
#            op = "[]"
#            moreops = []
#            while trd.PeekToken().text == "]":
#                collToks = [trd.GetToken()]
#                ret = SkipToMatch(trd, "]", "[", collToks)
#                if ret.text == "[":
#                    moreops.insert("[]", 0)
#            if not trd.PeekToken().IsWord():
#                break # 非法语法，直接结束
#            curTok = trd.GetToken()
#            omniScope = CxxOmniScope()
#            omniScope.text = curTok.text
#            omniScope.op = op
#            omniScope.moreops = moreops
#            omniScope.insert(omniScope, 0)
        else: # 其他 token
            # 遇到了其他字符, 结束. 前面判断的结果多数情况下是有用
            if curTok.IsKeyword() and curTok.text == "new":
                pass
            break

    # 获取几个成功就是几个呗
    omniInfo.precast = precast
    omniInfo.omniss = rOmniss[::-1]

    return omniInfo

def OmniInfo2Statement(omniInfo):
    strli = []
    omniss = omniInfo.omniss
    if omniInfo.precast:
        if omniInfo.precast == "this":
            strli.append("this->")
        elif omniInfo.precast == "<global>":
            strli.append("::")
        else:
            til = ""
            if omniss[0].til:
                til = "<%s >" % ", ".join(omniss[0].til)
            strli.append("((%s)%s)%s%s%s" % (omniInfo.precast, omniss[0].text,
                                             til, "".join(omniss[0].preops),
                                             omniss[0].op))
            omniss = omniss[1:]
    for s in omniss:
        strli.append(s.text)
        if s.til:
            strli.append("<%s >" % ", ".join(s.til))
        if s.preops:
            strli.append("".join(s.preops))
        strli.append(s.op)

    return "".join(strli)


def test():
    cases = [
        "A::B C<X, Y<Z> >::D::",
        "A::B()->C().",
        "A::B().C->",
        "A->B().",
        "A->B.",
        "Z Y = ((A*)B)->C.",
        "(A*)B()->C.",
        "static_cast<A*>(B)->C.",
        "caseXX: X::Y<M, N>(B)->C.",
        "A(B.C()->",
        "::A->",
        "A(::B.",
        "(A**)::B.",
    ]

    for case in cases:
        print "=" * 20
        print "stmt:", case
        ret = CxxParseOmniInfo(case)
        print ret.precast
        for i in ret.omniss:
            print "-" * 10
            i.Print()
        print OmniInfo2Statement(ret)

if __name__ == "__main__":
    test()
    s = "a<b>::c::xx.";
    toks = CxxTokenize(s)
    print JoinTokensToString(toks)
    print CxxParseTil(CxxTokenize("<A<B,C<D> >, E<F> >"))
