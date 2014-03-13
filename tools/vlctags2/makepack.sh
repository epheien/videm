#!/bin/bash

VERSION=`grep -P '^\s*#\s*define PROGRAM_VERSION' ctags.h | awk '{print $NF}' | awk -F '"' '{print $2}'`

DSTDIR="`pwd`/videm-tools-$VERSION"

rm -rf "$DSTDIR"
mkdir -pv "$DSTDIR"

cp -v *.c *.cpp *.h *.txt *.vlproject *.vlworkspace *.wspsettings "$DSTDIR"
mkdir -pv "$DSTDIR/gnu_regex"
cp -v gnu_regex/* "$DSTDIR/gnu_regex"

cd ftcb
./makepack.sh > /dev/null && mv -v ftcb "$DSTDIR"
cd - > /dev/null

cd IntExpr
./makepack.sh > /dev/null && mv -v IntExpr "$DSTDIR"
cd - > /dev/null

cd CxxParser
./makepack.sh > /dev/null && mv -v CxxParser "$DSTDIR"
cd - > /dev/null

rm "$DSTDIR/vlctags2.vlworkspace" "$DSTDIR/vlctags2.wspsettings"
cd `dirname "$DSTDIR"`
tar cfj "videm-tools-$VERSION.tar.bz2" `basename "$DSTDIR"`
cd - > /dev/null

echo "========================================"
echo "videm-tools-$VERSION.tar.bz2"

