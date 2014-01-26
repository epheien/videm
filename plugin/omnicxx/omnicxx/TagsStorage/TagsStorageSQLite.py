#!/usr/bin/env python
# -*- encoding:utf-8 -*-


from TagEntry import TagEntry
from TagEntry import GenPath
from TagEntry import SplitPath
from FileEntry import FileEntry
from Misc import ToU
from Misc import GetMTime
from Misc import TempFile

import sys
import os
import os.path
import traceback
import StringIO
import time
import subprocess
import platform
import sqlite3
import re
import json

__dir__ = os.path.dirname(os.path.abspath(__file__))

_DEBUG = False

# 使用 fileid 域, 至少需要处理以下情况
# * 以文件名索引删除 tags
# * 插入 tag 时需要获取到 fileid
# * 获取 tags 时需要获取到 file     # TODO
_USE_FILEID = True

STORAGE_VERSION = 3000

# 这两个变量暂时只对本模块生效
# FIXME: 应该使用公共的模块定义这两个变量
CPP_SOURCE_EXT = set(['c', 'cpp', 'cxx', 'c++', 'cc'])
CPP_HEADER_EXT = set(['h', 'hpp', 'hxx', 'hh', 'inl', 'inc'])

def _print(*args, **kwargs):
    sep = kwargs.get('sep', ' ')
    end = kwargs.get('end', '\n')
    file = kwargs.get('file', sys.stdout)
    file.write(sep.join(args) + end)

# 为了进一步减少数据库的容量, "<global>" 使用 "#" 字符代替存在数据库中
def ToAbbrGlobal(g):
    if g == '<global>':
        return ''
    return g
def ToFullGlobal(g):
    if g == '':
        return '<global>'
    return g

def Escape(string, chars):
    result = ''
    for char in string:
        if char in chars:
            # 转义之
            result += '\\' + char
        else:
            result += char
    return result

def MakeQMarkString(count):
    '''生成用于 sqlite3 语句的问号占位符，是包括括号的，一般用 IN 语法
    count 表示需要的 ? 的数量'''
    if count <= 1:
        return "(?)"
    else:
        return "(%s)" % ", ".join(["?" for i in range(count)])

def PrintExcept(*args):
    '''打印出错信息'''
    sio = StringIO.StringIO()
    traceback.print_exc(file=sio)
    errmsg = sio.getvalue()
    if not errmsg:
        return
    print errmsg

