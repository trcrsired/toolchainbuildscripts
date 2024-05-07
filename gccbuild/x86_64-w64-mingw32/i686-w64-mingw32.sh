#!/bin/bash
currentpath=$(realpath .)/artifacts
if [ ! -d ${currentpath} ]; then
	mkdir ${currentpath}
	cd ${currentpath}
fi
if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$currentpath/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$currentpath/toolchains
fi

if [ -z ${HOST+x} ]; then
	HOST=x86_64-w64-mingw32
fi
if [ -z ${TARGET+x} ]; then
	TARGET=i686-w64-mingw32
fi

BUILD=$(gcc -dumpmachine)
PREFIX=$TOOLCHAINSPATH/$BUILD/$TARGET
PREFIXTARGET=$PREFIX/$TARGET
export PATH=$PREFIX/bin:$TOOLCHAINSPATH/$BUILD/$HOST/bin:$PATH

if [ -z ${THREADSNUMMAKE} ]; then
THREADSNUMMAKE=-j16
fi

HOSTPREFIX=$TOOLCHAINSPATH/$HOST/$TARGET
HOSTPREFIXTARGET=$HOSTPREFIX/$TARGET

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

CROSSTRIPLETTRIPLETS="--build=$BUILD --host=$BUILD --target=$TARGET"
CANADIANTRIPLETTRIPLETS="--build=$BUILD --host=$HOST --target=$TARGET"
GCCCONFIGUREFLAGSCOMMON="--disable-nls --disable-werror --enable-languages=c,c++ --disable-multilib  --disable-bootstrap --disable-libstdcxx-verbose --enable-libstdcxx-static-eh-pool --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --disable-tls --disable-threads --disable-libstdcxx-threads --enable-libstdcxx-backtrace"

LIBRARIESCROSSPATH=${currentpath}/$TARGET/$TARGET

mkdir -p ${currentpath}

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
mkdir -p ${currentpath}
mkdir -p ${currentpath}/$BUILD
mkdir -p ${currentpath}/$BUILD/$TARGET
mkdir -p ${currentpath}/$BUILD/$TARGET/binutils-gdb
cd ${currentpath}/$BUILD/$TARGET/binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --with-python3 $CROSSTRIPLETTRIPLETS --prefix=$PREFIX
fi

if [ ! -d $PREFIX/lib/bfd-plugins ]; then
make $THREADSNUMMAKE
make install-strip -j
fi

mkdir -p ${currentpath}/$BUILD/$TARGET/gcc
cd ${currentpath}/$BUILD/$TARGET/gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX $CROSSTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON
fi
if [ ! -d $PREFIX/lib/gcc ]; then
make all-gcc $THREADSNUMMAKE
make install-strip-gcc -j
fi

mkdir -p ${currentpath}/$TARGET
mkdir -p $LIBRARIESCROSSPATH

if [ ! -d $LIBRARIESCROSSPATH/installs/mingw-w64-headers ]; then
cd $LIBRARIESCROSSPATH
mkdir -p mingw-w64-headers
cd mingw-w64-headers
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/mingw-w64/mingw-w64-headers/configure --host=$TARGET --prefix=$LIBRARIESCROSSPATH/installs/mingw-w64-headers --with-default-msvcrt=msvcrt
fi
make $THREADSNUMMAKE
make install-strip -j
cp -r $LIBRARIESCROSSPATH/installs/mingw-w64-headers/* $PREFIXTARGET/
fi

if [ ! -d $LIBRARIESCROSSPATH/installs/mingw-w64-crt ]; then
cd $LIBRARIESCROSSPATH
mkdir -p mingw-w64-crt
cd mingw-w64-crt
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/mingw-w64/mingw-w64-crt/configure --host=$TARGET --prefix=$LIBRARIESCROSSPATH/installs/mingw-w64-crt --with-default-msvcrt=msvcrt
fi
make -j8 2>err.txt
make install-strip -j8 2>err.txt
cp -r $LIBRARIESCROSSPATH/installs/mingw-w64-crt/* $PREFIXTARGET/
fi

if [ ! -d $PREFIXTARGET/include/c++ ]; then
cd ${currentpath}/$BUILD/$TARGET/gcc
make $THREADSNUMMAKE
make install-strip -j
fi

mkdir -p ${currentpath}/$HOST
mkdir -p ${currentpath}/$HOST/$TARGET
cd ${currentpath}/$HOST/$TARGET
mkdir -p binutils-gdb
cd binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror $CANADIANTRIPLETTRIPLETS --prefix=$HOSTPREFIX
fi

if [ ! -d $HOSTPREFIX/lib/bfd-plugins ]; then
make $THREADSNUMMAKE
make install-strip -j
fi
cd ${currentpath}/$HOST/$TARGET

mkdir -p gcc
cd gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$HOSTPREFIXTARGET/include/c++/v1 --prefix=$HOSTPREFIX $CANADIANTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON
fi
if [ ! -d $HOSTPREFIX/lib/gcc ]; then
make $THREADSNUMMAKE
make install-strip -j
fi

if [ ! -f $HOSTPREFIXTARGET/include/stdio.h ]; then
cp -r $LIBRARIESCROSSPATH/installs/mingw-w64-headers/* $HOSTPREFIXTARGET/
fi
if [ ! -f $HOSTPREFIXTARGET/lib/libntdll.a ]; then
cp -r $LIBRARIESCROSSPATH/installs/mingw-w64-crt/* $HOSTPREFIXTARGET/
fi

cd $TOOLCHAINSPATH/$HOST
if [ ! -f $TARGET.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $TARGET.tar.xz $TARGET
	chmod 755 $TARGET.tar.xz
fi

