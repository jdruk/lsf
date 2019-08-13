#!/bin/bash

mkdir -pv $LFS/{dev, proc, sys, run}
mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3