class TagsStorageSQLite(object):
    def __init__(self):
        self.fname = ''     # 数据库文件, os.path.realpath() 的返回值
        self.db = None      # sqlite3 的连接实例, 取此名字是为了与 codelite 统一

    def __del__(self):
        if self.db:
            self.db.close()
            self.db = None

    def GetVersion(self):
        global STORAGE_VERSION
        return STORAGE_VERSION

    def GetTagsBySQL(self, sql):
        '''外部/调试接口，返回元素为字典的列表'''
        if not sql:
            return []
        tags = self._FetchTags(sql)
        #return [tag.ToDict() for tag in tags]
        return tags

    def Begin(self):
        if self.db:
            try:
                self.db.execute("begin;")
            except sqlite3.OperationalError:
                PrintExcept()

    def Commit(self):
        if self.db:
            try:
                self.db.commit()
            except sqlite3.OperationalError:
                PrintExcept()

    def Rollback(self):
        if self.db:
            try:
                self.db.rollback()
            except sqlite3.OperationalError:
                PrintExcept()

    def CloseDatabase(self):
        if self.IsOpen():
            self.db.close()
            self.db = None

    def OpenDatabase(self, fname):
        '''正常返回0, 致命异常返回-1, 版本不兼容异常返回-2'''
        # TODO: 验证文件是否有效

        # 如果相同, 表示已经打开了相同的数据库, 直接返回
        if self.IsOpen() and self.fname == os.path.realpath(fname):
            return 0

        # Did we get a file name to use?
        # 未打开任何数据库, 且请求打开的文件无效, 直接返回
        if not self.IsOpen() and not fname:
            return -1

        # We did not get any file name to use BUT we
        # do have an open database, so we will use it
        # 传进来的是无效的文件, 但已经打开了某个数据库, 继续用之
        if not fname:
            return 0

        orig_fname = fname
        if not fname == ':memory:': # ':memory:' 是一个特殊值, 表示内存数据库
            fname = os.path.realpath(fname)

        # 先把旧的关掉
        self.CloseDatabase()

        try:
            self.db = sqlite3.connect(ToU(fname))
            self.db.text_factory = str # 以字符串方式保存而不是 unicode
            schema_version = self.GetSchemaVersion()
            if schema_version and schema_version != self.GetVersion():
                #_print('Failed to check database version:\n'
                       #'    database file version is %d, current schema version is %d'
                       #% (schema_version, self.GetVersion()))
                self.CloseDatabase()
                # 这个是标志返回值
                return -2
            # 固定调用, 因为打开的数据库可能是一个空的数据库
            self.CreateSchema()
            self.fname = fname
            return 0
        except sqlite3.OperationalError:
            PrintExcept()
            return -1

    def ExecuteSQL(self, sql, *args):
        '''NOTE: 这样封装对吗?'''
        if not sql or not self.IsOpen():
            return []

        result = []
        try:
            if args:
                result = self.db.execute(sql, args[0])
            else:
                result = self.db.execute(sql)
        except sqlite3.OperationalError:
            PrintExcept()
            return []
        return result

    def ExecuteSQLScript(self, sql):
        if not sql or not self.IsOpen():
            return -1
        try:
            self.db.executescript(sql)
        except sqlite3.OperationalError:
            PrintExcept()
            return -1
        return 0

    def DropSchema(self):
        # TODO: 需要识别版本
        version = self.GetSchemaVersion()
        if version != 3000:
            return

        sqls = [
            # and drop tables
            "DROP TABLE IF EXISTS TAGS;",
            "DROP TABLE IF EXISTS FILES;",
            "DROP TABLE IF EXISTS TAGS_VERSION;",

            # drop indexes
            "DROP INDEX IF EXISTS FILES_UNIQ_IDX;",
            "DROP INDEX IF EXISTS TAGS_UNIQ_IDX;",
            "DROP INDEX IF EXISTS TAGS_KIND_IDX;",
            "DROP INDEX IF EXISTS TAGS_FILE_IDX;",
            "DROP INDEX IF EXISTS TAGS_NAME_IDX;",
            "DROP INDEX IF EXISTS TAGS_SCOPE_IDX;",
            "DROP INDEX IF EXISTS TAGS_VERSION_UNIQ_IDX;",
        ]

        for sql in sqls:
            self.ExecuteSQL(sql)

    def CreateSchema(self):
        try:
            # improve performace by using pragma command:
            # (this needs to be done before the creation of the
            # tables and indices)
            sql = "PRAGMA synchronous = OFF;"
            self.ExecuteSQL(sql)

            sql = "PRAGMA temp_store = MEMORY;"
            self.ExecuteSQL(sql)

            # FILES 表
            sql = '''
            CREATE TABLE IF NOT EXISTS FILES (
                id      INTEGER PRIMARY KEY AUTOINCREMENT,
                file    STRING,
                tagtime INTEGER);
            '''
            sql = re.sub(r'\s+', ' ', sql).strip()
            self.ExecuteSQL(sql)

            # TAGS 表
            sql = '''
            CREATE TABLE IF NOT EXISTS TAGS (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                name            STRING,
                file            STRING,
                fileid          INTEGER,
                line            INTEGER,
                kind            STRING,
                scope           STRING,
                parent_kind     STRING,
                access          STRING,
                inherits        STRING,
                signature       STRING,
                extra           STRING);
            '''
            # 为了看起来美观点
            sql = re.sub(r'\s+', ' ', sql).strip()
            self.ExecuteSQL(sql)
            sqls = []
            sqls += ['CREATE UNIQUE INDEX IF NOT EXISTS FILES_UNIQ_IDX ON FILES(file);',]

            if _USE_FILEID:
                sqls += [
                    # 唯一索引 mod on 2011-01-07
                    # 不同源文件文件之间会存在相同的符号
                    # 最靠谱是(name, fileid, line, kind, scope, signature)
                    # 但是可能会比较慢, 所以尽量精简
                    # 假定同一行不会存在相同名字和类型的符号
                    '''
                    CREATE UNIQUE INDEX IF NOT EXISTS TAGS_UNIQ_IDX ON TAGS(name, fileid, kind, scope, signature);
                    ''',
                ]
            else:
                sqls += [
                    # 唯一索引 mod on 2011-01-07
                    # 不同源文件文件之间会存在相同的符号
                    # 最靠谱是(name, file, line, kind, scope, signature)
                    # 但是可能会比较慢, 所以尽量精简
                    # 假定同一行不会存在相同名字和类型的符号
                    '''
                    CREATE UNIQUE INDEX IF NOT EXISTS TAGS_UNIQ_IDX ON TAGS(name, file, kind, scope, signature);
                    ''',
                ]

            sqls += [
                #"CREATE INDEX IF NOT EXISTS TAGS_NAME_IDX ON TAGS(name);",
                #"CREATE INDEX IF NOT EXISTS TAGS_FILE_IDX ON TAGS(file);",
                #"CREATE INDEX IF NOT EXISTS TAGS_FILE_IDX ON TAGS(fileid);",
                #"CREATE INDEX IF NOT EXISTS TAGS_KIND_IDX ON TAGS(kind);",
                #"CREATE INDEX IF NOT EXISTS TAGS_SCOPE_IDX ON TAGS(scope);",

                # TAGS_VERSION 表
                "CREATE TABLE IF NOT EXISTS TAGS_VERSION (version INTEGER PRIMARY KEY);",
                "CREATE UNIQUE INDEX IF NOT EXISTS TAGS_VERSION_UNIQ_IDX ON TAGS_VERSION(version);",
            ]

            for sql in sqls:
                self.ExecuteSQL(sql)

            # 插入数据
            self.db.execute("INSERT OR REPLACE INTO TAGS_VERSION VALUES(?)",
                            (self.GetVersion(), ))

            # 必须提交
            self.Commit()
        except sqlite3.OperationalError:
            PrintExcept()

    def RecreateDatabase(self):
        '''只有打开数据库的时候才能进行这个操作'''
        if not self.IsOpen():
            return -1

        # 处理后事
        self.Commit()
        self.CloseDatabase()

        # 内存数据库的话, 直接这样就行了
        if self.fname == ':memory:':
            return self.OpenDatabase(self.fname)

        # 存在关联文件的数据库, 优先使用删除文件再创建的形式, 如果失败, 
        # 重新打开并重建 schema
        try:
            os.remove(self.fname)
        except:
            PrintExcept("Failed to remove %s" % self.fname)
            # Reopen the database
            self.OpenDatabase(self.fname)
            # Drop the schema
            self.DropSchema()
            # Create the schema
            self.CreateSchema()
        else:
            # 正常情况下, 再打开这个文件作为数据库即可
            self.OpenDatabase(self.fname)
        return 0

    def GetSchemaVersion(self):
        version = 0
        try:
            sql = "SELECT * FROM TAGS_VERSION;"
            for row in self.db.execute(sql):
                version = int(row[0])
                break
        except sqlite3.OperationalError:
            #PrintExcept()
            pass # 返回 0 即标志着错误
        return version

    def StoreFromTagFile(self, tagFile, auto_commit = True, filedict = {}):
        '''从 tags 文件保存'''
        if not self.IsOpen():
            return -1

        ret = -1

        if not tagFile:
            return -1

        try:
            updateList = [] # 不存在的直接插入, 存在的在原条目处更新

            if auto_commit:
                self.Begin()

            try:
                f = open(tagFile)
            except:
                return -1

            if _USE_FILEID:
                prevfile = ''
                prevfileid = 0
            for line in f:
                # does not matter if we insert or update, 
                # the cache must be cleared for any related tags
                if line.startswith('!'): # 跳过注释
                    continue

                tagEntry = TagEntry()
                tagEntry.FromLine(line)

                if _USE_FILEID:
                    # 切换到下一个文件, 有一些优化效果
                    if tagEntry.GetFile() != prevfile:
                        # 重查
                        tagEntry.fileid = filedict.get(tagEntry.GetFile(),
                                                       TagEntry()).id
                        prevfile = tagEntry.GetFile()
                        prevfileid = tagEntry.fileid
                    else:
                        # 使用上一次的结果
                        tagEntry.fileid = prevfileid

                if self.InsertTagEntry(tagEntry, auto_commit=False) != 0:
                    # 插入不成功?
                    # InsertTagEntry() 貌似是不会失败的?!
                    updateList.append(tagEntry)

            if auto_commit:
                self.Commit()

            # Do we need to update?
            if updateList:
                if auto_commit:
                    self.Begin()

                for i in updateList:
                    self.UpdateTagEntry(i, auto_commit=False)

                if auto_commit:
                    self.Commit()

            f.close()
            ret = 0
        except sqlite3.OperationalError:
            if auto_commit:
                self.Rollback()
            ret = -1

        return ret

    def DeleteTagsByFileids(self, fileids, auto_commit = True):
        if not self.IsOpen() or not fileids:
            return -1

        ret = -1
        try:
            if auto_commit:
                self.Begin()

            self.db.execute("DELETE FROM TAGS WHERE fileid IN %s;"
                            % MakeQMarkString(len(fileids)), tuple(fileids))

            if auto_commit:
                self.Commit()
            ret = 0
        except sqlite3.OperationalError:
            if auto_commit:
                self.Rollback()
            ret = -1
        return ret

    def DeleteTagsByFiles(self, files, auto_commit = True):
        '''删除属于指定文件名 fname 的所有标签'''
        if not self.IsOpen() or not files:
            return -1

        # 这里需要 bypass 掉
        if _USE_FILEID:
            fileids = self.GetFileidsByFiles(files)
            return self.DeleteTagsByFileids(fileids)

        ret = -1
        try:
            if auto_commit:
                self.Begin()

            self.db.execute("DELETE FROM TAGS WHERE file IN %s;"
                            % MakeQMarkString(len(files)), tuple(files))

            if auto_commit:
                self.Commit()
            ret = 0
        except sqlite3.OperationalError:
            if auto_commit:
                self.Rollback()
            ret = -1
        return ret

    def IsOpen(self):
        if self.db:
            return True
        else:
            return False

    def GetFileByFileid(self, fileid):
        if not self.IsOpen():
            return ''

        res = self.ExecuteSQL('SELECT * FROM FILES WHERE id = ?;', (fileid,))
        for row in res:
            return row[1]

        return ''

    def GetFileidsByFiles(self, files):
        if not self.IsOpen() or not files:
            return []

        res = self.ExecuteSQL("SELECT * FROM FILES WHERE file IN %s;" 
                        % MakeQMarkString(len(files)), tuple(files))
        return [int(row[0]) for row in res]

    def UpdateFilesFile(self, oldfile, newfile):
        '''用于支持文件重命名操作'''
        try:
            self.ExecuteSQL("UPDATE FILES SET file=? WHERE file=?;",
                            (newfile, oldfile))
        except sqlite3.OperationalError:
            pass
        return 0

    def GetFilesMapping(self, files = []):
        '''返回文件到文件条目的字典, 方便比较
        @files:     如果非空则为需要匹配的文件'''
        if not self.IsOpen():
            return {}

        result = {}

        if files:
            res = self.db.execute("SELECT * FROM FILES WHERE file IN %s;" 
                            % MakeQMarkString(len(files)), tuple(files))
        else:
            res = self.ExecuteSQL("SELECT * FROM FILES;")

        for row in res:
            fe = FileEntry()
            fe.id       = int(row[0])
            fe.file     = row[1]
            fe.tagtime  = row[2]
            result[fe.file] = fe

        return result

    def FromSQLite3ResultSet(self, row):
        '''从数据库的一行数据中提取标签对象
| id | name | file | fileid | line | kind | scope | parent_kind | access | inherits | signature | extra |
|----|------|------|--------|------|------|-------|-------------|--------|----------|-----------|-------|
|    |      |      |        |      |      |       |             |        |          |           |       |
'''
        entry = TagEntry()
        entry.id          = (row[0])
        entry.name        = (row[1])
        entry.file        = (row[2])
        entry.fileid      = int((row[3]))
        entry.line        = int((row[4]))

        entry.kind        = (row[5])
        entry.scope       = ToFullGlobal(row[6])
        entry.extra       = (row[11])

        # 这几个字段不一定存在的
        parent_kind = (row[7])
        access      = (row[8])
        inherits    = (row[9])
        signature   = (row[10])
        if parent_kind:
            entry.SetParentKind(parent_kind)
        if access:
            entry.SetAccess(access)
        if inherits:
            entry.SetInherits(inherits)
        if signature:
            entry.SetSignature(signature)

        return entry

    def _FetchTags(self, sql, *args):
        '''根据 sql 语句获取 tags'''
        if not self.IsOpen():
            return []

        try:
            tags = []
            if args:
                res = self.db.execute(sql, args[0])
            else:
                res = self.db.execute(sql)
            for row in res:
                tag = self.FromSQLite3ResultSet(row)
                tags.append(tag)
            return tags
        except:
            return []

    # ========================================================================
    # 各种获取 tags 的接口
    # ========================================================================
    def GetTagsByScopeAndName(self, scope, name):
        '''定义 tags 的原始方法'''
        if not scope or not name:
            return []
        return self._FetchTags('SELECT * FROM TAGS WHERE name=? AND scope=?;',
                               (name, ToAbbrGlobal(scope)))
    def GetTagsByPath(self, path):
        if not path:
            return []
        scope, name = SplitPath(path)
        return self.GetTagsByScopeAndName(scope, name)

    def GetTagsByScopeAndKind(self, scope, kind):
        if not scope or not not kind:
            return []
        return self._FetchTags('SELECT * FROM TAGS WHERE scope=? AND kind=?;',
                               (ToAbbrGlobal(scope), kind))

    # FIXME: 处理 name LIKE 的大小写问题
    def GetOrderedTagsByScopesAndName(self, scopes, name,
                                      submatch = True, limit = 1000):
        '''很常用的方法'''
        if not self.IsOpen():
            return []

        if not scopes:
            return []

        if not submatch and not name:
            return []

        orig_scopes = scopes
        scopes = [ToAbbrGlobal(s) for s in scopes]

        # 参数非法的话, 用默认值覆盖
        if not isinstance(limit, int) or limit <= 0:
            limit = 1000

        if submatch:
            sql = 'SELECT * FROM TAGS WHERE scope IN %s and name LIKE ? ORDER BY name ASC LIMIT %d' \
                    % (MakeQMarkString(len(scopes)), limit)
            return self._FetchTags(sql, tuple(scopes) + ('%s%%' % name, ))
        else:
            sql = 'SELECT * FROM TAGS WHERE scope IN %s and name=? ORDER BY name ASC LIMIT %d;' \
                    % (MakeQMarkString(len(scopes)), limit)
            return self._FetchTags(sql, tuple(scopes) + (name, ))

    # ------------------------------------------------------------------------

    def DeleteFileEntry(self, fname, auto_commit = True):
        try:
            if auto_commit:
                self.Begin()
            self.db.execute("DELETE FROM FILES WHERE file=?;", (fname, ))
            if auto_commit:
                self.Commit()
        except sqlite3.OperationalError:
            if auto_commit:
                self.Rollback()
            return -1
        else:
            return 0

    def DeleteFileEntries(self, files, auto_commit = True):
        try:
            if auto_commit:
                self.Begin()
            self.db.execute("DELETE FROM FILES WHERE file IN %s;" 
                            % MakeQMarkString(len(files)), tuple(files))
            if auto_commit:
                self.Commit()
        except sqlite3.OperationalError:
            if auto_commit:
                self.Rollback()
            return -1
        else:
            return 0

    def InsertFileEntry(self, fname, tagtime, auto_commit = True):
        try:
            if auto_commit:
                self.Begin()
            # 理论上, 不会插入失败
            self.db.execute("INSERT OR REPLACE INTO FILES VALUES(NULL, ?, ?);", 
                           (fname, tagtime))
            if auto_commit:
                self.Commit()
        except:
            if auto_commit:
                self.Rollback()
            PrintExcept()
            return -1
        else:
            return 0

    def UpdateFileEntry(self, fname, tagtime, auto_commit = True):
        try:
            if auto_commit:
                self.Begin()
            self.db.execute(
                "UPDATE OR REPLACE FILES SET tagtime=? WHERE file=?;", 
                (tagtime, fname))
            if auto_commit:
                self.Commit()
        except:
            if auto_commit:
                self.Rollback()
            PrintExcept()
            return -1
        else:
            return 0

    def InsertTagEntry(self, tag, auto_commit = True):
        if not tag.IsValid() or not self.IsOpen():
            return -1

        try:
            if _USE_FILEID:
                fname = ''
                fileid = tag.fileid
            else:
                fname = tag.GetFile()
                fileid = 0
            if auto_commit:
                self.Begin()
            # INSERT OR REPLACE 貌似是不会失败的?!
            self.db.execute('''
                INSERT OR REPLACE INTO TAGS VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                ''',
                (tag.GetName(),
                 fname,
                 fileid,
                 tag.GetLine(),
                 tag.GetAbbrKind(), # 缩写

                 ToAbbrGlobal(tag.GetScope()),
                 tag.GetAbbrParentKind(),
                 tag.GetAbbrAccess(),
                 tag.GetInheritsAsString(),
                 tag.GetSignature(),
                 tag.GetExtra()))
            if auto_commit:
                self.Commit()
        except:
            if auto_commit:
                self.Rollback()
            PrintExcept()
            return -1
        else:
            return 0

    def UpdateTagEntry(self, tag, auto_commit = True):
        if not tag.IsValid() or not self.IsOpen():
            return -1

        try:
            if _USE_FILEID:
                fname = ''
                fileid = tag.fileid
            else:
                fname = tag.GetFile()
                fileid = 0
            if auto_commit:
                self.Begin()
            self.db.execute('''
                UPDATE OR REPLACE TAGS SET
                    name=?, file=?, fileid, line=?, kind=?, scope=?,
                    parent_kind=?, access=?, inherits=?, signature=?,
                    extra=?
                WHERE name=? AND file=? AND kind=? AND scope=? AND signature=?;
                '''
                (tag.GetName(),
                 fname,
                 fileid,
                 tag.GetLine(),
                 tag.GetAbbrKind(),
                 ToAbbrGlobal(tag.GetScope()),
                 tag.GetAbbrParentKind(),
                 tag.GetAbbrAccess(),
                 tag.GetInheritsAsString(),
                 tag.GetSignature(),
                 tag.GetExtra(),

                 # 这几个参数能唯一定位
                 tag.GetName(),
                 tag.GetFile(),
                 tag.GetKind(),
                 ToAbbrGlobal(tag.GetScope()),
                 tag.GetSignature()))
            if auto_commit:
                self.Commit()
        except:
            if auto_commit:
                self.Rollback()
            PrintExcept()
            return -1
        else:
            return 0

#    def GetTagsByFiles(self, files):
#        if not files:
#            return []
#
#        return self._FetchTags('SELECT * FROM TAGS WHERE file IN %s' \
#                               % MakeQMarkString(len(files)), tuple(files))

try:
    # 暂时用这种尝试方法
    import vim
    VIDEM_DIR = vim.eval('g:VidemDir')
except ImportError:
    _print('%s: Can not get variable g:VidemDir, fallback to ~/.videm'
           % os.path.basename(__file__), file=sys.stderr)
    # only for Linux
    VIDEM_DIR = os.path.expanduser('~/.vim/_videm')

if platform.system() == 'Windows':
    CTAGS = os.path.join(VIDEM_DIR, 'bin', 'vlctags2.exe')
else:
    CTAGS = os.path.join(VIDEM_DIR, 'bin', 'vlctags2')

CTAGS_OPTS_LIST = [
    '--excmd=pattern',
    '--sort=no',
    '--fields=aKmSsnit',
    '--c-kinds=+px',
    '--c++-kinds=+px',
    # 强制视全部文件为 C++
    '--language-force=c++',
]

def AppendCtagsOptions(opt):
    '''用于添加额外的选项, 暂时用于添加 -m 选项'''
    global CTAGS_OPTS_LIST
    CTAGS_OPTS_LIST.append(opt)

