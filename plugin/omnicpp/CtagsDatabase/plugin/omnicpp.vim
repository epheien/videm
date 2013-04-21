" Vim Script
" Author:   fanhe <fanhed@163.com>
" License:  GPLv2
" Create:   1970-01-01
" Change:   1970-01-01

function videm#plugin#omnicpp#Init()
    py if not UseOmniCpp(): vim.command('return')
    call s:InitPythonIterfaces()
    py VidemWorkspace.RegDelNodePostHook(DelNodePostHook, 0, None)
    py VidemWorkspace.RegRnmNodePostHook(RnmNodePostHook, 0, None)
endfunction

function s:InitPythonIterfaces()
python << PYTHON_EOF
def DelNodePostHook(ins, nodepath, nodetype, files, data):
    ins.tagsManager.DeleteTagsByFiles(files, True)
    ins.tagsManager.DeleteFileEntries(files, True)

def RnmNodePostHook(ins, nodepath, nodetype, oldfile, newfile, data):
    ins.tagsManager.DeleteFileEntry(oldfile, True)
    ins.tagsManager.InsertFileEntry(newfile)
    ins.tagsManager.UpdateTagsFileColumnByFile(newfile, oldfile)
PYTHON_EOF
endfunction

" vim: fdm=marker fen et sw=4 sts=4 fdl=1
