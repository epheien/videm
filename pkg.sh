#!/bin/bash

SCRIPT_DIR=$(dirname `readlink -f $0`)
cd "$SCRIPT_DIR"

VERSION=`grep '^VIDEM_VER' "$SCRIPT_DIR/wsp/Macros.py" | awk '{print $3}'`
output="$SCRIPT_DIR/videm-$VERSION-build$(date +%Y%m%d).tar.bz2"

rm -rf "videm"
make --no-print-directory install

tar -cjf "$output" "videm"
echo "$output" is ready
