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
    $cmd - Command

USAGE:
    $cmd [options] [arguments]

OPTIONS:
    -h          this help information
EOF
}

##
## 主流程
##

## 参数解析
opt_optarg=""
while getopts "i:h" opt; do
    case "$opt" in
    "i")
        opt_optarg="$OPTARG"
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
cd "$__dir__"

cmd="./omnicxx.py ./videm.vltags test.cxx 6 16 ''"
echo "$cmd"
eval "$cmd"

cmd="./omnicxx.py ./videm.vltags test.cxx 6 10 ''"
echo "$cmd"
eval "$cmd"

# vi:set et sts=4 sw=4 ts=8:
