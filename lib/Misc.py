#!/usr/bin/env python
# -*- encoding:utf-8 -*-
# 各种例程

import sys
import os
import os.path
import time
import re
import getpass
import subprocess
import tempfile
import threading
import shlex
import platform
import json

# TODO: 现在的变量展开是不支持递归的，例如 $(a$(b))

def ToVimEval(o):
    '''把 python 字符串列表和字典转为健全的能被 vim 解析的数据结构
    对于整个字符串的引用必须使用双引号，例如:
        vim.command("echo %s" % ToVimEval(expr))'''
    if isinstance(o, str):
        return "'%s'" % o.replace("'", "''")
    elif isinstance(o, unicode):
        return "'%s'" % o.encode('utf-8').replace("'", "''")
    elif isinstance(o, (list, dict)):
        return json.dumps(o, ensure_ascii=False)
    else:
        return repr(o)

def ToUtf8(o):
    '''处理utf-8转码问题'''
    if isinstance(o, str):
        if IsWindowsOS():
            return o.decode('gb18030').encode('utf-8')
        else:
            return o
    elif isinstance(o, unicode):
        return o.encode('utf-8')
    return o

def ToU(o):
    '''把字符串转为unicode'''
    if isinstance(o, unicode):
        return o
    elif isinstance(o, str):
        if IsWindowsOS():
            return o.decode('gb18030')
        else:
            return o.decode('utf-8')
    return o

def CmpIC(s1, s2):
    '''忽略大小写比较两个字符串'''
    return cmp(s1.lower(), s2.lower())

def IsLinuxOS():
    '''判断系统是否 Linux'''
    return platform.system() == 'Linux'

def IsWindowsOS():
    '''判断系统是否 Windows'''
    return platform.system() == 'Windows'

def EscStr(string, chars, escchar = '\\'):
    '''转义字符串'''
    charli = []
    for char in string:
        if char in chars:
            charli.append(escchar)
        charli.append(char)
    return ''.join(charli)

def EscStr4DQ(string):
    '''转义 string，用于放到双引号里面'''
    return EscStr(string, '"\\')

patMkShStr = re.compile(r'^[a-zA-Z0-9_\-+.\$()/]+$')
def EscStr4MkSh(string):
    '''转义 string，用于在 Makefile 里面传给 shell，不是加引号的方式
    bash 的元字符包括：|  & ; ( ) < > space tab
    NOTE: 换行无法转义，应该把 \n 用 $$'\n'表示的
    
    参考 vim 的 shellescape() 函数'''
    global patMkShStr
    if IsWindowsOS():
        #return '"%s"' % string.replace('"', '""')
        # 在 Windows 下直接不支持带空格的路径好了，因为用双引号也有各种问题
        return '%s' % string
    else:
        #return EscStr(string, "|&;()<> \t'\"\\")
        # 有必要才转义，主要是为了好看
        if patMkShStr.match(string):
            return string
        else:
            return "'%s'" % string.replace("'", "'\\''")

def SplitSmclStr(s, sep = ';'):
    '''分割 sep 作为分割符的字符串为列表，双倍的 sep 代表 sep 自身'''
    l = len(s)
    idx = 0
    result = []
    chars = []
    while idx < l:
        char = s[idx]
        if char == sep:
            # 检查随后的是否为自身
            if idx + 1 < l:
                if s[idx+1] == sep: # 不是分隔符
                    chars.append(sep)
                    idx += 1 # 跳过下一个字符
                else: # 是分隔符
                    if chars:
                        result.append(''.join(chars))
                    del chars[:] # 清空
            else: # 最后的字符也为分隔符，直接忽略即可
                pass
        else: # 一般情况下，直接添加即可
            chars.append(char)
        idx += 1

    # 最后段
    if chars:
        result.append(''.join(chars))
    del chars[:]

    return result

def JoinToSmclStr(li, sep = ';'):
    '''串联字符串列表为 sep 分割的字符串，sep 用双倍的 sep 来表示'''
    tempList = []
    for elm in li:
        if elm:
            tempList.append(elm.replace(sep, sep + sep)) # 直接加倍即可
    return sep.join(tempList)

def SplitStrBy(string, sep):
    '''把 sep 作为分隔符的字符串分割，支持 '\\' 转义
    sep 必须是单个字符'''
    charli = []
    result = []
    esc = False
    for c in string:
        if c == '\\':
            esc = True
            continue
        if c == sep and not esc:
            if charli:
                result.append(''.join(charli))
            del charli[:]
            continue
        charli.append(c)
        esc = False
    if charli:
        result.append(''.join(charli))
        del charli[:]
    return result

def GetMTime(fn):
    try:
        return int(os.path.getmtime(fn))
    except:
        return 0

def TempFile():
    fd, fn = tempfile.mkstemp()
    os.close(fd)
    return fn

def GetFileModificationTime(filename):
    '''获取文件最后修改时间
    
    返回自 1970-01-01 以来的秒数'''
    return GetMTime(filename)

def Touch(lFiles):
    '''lFiles可以是列表或字符串'''
    if isinstance(lFiles, str): lFiles = [lFiles]
    for sFile in lFiles:
        #print "touching %s" % sFile
        try:
            os.utime(sFile, None)
        except OSError:
            open(sFile, "ab").close()

def PosixPath(p):
    '''把路径分割符全部转换为 posix 标准的分割符'''
    return p.replace('\\', '/')

