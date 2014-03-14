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

Installation
============
    1. Run ./pkg.sh to make a installer package
    2. Extract the installer package and copy files to correct directories
       If you use pathogen plugin of vim, just copy videm folder to ~/.vim/bundle
    3. Install tools/videm-tools
    4. Install tools/win32bin if you use Windows
