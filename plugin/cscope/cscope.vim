" cscope symbol database plugin for videm
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-05-18
" Change:   2013-12-22

let s:enable = 0

" 初始化变量仅在变量没有定义时才赋值，var 必须是合法的变量名
function! s:InitVariable(var, value, ...) "{{{2
    let force = get(a:000, 0, 0)
    if force || !exists(a:var)
        if exists(a:var)
            unlet {a:var}
        endif
        let {a:var} = a:value
    endif
endfunction
"}}}2

call s:InitVariable('g:VLWorkspaceCscopeProgram', &cscopeprg)
call s:InitVariable('g:VLWorkspaceCscopeContainExternalHeader', 1)
call s:InitVariable('g:VLWorkspaceCreateCscopeInvertedIndex', 0)
" 以下几个 cscope 选项仅供内部使用
call s:InitVariable('g:VLWorkspaceCscpoeFilesFile', '_cscope.files')
call s:InitVariable('g:VLWorkspaceCscpoeOutFile', '_cscope.out')

let s:CscopeSettings = {
    \ '.videm.symdb.cscope.Enable'          : 1,
    \ '.videm.symdb.cscope.Program'         : &cscopeprg,
    \ '.videm.symdb.cscope.IncExtHdr'       : 1,
    \ '.videm.symdb.cscope.GenInvIdx'       : 0,
    \ '.videm.symdb.cscope.FilesFile'       : '_cscope.files',
    \ '.videm.symdb.cscope.OutFile'         : '_cscope.out',
\ }

let s:CompatSettings = {
    \ 'g:VLWorkspaceCscopeProgram'          : '.videm.symdb.cscope.Program',
    \ 'g:VLWorkspaceCscopeContainExternalHeader'
    \       : '.videm.symdb.cscope.IncExtHdr',
    \ 'g:VLWorkspaceCreateCscopeInvertedIndex'
    \       : '.videm.symdb.cscope.GenInvIdx',
    \ 'g:VLWorkspaceCscpoeFilesFile'        : '.videm.symdb.cscope.FilesFile',
    \ 'g:VLWorkspaceCscpoeOutFile'          : '.videm.symdb.cscope.OutFile',
\ }

function! s:InitCompatSettings() "{{{2
    for item in items(s:CompatSettings)
        if !exists(item[0])
            continue
        endif
        call videm#settings#Set(item[1], {item[0]})
    endfor
endfunction
"}}}2
function! s:InitSettings() "{{{2
    if videm#settings#Get('.videm.Compatible')
        call s:InitCompatSettings()
    endif
    call videm#settings#Init(s:CscopeSettings)
endfunction
"}}}
function! s:InitVLWCscopeDatabase(...) "{{{2
    " 初始化 cscope 数据库。文件的更新采用粗略算法，
    " 只比较记录文件与 cscope.files 的时间戳而不是很详细的记录每次增删条目
    " 如果 cscope.files 比工作空间和包含的所有项目都要新，无须刷新 cscope.files

    " 如果传进来的第一个参数非零，强制全部初始化并刷新全部
    let force = get(a:000, 0, 0)

    if !g:VLWorkspaceHasStarted || 
            \ !videm#settings#Get('.videm.symdb.cscope.Enable', 0)
        return
    endif

    py l_ds = DirSaver()
    py if os.path.isdir(ws.VLWIns.dirName): os.chdir(ws.VLWIns.dirName)

    let lFiles = []
    let sWspName = GetWspName()
    let sCsFilesFile = sWspName . videm#settings#Get('.videm.symdb.cscope.FilesFile')
    let sCsOutFile = sWspName . videm#settings#Get('.videm.symdb.cscope.OutFile')

