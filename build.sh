#!/bin/bash

SCRIPT_DIR=$(dirname `readlink -f $0`)
TGT_DIR="$SCRIPT_DIR/videm_files"
VERSION=`grep '^VIDEM_VER' "$SCRIPT_DIR/common/Macros.py" | awk '{print $3}'`

output="$SCRIPT_DIR/videm-$VERSION.tar.xz"

rm -rf "$TGT_DIR"
make --no-print-directory install

cd "$SCRIPT_DIR/videm_files/videm"
makevba && mv videm.v* ..
cd - >/dev/null

cd "$TGT_DIR" && tar -cJf "$output" *
cd - >/dev/null
echo "$output" is ready
