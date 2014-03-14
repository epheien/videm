#!/bin/bash

# 几个有用的变量
__file__=$(readlink -f "$0")
__name__=$(basename "$__file__")
__dir__=$(dirname "$__file__")

function usage()
{
    local cmd=$(basename "$0")
    cat << EOF
NAME:
    $cmd - package generator for Videm

USAGE:
    $cmd [options] [arguments]

OPTIONS:
    -h          this help information
    -w          make a package for Windows 32bit
    -t          also make a package of videm-tools
EOF
}

##
## 主流程
##

## 参数解析
# 1 - 表示用于win32的安装包
opt_win32=0
# 1 - 表示也打包videm-tools
opt_tools=0
while getopts "wti:h" opt; do
    case "$opt" in
    "i")
        opt_optarg="$OPTARG"
        ;;
    "w")
        opt_win32=1
        ;;
    "t")
        opt_tools=1
        ;;
    "h")
        usage "$0"
        exit 0
        ;;
    "?")
        # optstring的第一个字符不为':'时，遇到非法选项时的处理
        usage "$0"
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1))

## 流程开始
SCRIPT_DIR="$__dir__"
cd "$SCRIPT_DIR"

VERSION=`grep '^VIDEM_VER' "$SCRIPT_DIR/wsp/Macros.py" | awk '{print $3}'`
TIMESTAMP=$(date +%Y%m%d)

rm -rf "videm"
make --no-print-directory install

if ((opt_win32)); then
# 用于win32的安装包
    output="$SCRIPT_DIR/videm-$VERSION-build${TIMESTAMP}-win32.zip"

    # 复制videm-tools的预编译文件
    cd videm
    7z x ../tools/videm-tools/win32build/_videm.7z >/dev/null || exit $?
    cd - >/dev/null

    # 复制win32bin
    cp -r tools/win32bin/* videm/_videm/bin || exit $?
    rm -f videm/_videm/bin/README

    # 打包
    rm -f "$output"
    7z a -tzip "$output" "videm" >/dev/null
else
# 普通的安装包
    output="$SCRIPT_DIR/videm-$VERSION-build${TIMESTAMP}.tar.bz2"
    tar -cjf "$output" "videm"
fi

echo "$output" is ready

# 打包videm-tools
if ((opt_tools)); then
    videm_tools_output="$SCRIPT_DIR/videm-tools-$VERSION-build${TIMESTAMP}.zip"
    rm -f "$videm_tools_output"

    cd tools/videm-tools
    git archive --prefix=videm-tools-$VERSION/ -o "$videm_tools_output" master . || exit $?
    7z d "$videm_tools_output" videm-tools-$VERSION/win32build >/dev/null
    cd - >/dev/null

    echo "$videm_tools_output" is ready
fi

# vi:set et sts=4 sw=4 ts=8:
