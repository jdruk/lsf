# criar partições

# formatar
mkfs -v -t ext4 /dev/sdb2
mkswap /dev/sdb1

# criar LSF
export LFS=/mnt/lfs

# montar
mkdir -pv $LFS
mount -v -t ext4 /dev/sdb2 $LFS

# ativar swap
swapon /dev/sdb1

mkdir -v $LFS/sources

chmod -v a+wt $LFS/sources

# baixar lista de pacotes
wget http://www.linuxfromscratch.org/lfs/view/stable/wget-list
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources/
wget http://www.linuxfromscratch.org/lfs/view/stable/md5sums

pushd $LFS/sources
md5sum -c md5sums
popd
mkdir -v $LFS/tools
ln -sv $LFS/tools/ /

groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs

passwd lfs
chown -v lfs $LFS/tools
chown -v lfs $LFS/sources

su - lfs

cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF

export MAKEFLAGS='-j 5'
source ~/.bash_profile

# Descompactar e compilar
cd $LFS/sources

# binutils-2.32
tar -xvf binutils-2.32.tar.xz
cd binutils-2.32
mkdir -v build
cd build
../configure --prefix=/tools            \
             --with-sysroot=$LFS        \
             --with-lib-path=/tools/lib \
             --target=$LFS_TGT          \
             --disable-nls              \
             --disable-werror
make

case $(uname -m) in
  x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
esac

make install
cd ../..
rm -Rf binutils-2.32

# Gcc
tar -xvf gcc-8.2.0.tar.xz
cd gcc-8.2.0
tar -xf ../mpfr-4.0.2.tar.xz
mv -v mpfr-4.0.2 mpfr
tar -xf ../gmp-6.1.2.tar.xz
mv -v gmp-6.1.2 gmp
tar -xf ../mpc-1.1.0.tar.gz
mv -v mpc-1.1.0 mpc

for file in gcc/config/{linux,i386/linux{,64}}.h
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
      -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac

mkdir -v build
cd build

../configure                                       \
    --target=$LFS_TGT                              \
    --prefix=/tools                                \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libmpx                               \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++

make
make install
cd ../..
rm -Rf gcc-8.2.0

