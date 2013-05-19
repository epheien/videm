#!/usr/bin/env python
# -*- coding:utf-8 -*-

li1 = [
    's:ID_PSCtl_ProjectType',
    's:ID_PSCtl_Compiler',
    's:ID_PSCtl_OutDir',
    's:ID_PSCtl_OutputFile',
    's:ID_PSCtl_Program',
    's:ID_PSCtl_ProgramWD',
    's:ID_PSCtl_ProgramArgs',
    's:ID_PSCtl_UseSepDbgArgs',
    's:ID_PSCtl_DebugArgs',
    's:ID_PSCtl_IgnoreFiles',

    's:ID_PSCtl_Cmpl_UseWithGlb',
    's:ID_PSCtl_Cmpl_COpts',
    's:ID_PSCtl_Cmpl_CxxOpts',
    's:ID_PSCtl_Cmpl_IncPaths',
    's:ID_PSCtl_Cmpl_Prep',
    's:ID_PSCtl_Cmpl_PCH',
    's:ID_PSCtl_Link_UseWithGlb',
    's:ID_PSCtl_Link_Opts',
    's:ID_PSCtl_Link_LibPaths',
    's:ID_PSCtl_Link_Libs',

    's:ID_PSCtl_PreBuild',
    's:ID_PSCtl_PostBuild',

    's:ID_PSCtl_CstBld_Enable',
    's:ID_PSCtl_CstBld_WorkDir',
    's:ID_PSCtl_CstBld_Targets',

    #'s:ID_PSCtl_Glb_Cmpl_COpts',
    #'s:ID_PSCtl_Glb_Cmpl_CxxOpts',
    #'s:ID_PSCtl_Glb_Cmpl_IncPaths',
    #'s:ID_PSCtl_Glb_Cmpl_Prep',
    #'s:ID_PSCtl_Glb_Link_Opts',
    #'s:ID_PSCtl_Glb_Link_LibPaths',
    #'s:ID_PSCtl_Glb_Link_Libs',
]

li2 = [
    'type',
    'cmplName',
    'outDir',
    'output',
    'program',
    'progWD',
    'progArgs',
    'useSepDbgArgs',
    'dbgArgs',
    'ignFiles',

    'cmplOptsFlag',
    'cCmplOpts',
    'cxxCmplOpts',
    'incPaths',
    'preprocs',
    'PCH',
    'linkOptsFlag',
    'linkOpts',
    'libPaths',
    'libs',

    'preBldCmds',
    'postBldCmds',

    'enableCstBld',
    'cstBldWD',
    'othCstTgts',
    #'cstBldCmd',
    #'cstClnCmd',
]

li3 = [
    's:ID_PSCtl_Glb_Cmpl_COpts',
    's:ID_PSCtl_Glb_Cmpl_CxxOpts',
    's:ID_PSCtl_Glb_Cmpl_IncPaths',
    's:ID_PSCtl_Glb_Cmpl_Prep',
    's:ID_PSCtl_Glb_Link_Opts',
    's:ID_PSCtl_Glb_Link_LibPaths',
    's:ID_PSCtl_Glb_Link_Libs',
]

li4 = [
    'cCmplOpts',
    'cxxCmplOpts',
    'incPaths',
    'preprocs',
    'linkOpts',
    'libPaths',
    'libs',
]

s1 = '''\
        elseif ctlId == %s
            if bIsSave
                let confDict['%s'] = ctl.GetValue()
            else
                call ctl.SetValue(confDict['%s'])
            endif'''

assert len(li1) == len(li2)
assert len(li3) == len(li4)

#for idx, elm in enumerate(li1):
    #print s1 % (elm, li2[idx], li2[idx])



for idx, elm in enumerate(li3):
    print '''\
        elseif ctlId == %s
            if bIsSave
                let glbCnfDict['%s'] = ctl.GetValue()
            else
                call ctl.SetValue(glbCnfDict['%s'])
            endif''' % (elm, li4[idx], li4[idx])