python << PYTHON_EOF
def InitVLWCscopeDatabase():
    # 检查是否需要更新 cscope.files 文件
    csFilesMt = GetMTime(vim.eval('sCsFilesFile'))
    wspFileMt = ws.VLWIns.GetWorkspaceFileLastModifiedTime()
    needUpdateCsNameFile = False
    # FIXME: codelite 每次退出都会更新工作空间文件的时间戳
    if wspFileMt > csFilesMt:
        needUpdateCsNameFile = True
    else:
        for project in ws.VLWIns.projects.itervalues():
            if project.GetProjFileLastModifiedTime() > csFilesMt:
                needUpdateCsNameFile = True
                break
    if needUpdateCsNameFile or vim.eval('force') == '1':
        #vim.command('let lFiles = %s' 
            #% [i.encode('utf-8') for i in ws.VLWIns.GetAllFiles(True)])
        files = list(set(ws.VLWIns.GetAllFiles(True)))
        files.sort()
        vim.command('let lFiles = %s' % json.dumps(files, ensure_ascii=False))

    # TODO: 添加激活的项目的包含头文件路径选项
    # 这只关系到跳到定义处，如果实现了 ctags 数据库，就不需要
    # 比较麻烦，暂不实现
    incPaths = []
    if vim.eval('videm#settings#Get(".videm.symdb.cscope.IncExtHdr")') != '0':
        incPaths = ws.GetWorkspaceIncludePaths()
    vim.command('let lIncludePaths = %s"' % ToVimEval(incPaths))

InitVLWCscopeDatabase()
PYTHON_EOF

    "echomsg string(lFiles)
    if !empty(lFiles)
        if vlutils#IsWindowsOS()
            " Windows 的 cscope 不能处理 \ 分割的路径，转为 posix 路径
            call map(lFiles, 'vlutils#PosixPath(v:val)')
        endif
        call writefile(lFiles, sCsFilesFile)
    endif

    let sIncludeOpts = ''
    if !empty(lIncludePaths)
        call map(lIncludePaths, 'shellescape(v:val)')
        let sIncludeOpts = '-I' . join(lIncludePaths, ' -I')
    endif

    " Windows 下必须先断开链接，否则无法更新
    exec 'silent! cs kill' fnameescape(sCsOutFile)

    let rets = [0, '', '']
    let prog = videm#settings#Get('.videm.symdb.cscope.Program')
    if filereadable(sCsOutFile)
        " 已存在，但不更新，应该由用户调用 s:UpdateVLWCscopeDatabase 来更新
        " 除非为强制初始化全部
        if force
            if videm#settings#Get('.videm.symdb.cscope.GenInvIdx')
                let sFirstOpts = '-bqkU'
            else
                let sFirstOpts = '-bkU'
            endif
            let sCmd = printf('%s %s %s -i %s -f %s', 
                    \         shellescape(prog), 
                    \         sFirstOpts, sIncludeOpts, 
                    \         shellescape(sCsFilesFile),
                    \         shellescape(sCsOutFile))
            "call system(sCmd)
            py vim.command("let rets = %s" % ToVimEval(System(vim.eval('sCmd'))))
        endif
    else
        if videm#settings#Get('.videm.symdb.cscope.GenInvIdx')
            let sFirstOpts = '-bqk'
        else
            let sFirstOpts = '-bk'
        endif
        let sCmd = printf('%s %s %s -i %s -f %s', 
                \         shellescape(prog), 
                \         sFirstOpts, sIncludeOpts, 
                \         shellescape(sCsFilesFile), shellescape(sCsOutFile))
        " System() 返回 (returncode, stdout, stderr)
        py vim.command("let rets = %s" % ToVimEval(System(vim.eval('sCmd'))))
    endif

    if rets[0]
        echomsg sCmd
        echomsg printf("cscope occurs errors, return %d", rets[0])
        " 错误信息可能是多行，echomsg 显示多行是不知如何解决...
        echo rets[2]
        py del l_ds
        return
    endif

    let sDir = fnamemodify(sCsOutFile, ':h')
    if sDir ==# '.' || empty(sDir)
        let sDir = getcwd()
    endif

    "exec 'silent! cs kill' fnameescape(sCsOutFile)
    "exec 'cs add' fnameescape(sCsOutFile) fnameescape(sDir)
    call vlutils#CscopeAdd(sCsOutFile, sDir)

    py del l_ds
endfunction