def IsCppSourceFile(fname):
    ext = os.path.splitext(fname)[1][1:]
    if ext in CPP_SOURCE_EXT:
        return True
    else:
        return False

def IsCppHeaderFile(fname):
    ext = os.path.splitext(fname)[1][1:]
    if ext in CPP_HEADER_EXT:
        return True
    else:
        return False

def ParseFilesToTags(files, tagFile, macros_files = []):
    if platform.system() == 'Windows':
        # Windows 下的 cmd.exe 不支持过长的命令行
        batchCount = 10
    else:
        batchCount = 100
    totalCount = len(files)
    i = 0
    batchFiles = files[i : i + batchCount]
    firstEnter = True
    while batchFiles:
        if firstEnter:
            ret = _ParseFilesToTags(batchFiles, tagFile, macros_files,
                                    append = False)
            firstEnter = False
        else:
            ret = _ParseFilesToTags(batchFiles, tagFile, macros_files,
                                    append = True)
        if ret != 0:
            return ret
        i += batchCount
        batchFiles = files[i : i + batchCount]
    return 0

def _ParseFilesToTags(files, tagFile, macros_files = [], append = False,
                      retmsg = {}):
    '''append 为真时，添加新的tags到tagFile'''
    if not files or not tagFile:
        return -1

    ret = 0
    envDict = os.environ.copy()
    if macros_files:
        envDict['CTAGS_GLOBAL_MACROS_FILES'] = ','.join(macros_files)

    if platform.system() == 'Windows':
        if append:
            cmd = '"%s" -a %s -f "%s" "%s"' % (CTAGS, ' '.join(CTAGS_OPTS_LIST),
                                               tagFile, '" "'.join(files))
        else:
            cmd = '"%s" %s -f "%s" "%s"' % (CTAGS, ' '.join(CTAGS_OPTS_LIST),
                                            tagFile, '" "'.join(files))
        p = subprocess.Popen(cmd, shell=True,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             env=envDict)
    else:
        if append:
            cmd = [CTAGS, '-a'] + CTAGS_OPTS_LIST + ['-f', tagFile] + files
        else:
            cmd = [CTAGS] + CTAGS_OPTS_LIST + ['-f', tagFile] + files
        # NOTE: 不用 shell，会快近两倍！
        p = subprocess.Popen(cmd, shell=False,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             env=envDict)

    out, err = p.communicate()

    if p.returncode != 0:
        errmsg = cmd + '\n'
        errmsg += '%d: ctags occured some errors\n' % p.returncode
        errmsg += err + '\n'
        retmsg['error'] = errmsg
        ret = -1

    return ret

