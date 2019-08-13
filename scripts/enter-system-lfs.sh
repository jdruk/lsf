#!/bin/bash
LFS=/mnt/lfs
sudo mount -v -t ext4 /dev/sda3 $LFS

# mount dev's
sudo ./mount-lfs.sh

sudo chroot "$LFS" /tools/bin/env -i \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
    /tools/bin/bash --login +h