# Kernel
tar -xvf linux-4.20.12.tar.xz
cd linux-4.20.12
make mrproper
make INSTALL_HDR_PATH=dest headers_install
cp -rv dest/include/* /tools/include
cd ..
rm -Rf linux-4.20.12

# Glibc
tar -xvf glibc-2.29.tar.xz 
cd glibc-2.29
mkdir -v build
cd build
../configure                             \
      --prefix=/tools                    \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2                \
      --with-headers=/tools/include
make
make install 
echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c
readelf -l a.out | grep ': /tools'
cd ../..
rm -Rf glibc-2.29

# LIBSTDC
tar -xvf gcc-8.2.0.tar.xz 
cd gcc-8.2.0
mkdir -v build
cd build
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --prefix=/tools                 \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-threads     \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/8.2.0

make
make install 
cd ../.. 
rm -Rf gcc-8.2.0

# binutils 
tar -xvf binutils-2.32.tar.xz
cd binutils-2.32
mkdir -v build 
cd build
CC=$LFS_TGT-gcc                \
AR=$LFS_TGT-ar                 \
RANLIB=$LFS_TGT-ranlib         \
../configure                   \
    --prefix=/tools            \
    --disable-nls              \
    --disable-werror           \
    --with-lib-path=/tools/lib \
    --with-sysroot

make 
make install 
make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cp -v ld/ld-new /tools/bin
cd ../.. 
rm -Rf binutils-2.32

# Gcc parte 2
tar -xvf gcc-8.2.0.tar.xz
cd gcc-8.2.0
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h

for file in gcc/config/{linux,i386/linux{,64}}.h
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
      -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

tar -xf ../mpfr-4.0.2.tar.xz
mv -v mpfr-4.0.2 mpfr
tar -xf ../gmp-6.1.2.tar.xz
mv -v gmp-6.1.2 gmp
tar -xf ../mpc-1.1.0.tar.gz
mv -v mpc-1.1.0 mpc

mkdir -v build 
cd build
CC=$LFS_TGT-gcc                                    \
CXX=$LFS_TGT-g++                                   \
AR=$LFS_TGT-ar                                     \
RANLIB=$LFS_TGT-ranlib                             \
../configure                                       \
    --prefix=/tools                                \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --enable-languages=c,c++                       \
    --disable-libstdcxx-pch                        \
    --disable-multilib                             \
    --disable-bootstrap                            \
    --disable-libgomp

make
make install 
ln -sv gcc /tools/bin/cc
echo 'int main(){}' > dummy.c
cc dummy.c
readelf -l a.out | grep ': /tools'

cd ../..
rm -Rf gcc-8.2.0

# tcl
tar -xvf tcl8.6.9-src.tar.gz
cd tcl8.6.9
cd unix
./configure --prefix=/tools
make
make install 
chmod -v u+w /tools/lib/libtcl8.6.so
make install-private-headers
ln -sv tclsh8.6 /tools/bin/tclsh
cd ../..
rm -Rf tcl8.6.9

# expect
tar -xvf expect5.45.4.tar.gz
cd expect5.45.4
cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure
./configure --prefix=/tools       \
            --with-tcl=/tools/lib \
            --with-tclinclude=/tools/include


make
make SCRIPTS="" install
cd ..
rm -Rf expect5.45.4

# dejavu
tar -xvf dejagnu-1.6.2.tar.gz 
cd dejagnu-1.6.2
./configure --prefix=/tools
make install 
cd ..
rm -Rf dejagnu-1.6.2

# m4
tar -xvf m4-1.4.18.tar.xz
cd m4-1.4.18
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/tools
make 
make install 
cd ..
rm -Rf m4-1.4.18

# ncurses
tar -xvf ncurses-6.1.tar.gz 
cd ncurses-6.1
sed -i s/mawk// configure
./configure --prefix=/tools \
            --with-shared   \
            --without-debug \
            --without-ada   \
            --enable-widec  \
            --enable-overwrite
make 
make install 
ln -s libncursesw.so /tools/lib/libncurses.so
cd ..
rm -Rf ncurses-6.1

# bash 5
tar -xvf bash-5.0.tar.gz
cd bash-5.0
./configure --prefix=/tools --without-bash-malloc
make 
make install 
ln -sv bash /tools/bin/sh
cd ..
rm -Rf bash-5.0

#bison
tar -xvf bison-3.3.2.tar.xz 
cd bison-3.3.2
./configure --prefix=/tools
make 
make install 
cd ..
rm -Rf bison-3.3.2

# bzip
tar -xvf bzip2-1.0.6.tar.gz
cd bzip2-1.0.6
make
make PREFIX=/tools install 
cd ..
rm -Rf bzip2-1.0.6

# coreutils
tar -xvf coreutils-8.30.tar.xz
cd coreutils-8.30
./configure --prefix=/tools --enable-install-program=hostname
make 
make install 
cd ..
rm -Rf coreutils-8.30

# diff
tar -xvf diffutils-3.7.tar.xz 
cd diffutils-3.7
./configure --prefix=/tools
make 
make install 
cd ..
rm -Rf diffutils-3.7

# file
tar -xvf file-5.36.tar.gz
cd file-5.36
./configure --prefix=/tools
make 
make install 
cd ..
rm -Rf file-5.36

# findutils
tar -xvf findutils-4.6.0.tar.gz 
cd findutils-4.6.0
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h
./configure --prefix=/tools
make 
make install 
cd ..
rm -Rf findutils-4.6.0

# gawk
tar -xvf gawk-4.2.1.tar.xz
cd gawk-4.2.1
./configure --prefix=/tools
make
make install 
cd ..
rm -Rf gawk-4.2.1

# getext
tar -xvf gettext-0.19.8.1.tar.xz
cd gettext-0.19.8.1
cd gettext-tools
EMACS="no" ./configure --prefix=/tools --disable-shared
make -C gnulib-lib
make -C intl pluralx.c
make -C src msgfmt
make -C src msgmerge
make -C src xgettext
cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin
cd ../..
rm -Rf gettext-0.19.8.1

# grep 
tar -xvf grep-3.3.tar.xz
cd grep-3.3
./configure --prefix=/tools
make 
make install 
cd ..
rm -Rf grep-3.3

# gzip
tar -xvf gzip-1.10.tar.xz
cd gzip-1.10
./configure --prefix=/tools
make
make install 
cd ..
rm -Rf gzip-1.10

# make
tar -xvf make-4.2.1.tar.bz2
cd make-4.2.1
sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
./configure --prefix=/tools --without-guile
make
make install 
cd ..
rm -Rf make-4.2.1

# patch 
tar -xvf patch-2.7.6.tar.xz
cd patch-2.7.6
./configure --prefix=/tools
make 
make install 
cd ..
rm -Rf patch-2.7.6

# perl
tar -xvf perl-5.28.1.tar.xz 
cd perl-5.28.1
sh Configure -des -Dprefix=/tools -Dlibs=-lm -Uloclibpth -Ulocincpth
make 
cp -v perl cpan/podlators/scripts/pod2man /tools/bin
mkdir -pv /tools/lib/perl5/5.28.1
cp -Rv lib/* /tools/lib/perl5/5.28.1
cd ..
rm -Rf perl-5.28.1

# python
tar -xvf Python-3.7.2.tar.xz 
cd Python-3.7.2
sed -i '/def add_multiarch_paths/a \        return' setup.py
./configure --prefix=/tools --without-ensurepip
make
make install 
cd ..
rm -Rf Python-3.7.2

# sed
tar -xvf sed-4.7.tar.xz
cd sed-4.7
./configure --prefix=/tools
make
make install 
cd ..
rm -Rf sed-4.7

# tar 
tar -xvf tar-1.31.tar.xz 
cd tar-1.31
./configure --prefix=/tools
make
make install 
cd ..
rm -Rf tar-1.31

# textinfo
 tar -xvf texinfo-6.5.tar.xz 
 cd texinfo-6.5
 ./configure --prefix=/tools
 make 
 make install 
 cd ..
 rm -Rf texinfo-6.5

# xz
 tar -xvf xz-5.2.4.tar.xz
cd xz-5.2.4
./configure --prefix=/tools
make
make install 
cd ..
rm -Rf xz-5.2.4



### Strip

strip --strip-debug /tools/lib/*
/usr/bin/strip --strip-unneeded /tools/{,s}bin/*
rm -rf /tools/{,share}/{info,man,doc}
find /tools/{lib,libexec} -name \*.la -delete

exit 
chown -R root:root $LFS/tools
