#!/bin/bash

PARTITION=/dev/sda3
LFS=/mnt/lfs

export LFS

if [ ! -d "{$LFS}" ]; then
	sudo mkdir -pv $LFS 
fi 

sudo mount -v -t ext4 $PARTITION $LFS


