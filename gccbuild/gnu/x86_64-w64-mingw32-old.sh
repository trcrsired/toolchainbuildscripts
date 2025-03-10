#!/bin/bash
./dependencycheck.sh

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

if [ -z ${HOST+x} ]; then
	HOST=x86_64-w64-mingw32
fi

relpath=$(realpath .)
currentpath=$relpath/.gnuartifacts/$HOST
mkdir -p $currentpath
cd $currentpath
BUILD=$(gcc -dumpmachine)
TARGET=$BUILD
PREFIX=$TOOLCHAINSPATH_GNU/$BUILD/$HOST
PREFIXTARGET=$PREFIX/$HOST
export PATH=$PREFIX/bin:$PATH

HOSTPREFIX=$TOOLCHAINSPATH_GNU/$HOST/$HOST
HOSTPREFIXTARGET=$HOSTPREFIX
BINUTILSCONFIGUREFLAGSCOMMON=""
if [[ $HOST == "x86_64-w64-mingw32" ]]; then
MINGWW64FLAGS=""
elif [[ $HOST == "aarch64-w64-mingw32" ]]; then
MINGWW64FLAGS="--disable-libarm32 --disable-lib32 --disable-lib64 --enable-libarm64"
elif [[ $HOST == "i686-w64-mingw32" ]]; then
MINGWW64FLAGS="--disable-libarm32 --enable-lib32 --disable-lib64 --disable-libarm64 --with-default-msvcrt=msvcrt"
fi

if [[ ${BUILD} == ${HOST} ]]; then
	echo "Native compilation not supported"
	exit 1
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf ${currentpath}
	rm -rf ${PREFIX}
	rm -rf ${HOSTPREFIX}
	rm -f $HOSTPREFIX.tar.xz
	echo "restart done"
fi

CROSSTRIPLETTRIPLETS="--build=$BUILD --host=$BUILD --target=$HOST"
CANADIANTRIPLETTRIPLETS="--build=$BUILD --host=$HOST --target=$HOST"
GCCCONFIGUREFLAGSCOMMON="--disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib  --disable-bootstrap --disable-libstdcxx-verbose --enable-libstdcxx-static-eh-pool --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --enable-libstdcxx-threads --enable-libstdcxx-backtrace"

if ! $relpath/clonebinutilsgccwithdeps.sh
then
exit 1
fi

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/mingw-w64" ]; then
git clone https://git.code.sf.net/p/mingw-w64/mingw-w64
fi
cd "$TOOLCHAINS_BUILD/mingw-w64"
git pull --quiet

cd $currentpath
mkdir -p ${currentpath}/targetbuild
mkdir -p ${currentpath}/targetbuild/$HOST
cd ${currentpath}/targetbuild/$HOST
mkdir -p binutils-gdb
cd binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --with-python3 $BINUTILSCONFIGUREFLAGSCOMMON $CROSSTRIPLETTRIPLETS --prefix=$PREFIX
fi
if [ ! -d $PREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi
cd ..

cd ${currentpath}/targetbuild/$HOST
mkdir -p gcc
cd gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX $CROSSTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON
fi
if [ ! -d $PREFIX/lib/gcc ]; then
make all-gcc -j$(nproc)
make install-strip-gcc -j
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > ${currentpath}/targetbuild/$HOST/gcc/include/limits.h
fi

cd ${currentpath}
mkdir -p build

if [ ! -d ${currentpath}/installs/mingw-w64-headers ]; then
cd ${currentpath}/build
mkdir -p mingw-w64-headers
cd mingw-w64-headers
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/mingw-w64/mingw-w64-headers/configure --host=$HOST --prefix=${currentpath}/installs/mingw-w64-headers $MINGWW64FLAGS
fi
make -j$(nproc)
make install-strip -j$(nproc)
cp -r ${currentpath}/installs/mingw-w64-headers/* $PREFIXTARGET/
fi

if [ ! -d ${currentpath}/installs/mingw-w64-crt ]; then
cd ${currentpath}/build
mkdir -p mingw-w64-crt
cd mingw-w64-crt
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/mingw-w64/mingw-w64-crt/configure --host=$HOST --prefix=${currentpath}/installs/mingw-w64-crt $MINGWW64FLAGS
fi
make -j$(nproc) 2>err.txt
make install-strip -j$(nproc)8 2>err.txt
cp -r ${currentpath}/installs/mingw-w64-crt/* $PREFIXTARGET/
cd $PREFIXTARGET/lib
if [[ $HOST == "x86_64-w64-mingw32" ]]; then
ln -s ../lib32 32
fi
fi

cd ${currentpath}/targetbuild/$HOST

if [ ! -d $PREFIXTARGET/include/c++ ]; then
cd gcc
make -j$(nproc)
make install-strip -j$(nproc)
fi

TOOLCHAINS_BUILD=$TOOLCHAINS_BUILD TOOLCHAINSPATH_GNU=$TOOLCHAINSPATH_GNU GMPMPFRMPCHOST=$HOST GMPMPFRMPCBUILD=${currentpath}/targetbuild/$HOST GMPMPFRMPCPREFIX=$PREFIXTARGET ${relpath}/buildgmpmpfrmpc.sh
if [ $? -ne 0 ]; then
	exit 1
fi

mkdir -p ${currentpath}/hostbuild
mkdir -p ${currentpath}/hostbuild/$HOST
cd ${currentpath}/hostbuild/$HOST
mkdir -p binutils-gdb
cd binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror $BINUTILSCONFIGUREFLAGSCOMMON $CANADIANTRIPLETTRIPLETS --prefix=$HOSTPREFIX
fi

if [ ! -d $HOSTPREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "host binutils-gdb build failure"
exit 1
fi
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
echo "host binutils-gdb install-strip failure"
exit 1
fi
fi
cd ${currentpath}/hostbuild/$HOST

mkdir -p gcc
cd gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$HOSTPREFIXTARGET/include/c++/v1 --prefix=$HOSTPREFIX $CANADIANTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON
fi
if [ ! -f ${currentpath}/hostbuild/$HOST/gcc/.buildgcc ]; then
make all-gcc -j$(nproc)
if [ $? -ne 0 ]; then
echo "make all-gcc failed"
exit 1
fi
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > ${currentpath}/hostbuild/$HOST/gcc/include/limits.h
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "make gcc failed"
exit 1
fi
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
echo "make install failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/hostbuild/$HOST/gcc/.buildgcc
fi

if [ ! -f $HOSTPREFIXTARGET/include/stdio.h ]; then
cp -r ${currentpath}/installs/mingw-w64-headers/* $HOSTPREFIXTARGET/
fi
if [ ! -f $HOSTPREFIXTARGET/lib/libntdll.a ]; then
cp -r ${currentpath}/installs/mingw-w64-crt/* $HOSTPREFIXTARGET/
fi

cd $TOOLCHAINSPATH_GNU/$BUILD
if [ ! -f $HOST.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
	chmod 755 $HOST.tar.xz
fi

cd $TOOLCHAINSPATH_GNU/$HOST
if [ ! -f $HOST.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
	chmod 755 $HOST.tar.xz
fi

