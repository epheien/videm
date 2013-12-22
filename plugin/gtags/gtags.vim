" gtags symbol database plugin for videm
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

" gtags symbol database
call s:InitVariable('g:VLWorkspaceGtagsProgram', 'gtags')
call s:InitVariable('g:VLWorkspaceGtagsCscopeProgram', 'gtags-cscope')
call s:InitVariable('g:VLWorkspaceGtagsFilesFile', '_gtags.files')
call s:InitVariable('g:VLWorkspaceUpdateGtagsAfterSave', 1)

let s:GtagsSettings = {
    \ '.videm.symdb.gtags.Enable'           : 0,
    \ '.videm.symdb.gtags.Program'          : 'gtags',
    \ '.videm.symdb.gtags.CscopeProg'       : 'gtags-cscope',
    \ '.videm.symdb.gtags.FilesFile'        : '_gtags.files',
    \ '.videm.symdb.gtags.UpdAfterSave'     : 1,
\ }

let s:CompatSettings = {
    \ 'g:VLWorkspaceGtagsProgram'           : '.videm.symdb.gtags.Program',
    \ 'g:VLWorkspaceGtagsCscopeProgram'     : '.videm.symdb.gtags.CscopeProg',
    \ 'g:VLWorkspaceGtagsFilesFile'         : '.videm.symdb.gtags.FilesFile',
    \ 'g:VLWorkspaceUpdateGtagsAfterSave'   : '.videm.symdb.gtags.UpdAfterSave',
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
    call videm#settings#Init(s:GtagsSettings)
endfunction
"}}}
function! s:InitVLWGtagsDatabase(bIncremental) "{{{2
    " 求简单，调用这个函数就表示强制新建数据库
    py l_ds = DirSaver()
    py if os.path.isdir(ws.VLWIns.dirName): os.chdir(ws.VLWIns.dirName)

    let lFiles = []
    py l_files = list(set(ws.VLWIns.GetAllFiles(True)))
    py l_files.sort()
    py vim.command('let lFiles = %s' % json.dumps(l_files, ensure_ascii=False))
    py del l_files

    let sWspName = GetWspName()
    let sGlbFilesFile = sWspName . g:VLWorkspaceGtagsFilesFile
    let sGlbOutFile = 'GTAGS'
    let sGtagsProgram = g:VLWorkspaceGtagsProgram

    if !empty(lFiles)
        if vlutils#IsWindowsOS()
            " Windows 的 gtags 不能处理 \ 分割的路径
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
        "exec 'silent! cs kill' fnameescape(sGlbOutFile)
        "exec 'cs add' fnameescape(sGlbOutFile) fnameescape(sDir)
        call vlutils#CscopeAdd(sGlbOutFile, sDir)
        let s:bHadConnGtagsDb = 1
    endif
endfunction
"}}}
" 假定 sFile 是绝对路径的文件名
function! s:Autocmd_UpdateGtagsDatabase(sFile, ...) "{{{2
    py if not ws.VLWIns.IsWorkspaceFile(vim.eval("a:sFile")):
                \vim.command('return')

    " 同步等待子进程终结
    let sync = get(a:000, 0, 0)

    if exists('s:bHadConnGtagsDb') && s:bHadConnGtagsDb
        let sGlbFilesFile = GetWspName() . g:VLWorkspaceGtagsFilesFile
        py vim.command("let sWspDir = %s" % ToVimEval(ws.VLWIns.dirName))
        let sGlbFilesFile = g:vlutils#os.path.join(sWspDir, sGlbFilesFile)

        if sync
            let sCmd = printf("cd %s && %s -f %s --single-update %s",
                        \     shellescape(sWspDir),
                        \     shellescape(g:VLWorkspaceGtagsProgram),
                        \     shellescape(sGlbFilesFile),
                        \     shellescape(a:sFile))
            " 调试的时候用
            call system(sCmd)
            if v:shell_error != 0
                call vlutils#EchoWarnMsg(printf("return %d with command: %s",
                        \                        v:shell_error, sCmd))
            endif
        else
            " TODO 需要获取输出和错误信息
            let cmd = [g:VLWorkspaceGtagsProgram, '-f', sGlbFilesFile,
                    \  '--single-update', a:sFile]
            let cwd = sWspDir
            if vlutils#IsWindowsOS()
                " 要这样实现在后台更新
                py subprocess.Popen(['start', '/min'] + vim.eval('cmd'),
                        \           cwd=vim.eval('cwd'), shell=True)
            else
                py subprocess.Popen(vim.eval('cmd'), cwd=vim.eval('cwd'))
            endif
        endif
    endif
