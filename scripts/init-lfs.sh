#!/bin/bash

PARTITION=/dev/sda3
LFS=/mnt/lfs

export LFS

if [ ! -d $LFS ]; then
	sudo mkdir -pv $LFS 
fi 

sudo mount -v -t ext4 $PARTITION $LFS

mkdir -v $LFS/tools
ln -sv $LFS/tools /
# unpack lfs-8.4.tar.xz in tools

mkdir -v $LFS/sources
chmod -v a+wt $LFS /sources
cp -rv ../packages/* $LFS/sources 