def GetFilesMappingSafe(storage, files):
    filedict = {}
    # 每次 200 个足够吧?
    i = 0
    batch = 200

    while i < len(files):
        fs = files[i : i+batch]
        filedict.update(storage.GetFilesMapping(fs))
        i += batch

    return filedict

# 常用的接口
def ParseAndStore(storage, files, macros_files = [], ignore_needless = True,
                  indicator = None, filter_noncxx = False):
    '''filter_noncxx = False 表示不检查文件是否c++头文件或源文件'''
    # 确保打开了一个数据库
    if not storage.IsOpen():
        return -1

    if not files:
        return 0

    # NOTE: 全部转为绝对路径, 如果必要的话仅 parse C++ 头文件和源文件
    if filter_noncxx:
        pending_files = [os.path.abspath(f) for f in files
                          if IsCppSourceFile(f) or IsCppHeaderFile(f)]
    else:
        pending_files = [os.path.abspath(f) for f in files]

    if ignore_needless:
        # NOTE: pending_files 数量太多的话, SQL 无法支持, 需要分批来获取
        #filedict = storage.GetFilesMapping(pending_files)
        filedict = GetFilesMappingSafe(storage, pending_files)
        tmp = pending_files
        pending_files = []
        for pf in tmp:
            if filedict.has_key(pf) and \
               filedict[pf].tagtime >= GetMTime(pf):
                # 如果数据库保存的 tagtime 比文件的 mtime 要新, 则忽略这个文件
                continue
            pending_files.append(pf)

    # 分批 parse
    totalCount = len(pending_files)
    batchCount = totalCount / 10
    if batchCount > 200:    # 上限
        batchCount = 200
    if batchCount <= 0:     # 下限
        batchCount = 1

    i = 0
    batchFiles = pending_files[i : i + batchCount]
    if indicator:
        indicator(0, 100)

    if not _DEBUG:
        tagFile = TempFile()
    while batchFiles:
        if _DEBUG:
            tagFile = os.path.join(__dir__, 'tags_%d.txt' % i)
            ret = 0
        # 使用临时文件
        ret = ParseFilesToTags(batchFiles, tagFile, macros_files)
        if ret == 0: # 只有解析成功才入库
            storage.Begin()

            # 先删除旧的 tags
            if storage.DeleteTagsByFiles(batchFiles, auto_commit = False) != 0:
                storage.Rollback()
                storage.Begin()

            # 存 FILES 表
            tagtime = int(time.time())
            for f in batchFiles:
                if os.path.isfile(f):
                    storage.InsertFileEntry(f, tagtime, auto_commit = False)
            if _USE_FILEID:
                filedict = storage.GetFilesMapping()
            else:
                filedict = {}

            # 存 TAGS 表
            if storage.StoreFromTagFile(tagFile, auto_commit = False,
                                        filedict = filedict) != 0:
                storage.Rollback()
                storage.Begin()

            storage.Commit()

        i += batchCount
        # 下一个 batchFiles
        batchFiles = pending_files[i : i + batchCount]
        if indicator:
            indicator(i, totalCount)

    if not _DEBUG:
        os.remove(tagFile)

    # 这个可以删掉
    if indicator:
        indicator(100, 100)

    return 0

