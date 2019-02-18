# Vim's IDE Mode
                       _   _______ ____  _______   _
                      | | / /_  _// __ \/ ____/ | / |
                      | |/ / / / / / / / __/ /  |/  |
                      | / /_/ /_/ /_/ / /___/ /|  | |
                      |__/_____/_____/_____/_/ |_/|_|

Videm is an intuitive C/C++ project manager which can works like IDE.

Videm only provides project manager and some APIs, other features such like debug,
code completion, symbol searching does not provided by videm, these will be
provided by other plugins, such as terminal-debug (`:h terminal-debug`),
[YouCompleteMe](https://github.com/Valloric/YouCompleteMe) or
[deoplete](https://github.com/Shougo/deoplete.nvim), etc.

## Dependencies for vim
  - vim 8.1 or later
  - +python3
  - +terminal

## Dependencies for software
  - python3
  - make
  - gcc
  - gdb
  - python-lxml   (optional)

## Install

For vim-plug

```viml
Plug 'epheien/videm'
```

For manual installation

- Extract the files and put them in your .vim directory  
  (usually `~/.vim`).

## Usage

Run `:VidemOpen` to start, and press `.` to show operation menus.

Run `:h videm.txt` for more information.

## Screenshots

![Build](https://ws2.sinaimg.cn/large/006tKfTcgy1g0aiabz8lqj313z0u0nfo.jpg)
![Debug](https://ws1.sinaimg.cn/large/006tKfTcgy1g0aiaeacrnj313z0u0qnk.jpg)
