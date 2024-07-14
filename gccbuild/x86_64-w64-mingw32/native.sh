#!/bin/bash

./dependencycheck.sh
if [ $? -ne 0 ]; then
exit 1
fi

BUILD=$(gcc -dumpmachine)
HOST=$BUILD
TARGET=$BUILD
currentpath=$relpath/.gnuartifacts/$BUILD/$HOST
if [ ! -d ${currentpath} ]; then
	mkdir ${currentpath}
	cd ${currentpath}
fi

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

TRIPLETTRIPLETS="--build=$BUILD --host=$HOST --target=$TARGET"
PREFIX=$TOOLCHAINSPATH/$HOST/$TARGET
PREFIXTARGET=$PREFIX/$TARGET
export PATH=$PREFIX/bin:$PATH
export -n LD_LIBRARY_PATH

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf ${currentpath}
    rm -rf ${PREFIX}
	rm -f $PREFIX.tar.xz
	echo "restart done"
fi

mkdir -p $currentpath
mkdir -p $PREFIX

./clonegccbinutils.sh
if [ $? -ne 0 ]; then
exit 1
fi

mkdir -p ${currentpath}/gcc

if [ ! -f ${currentpath}/gcc/Makefile ]; then
cd ${currentpath}/gcc
$TOOLCHAINS_BUILD/gcc/configure --disable-nls --disable-werror --disable-libstdcxx-verbose $TRIPLETTRIPLETS --prefix=$PREFIX --with-gxx-libcxx-include-dir=$PREFIX/include/c++/v1 --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --enable-multilib --with-multilib-list=m64 --enable-libstdcxx-static-eh-pool --with-libstdcxx-eh-pool-obj-count=0 --enable-libstdcxx-backtrace
if [ $? -ne 0 ]; then
echo "gcc configure failure"
exit 1
fi
fi
if [ ! -d $PREFIX/include/c++ ]; then
cd ${currentpath}/gcc
make -j16
if [ $? -ne 0 ]; then
echo "gcc build failure"
exit 1
fi
make install-strip -j
if [ $? -ne 0 ]; then
make install -j
$HOST-strip --strip-unneeded $PREFIX/bin
$HOST-strip --strip-unneeded $PREFIXTARGET/bin
$HOST-strip --strip-unneeded $PREFIX/lib
fi
fi

mkdir -p ${currentpath}/binutils-gdb

if [ ! -f ${currentpath}/binutils-gdb/Makefile ]; then
cd ${currentpath}/binutils-gdb
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --with-python3 --enable-gold $TRIPLETTRIPLETS --prefix=$PREFIX
if [ $? -ne 0 ]; then
echo "binutils-gdb configure failure"
exit 1
fi
fi
if [ ! -d $PREFIX/lib/bfd-plugins ]; then
cd ${currentpath}/binutils-gdb
make -j16
if [ $? -ne 0 ]; then
echo "binutils-gdb build failure"
exit 1
fi
make install-strip -j
if [ $? -ne 0 ]; then
make install -j
$HOST-strip --strip-unneeded $PREFIX/bin
$HOST-strip --strip-unneeded $PREFIXTARGET/bin
$HOST-strip --strip-unneeded $PREFIX/lib
fi
fi