function! s:UpdateVLWCscopeDatabase(...) "{{{2
    " 默认仅仅更新 .out 文件，如果有参数传进来且为 1，也更新 .files 文件
    " 仅在已经存在能用的 .files 文件时才会更新

    if !g:VLWorkspaceHasStarted || 
            \ !videm#settings#Get('.videm.symdb.cscope.Enable', 0)
        return
    endif


    py l_ds = DirSaver()
    py if os.path.isdir(ws.VLWIns.dirName): os.chdir(ws.VLWIns.dirName)

    let sWspName = GetWspName()
    let sCsFilesFile = sWspName . videm#settings#Get('.videm.symdb.cscope.FilesFile')
    let sCsOutFile = sWspName . videm#settings#Get('.videm.symdb.cscope.OutFile')

    if !filereadable(sCsFilesFile)
        " 没有必要文件，自动忽略
        py del l_ds
        return
    endif

    if exists('a:1') && a:1 != 0
        " 如果传入参数且非零，强制刷新文件列表
        py vim.command('let lFiles = %s' % json.dumps(
                    \ws.VLWIns.GetAllFiles(True), ensure_ascii=False))
        if vlutils#IsWindowsOS()
            " Windows 的 cscope 不能处理 \ 分割的路径
            call map(lFiles, 'vlutils#PosixPath(v:val)')
        endif
        call writefile(lFiles, sCsFilesFile)
    endif

    let lIncludePaths = []
    if videm#settings#Get('.videm.symdb.cscope.IncExtHdr')
        py vim.command("let lIncludePaths = %s" % json.dumps(
                    \ws.GetWorkspaceIncludePaths(), ensure_ascii=False))
    endif
    let sIncludeOpts = ''
    if !empty(lIncludePaths)
        call map(lIncludePaths, 'shellescape(v:val)')
        let sIncludeOpts = '-I' . join(lIncludePaths, ' -I')
    endif

    let sFirstOpts = '-bkU'
    if videm#settings#Get('.videm.symdb.cscope.GenInvIdx')
        let sFirstOpts .= 'q'
    endif
    let prog = videm#settings#Get('.videm.symdb.cscope.Program')
    let sCmd = printf('%s %s %s -i %s -f %s', 
            \         shellescape(prog), sFirstOpts, 
            \         sIncludeOpts, 
            \         shellescape(sCsFilesFile), shellescape(sCsOutFile))

    " Windows 下必须先断开链接，否则无法更新
    exec 'silent! cs kill' fnameescape(sCsOutFile)

    "call system(sCmd)
    py vim.command("let rets = %s" % ToVimEval(System(vim.eval('sCmd'))))

    if rets[0]
        echomsg sCmd
        echomsg printf("cscope occurs errors, return %d", rets[0])
        echo rets[2]
        "py del l_ds
        "return
    endif

    let sDir = fnamemodify(sCsOutFile, ':h')
    if sDir ==# '.' || empty(sDir)
        let sDir = getcwd()
    endif
    "exec 'cs add' fnameescape(sCsOutFile) fnameescape(sDir)
    call vlutils#CscopeAdd(sCsOutFile, sDir)

    py del l_ds
endfunction
"}}}
" 可选参数为 cscope.out 文件
function! videm#plugin#cscope#ConnectCscopeDatabase(...) "{{{2
    " 默认的文件名...
    py l_ds = DirSaver()
    py if os.path.isdir(ws.VLWIns.dirName): os.chdir(ws.VLWIns.dirName)
    let sWspName = GetWspName()
    let sCsOutFile = sWspName . videm#settings#Get('.videm.symdb.cscope.OutFile')

    let sCsOutFile = a:0 > 0 ? a:1 : sCsOutFile
    if filereadable(sCsOutFile)
        let sDir = fnamemodify(sCsOutFile, ':h')
        if sDir ==# '.' || empty(sDir)
            let sDir = getcwd()
        endif
        "exec 'silent! cs kill' fnameescape(sCsOutFile)
        "exec 'cs add' fnameescape(sCsOutFile) fnameescape(sDir)
        call vlutils#CscopeAdd(sCsOutFile, sDir)
    endif
    py del l_ds
