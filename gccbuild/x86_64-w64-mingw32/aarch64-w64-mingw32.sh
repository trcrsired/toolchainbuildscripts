#!/bin/bash
if [ -z ${HOST+x} ]; then
	HOST=aarch64-w64-mingw32
fi
currentpath=$(realpath .)/.gccartifacts/$HOST
mkdir -p ${currentpath}
cd ${currentpath}
if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$currentpath/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$currentpath/toolchains
fi

BUILD=$(gcc -dumpmachine)
TARGET=$BUILD
PREFIX=$TOOLCHAINSPATH/$BUILD/$HOST
PREFIXTARGET=$PREFIX/$HOST
export PATH=$PREFIX/bin:$PATH

HOSTPREFIX=$TOOLCHAINSPATH/$HOST/$HOST
HOSTPREFIXTARGET=$HOSTPREFIX

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
GCCCONFIGUREFLAGSCOMMON="--disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib --disable-bootstrap --disable-libstdcxx-verbose --enable-libstdcxx-static-eh-pool --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --enable-libstdcxx-threads --enable-libstdcxx-backtrace"
MINGWW64FLAGS="--disable-lib32 --disable-lib64 --disable-libarm32 --enable-libarm64"

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/binutils-gdb" ]; then
git clone git://sourceware.org/git/binutils-gdb.git
fi
cd "$TOOLCHAINS_BUILD/binutils-gdb"
git pull --quiet

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/gcc" ]; then
git clone git://gcc.gnu.org/git/gcc.git
fi
cd "$TOOLCHAINS_BUILD/gcc"
git pull --quiet

if [ ! -L "$TOOLCHAINS_BUILD/gcc/gmp" ]; then
cd $TOOLCHAINS_BUILD/gcc
./contrib/download_prerequisites
fi

if [ ! -L "$TOOLCHAINS_BUILD/binutils-gdb/gmp" ]; then
cd $TOOLCHAINS_BUILD/binutils-gdb
ln -s ../gcc/gmp gmp
ln -s ../gcc/mpfr mpfr
ln -s ../gcc/mpc mpc
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
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --with-python3 $CROSSTRIPLETTRIPLETS --prefix=$PREFIX
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
fi

cd ${currentpath}
mkdir -p build

if [ ! -d ${currentpath}/installs/mingw-w64-headers ]; then
cd ${currentpath}/build
mkdir -p mingw-w64-headers
cd mingw-w64-headers
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/mingw-w64/mingw-w64-headers/configure --host=$HOST --prefix=${currentpath}/installs/mingw-w64-headers ${MINGWW64FLAGS}
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
$TOOLCHAINS_BUILD/mingw-w64/mingw-w64-crt/configure --host=$HOST --prefix=${currentpath}/installs/mingw-w64-crt ${MINGWW64FLAGS}
fi
make -j$(nproc) 2>err.txt
make install-strip -j$(nproc)8 2>err.txt
cp -r ${currentpath}/installs/mingw-w64-crt/* $PREFIXTARGET/
fi

cd ${currentpath}/targetbuild/$HOST

if [ ! -d $PREFIXTARGET/include/c++ ]; then
cd gcc
make -j$(nproc)
make install-strip -j$(nproc)
fi

mkdir -p ${currentpath}/hostbuild
mkdir -p ${currentpath}/hostbuild/$HOST
cd ${currentpath}/hostbuild/$HOST
mkdir -p binutils-gdb
cd binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror $CANADIANTRIPLETTRIPLETS --prefix=$HOSTPREFIX
fi

if [ ! -d $HOSTPREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi
cd ${currentpath}/hostbuild/$HOST

mkdir -p gcc
cd gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$HOSTPREFIXTARGET/include/c++/v1 --prefix=$HOSTPREFIX $CANADIANTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON
fi
if [ ! -d $HOSTPREFIX/lib/gcc ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi

if [ ! -f $HOSTPREFIXTARGET/include/stdio.h ]; then
cp -r ${currentpath}/installs/mingw-w64-headers/* $HOSTPREFIXTARGET/
fi
if [ ! -f $HOSTPREFIXTARGET/lib/libntdll.a ]; then
cp -r ${currentpath}/installs/mingw-w64-crt/* $HOSTPREFIXTARGET/
fi

cd $TOOLCHAINSPATH/$HOST
if [ ! -f $HOST.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
	chmod 755 $HOST.tar.xz
fi
	