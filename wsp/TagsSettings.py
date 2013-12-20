#!/usr/bin/env python
# -*- encoding:utf-8 -*-

'''这个模块作为全局模块而不是OmniCpp的子模块，因为这个模块的包含路径被好几个
模块同时使用'''

import pickle
import os.path
import json

from Macros import VIDEM_DIR
from Misc import IsWindowsOS
from Misc import Obj2Dict, Dict2Obj

CONFIG_FILE = os.path.join(VIDEM_DIR, 'config', 'TagsSettings.conf')

class TagsSettings:
    '''tags 设置'''

    def __init__(self, fileName = ''):
        if not fileName:
            self.fileName = ''
        else:
            self.fileName = os.path.abspath(fileName)
        self.includePaths = []
        self.excludePaths = []
        self.tagsTokens = [] # 宏处理符号
        self.tagsTypes = [] # 类型映射符号

        # 如果指定了 fileName, 从文件载入
        if fileName:
            self.Load(fileName)

    def ToDict(self):
        return Obj2Dict(self, set(['fileName']))

    def FromDict(self, d):
        Dict2Obj(self, d, set(['fileName']))

    def SetFileName(self, fileName):
        self.fileName = fileName

    def AddTagsToken(self, tagsToken):
        self.tagsTokens.append(tagsToken)

    def RemoveTagsToken(self, index):
        try:
            del self.tagsTokens[index]
        except IndexError:
            return

    def AddTagsType(self, tagsType):
        self.tagsTypes.append(tagsType)

    def RemoveTagsType(self, index):
        try:
            del self.tagsTypes[index]
        except IndexError:
            return

    def AddIncludePath(self, path):
        self.includePaths.append(path)

    def RemoveIncludePath(self, index):
        try:
            del self.includePaths[index]
        except IndexError:
            return

    def AddExcludePath(self, path):
        self.excludePaths.append(path)

    def RemoveExcludePath(self, index):
        try:
            del self.excludePaths[index]
        except IndexError:
            return

    def Load(self, fileName = ''):
        if not fileName and not self.fileName:
            return False

        isjson = False
        ret = False
        obj = None
        try:
            if not fileName:
                fileName = self.fileName
            f = open(fileName, 'rb')
            obj = pickle.load(f)
            f.close()
        except IOError:
            #print 'IOError:', fileName
            return False
        except:
            f.close()
            isjson = True

        if not isjson and obj:
            #self.fileName = obj.fileName
            self.includePaths = obj.includePaths
            self.excludePaths = obj.excludePaths
            self.tagsTokens = obj.tagsTokens
            self.tagsTypes = obj.tagsTypes
            del obj
            ret = True

        if isjson:
            try:
                f = open(fileName, 'rb')
                d = json.load(f)
                f.close()
                self.FromDict(d)
            except IOError:
                return False
            except:
                f.close()
                return False
            ret = True

        return ret

    def Save(self, fileName = ''):
        if not fileName and not self.fileName:
            return False
        if not fileName:
            fileName = self.fileName

        ret = False
        d = self.ToDict()
        dirName = os.path.dirname(fileName)

        try:
            if not os.path.exists(dirName):
                os.makedirs(dirName)
        except:
            return False

        try:
            f = open(fileName, 'wb')
            json.dump(d, f, indent=4, sort_keys=True, ensure_ascii=True)
            f.close()
            ret = True
        except IOError:
            print 'IOError:', fileName
            return False

        return ret


class TagsSettingsST:
    __ins = None

    @staticmethod
    def Get():
        if not TagsSettingsST.__ins:
            TagsSettingsST.__ins = TagsSettings()
            # 载入默认设置
            if not TagsSettingsST.__ins.Load(CONFIG_FILE):
                # 文件不存在, 新建默认设置文件
                GenerateDefaultTagsSettings()
                TagsSettingsST.__ins.Save(CONFIG_FILE)
            TagsSettingsST.__ins.SetFileName(CONFIG_FILE)
        return TagsSettingsST.__ins

    @staticmethod
    def Free():
        del TagsSettingsST.__ins
        TagsSettingsST.__ins = None



