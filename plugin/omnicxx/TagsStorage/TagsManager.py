#!/usr/bin/env python
# -*- coding:utf-8 -*-

import os
import os.path
import time
import threading
import TagsStorageSQLite as TagsStorage
from TagEntry import ToFullKind, ToFullKinds
from Misc import RunSimpleThread

__dir__ = os.path.dirname(os.path.abspath(__file__))

def TagEntry2Tag(tagEntry):
    '''把 python 的 TagEntry 转为 vim 的 tag 字典'''
    tag = {} # taglist() 返回的列表的项目
    # 必不可少的五个字段
    # omnicpp 需要完整的名字
    #tag['name'] = tagEntry.GetPath()
    tag['name'] = tagEntry.GetName()
    tag['filename'] = tagEntry.GetFile()
    # FIXME: 若模式中有单引号暂无办法安全传到 vim
    # 即使替换成 vim 的双单引号转义, 最终显示的是 "\'\'", 无解!
    # 暂时只能替换为空格(可以约定一个特殊字符然后替换?)
    #tag['cmd'] = tagEntry.GetPattern().replace("'", " ")
    #tag['cmd'] = tagEntry.GetText() # 这个域暂时用 'text' 域填充
    tag['cmd'] = ''
    # 全称改为简称, 用命令参数控制
    tag['kind'] = tagEntry.GetAbbrKind()
    tag['static'] = 0 # 作用不明

    # 必不可少的附加域
    #tag['text'] = tagEntry.GetText()
    tag['extra'] = tagEntry.GetExtra()
    tag['line'] = tagEntry.GetLine() # 行号, 用于定位
    tag['parent'] = tagEntry.GetParent() # 父亲的名字, 不带路径
    tag['path'] = tagEntry.GetPath()
    tag['scope'] = tagEntry.GetScope()

    # 附加字段
    if tagEntry.GetAccess():
        tag['access'] = tagEntry.GetAccess()
    if tagEntry.GetInherits():
        tag['inherits'] = tagEntry.GetInherits()
    if tagEntry.GetSignature():
        tag['signature'] = tagEntry.GetSignature()
    if tagEntry.GetTyperef():
        tag['typeref'] = tagEntry.GetTyperef()
    if tagEntry.GetParentKind():
        tag[tagEntry.GetParentKind()] = tagEntry.GetScope()
    #if tagEntry.GetTemplate():
        #tag['template'] = tagEntry.GetTemplate()
    #if tagEntry.GetReturn():
        #tag['return'] = tagEntry.GetReturn()

    return tag

def TagEntries2Tags(tagEntries):
    tags = [] # 符合 vim 接口的 tags 列表
    tags = []
    for tagEntry in tagEntries:
        tags.append(TagEntry2Tag(tagEntry))
    return tags

AppendCtagsOptions = TagsStorage.AppendCtagsOptions

class ParseFilesThread(threading.Thread):
    '''同时只允许单个线程工作'''
    lock = threading.Lock()

    def __init__(self, dbfile, files, macros_files = [],
                 PostCallback = None, callbackPara = None,
                 ignore_needless = True, filter_noncxx = False):
        '''
        异步 parse 文件线程
        NOTE: sqlite3 是线程安全的
        NOTE: 不同线程不能使用同一个连接实例，必须新建
        '''
        threading.Thread.__init__(self)

        self.dbfile = dbfile
        self.files = files
        self.macros_files = macros_files

        self.PostCallback = PostCallback
        self.callbackPara = callbackPara
        self.ignore_needless = ignore_needless
        self.filter_noncxx = filter_noncxx

        self.name = 'Videm-' + self.name

    def run(self):
        ParseFilesThread.lock.acquire()

        try:
            storage = TagsStorage.TagsStorageSQLite()
            storage.OpenDatabase(self.dbfile)
            TagsStorage.ParseAndStore(storage, self.files,
                                      self.macros_files, self.ignore_needless,
                                      filter_noncxx = self.filter_noncxx)
            del storage
        except:
            # FIXME: gvim里面这样打印就会导致gvim崩溃了
            #print 'ParseFilesThread() failed'
            pass

        ParseFilesThread.lock.release()

        if self.PostCallback:
            try:
                self.PostCallback(self.callbackPara)
            except:
                pass

def AsyncTagsStorageOperate(data):
    '''
    data: 数组，[0]=数据库文件，[1]=函数名，其他是该函数的参数'''
    # 需要的参数：1、数据库文件；2、操作参数；3、操作函数的参数
    dbfile = data[0]
    funcName = data[1]
    args = data[2:]

    storage = TagsStorage.TagsStorageSQLite()
    storage.OpenDatabase(dbfile)

    s = 'storage.%s' % funcName
    li = ['args[%d]' % i for i in range(len(args))]
    s += '(%s)' % ', '.join(li)
    #print s
    #print args[0]
    eval(s)

class TagsManager(TagsStorage.TagsStorageSQLite):
    '''封装类, 外部直接使用本类即可'''
    def __init__(self, dbfile = ''):
        self.parse_thread = None
        TagsStorage.TagsStorageSQLite.__init__(self)
        if dbfile:
            # NOTE: 无法返回错误信息
            self.OpenDatabase(dbfile)

    def ParseFilesAsync(self, files, macros_files = [],
                        PostCallback = None, callbackPara = None,
                        ignore_needless = True, filter_noncxx = False):
        # 暂时只允许单个异步 parse
        if self.parse_thread:
            try:
                self.parse_thread.join()
            except RuntimeError:
                return -1

        self.parse_thread = ParseFilesThread(self.fname,
                                             files, macros_files,
                                             PostCallback, callbackPara,
                                             ignore_needless, filter_noncxx)
        self.parse_thread.start()
        return 0

    def ParseFiles(self, files, macros_files = [], indicator = None,
                   ignore_needless = True, filter_noncxx = False):
        return TagsStorage.ParseAndStore(self, files, macros_files,
                                         ignore_needless = ignore_needless,
                                         indicator = indicator,
                                         filter_noncxx = filter_noncxx)

def test():
    import time
    from Misc import TempFile

    content = '''
template <class T1, typename T2>
class Clazz : AA<BB, CC>, ZZ<YY>, XX {
public:
    void *ptr;
};
'''

    tfile = TempFile()
    with open(tfile, 'wb') as f:
        f.write(content)

    files = [tfile]

    tdbfile = TempFile()
    try:
        tagmgr = TagsManager()
        assert tagmgr.OpenDatabase(tdbfile) == 0

        assert tagmgr.RecreateDatabase() == 0
        assert tagmgr.ParseFiles(files) == 0
        assert len(tagmgr.GetTagsBySQL('SELECT * FROM TAGS;')) == 2

        def Test(x):
            print 'Test(%s)' % x

        # NOTE: 异步模式, 文件名不能为 ':memory:', 因为每次打开都是一个新的数据库
        assert tagmgr.RecreateDatabase() == 0
        tagmgr.ParseFilesAsync(files, PostCallback = Test, callbackPara = None)
        while True:
            if tagmgr.parse_thread.isAlive():
                print "Parsing,", time.time()
            else:
                print "End,", time.time()
                break
            time.sleep(1)

        tags = tagmgr.GetTagsBySQL('SELECT * FROM TAGS;')
        #for tag in tags:
            #print tag.ToJson()
        assert len(tags) == 2
    finally:
        os.remove(tfile)
        os.remove(tdbfile)

if __name__ == '__main__':
    test()