endfunction
"}}}
function! videm#plugin#cscope#InitDatabase(...) "{{{2
    call s:InitVLWCscopeDatabase(1)
endfunction
"}}}
function! videm#plugin#cscope#UpdateDatabase(...) "{{{2
    call s:UpdateVLWCscopeDatabase(1)
endfunction
"}}}
function! s:ThisInit() "{{{2
    call s:InitPythonIterfaces()
    py VidemWorkspace.wsp_ntf.Register(VidemWspCscopeHook, 0, None)
    " 命令
    command! -nargs=0 VCscopeInitDatabase 
                \               call <SID>InitVLWCscopeDatabase(1)
    command! -nargs=0 VCscopeUpdateDatabase 
                \               call <SID>UpdateVLWCscopeDatabase(1)
    " 统一hook
    call Videm_RegisterSymdbInitHook('videm#plugin#cscope#InitDatabase', '')
    call Videm_RegisterSymdbUpdateHook('videm#plugin#cscope#UpdateDatabase', '')
    " 保存并设置一些选项
    let save_opts = ['cscopeprg', 'cscopetagorder', 'cscopetag', 'cscopeverbose']
    let s:opts_bak = vlutils#SaveVimOptions(save_opts)
    let &cscopeprg = videm#settings#Get('.videm.symdb.cscope.Program')
    set cscopetagorder=0
    set cscopetag
    set cscopeverbose
endfunction
"}}}
function! videm#plugin#cscope#SettingsHook(event, data, priv) "{{{2
    let event = a:event
    let opt = a:data['opt']
    let val = a:data['val']
    if event ==# 'set'
        if opt ==# '.videm.symdb.cscope.Enable'
            "echomsg 'cscope'
            "echomsg s:enable
            "echomsg event
            "echomsg val
            if val
                call videm#plugin#cscope#Enable()
            else
                call videm#plugin#cscope#Disable()
            endif
        endif
    endif
endfunction
"}}}
function! videm#plugin#cscope#Init() "{{{2
    call s:InitSettings()
    call videm#settings#RegisterHook('videm#plugin#cscope#SettingsHook', 0, 0)
    if videm#settings#Get('.videm.symdb.cscope.Enable')
        return videm#plugin#cscope#Enable()
    endif
endfunction
"}}}
function! videm#plugin#cscope#HasEnabled() "{{{2
    return s:enable
endfunction
"}}}
function! videm#plugin#cscope#Enable() "{{{2
    if s:enable
        return 0
    endif
    call s:ThisInit()
    
    py if ws.IsOpen():
            \ vim.command('call videm#plugin#cscope#ConnectCscopeDatabase()')
    let s:enable = 1
endfunction
"}}}
function! videm#plugin#cscope#Disable() "{{{2
    if !s:enable
        return
    endif
    py VidemWorkspace.wsp_ntf.Unregister(VidemWspCscopeHook, 0)
    " 命令
    delcommand VCscopeInitDatabase
    delcommand VCscopeUpdateDatabase
    " 删除统一hook
    call Videm_UnregisterSymdbInitHook('videm#plugin#cscope#InitDatabase')
    call Videm_UnregisterSymdbUpdateHook('videm#plugin#cscope#UpdateDatabase')
    " kill symdb
    let sCsOutFile = GetWspName() . videm#settings#Get('.videm.symdb.cscope.OutFile')
    py if ws.IsOpen(): vim.command("exec 'silent! cs kill' fnameescape(sCsOutFile)")
    " 尽量还原选项
    if exists('s:opts_bak')
        call vlutils#RestoreVimOptions(s:opts_bak)
        unlet s:opts_bak
    endif
    let s:enable = 0
endfunction
"}}}
function! s:InitPythonIterfaces() "{{{2
python << PYTHON_EOF
import vim
#from Notifier import Notifier

def VidemWspCscopeHook(event, wsp, unused):
    if event == 'open_post':
        vim.command("call videm#plugin#cscope#ConnectCscopeDatabase()")
    elif event == 'close_post':
        pass
    return Notifier.OK
PYTHON_EOF
endfunction
"}}}
" vim: fdm=marker fen et sw=4 sts=4 fdl=1