class DirSaver:
    '''用于在保持当前工作目录下，跳至其他目录工作，
    在需要作用的区域，必须保持一个引用！'''
    def __init__(self):
        self.curDir = os.getcwd()
        #print 'curDir =', self.curDir
    
    def __del__(self):
        os.chdir(self.curDir)
        #print 'back to', self.curDir

def Obj2Dict(obj, exclude=set()):
    '''常规对象转为字典
    把所有公共属性（不包含方法）作为键，把属性值作为值
    NOTE: 不会递归转换，也就是只转一层'''
    d = {}
    for k in dir(obj):
        if k in exclude:
            continue
        v = getattr(obj, k)
        if callable(v) or k.startswith("_"):
            continue
        d[k] = v
    return d

def Dict2Obj(obj, d, exclude=set()):
    '''把字典转为对象
    字典的键对应对象的属性，字典的值对应对象的属性值
    NOTE: 不会递归转换，也就是只转一层'''
    for k, v in d.iteritems():
        if k in exclude:
            continue
        if isinstance(v, unicode):
            # 统一转成 utf-8 编码的字符串，唉，python2 的软肋
            v = v.encode('utf-8')
        setattr(obj, k, v)
    return obj

class SimpleThread(threading.Thread):
    def __init__(self, callback, prvtData, 
                 postHook = None, postPara = None,
                 exceptHook = None, exceptPara = None):
        '''简单线程接口'''
        threading.Thread.__init__(self)

        self.callback = callback
        self.prvtData = prvtData

        self.postHook = postHook
        self.postPara = postPara

        self.exceptHook = exceptHook
        self.exceptPara = exceptPara

        self.name = 'Videm-' + self.name

    def run(self):
        try:
            self.callback(self.prvtData)
        except:
            #print 'SimpleThread() failed'
            if self.exceptHook:
                self.exceptHook(self.exceptPara)

        if self.postHook:
            try:
                self.postHook(self.postPara)
            except:
                pass

def RunSimpleThread(callback, prvtData):
    thrd = SimpleThread(callback, prvtData)
    thrd.start()
    return thrd

def GetBgThdCnt():
    count = 0
    for td in threading.enumerate():
        if td.name.startswith('Videm-'):
            count += 1
    return count

class ConfTree:
    '''一种抽象的树状结构，路径表示方式为 ".videm.wsp.conf"
    叶子结点只支持保存四种类型：字典、列表、数字、字符串'''
    def __init__(self):
        self.tree = {}

    def Set(self, opt, val):
        li = [i for i in opt.split('.') if i]
        if not li:
            return

        d = self.tree
        for key in li[:-1]:
            if not d.has_key(key):
                d[key] = {}
            if not isinstance(d[key], dict):
                # 非页结点必须是字典，否则退出
                return
            d = d[key]
        d[li[-1]] = val
        return 0

    def Get(self, opt, val=0):
        li = [i for i in opt.split('.') if i]
        if not li:
            return self.tree

        d = self.tree
        for key in li[:-1]:
            if not d.has_key(key):
                return val
            if not isinstance(d[key], dict):
                return val
            d = d[key]
        return d.get(li[-1], val)

    def Has(self, opt):
        li = [i for i in opt.split('.') if i]
        if not li:
            return False

        d = self.tree
        for key in li[:-1]:
            if not d.has_key(key):
                return False
            if not isinstance(d[key], dict):
                return False
            d = d[key]
        return d.has_key(li[-1])

    def Save(self, filename):
        dirname = os.path.dirname(filename)
        if dirname and not os.path.exists(dirname):
            os.makedirs(dirname)
        f = open(filename, 'wb')
        json.dump(self.tree, f, indent=4, sort_keys=True, ensure_ascii=True)
        f.close()
        return 0

    def Load(self, filename):
        f = open(filename, 'rb')
        d = json.load(f)
        f.close()
        self.tree = d
        return 0

#===============================================================================

if __name__ == '__main__':
    import unittest
    import shlex
    import getopt

    def ppp(yy):
        import time
        time.sleep(3)
        print dir(yy)
    #print RunSimpleThread(ppp, list)

    print GetBgThdCnt()
    print threading.active_count()

    class test(unittest.TestCase):
        def testDirSaver(self):
            def TestDirSaver():
                ds = DirSaver()
                os.chdir('/')
                self.assertTrue(os.getcwd() == '/')
                #print 'I am in', os.getcwd()
                #print 'Byebye'

            cwd = os.getcwd()
            TestDirSaver()
            self.assertTrue(cwd == os.getcwd())

        def testSplitStrBy(self):
            self.assertTrue(SplitStrBy("snke\;;snekg;", ';') 
                            == ['snke;', 'snekg'])

    s = ';abc;;d;efg;'
    l = ['abc;d', 'efg']
    assert l == SplitSmclStr(s)
    assert 'abc;;d;efg' == JoinToSmclStr(l)
    assert l == SplitSmclStr(JoinToSmclStr(l))

    conftree = ConfTree()
    conftree.Set('.videm.wsp.conf', 'hello')
    assert conftree.Get('.videm.wsp.conf') == 'hello'
    assert not conftree.Has('.abc')
    assert conftree.Has('.videm.wsp')
    assert conftree.Get('.videm.wsp.xxx', 123) == 123
    print conftree.Save('x.json')

    print GetFileModificationTime(sys.argv[0])

    print '= unittest ='
    unittest.main() # 跑这个函数会直接退出，所以后面的语句会全部跑不了
