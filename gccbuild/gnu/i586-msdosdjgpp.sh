#!/bin/bash

./dependencycheck.sh
if [ $? -ne 0 ]; then
exit 1
fi

BUILD=$(gcc -dumpmachine)
if [ -z ${HOST+x} ]; then
        HOST=x86_64-w64-mingw32
fi
if [ -z ${TARGET+x} ]; then
        TARGET=i586-msdosdjgpp
fi

currentpath=$(realpath .)/.gnuartifacts/$TARGET/$HOST

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

if [ ! -d ${currentpath} ]; then
        mkdir ${currentpath}
        cd ${currentpath}
fi

mkdir -p "${currentpath}"

if [ -z ${DJCRX+x} ]; then
        DJCRX=djcrx205
fi
PREFIX=$TOOLCHAINSPATH_GNU/$BUILD/$TARGET
PREFIXTARGET=$PREFIX/$TARGET
export PATH="$PREFIX/bin:$PATH"

CANADIANPREFIX=$TOOLCHAINSPATH_GNU/$HOST/$TARGET
CANADIANPREFIXTARGET=$CANADIANPREFIX/$TARGET

export PATH="$TOOLCHAINSPATH_GNU/$BUILD/$HOST/bin:$PATH"

if [[ ${HOST} == ${TARGET} ]]; then
        echo "Native compilation not supported"
        exit 1
fi

CROSSTRIPLETTRIPLETS="--build=$BUILD --host=$BUILD --target=$TARGET"
CANADIANTRIPLETTRIPLETS="--build=$BUILD --host=$HOST --target=$TARGET"

if [[ $1 == "restart" ]]; then
        echo "restarting"
        rm -rf ${currentpath}
        rm -rf ${PREFIX}
        rm -rf ${CANADIANPREFIX}
        rm -f "$CANADIANPREFIX.tar.xz"
        echo "restart done"
fi
mkdir -p ${currentpath}
cd "$TOOLCHAINS_BUILD/binutils-gdb"
git pull --quiet
cd $currentpath
cd "$TOOLCHAINS_BUILD/gcc"
git pull --quiet

mkdir -p ${currentpath}
cd ${currentpath}
mkdir -p ${currentpath}/build
cd ${currentpath}/build
if [ ! -f ${DJCRX}.zip ]; then
wget http://www.delorie.com/pub/djgpp/current/v2/${DJCRX}.zip
chmod 755 ${DJCRX}.zip
unzip ${DJCRX}.zip -d ${DJCRX}
fi

mkdir -p "${TOOLCHAINSPATH_GNU}/${BUILD}"
mkdir -p "${PREFIX}"
mkdir -p "${PREFIXTARGET}"
mkdir -p "${PREFIXTARGET}/bin"

gcc -o $PREFIXTARGET/bin/stubify ${currentpath}/build/${DJCRX}/src/stub/stubify.c -s -Ofast -std=c2x -flto -fuse-ld=gold
gcc -o $PREFIXTARGET/bin/stubedit ${currentpath}/build/${DJCRX}/src/stub/stubedit.c -s -Ofast -std=c2x -flto -fuse-ld=gold

if [ ! -f $PREFIXTARGET/include/stdio.h ]; then
cp -r ${currentpath}/build/${DJCRX}/include $PREFIXTARGET/
${TARGET}-strip --strip-unneeded ${currentpath}/build/${DJCRX}/lib/*
cp -r ${currentpath}/build/${DJCRX}/lib $PREFIXTARGET/
fi

cd ${currentpath}
mkdir -p ${currentpath}/targetbuild
mkdir -p ${currentpath}/targetbuild/$TARGET
cd ${currentpath}/targetbuild/$TARGET
mkdir -p binutils-gdb
cd binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --with-python3 $CROSSTRIPLETTRIPLETS --prefix=$PREFIX --disable-tui --without-debuginfod
fi

if [ ! -d $PREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi

cd ${currentpath}/targetbuild/$TARGET
mkdir -p gcc
cd gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX $CROSSTRIPLETTRIPLETS --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --enable-libstdcxx-backtrace --disable-libquadmath
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
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror $CANADIANTRIPLETTRIPLETS --prefix=$CANADIANPREFIX
fi

if [ ! -d $CANADIANPREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi
cd ${currentpath}/hostbuild/$HOST

${HOST}-gcc -o $CANADIANPREFIXTARGET/bin/stubify ${currentpath}/build/${DJCRX}/src/stub/stubify.c -s -Ofast -flto
${HOST}-gcc -o $CANADIANPREFIXTARGET/bin/stubedit ${currentpath}/build/${DJCRX}/src/stub/stubedit.c -s -Ofast -flto

cd ${currentpath}/hostbuild/$HOST
mkdir -p gcc
cd gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib --with-gxx-libcxx-include-dir=$CANADIANPREFIXTARGET/include/c++/v1 --prefix=$CANADIANPREFIX $CANADIANTRIPLETTRIPLETS --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --enable-libstdcxx-backtrace --disable-libquadmath
fi
if [ ! -d $CANADIANPREFIX/lib/gcc ]; then
make all-gcc -j$(nproc)
make install-strip-gcc -j$(nproc)
make all-target-libgcc -j$(nproc)
make install-strip-target-libgcc -j$(nproc)
fi

if [ ! -d $CANADIANPREFIXTARGET/include/c++ ]; then
cp -r "$PREFIXTARGET/include" "$CANADIANPREFIXTARGET/"
cp -r "$PREFIXTARGET/lib" "$CANADIANPREFIXTARGET/"
fi

cd $TOOLCHAINSPATH_GNU/$BUILD
if [ ! -f $TARGET.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $TARGET.tar.xz $TARGET
	chmod 755 $TARGET.tar.xz
fi

cd $CANADIANPREFIX/..
if [ ! -f $TARGET.tar.xz ]; then
        XZ_OPT=-e9T0 tar cJf $TARGET.tar.xz $TARGET
        chmod 755 $TARGET.tar.xz
fi
