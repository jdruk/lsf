#!/bin/bash

# create ...

# config permission 
sudo chwon -v lfs $LFS/tools
sudo chwon -v lfs $LFS/sources

# create tempory system!


# create basic system
./create-directory-base-lfs.sh

# config user lfs of the host system
sudo su -s /bin/bash  -c ". `pwd`/config-user-lfs.sh" - lfs