def GetGccIncludeSearchPaths():
    start = False
    result = []

    #cmd = 'gcc -v -x c++ -fsyntax-only /dev/null 2>&1'
    cmd = 'echo "" | gcc -v -x c++ -fsyntax-only - 2>&1'

    for line in os.popen(cmd):
        #if line == '#include <...> search starts here:\n':
        if line.startswith('#include <...>'):
            start = True
            continue
        #elif line == 'End of search list.\n':
        if start and not line.startswith(' '):
            break

        if start:
            result.append(os.path.normpath(line.strip()))

    return result


def GenerateDefaultTagsSettings():
    # 预设值
    defaultIncludePaths = GetGccIncludeSearchPaths()
    tags_tokens = '''\
#define EXPORT
#define WXDLLIMPEXP_CORE
#define WXDLLIMPEXP_BASE
#define WXDLLIMPEXP_XML
#define WXDLLIMPEXP_XRC
#define WXDLLIMPEXP_ADV
#define WXDLLIMPEXP_AUI
#define WXDLLIMPEXP_CL
#define WXDLLIMPEXP_LE_SDK
#define WXDLLIMPEXP_SQLITE3
#define WXDLLIMPEXP_SCI
#define WXMAKINGDLL
#define WXUSINGDLL
#define _CRTIMP
#define __CRT_INLINE
#define __cdecl
#define __stdcall
#define WXDLLEXPORT
#define WXDLLIMPORT
#define __MINGW_ATTRIB_PURE
#define __MINGW_ATTRIB_MALLOC
#define __GOMP_NOTHROW
#define SCI_SCOPE(x) x
#define WINBASEAPI
#define WINAPI
#define __nonnull
#define wxTopLevelWindowNative wxTopLevelWindowGTK
#define wxWindow wxWindowGTK
#define wxWindowNative wxWindowBase
#define wxStatusBar wxStatusBarBase
#define BEGIN_DECLARE_EVENT_TYPES() enum {
#define END_DECLARE_EVENT_TYPES() };
#define DECLARE_EVENT_TYPE
#define DECLARE_EXPORTED_EVENT_TYPE
#define WXUNUSED(x) x
#define wxDEPRECATED(x) x
#define ATTRIBUTE_PRINTF_1
#define ATTRIBUTE_PRINTF_2
#define WXDLLIMPEXP_FWD_BASE
#define WXDLLIMPEXP_FWD_CORE
#define DLLIMPORT
#define DECLARE_INSTANCE_TYPE
#define emit
#define Q_OBJECT
#define Q_PACKED
#define Q_GADGET
#define QT_BEGIN_HEADER
#define QT_END_HEADER
#define Q_REQUIRED_RESULT
#define Q_INLINE_TEMPLATE
#define Q_OUTOFLINE_TEMPLATE
#define _GLIBCXX_BEGIN_NAMESPACE(x) namespace x {
#define _GLIBCXX_END_NAMESPACE }
#define _GLIBCXX_BEGIN_NESTED_NAMESPACE(x, y) namespace x {
#define _GLIBCXX_END_NESTED_NAMESPACE }
#define _GLIBCXX_STD std
#define __const const
#define __restrict
#define __THROW
#define __wur
#define _STD_BEGIN namespace std {
#define _STD_END }
#define __CLRCALL_OR_CDECL
#define _CRTIMP2_PURE
#define __BEGIN_NAMESPACE_STD
#define __END_NAMESPACE_STD
#define __attribute_malloc__
#define __attribute_pure__
#define _GLIBCXX_BEGIN_NAMESPACE_CONTAINER
#define _GLIBCXX_END_NAMESPACE_CONTAINER
#define __cplusplus 1
#define __attribute__(x)
#define _GLIBCXX_VISIBILITY(x)
/* ========== for linux kernel ========== */
#define __KERNEL__
#define __init
#define __initdata
#define __exitdata
#define __exit_call
#define __exit
#define __devinit
#define __devinitdata
#define __devexit
#define __devexitdata
#define __inline__ inline
#define __always_inline inline
#define __read_mostly
#define __write_mostly
#define asmlinkage
#define EXPORT_SYMBOL(sym)
#define EXPORT_SYMBOL_GPL(sym)
#define EXPORT_SYMBOL_GPL_FUTURE(sym)
#define EXPORT_UNUSED_SYMBOL(sym)
#define EXPORT_UNUSED_SYMBOL_GPL(sym)
#define module_init(x)
#define module_exit(x)
#define unlikely(x) x
#define likely(x) x
// locks declaring
#define DEFINE_SPINLOCK(x) spinlock_t x
#define DEFINE_RAW_SPINLOCK(x) raw_spinlock_t x
#define DEFINE_MUTEX(mutexname) struct mutex mutexname
#define DEFINE_RWLOCK(x) rwlock_t x
// from compiler.h
#define __user
#define __kernel
#define __safe
#define __force
#define __nocast
#define __iomem
#define __chk_user_ptr(x) (void)0
#define __chk_io_ptr(x) (void)0
#define __builtin_warning(x, y...) (1)
#define __acquires(x)
#define __releases(x)
#define __acquire(x) (void)0
#define __release(x) (void)0
#define __cond_lock(x,c) (c)
#define __percpu
#define ____cacheline_aligned
#define ____cacheline_aligned_in_smp
#define DECLARE_PER_CPU(type, name) extern type name
#define DEFINE_PER_CPU(type, name) type name
// syscalls
#define __SC_DECL1(t1, a1)      t1 a1
#define __SC_DECL2(t2, a2, ...) t2 a2, __SC_DECL1(__VA_ARGS__)
#define __SC_DECL3(t3, a3, ...) t3 a3, __SC_DECL2(__VA_ARGS__)
#define __SC_DECL4(t4, a4, ...) t4 a4, __SC_DECL3(__VA_ARGS__)
#define __SC_DECL5(t5, a5, ...) t5 a5, __SC_DECL4(__VA_ARGS__)
#define __SC_DECL6(t6, a6, ...) t6 a6, __SC_DECL5(__VA_ARGS__)
#define __SYSCALL_DEFINEx(x, name, ...) long sys##name(__SC_DECL##x(__VA_ARGS__))
#define SYSCALL_DEFINEx(x, sname, ...) __SYSCALL_DEFINEx(x, sname, __VA_ARGS__)
#define SYSCALL_DEFINE0(name)      long sys_##name(void)
#define SYSCALL_DEFINE1(name, ...) SYSCALL_DEFINEx(1, _##name, __VA_ARGS__)
#define SYSCALL_DEFINE2(name, ...) SYSCALL_DEFINEx(2, _##name, __VA_ARGS__)
#define SYSCALL_DEFINE3(name, ...) SYSCALL_DEFINEx(3, _##name, __VA_ARGS__)
#define SYSCALL_DEFINE4(name, ...) SYSCALL_DEFINEx(4, _##name, __VA_ARGS__)
#define SYSCALL_DEFINE5(name, ...) SYSCALL_DEFINEx(5, _##name, __VA_ARGS__)
#define SYSCALL_DEFINE6(name, ...) SYSCALL_DEFINEx(6, _##name, __VA_ARGS__)
// glibc 4.7
#define _GLIBCXX_NOEXCEPT
#define noexcept
'''
    defaultTagsTokens = tags_tokens.splitlines()

    tags_types = '''\
std::vector<A>::reference=A
std::vector<A>::const_reference=A
std::vector<A>::iterator=A
std::vector<A>::const_iterator=A
std::list<A>::iterator=A
std::list<A>::const_iterator=A
std::queue<A>::reference=A
std::queue<A>::const_reference=A
std::set<A>::const_iterator=A
std::set<A>::iterator=A
std::deque<A>::reference=A
std::deque<A>::const_reference=A
std::map<A,B>::iterator=std::pair<A,B>
std::map<A,B>::const_iterator=std::pair<A,B>
std::multimap<A,B>::iterator=std::pair<A,B>
std::multimap<A,B>::const_iterator=std::pair<A,B>
'''
    defaultTagsTypes = tags_types.splitlines()

    ins = TagsSettingsST.Get()
    ins.includePaths = defaultIncludePaths
    ins.tagsTokens = defaultTagsTokens
    ins.tagsTypes = defaultTagsTypes


if __name__ == '__main__':
    ins = TagsSettingsST.Get()
    print ins.fileName
    print '\n'.join(ins.includePaths)
    print '\n'.join(ins.tagsTokens)
    print '\n'.join(ins.tagsTypes)

