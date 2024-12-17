#!/bin/bash
relpath=$(realpath .)
currentpath=$relpath/artifacts
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
	TARGET=x86_64-elf
fi
BUILD=$(gcc -dumpmachine)
PREFIX=$TOOLCHAINSPATH/$BUILD/$TARGET
PREFIXTARGET=$PREFIX/$TARGET
export PATH=$PREFIX/bin:$PATH

CANADIANPREFIX=$TOOLCHAINSPATH/$HOST/$TARGET
CANADIANPREFIXTARGET=$CANADIANPREFIX/$TARGET

if [[ ${HOST} == ${TARGET} ]]; then
	echo "Native compilation not supported"
	exit 1
fi

if [[ ${ARCH} == "loongarch" ]]; then
ENABLEGOLD="--disable-tui --without-debuginfod"
else
ENABLEGOLD="--disable-tui --without-debuginfod --enable-gold"
fi

if ! $relpath/clonebinutilsgccwithdeps.sh
then
exit 1
fi

CROSSTRIPLETTRIPLETS="--build=$BUILD --host=$BUILD --target=$TARGET"
CANADIANTRIPLETTRIPLETS="--build=$BUILD --host=$HOST --target=$TARGET"
GCCCONFIGURE="--without-headers --disable-shared --disable-threads --disable-nls --disable-werror --disable-libssp --disable-libquadmath --disable-libbacktarce --enable-languages=c,c++ --enable-multilib --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions"

if [[ ${USE_NEWLIB} == "yes" ]]; then
GCCCONFIGURE="$GCCCONFIGURE --disable-libstdcxx-verbose"


if [ ! -d "$TOOLCHAINS_BUILD/newlib-cygwin" ]; then
git clone git@github.com:mirror/newlib-cygwin.git
if [ $? -ne 0 ]; then
echo "newlib-cygwin clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/newlib-cygwin"
git pull --quiet

else
GCCCONFIGURE="$GCCCONFIGURE --disable-hosted-libstdcxx"
fi

cd "$TOOLCHAINS_BUILD/binutils-gdb"
git pull --quiet
cd $currentpath
cd "$TOOLCHAINS_BUILD/gcc"
git pull --quiet

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf ${currentpath}
	rm -rf ${PREFIX}
	rm -rf ${CANADIANPREFIX}
	rm -f "$CANADIANPREFIXTARGET.tar.xz"
	echo "restart done"
fi

cd ${currentpath}
mkdir -p build
cd build

cd ${currentpath}
mkdir -p ${currentpath}/targetbuild
mkdir -p ${currentpath}/targetbuild/$TARGET
cd ${currentpath}/targetbuild/$TARGET
mkdir -p binutils-gdb
cd binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --with-python3 $CROSSTRIPLETTRIPLETS --prefix=$PREFIX $ENABLEGOLD
fi

if [ ! -d $PREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi

cd ${currentpath}/targetbuild/$TARGET
mkdir -p gcc
cd gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure $GCCCONFIGURE $CROSSTRIPLETTRIPLETS --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX
fi

if [ ! -d $PREFIX/lib/gcc ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi

if [ ! -f $PREFIX/bin/${TARGET}-cc ]; then
cd $PREFIX/bin
ln -s ${TARGET}-gcc ${TARGET}-cc
fi

mkdir -p ${currentpath}/hostbuild
mkdir -p ${currentpath}/hostbuild/$HOST
cd ${currentpath}/hostbuild/$HOST
mkdir -p binutils-gdb
cd binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror $CANADIANTRIPLETTRIPLETS --prefix=$CANADIANPREFIX $ENABLEGOLD
fi

if [ ! -d $CANADIANPREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi

cd ${currentpath}/hostbuild/$HOST
mkdir -p gcc
cd gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure $GCCCONFIGURE $CANADIANTRIPLETTRIPLETS --with-gxx-libcxx-include-dir=$CANADIANPREFIXTARGET/include/c++/v1 --prefix=$CANADIANPREFIX
fi
if [ ! -d $CANADIANPREFIX/lib/gcc ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi

cd $TOOLCHAINSPATH/$BUILD
if [ ! -f $TARGET.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $TARGET.tar.xz $TARGET
	chmod 755 $TARGET.tar.xz
fi

cd $CANADIANPREFIX/..
if [ ! -f $TARGET.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $TARGET.tar.xz $TARGET
	chmod 755 $TARGET.tar.xz
fi
