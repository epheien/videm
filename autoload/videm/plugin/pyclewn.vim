" pyclewn plugin for videm
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   2013-05-19
" Change:   2013-12-22

let s:PyclewnSettings = {
    \ '.videm.dbg.pyclewn.Enable'               : 1,
    \ '.videm.dbg.pyclewn.SaveBpInfo'           : 1,
    \ '.videm.dbg.pyclewn.DisableNeedlessTools' : 1,
    \ '.videm.dbg.pyclewn.WatchVarKey'          : '<C-w>',
    \ '.videm.dbg.pyclewn.PrintVarKey'          : '<C-p>',
    \ '.videm.dbg.pyclewn.ConfName'             : 'VLWDbg.conf',
\ }

let s:CompatSettings = {
    \ 'g:VLWDbgSaveBreakpointsInfo' : '.videm.dbg.pyclewn.SaveBpInfo',
    \ 'g:VLWDisableUnneededTools'   : '.videm.dbg.pyclewn.DisableNeedlessTools',
    \ 'g:VLWDbgWatchVarKey'         : '.videm.dbg.pyclewn.WatchVarKey',
    \ 'g:VLWDbgPrintVarKey'         : '.videm.dbg.pyclewn.PrintVarKey',
    \ 'g:VLWorkspaceDbgConfName'    : '.videm.dbg.pyclewn.ConfName',
    \ 'g:VLWDbgFrameSignBackground' : '.videm.dbg.pyclewn.FrameSignBackground',
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
function! s:InitInverseCompatSettings() "{{{2
    for [oldopt, newopt] in items(s:CompatSettings)
        if videm#settings#Has(newopt)
            let {oldopt} = videm#settings#Get(newopt)
        endif
    endfor
endfunction
"}}}2
function! s:InitSettings() "{{{2
    call s:InitInverseCompatSettings()
    if videm#settings#Get('.videm.Compatible')
        call s:InitCompatSettings()
    endif
    call videm#settings#Init(s:PyclewnSettings)
endfunction
"}}}2
"{{{1
let s:dbgProjectName = ''
let s:dbgProjectDirName = ''
let s:dbgProjectConfName = ''
let s:dbgProjectFile = ''
let s:dbgSavedPos = {}
let g:dbgSavedPos = s:dbgSavedPos
let s:dbgSavedUpdatetime = &updatetime
let s:dbgFirstStart = 1
let s:dbgStandalone = 0 " 独立运行
function! s:Autocmd_DbgRestoreCursorPos() "{{{2
    call vlutils#SetPos('.', s:dbgSavedPos)
    au! AU_VLWDbgTemp CursorHold *
    augroup! AU_VLWDbgTemp
    let &updatetime = s:dbgSavedUpdatetime
endfunction
"}}}
" 调试器键位映射
function! s:DbgSetupKeyMappings() "{{{2
    exec 'xnoremap <silent>' videm#settings#Get('.videm.dbg.pyclewn.WatchVarKey')
            \ ':<C-u>exec "Cdbgvar" vlutils#GetVisualSelection()<CR>'
    exec 'xnoremap <silent>' videm#settings#Get('.videm.dbg.pyclewn.PrintVarKey')
            \ ':<C-u>exec "Cprint" vlutils#GetVisualSelection()<CR>'

    " 重新包裹，为了文件自动补全
    command! -bar -nargs=* -complete=file CCoreFile
            \ :C core-file <args>
    command! -bar -nargs=* -complete=file CAddSymbolFile
            \ :C add-symbol-file <args>
endfunction
"}}}
function! s:DbgHadStarted() "{{{2
    if has("netbeans_enabled")
        return 1
    else
        return 0
    endif
endfunction
"}}}
" 可选参数 a:1 若存在且非零，则表示为独立运行
function! s:DbgStart(...) "{{{2
    let s:dbgStandalone = get(a:000, 0, 0)
    " TODO pyclewn 首次运行, pyclewn 运行中, pyclewn 一次调试完毕后
    if !s:DbgHadStarted() && !s:dbgStandalone
        " 检查
        py if not ws.VLWIns.GetActiveProjectName(): vim.command(
                \ 'call vlutils#EchoWarnMsg("There is no active project!") | '
                \ 'return')

        " Windows 平台暂时有些问题没有解决
        if vlutils#IsWindowsOS()
            echohl WarningMsg
            echo 'Notes!!!'
            echo 'The debugger on Windows does not work correctly currently.' 
                        \'So...'
            echo '1. If the "(clewn)_console" buffer does not have any output,' 
                        \' please run ":Cpwd" manually to flush the buffer.'
            echo '2. If there are some problems when using debugger toolbar' 
                        \'icon, use commands instead. For example, ":Cstep".'
            echo '3. Sorry about this.'
            echo 'Press any key to continue...'
            echohl None
            call getchar()
        endif

        if videm#settings#Get('.videm.dbg.pyclewn.SaveBpInfo')
            let ConfName = videm#settings#Get('.videm.dbg.pyclewn.ConfName')
            py proj = ws.VLWIns.FindProjectByName(
                        \ws.VLWIns.GetActiveProjectName())
            py if proj: vim.command("let s:dbgProjectFile = %s" % ToVimEval(
                        \os.path.join(
                        \   proj.dirName, ws.VLWIns.GetActiveProjectName() 
                        \       + '_' + vim.eval("ConfName"))))
            " 设置保存的断点
            py vim.command("let s:dbgProjectName = %s" % ToVimEval(proj.name))
            py vim.command("let s:dbgProjectDirName = %s" % 
                        \   ToVimEval(proj.dirName))
            py vim.command("let s:dbgProjectConfName = %s" % ToVimEval(
                        \           ws.GetProjectCurrentConfigName(proj.name)))
            py del proj
            " 用临时文件
            let s:dbgProjectFile = tempname()
            py Touch(vim.eval('s:dbgProjectFile'))
            call s:DbgLoadBreakpointsToFile(s:dbgProjectFile)
            " 需要用 g:VLWDbgProjectFile 这种方式，否则会有同步问题
            let g:VLWDbgProjectFile = s:dbgProjectFile
        endif

        let bNeedRestorePos = 1
        " 又要特殊处理了...
        if bufname('%') ==# '' && !&modified
            " 初始未修改的未命名缓冲区的话，就不需要恢复位置了
            let bNeedRestorePos = 0
        endif
        let s:dbgSavedPos = vlutils#GetPos('.')
        let g:dbgSavedPos = s:dbgSavedPos
        silent VPyclewn
        " BUG:? 运行 ws.DebugActiveProject() 前必须运行一条命令,
        " 否则出现灵异事件. 这条命令会最后才运行
        Cpwd

        py ws.DebugActiveProject(False)
        " 再 source
        if g:VLWDbgSaveBreakpointsInfo
            exec 'Csource' fnameescape(s:dbgProjectFile)
            " TODO 应该等待 pyclewn 通知
            if bNeedRestorePos
                " 这个办法是没办法的办法...
                let s:dbgSavedUpdatetime = &updatetime
                set updatetime=1000
                augroup AU_VLWDbgTemp
                    autocmd!
                    autocmd! CursorHold * call <SID>Autocmd_DbgRestoreCursorPos()
                    autocmd! VimLeave   * call <SID>Autocmd_Quit()
                augroup END
            endif
        endif

        call s:DbgSetupKeyMappings()

        if s:dbgFirstStart
            call s:DbgPythonInterfacesInit()
            let s:dbgFirstStart = 0
        endif
        call s:DbgRefreshToolBar()
    elseif !s:DbgHadStarted() && s:dbgStandalone
        " 独立运行
        VPyclewn
        call s:DbgSetupKeyMappings()
    else
        let sLastDbgOutput = getbufline(bufnr('(clewn)_console'), '$')[0]
        if sLastDbgOutput !=# '(gdb) '
            " 正在运行, 中断之, 重新运行
            Csigint
        endif
        " 为避免修改了程序参数, 需要重新设置程序参数
        py ws.DebugActiveProject(False, False)
    endif
endfunction
"}}}
function! s:DbgToggleBreakpoint(...) "{{{2
    let bHardwareBp = a:0 > 0 ? a:1 : 0
    if !s:DbgHadStarted()
        call vlutils#EchoWarnMsg('Please start the debugger firstly.')
        return
    endif
    let nCurLine = line('.')
    let sCurFile = vlutils#PosixPath(expand('%:p'))
    if empty(sCurFile)
        return
    endif

    let nSigintFlag = 0
    let nIsDelBp = 0

    let sCursorSignName = ''
    for sLine in split(vlutils#GetCmdOutput('sign list'), "\n")
        if sLine =~# '^sign '
            if matchstr(sLine, '\Ctext==>') !=# ''
                let sCursorSignName = matchstr(sLine, '\C^sign \zs\w\+\>')
                break
            elseif matchstr(sLine, '\Ctext=') ==# ''
                " 没有文本
                let sCursorSignName = matchstr(sLine, '\C^sign \zs\w\+\>')
                break
            endif
        endif
    endfor

    let sLastDbgOutput = getbufline(bufnr('(clewn)_console'), '$')[0]
    if sLastDbgOutput !=# '(gdb) '
        " 正在运行时添加断点, 必须先中断然后添加
        Csigint
        let nSigintFlag = 1
    endif

    for sLine in split(vlutils#GetCmdOutput('sign place buffer=' . bufnr('%')),
            \                               "\n")
        if sLine =~# '^\s\+line='
            let nSignLine = str2nr(matchstr(sLine, '\Cline=\zs\d\+'))
            let sSignName = matchstr(sLine, '\Cname=\zs\w\+\>')
            if nSignLine == nCurLine && sSignName !=# sCursorSignName
                " 获取断点的编号, 按编号删除
                "let nID = str2nr(matchstr(sLine, '\Cid=\zs\d\+'))
                " 获取断点的名字, 按名字删除
                let sName = matchstr(sLine, '\Cid=\zs\w\+')
                for sLine2 in split(vlutils#GetCmdOutput('sign list'), "\n")
                    "if matchstr(sLine2, '\C^sign ' . nID) !=# ''
                    if matchstr(sLine2, '\C^sign ' . sName) !=# ''
                        let sBpID = matchstr(sLine2, '\Ctext=\zs\d\+')
                        exec 'Cdelete ' . sBpID
                        break
                    endif
                endfor

                "exec "Cclear " . sCurFile . ":" . nSignLine
                let nIsDelBp = 1
                break
            endif
        endif
    endfor

    if !nIsDelBp
        if bHardwareBp
            exec "Chbreak " . sCurFile . ":" . nCurLine
        else
            exec "Cbreak " . sCurFile . ":" . nCurLine
        endif
    endif

    if nSigintFlag
        Ccontinue
    endif
endfunction
"}}}
function! s:DbgStop() "{{{2
    if s:dbgStandalone
        Cstop
        nbclose
        return
    endif
python << PYTHON_EOF
def DbgSaveBreakpoints(data):
    ins = VLProjectSettings()
    ins.SetBreakpoints(data['s:dbgProjectConfName'],
                       DumpBreakpointsFromFile(data['s:dbgProjectFile'],
                                               data['s:dbgProjectDirName']))
    if ins.Save(data['sSettingsFile']):
        return 0
    return -1
def SaveDbgBpsFunc(data, baseTime = int(time.time())):
    # TODO 应该等待信号来通知，而不是轮询检查
    ret = -1
    dbgProjectFile = data['s:dbgProjectFile']
    if not dbgProjectFile:
        return
    for i in xrange(10): # 顶多试十次
        modiTime = GetMTime(dbgProjectFile)
        # 同步等待调试器保存project文件成功
        if modiTime >= baseTime:
            # 开工
            ret = DbgSaveBreakpoints(data)
            try:
                # 删除文件
                os.remove(dbgProjectFile)
            except:
                pass
            break
        time.sleep(0.5)
    return ret
PYTHON_EOF
    if s:DbgHadStarted()
        silent Cstop
        " 保存断点信息
        if videm#settings#Get('.videm.dbg.pyclewn.SaveBpInfo')
            " FIXME 秒的精度是否足够？
            let nBaseTime = localtime()
            exec 'Cproject' fnameescape(s:dbgProjectFile)
            " 要用异步的方式保存...
            "py Misc.RunSimpleThread(SaveDbgBpsFunc, 
                        "\              vim.eval('s:GenSaveDbgBpsFuncData()'))
            " 还是用同步的方式保存比较靠谱，懒得处理同步问题
            echo 'Saving debugger info to file ...'
            py if SaveDbgBpsFunc(vim.eval('s:GenSaveDbgBpsFuncData()'),
                    \            int(vim.eval('nBaseTime'))) != 0:
                    \ vim.command('call vlutils#EchoWarnMsg('
                    \             '"Save breakpoints failed!")')
        endif
        silent nbclose
        let g:VLWDbgProjectFile = ''
        call s:DbgRefreshToolBar()
    endif
endfunction
"}}}2
function! s:GenSaveDbgBpsFuncData() "{{{2
    let d = {}
    py vim.command("let sSettingsFile = %s" % ToVimEval(
                \   os.path.join(vim.eval('s:dbgProjectDirName'), 
                \      vim.eval('s:dbgProjectName') + '.projsettings')))
    let d['sSettingsFile'] = sSettingsFile
    let d['s:dbgProjectFile'] = s:dbgProjectFile
    let d['s:dbgProjectDirName'] = s:dbgProjectDirName
    let d['s:dbgProjectConfName'] = s:dbgProjectConfName
    return d
endfunction
"}}}2
function! s:DbgStepIn() "{{{2
    if !s:DbgHadStarted()
        echoerr 'Please start the debugger firstly.'
        return
    endif
    silent Cstep
endfunction

function! s:DbgNext() "{{{2
    if !s:DbgHadStarted()
        echoerr 'Please start the debugger firstly.'
        return
    endif
    silent Cnext
endfunction

function! s:DbgStepOut() "{{{2
    if !s:DbgHadStarted()
        echoerr 'Please start the debugger firstly.'
        return
    endif
    silent Cfinish
endfunction

function! s:DbgContinue() "{{{2
    if !s:DbgHadStarted()
        echoerr 'Please start the debugger firstly.'
        return
    endif
    silent Ccontinue
endfunction

function! s:DbgRunToCursor() "{{{2
    if !s:DbgHadStarted()
        echoerr 'Please start the debugger firstly.'
        return
    endif
    let nCurLine = line('.')
    let sCurFile = vlutils#PosixPath(expand('%:p'))

    let sLastDbgOutput = getbufline(bufnr('(clewn)_console'), '$')[0]
    if sLastDbgOutput !=# '(gdb) '
        " 正在运行时添加断点, 必须先中断然后添加
        Csigint
    endif

    exec "Cuntil " . sCurFile . ":" . nCurLine
endfunction
"}}}
function! s:DbgBacktrace() "{{{2
    " FIXME: 这个命令不会阻塞, 很可能得不到结果
    "silent! Cbt
    let nBufNr = bufnr('(clewn)_console')
    let nWinNr = bufwinnr(nBufNr)
    if nWinNr == -1
        return
    endif

    " 获取文本
    exec 'noautocmd ' . nWinNr . 'wincmd w'
    let lOrigCursor = getpos('.')
    call cursor(line('$'), 1)
    let sLine = getline('.')
    if sLine !~# '^(gdb)'
        call setpos('.', lOrigCursor)
        noautocmd wincmd p
        return
    endif

    let nEndLineNr = line('$')
    let nStartLineNr = search('^(gdb) bt$', 'bn')
    if nStartLineNr == 0
        call setpos('.', lOrigCursor)
        noautocmd wincmd p
        return
    endif

    call setpos('.', lOrigCursor)
    noautocmd wincmd p

    " 使用错误列表
    let bak_efm = &errorformat
    set errorformat=%m\ at\ %f:%l
    exec printf("%d,%d cgetbuffer %d", nStartLineNr + 1, nEndLineNr - 1, nBufNr)
    let &errorformat = bak_efm
endfunction
"}}}2
function! s:DbgSaveBreakpoints(sPyclewnProjFile) "{{{2
    let sPyclewnProjFile = a:sPyclewnProjFile
    if sPyclewnProjFile !=# ''
        py vim.command("let sSettingsFile = %s" % ToVimEval(
                    \   os.path.join(vim.eval('s:dbgProjectDirName'), 
                    \      vim.eval('s:dbgProjectName') + '.projsettings')))
        "echomsg sSettingsFile
        py l_ins = VLProjectSettings()
        py l_ins.Load(vim.eval('sSettingsFile'))
        py l_ins.SetBreakpoints(vim.eval('s:dbgProjectConfName'), 
                    \   DumpBreakpointsFromFile(
                    \                   vim.eval('sPyclewnProjFile'), 
                    \                   vim.eval('s:dbgProjectDirName')))
        py l_ins.Save(vim.eval('sSettingsFile'))
        py del l_ins
    endif
endfunction
"}}}2
function! s:DbgLoadBreakpointsToFile(sPyclewnProjFile) "{{{2
python << PYTHON_EOF
def DbgLoadBreakpointsToFile(pyclewnProjFile):
    settingsFile = os.path.join(vim.eval('s:dbgProjectDirName'),
                                vim.eval('s:dbgProjectName') + '.projsettings')
    #print settingsFile
    if not settingsFile:
        return -1
    ds = DirSaver()
    os.chdir(vim.eval('s:dbgProjectDirName'))
    ins = VLProjectSettings()
    if not ins.Load(settingsFile):
        return -1

    try:
        f = open(pyclewnProjFile, 'wb')
        for d in ins.GetBreakpoints(vim.eval('s:dbgProjectConfName')):
            f.write('break %s:%d\n' % (os.path.abspath(d['file']),
                                       int(d['line'])))
    except IOError:
        return -1
    f.close()

    return 0
PYTHON_EOF
    let sPyclewnProjFile = a:sPyclewnProjFile
    if sPyclewnProjFile ==# ''
        return
    endif
    py if DbgLoadBreakpointsToFile(vim.eval('sPyclewnProjFile')) != 0:
            \ vim.command(
            \  'call vlutils#EchoWarnMsg("Load breakpoints from file failed!")')
endfunction
"}}}2
function! s:DbgEnableToolBar() "{{{2
    anoremenu enable ToolBar.DbgStop
    anoremenu enable ToolBar.DbgStepIn
    anoremenu enable ToolBar.DbgNext
    anoremenu enable ToolBar.DbgStepOut
    anoremenu enable ToolBar.DbgRunToCursor
    anoremenu enable ToolBar.DbgContinue
endfunction
"}}}
function! s:DbgDisableToolBar() "{{{2
    if !videm#settings#Get('.videm.dbg.pyclewn.DisableNeedlessTools')
        return
    endif
    anoremenu disable ToolBar.DbgStop
    anoremenu disable ToolBar.DbgStepIn
    anoremenu disable ToolBar.DbgNext
    anoremenu disable ToolBar.DbgStepOut
    anoremenu disable ToolBar.DbgRunToCursor
    anoremenu disable ToolBar.DbgContinue
endfunction
"}}}
function! s:DbgRefreshToolBar() "{{{2
    if s:DbgHadStarted()
        call s:DbgEnableToolBar()
    else
        call s:DbgDisableToolBar()
    endif
endfunction
"}}}
" 调试器用的 python 例程
function! s:DbgPythonInterfacesInit() "{{{2
python << PYTHON_EOF
def DumpBreakpointsFromFile(pyclewnProjFile, relStartPath = '.'):
    debug = False
    fn = pyclewnProjFile
    bps = [] # 项目为 {<文件相对路径>, <行号>}
    f = open(fn, 'rb')
    for line in f:
        if line.startswith('break '):
            if debug: print 'line:', line
            if debug: print line.lstrip('break ').rsplit(':', 1)
            li = line.lstrip('break ').rsplit(':', 1)
            if len(li) != 2:
                continue
            fileName = li[0]
            fileLine = li[1]
            fileName = os.path.relpath(fileName, relStartPath)
            fileLine = int(fileLine.strip())
            if debug: print fileName, fileLine
            bps.append({'file': fileName, 'line': fileLine})
    return bps

PYTHON_EOF
endfunction
"}}}2
"}}}1
function! s:Autocmd_Quit() "{{{2
    call s:DbgStop()
endfunction
"}}}
function! s:InstallCommands() "{{{2
    command! -nargs=? -bar VDbgStart            call <SID>DbgStart(<f-args>)
    command! -nargs=0 -bar VDbgStop             call <SID>DbgStop()
    command! -nargs=0 -bar VDbgStepIn           call <SID>DbgStepIn()
    command! -nargs=0 -bar VDbgNext             call <SID>DbgNext()
    command! -nargs=0 -bar VDbgStepOut          call <SID>DbgStepOut()
    command! -nargs=0 -bar VDbgRunToCursor      call <SID>DbgRunToCursor()
    command! -nargs=0 -bar VDbgContinue         call <SID>DbgContinue()
    command! -nargs=? -bar VDbgToggleBp       
            \                           call <SID>DbgToggleBreakpoint(<f-args>)
    command! -nargs=0 -bar VDbgBacktrace        call <SID>DbgBacktrace()
    command! -nargs=0 -bar VDbgSetupKeyMap      call <SID>DbgSetupKeyMappings()
endfunction
"}}}2
" 调试工具栏
function! s:InstallToolBarMenu() "{{{2
    let rtp_bak = &runtimepath
    let &runtimepath = vlutils#PosixPath(g:VidemDir) . ',' . &runtimepath

    anoremenu 1.600 ToolBar.-Sep16- <Nop>
    anoremenu <silent> icon=breakpoint 1.605 
                \ToolBar.DbgToggleBreakpoint 
                \:call <SID>DbgToggleBreakpoint()<CR>

    anoremenu 1.609 ToolBar.-Sep17- <Nop>
    anoremenu <silent> icon=start 1.610 
                \ToolBar.DbgStart 
                \:call <SID>DbgStart()<CR>
    anoremenu <silent> icon=stepin 1.630 
                \ToolBar.DbgStepIn 
                \:call <SID>DbgStepIn()<CR>
    anoremenu <silent> icon=next 1.640 
                \ToolBar.DbgNext 
                \:call <SID>DbgNext()<CR>
    anoremenu <silent> icon=stepout 1.650 
                \ToolBar.DbgStepOut 
                \:call <SID>DbgStepOut()<CR>
    anoremenu <silent> icon=continue 1.660 
                \ToolBar.DbgContinue 
                \:call <SID>DbgContinue()<CR>
    anoremenu <silent> icon=runtocursor 1.665 
                \ToolBar.DbgRunToCursor 
                \:call <SID>DbgRunToCursor()<CR>
    anoremenu <silent> icon=stop 1.670 
                \ToolBar.DbgStop 
                \:call <SID>DbgStop()<CR>

    tmenu ToolBar.BuildActiveProject    Build Active Project
    tmenu ToolBar.CleanActiveProject    Clean Active Project
    tmenu ToolBar.RunActiveProject      Run Active Project

    tmenu ToolBar.DbgStart              Start / Run Debugger
    tmenu ToolBar.DbgStop               Stop Debugger
    tmenu ToolBar.DbgStepIn             Step In
    tmenu ToolBar.DbgNext               Next
    tmenu ToolBar.DbgStepOut            Step Out
    tmenu ToolBar.DbgRunToCursor        Run to cursor
    tmenu ToolBar.DbgContinue           Continue

    tmenu ToolBar.DbgToggleBreakpoint   Toggle Breakpoint

    call s:DbgRefreshToolBar()

    let &runtimepath = rtp_bak
endfunction
"}}}2
function! s:ThisInit() "{{{2
    call s:InitPythonIterfaces()
    if videm#settings#Get('.videm.wsp.EnableToolBar')
        " 添加工具栏菜单
        call s:InstallToolBarMenu()
    endif
    call s:InstallCommands()
endfunction
"}}}2
function! videm#plugin#pyclewn#HasEnabled() "{{{2
    return 1
endfunction
"}}}
function! videm#plugin#pyclewn#Init() "{{{2
    call s:InitSettings()
    if !videm#settings#Get('.videm.dbg.pyclewn.Enable', 0)
        return
    endif
    call s:ThisInit()
endfunction
"}}}
function! s:InitPythonIterfaces() "{{{2
python << PYTHON_EOF
PYTHON_EOF
endfunction
"}}}
" vim: fdm=marker fen et sw=4 sts=4 fdl=1
