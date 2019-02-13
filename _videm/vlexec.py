#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import subprocess

def main():
    ret = None
    if len(sys.argv) <= 1:
        ret = 0
    else:
        ret = subprocess.call(sys.argv[1:])
    input('Press ENTER to continue...\n')
    return ret

if __name__ == '__main__':
    sys.exit(main())