endfunction
"}}}
function! videm#plugin#gtags#SettingsHook(event, data, priv) "{{{2
    let event = a:event
    let opt = a:data['opt']
    let val = a:data['val']
    if event ==# 'set'
        if opt ==# '.videm.symdb.gtags.Enable'
            "echomsg 'gtags'
            "echomsg s:enable
            "echomsg event
            "echomsg val
            if val
                call videm#plugin#gtags#Enable()
            else
                call videm#plugin#gtags#Disable()
            endif
        endif
    endif
endfunction
"}}}
function! s:ThisInit() "{{{2
    if !s:SanityCheck()
        "call vlutils#EchoWarnMsg("gtags SanityCheck failed! Please fix it up.")
        call getchar()
        return -1
    endif
    call s:InitPythonIterfaces()
    py VidemWorkspace.wsp_ntf.Register(VidemWspGtagsHook, 0, None)
    " 命令
    command! -nargs=0 VGtagsInitDatabase call <SID>InitVLWGtagsDatabase(0)
    command! -nargs=0 VGtagsUpdateDatabase call <SID>UpdateVLWGtagsDatabase()
    " 自动命令
    if videm#settings#Get('.videm.symdb.gtags.UpdAfterSave')
        augroup VidemSyndbGtags
            autocmd! BufWritePost *
                    \ call <SID>Autocmd_UpdateGtagsDatabase(expand('%:p'))
        augroup END
    endif
    " 保存并设置一些选项
    let save_opts = ['cscopeprg', 'cscopetagorder', 'cscopetag', 'cscopeverbose']
    let s:opts_bak = vlutils#SaveVimOptions(save_opts)
    let &cscopeprg = videm#settings#Get('.videm.symdb.gtags.CscopeProg')
    set cscopetagorder=0
    set cscopetag
    set cscopeverbose
    " 统一hook
    call Videm_RegisterSymdbInitHook('videm#plugin#gtags#InitDatabase', '')
    call Videm_RegisterSymdbUpdateHook('videm#plugin#gtags#UpdateDatabase', '')
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
function! videm#plugin#gtags#Init() "{{{2
    call s:InitSettings()
    call videm#settings#RegisterHook('videm#plugin#gtags#SettingsHook', 0, 0)
    if videm#settings#Get('.videm.symdb.gtags.Enable')
        return videm#plugin#gtags#Enable()
    endif
endfunction
"}}}
function! videm#plugin#gtags#InitDatabase(...) "{{{2
    call s:InitVLWGtagsDatabase(0)
endfunction
"}}}
function! videm#plugin#gtags#UpdateDatabase(...) "{{{2
    call s:UpdateVLWGtagsDatabase()
endfunction
"}}}
function! videm#plugin#gtags#Disable() "{{{2
    if !s:enable
        return
    endif
    py VidemWorkspace.wsp_ntf.Unregister(VidemWspGtagsHook, 0)
    " 命令
    delcommand VGtagsInitDatabase
    delcommand VGtagsUpdateDatabase
    " 自动命令
    augroup VidemSyndbGtags
        autocmd!
    augroup END
    augroup! VidemSyndbGtags
    " 删除统一hook
    call Videm_UnregisterSymdbInitHook('videm#plugin#gtags#InitDatabase')
    call Videm_UnregisterSymdbUpdateHook('videm#plugin#gtags#UpdateDatabase')
    " kill symdb
    py if ws.IsOpen(): vim.command("silent! cs kill GTAGS")
    " 尽量还原选项
    if exists('s:opts_bak')
        call vlutils#RestoreVimOptions(s:opts_bak)
        unlet s:opts_bak
    endif
    let s:enable = 0
endfunction
"}}}
function! videm#plugin#gtags#HasEnabled() "{{{2
    return s:enable
endfunction
"}}}
function! videm#plugin#gtags#Enable() "{{{2
    if s:enable
        return 0
    endif
    let ret = s:ThisInit()
    if ret
        return ret
    endif
    py if ws.IsOpen():
            \ vim.command("call videm#plugin#gtags#ConnectGtagsDatabase()")
    let s:enable = 1
endfunction
"}}}
function! s:InitPythonIterfaces() "{{{2
python << PYTHON_EOF
import subprocess
import vim

def VidemWspGtagsHook(event, wsp, unused):
    if event == 'open_post':
        vim.command("call videm#plugin#gtags#ConnectGtagsDatabase()")
    elif event == 'close_post':
        vim.command("silent! cs kill GTAGS")
    return Notifier.OK
PYTHON_EOF
endfunction
"}}}
" vim: fdm=marker fen et sw=4 sts=4 fdl=1
