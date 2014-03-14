Vim's IDE Mode
==============
                       _   _______ ____  _______   _
                      | | / /_  _// __ \/ ____/ | / |
                      | |/ / / / / / / / __/ /  |/  |
                      | / /_/ /_/ /_/ / /___/ /|  | |
                      |__/_____/_____/_____/_/ |_/|_|

common  -> videm共享的常量，例程
lib     -> 相对独立的公共例程，不依赖videm的任何概念
others  -> 其他的一些资料，一般来说不是必要的
plugin  -> videm的插件
tools   -> videm需要用到的一些工具，如解析器等等
vim     -> videm的vim例程
wsp     -> videm的核心——工作区

Dependencies for vim
====================
    * +python 
    * +netbeans_intg (required by debugger) 

Dependencies for software
=========================
    * python
    * python-lxml   (optional)
    * make
    * cscope
    * global        (gnu global)
    * gcc
    * gdb
    * libclang      (version 3.0 or later, required by VIMCCC)
    * pywin32       (required by pyclewn on Windows)

Installation on Linux
=====================
    1. Run "./pkg.sh -t" to make some installer packages
    2. Extract the videm-<version>.tar.bz2 package and copy files to correct directories
       If you use pathogen plugin of vim, just copy videm folder to ~/.vim/bundle
    3. Extract the videm-tools-<version>.zip package
       Enter the videm-tools-<version> folder and run "make && make install"
       You can read the README for more information

Installation on Windows
=======================
    1. Run "./pkg.sh -w" to make some installer packages (on Linux environment)
    2. Extract the videm-<version>-win32.zip package and copy files to correct directories
    3. Add X:\YOURPATH\videm\_videm\bin to system %PATH% environment variable
    4. Install MingGW for compiling and debugging your program