def test():
    AppendCtagsOptions('-m')

    content = '''
// typedef
typedef typename _Alloc::template rebind<value_type>::other _Pair_alloc_type;

// template class or struct
template <typename T1, class T2>
class Clazz {
public:
};

// template function
template <typename T1, typename T2>
func(T1 t1, T2 t2)
{
}

// variable
void *p1, **p2;

// typeref
struct ss {
    int i;
} xx, *yy;

class C {
public:
    char cc;
};

char g_cc;
extern int g_ii;
'''
    tfile = TempFile()
    with open(tfile, 'wb') as f:
        f.write(content)

    #files = ['/usr/include/stdio.h', '/usr/include/stdlib.h']
    files = [tfile]
    macros_files = ['global.h', 'global.hpp']
    storage = TagsStorageSQLite()

    if _DEBUG:
        dbfile = os.path.join(__dir__, 'test.tagsdb')
        tagsfiles = os.path.join(__dir__, 'tags.files')
    else:
        dbfile = ':memory:'
        tagsfiles = ''

    if os.path.exists(tagsfiles):
        del files[:]
        with open(tagsfiles) as f:
            for line in f:
                files.append(line.strip())

    def PrintProgress(*args):
        print args

    filter_noncxx = False
    if _DEBUG:
        filter_noncxx = True

    storage.OpenDatabase(dbfile)
    storage.RecreateDatabase()
    t1 = time.time()
    ParseAndStore(storage, files, macros_files, ignore_needless = False,
                  indicator = PrintProgress, filter_noncxx = filter_noncxx)
    t2 = time.time()
    print "consume time: %f" % (t2 - t1)

    os.remove(tfile)

    if _DEBUG:
        return

    #tags = storage.GetTagsBySQL('SELECT * FROM TAGS;')
    #for tag in tags:
        #tag.Print()
        #print json.dumps(tag.ToDict(), sort_keys=True, indent=4)

    print '===== %s =====' % 'GetOrderedTagsByScopesAndName'
    for tag in storage.GetOrderedTagsByScopesAndName(['<global>', 'C'], 'c'):
        tag.Print()

    assert storage.GetFileByFileid(1)
    assert storage.GetFileidsByFiles([storage.GetFileByFileid(1)]) == [1]
    assert storage.GetTagsByPath('C::cc')

    #print storage.GetFilesMapping(['/usr/include/stdio.h',
                               #'/usr/include/unistd.h',
                               #'xstring.hpp'])
    #print storage.DeleteFileEntries(files)


if __name__ == '__main__':
    test()
