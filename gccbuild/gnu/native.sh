#!/bin/bash

./dependencycheck.sh
if [ $? -ne 0 ]; then
exit 1
fi

BUILD=$(gcc -dumpmachine)
HOST=$BUILD
TARGET=$BUILD
currentpath=$(realpath .)/.gnuartifacts/$BUILD/$HOST

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -z ${TOOLCHAINSPATH_GNU+x} ]; then
	TOOLCHAINSPATH_GNU=$TOOLCHAINSPATH/gnu
fi

mkdir -p "${TOOLCHAINSPATH_GNU}"

TRIPLETTRIPLETS="--build=$BUILD --host=$HOST --target=$TARGET"
PREFIX=$TOOLCHAINSPATH_GNU/$HOST/$TARGET
PREFIXTARGET=$PREFIX/$TARGET
export PATH=$PREFIX/bin:$PATH
export -n LD_LIBRARY_PATH

if [[ $1 == "clean" ]]; then
	echo "cleaning"
	rm -rf ${currentpath}
	rm -f $PREFIX.tar.xz
	echo "cleaning done"
    exit 0
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf ${currentpath}
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
$TOOLCHAINS_BUILD/gcc/configure --disable-nls --disable-werror --disable-libstdcxx-verbose --enable-languages=c,c++ $TRIPLETTRIPLETS --prefix=$PREFIX --with-gxx-libcxx-include-dir=$PREFIX/include/c++/v1 --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --enable-multilib --with-multilib-list=m64 --enable-libstdcxx-static-eh-pool --with-libstdcxx-eh-pool-obj-count=0 --enable-libstdcxx-backtrace
if [ $? -ne 0 ]; then
echo "gcc configure failure"
exit 1
fi
fi
if [ ! -f ${currentpath}/gcc/.buildsuccess ]; then
cd ${currentpath}/gcc
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/gcc/.buildsuccess
fi

if [ ! -f ${currentpath}/gcc/.installsuccess ]; then
cd ${currentpath}/gcc
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
make install -j$(nproc)
$HOST-strip --strip-unneeded $PREFIX/bin
$HOST-strip --strip-unneeded $PREFIXTARGET/bin
$HOST-strip --strip-unneeded $PREFIX/lib
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/gcc/.installsuccess
fi

if [ -e "${PREFIXTARGET}/bin/gcc" ]; then
  cd "${PREFIXTARGET}/bin"
  ln -s gcc cc
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
if [ ! -f ${currentpath}/binutils-gdb/.buildsuccess ]; then
cd ${currentpath}/binutils-gdb
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "binutils-gdb build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/binutils-gdb/.buildsuccess
fi

if [ ! -f ${currentpath}/binutils-gdb/.installsuccess ]; then
cd ${currentpath}/binutils-gdb
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
make install -j$(nproc)
$HOST-strip --strip-unneeded $PREFIX/bin
$HOST-strip --strip-unneeded $PREFIXTARGET/bin
$HOST-strip --strip-unneeded $PREFIX/lib
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/binutils-gdb/.installsuccess
fi

if [ ! -f ${PREFIX}.tar.xz ]; then
cd ${PREFIX}/..
XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
chmod 755 $HOST.tar.xz
fi