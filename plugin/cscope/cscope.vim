" cscope symbol database plugin for videm
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-05-18
" Change:   2013-05-18

let s:CscopeSettings = {
    \ '.videm.symdb.cscope.Enable'          : 1,
    \ '.videm.symdb.cscope.Program'         : &cscopeprg,
    \ '.videm.symdb.cscope.IncExtHdr'       : 1,
    \ '.videm.symdb.cscope.GenInvIdx'       : 0,
    \ '.videm.symdb.cscope.FilesFile'       : '_cscope.files',
    \ '.videm.symdb.cscope.OutFile'         : '_cscope.out',
\ }

function! s:InitSettings() "{{{2
    call videm#settings#Init(s:CscopeSettings)
endfunction
"}}}
function! s:InitVLWCscopeDatabase(...) "{{{2
    " 初始化 cscope 数据库。文件的更新采用粗略算法，
    " 只比较记录文件与 cscope.files 的时间戳而不是很详细的记录每次增删条目
    " 如果 cscope.files 比工作空间和包含的所有项目都要新，无须刷新 cscope.files

    " 如果传进来的第一个参数非零，强制全部初始化并刷新全部

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

    let l:force = 0
    if exists('a:1') && a:1 != 0
        let l:force = 1
    endif

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
    if needUpdateCsNameFile or vim.eval('l:force') == '1':
        #vim.command('let lFiles = %s' 
            #% [i.encode('utf-8') for i in ws.VLWIns.GetAllFiles(True)])
        # 直接 GetAllFiles 可能会出现重复的情况，直接用 filesIndex 字典键值即可
        ws.VLWIns.GenerateFilesIndex() # 重建，以免任何特殊情况
        files = ws.VLWIns.filesIndex.keys()
        files.sort()
        vim.command('let lFiles = %s' % json.dumps(files, ensure_ascii=False))

    # TODO: 添加激活的项目的包含头文件路径选项
    # 这只关系到跳到定义处，如果实现了 ctags 数据库，就不需要
    # 比较麻烦，暂不实现
    incPaths = []
    if vim.eval('g:VLWorkspaceCscopeContainExternalHeader') != '0':
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
    exec 'silent! cs kill '. sCsOutFile

    let retval = 0
    if filereadable(sCsOutFile)
        " 已存在，但不更新，应该由用户调用 s:UpdateVLWCscopeDatabase 来更新
        " 除非为强制初始化全部
        if l:force
            if g:VLWorkspaceCreateCscopeInvertedIndex
                let sFirstOpts = '-bqkU'
            else
                let sFirstOpts = '-bkU'
            endif
            let sCmd = printf('%s %s %s -i %s -f %s', 
                        \shellescape(g:VLWorkspaceCscopeProgram), 
                        \sFirstOpts, sIncludeOpts, 
                        \shellescape(sCsFilesFile), shellescape(sCsOutFile))
            "call system(sCmd)
            py vim.command('let retval = %d' % System(vim.eval('sCmd'))[0])
        endif
    else
        if g:VLWorkspaceCreateCscopeInvertedIndex
            let sFirstOpts = '-bqk'
        else
            let sFirstOpts = '-bk'
        endif
        let sCmd = printf('%s %s %s -i %s -f %s', 
                    \shellescape(g:VLWorkspaceCscopeProgram), 
                    \sFirstOpts, sIncludeOpts, 
                    \shellescape(sCsFilesFile), shellescape(sCsOutFile))
        "call system(sCmd)
        py vim.command('let retval = %d' % System(vim.eval('sCmd'))[0])
    endif

    if retval
        echomsg printf("cscope occur error: %d", retval)
        echomsg sCmd
        py del l_ds
        return
    endif

    set cscopetagorder=0
    set cscopetag
    "set nocsverb
    exec 'silent! cs kill '. sCsOutFile
    exec 'cs add '. sCsOutFile
    "set csverb

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
    if g:VLWorkspaceCscopeContainExternalHeader
        py vim.command("let lIncludePaths = %s" % json.dumps(
                    \ws.GetWorkspaceIncludePaths(), ensure_ascii=False))
    endif
    let sIncludeOpts = ''
    if !empty(lIncludePaths)
        call map(lIncludePaths, 'shellescape(v:val)')
        let sIncludeOpts = '-I' . join(lIncludePaths, ' -I')
    endif

    let sFirstOpts = '-bkU'
    if g:VLWorkspaceCreateCscopeInvertedIndex
        let sFirstOpts .= 'q'
    endif
    let sCmd = printf('%s %s %s -i %s -f %s', 
                \shellescape(g:VLWorkspaceCscopeProgram), sFirstOpts, 
                \sIncludeOpts, 
                \shellescape(sCsFilesFile), shellescape(sCsOutFile))

    " Windows 下必须先断开链接，否则无法更新
    exec 'silent! cs kill '. sCsOutFile

    "call system(sCmd)
    py vim.command('let retval = %d' % System(vim.eval('sCmd'))[0])

    if retval
        echomsg printf("cscope occur error: %d", retval)
        echomsg sCmd
        "py del l_ds
        "return
    endif

    exec 'cs add '. sCsOutFile

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
        let &cscopeprg = g:VLWorkspaceCscopeProgram
        set cscopetagorder=0
        set cscopetag
        exec 'silent! cs kill '. sCsOutFile
        exec 'cs add '. sCsOutFile
    endif
    py del l_ds
endfunction
"}}}
function! s:ThisInit() "{{{2
    call s:InitPythonIterfaces()
    py VidemWorkspace.wsp_ntf.Register(VidemWspCscopeHook, 0, None)
    " 命令
    command! -nargs=0 VLWInitCscopeDatabase 
                \               call <SID>InitVLWCscopeDatabase(1)
    command! -nargs=0 VLWUpdateCscopeDatabase 
                \               call <SID>UpdateVLWCscopeDatabase(1)
endfunction
"}}}
function! videm#plugin#cscope#Init()
    call s:InitSettings()
    if !videm#settings#Get('.videm.symdb.cscope.Enable', 0)
        return
    endif
    call s:ThisInit()
endfunction
function! s:InitPythonIterfaces()
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

" vim: fdm=marker fen et sw=4 sts=4 fdl=1