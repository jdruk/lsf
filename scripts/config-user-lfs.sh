#!/bin/bash

# Config bash
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

# CPU CORES -- FIX ME
CORES=`sudo cat /proc/cpuinfo | awk 'match($1, /cpuid/, b){c++} END {print c}'`

cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
export MAKEFLAGS="-j 4"
EOF

source ~/.bash_profile

echo $MAKEFLAGS

exit

