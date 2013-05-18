" gtags symbol database plugin for videm
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-05-18
" Change:   2013-05-18

let s:GtagsSettings = {
    \ '.videm.symdb.gtags.Enable'           : 0,
    \ '.videm.symdb.gtags.Program'          : 'gtags',
    \ '.videm.symdb.gtags.CscopeProg'       : 'gtags-cscope',
    \ '.videm.symdb.gtags.FilesFile'        : '_gtags.files',
    \ '.videm.symdb.gtags.UpdAfterSave'     : 1,
\ }

function! s:InitSettings() "{{{2
    call videm#settings#Init(s:GtagsSettings)
endfunction
"}}}
function! s:InitVLWGtagsDatabase(bIncremental) "{{{2
    " 求简单，调用这个函数就表示强制新建数据库
    py l_ds = DirSaver()
    py if os.path.isdir(ws.VLWIns.dirName): os.chdir(ws.VLWIns.dirName)

    let lFiles = []
    py ws.VLWIns.GenerateFilesIndex() # 重建，以免任何特殊情况
    py l_files = ws.VLWIns.filesIndex.keys()
    py l_files.sort()
    py vim.command('let lFiles = %s' % json.dumps(l_files, ensure_ascii=False))
    py del l_files

    let sWspName = GetWspName()
    let sGlbFilesFile = sWspName . g:VLWorkspaceGtagsFilesFile
    let sGlbOutFile = 'GTAGS'
    let sGtagsProgram = g:VLWorkspaceGtagsProgram

    if !empty(lFiles)
        if vlutils#IsWindowsOS()
            " Windows 的 cscope 不能处理 \ 分割的路径
            call map(lFiles, 'vlutils#PosixPath(v:val)')
        endif
        call writefile(lFiles, sGlbFilesFile)
    endif

    exec 'silent! cs kill '. sGlbOutFile
    let sCmd = printf('%s -f %s', 
                \     shellescape(sGtagsProgram), shellescape(sGlbFilesFile))
    if a:bIncremental && filereadable(sGlbOutFile)
        " 增量更新
        let sCmd .= ' -i'
    endif
    "call system(sCmd)
    py vim.command('let retval = %d' % System(vim.eval('sCmd'))[0])
    if retval
        echom printf("gtags occur error: %d", retval)
        echom sCmd
        "py del l_ds
        "return
    endif

    call videm#plugin#gtags#ConnectGtagsDatabase(sGlbOutFile)

    py del l_ds
endfunction
"}}}
function! s:UpdateVLWGtagsDatabase() "{{{2
    " 仅在已经初始化过了才可以更新
    if exists('s:bHadConnGtagsDb') && s:bHadConnGtagsDb
        call s:InitVLWGtagsDatabase(1)
    endif
endfunction
"}}}
" 可选参数为 GTAGS 文件
function! videm#plugin#gtags#ConnectGtagsDatabase(...) "{{{2
    let sGlbOutFile = get(a:000, 0, 'GTAGS')
    if filereadable(sGlbOutFile)
        let sDir = fnamemodify(sGlbOutFile, ':h')
        if sDir ==# '.' || empty(sDir)
            let sDir = getcwd()
        endif
        let &cscopeprg = videm#settings#Get('.videm.symdb.gtags.CscopeProg')
        set cscopetagorder=0
        set cscopetag
        exec 'silent! cs kill' fnameescape(sGlbOutFile)
        exec 'cs add' fnameescape(sGlbOutFile) fnameescape(sDir)
        let s:bHadConnGtagsDb = 1
    endif
endfunction
"}}}
" 假定 sFile 是绝对路径的文件名
function! s:Autocmd_UpdateGtagsDatabase(sFile) "{{{2
    py if not ws.VLWIns.IsWorkspaceFile(vim.eval("a:sFile")):
                \vim.command('return')

    if exists('s:bHadConnGtagsDb') && s:bHadConnGtagsDb
        let sGlbFilesFile = GetWspName() . g:VLWorkspaceGtagsFilesFile
        py vim.command("let sWspDir = %s" % ToVimEval(ws.VLWIns.dirName))
        let sGlbFilesFile = g:vlutils#os.path.join(sWspDir, sGlbFilesFile)
        let sCmd = printf("cd %s && %s -f %s --single-update %s &", 
                    \     shellescape(sWspDir),
                    \     shellescape(g:VLWorkspaceGtagsProgram),
                    \     shellescape(sGlbFilesFile),
                    \     shellescape(a:sFile))
        "echo sCmd
        "exec sCmd
        call system(sCmd)
        "echom 'enter s:Autocmd_UpdateGtagsDatabase()'
    endif
endfunction
"}}}
function! s:ThisInit() "{{{2
    call s:InitPythonIterfaces()
    py VidemWorkspace.wsp_ntf.Register(VidemWspGtagsHook, 0, None)
    " 命令
    command! -nargs=0 VLWInitGtagsDatabase call <SID>InitVLWGtagsDatabase(0)
    command! -nargs=0 VLWUpdateGtagsDatabase call <SID>UpdateVLWGtagsDatabase()
    " 自动命令
    if videm#settings#Get('.videm.symdb.gtags.UpdAfterSave')
        augroup VidemSyndbGtags
            autocmd! BufWritePost *
                    \ call <SID>Autocmd_UpdateGtagsDatabase(expand('%:p'))
        augroup END
    endif
endfunction
"}}}
" 各种检查，返回 0 表示失败，否则返回 1
function! s:SanityCheck() "{{{2
    " gtags 的版本至少需要 5.7.6
    let minver = 5.8
    let cmd = printf("%s --version", g:VLWorkspaceGtagsProgram)
    let output = system(cmd)
    let sVersion = get(split(get(split(output, '\n'), 0, '')), -1)
    if empty(output) || empty(sVersion)
        call vlutils#EchoWarnMsg('failed to run gtags')
        return 0
    endif
    " 取前面两位
    let ver = str2float(sVersion)
    if ver < minver
        let sErr = printf("Required gtags %.1f or later, "
                    \     . "please update it.\n", minver)
        let sErr .= "Otherwise you should set '.videm.symdb.gtags.Enable'"
                \    . " to 0 to disable gtags."
        call vlutils#EchoWarnMsg(sErr)
        return 0
    endif

    return 1
endfunction
"}}}
function! videm#plugin#gtags#Init()
    call s:InitSettings()
    if !videm#settings#Get('.videm.symdb.gtags.Enable', 0)
        return
    endif
    if !s:SanityCheck()
        "call vlutils#EchoWarnMsg("gtags SanityCheck failed! Please fix it up.")
        call getchar()
        return
    endif
    call s:ThisInit()
endfunction

function! s:InitPythonIterfaces()
python << PYTHON_EOF
import vim

def VidemWspGtagsHook(event, wsp, unused):
    if event == 'open_post':
        vim.command("call videm#plugin#gtags#ConnectGtagsDatabase()")
    elif event == 'close_post':
        pass
    return Notifier.OK
PYTHON_EOF
endfunction

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
