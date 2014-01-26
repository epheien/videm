#!/usr/bin/env python
# -*- encoding:utf-8 -*-
'''一些全局宏'''

import os

##-----------------------------------------------------
## Constants
##-----------------------------------------------------

# 版本号 1001 -> 1.001
VIDEM_VER = 1100

# videm 起始目录
VIDEM_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 后向兼容
VIMLITE_VER = VIDEM_VER
VIMLITE_DIR = VIDEM_DIR

WORKSPACE_FILE_SUFFIX   = 'vlworkspace'
PROJECT_FILE_SUFFIX     = 'vlproject'

# nodepath和wsppath的路径分隔符
WSP_PATH_SEP = '/'

# 全局源文件判断控制
# 扩展名约定是包括 '.' 的，例如 .c; .cpp
C_SOURCE_EXT    = set(['.c'])
CPP_SOURCE_EXT  = set(['.cpp', '.cxx', '.c++', '.cc'])
# 头文件扩展名暂不支持修改
CPP_HEADER_EXT  = set(['.h', '.hpp', '.hxx', '.hh', '.inl', '.inc'])

DEFAULT_C_SOURCE_EXT    = set(['.c'])
DEFAULT_CPP_SOURCE_EXT  = set(['.cpp', '.cxx', '.c++', '.cc'])

clCMD_NEW   = "<New...>"
clCMD_EDIT  = "<Edit...>"
# clCMD_DELETE = "<Delete...>"  #Unused

# constant message
BUILD_START_MSG             = "----------Build Started--------\n"
BUILD_END_MSG               = "----------Build Ended----------\n"
BUILD_PROJECT_PREFIX        = "----------Building project:[ "
CLEAN_PROJECT_PREFIX        = "----------Cleaning project:[ "
SEARCH_IN_WORKSPACE         = "Entire Workspace"
SEARCH_IN_PROJECT           = "Active Project"
SEARCH_IN_CURR_FILE_PROJECT = "Current File's Project"
SEARCH_IN_CURRENT_FILE      = "Current File"

USE_WORKSPACE_ENV_VAR_SET   = "<Use Defaults>"
USE_GLOBAL_SETTINGS         = "<Use Defaults>"

# TODO
TERMINAL_CMD = ""

PATH_SEP = os.sep


def IsSourceFile(ext):
    return ext == 'cpp' or ext == 'cxx' or ext == 'c' or ext == 'c++' or ext == 'cc'


def BoolToString(bool):
    if bool:
        return 'yes'
    else:
        return 'no'

