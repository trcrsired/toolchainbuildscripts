#!/bin/bash
relpath=$(realpath .)
if [ -z ${HOST+x} ]; then
	HOST=x86_64-linux-musl
fi
currentpath=$relpath/.gnuartifacts/$HOST
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
if [ -z ${CANADIANHOST+x} ]; then
	CANADIANHOST=x86_64-w64-mingw32
fi

BUILD=$(gcc -dumpmachine)
TARGET=$BUILD
PREFIX=$TOOLCHAINSPATH_GNU/$BUILD/$HOST
PREFIXTARGET=$PREFIX/$HOST
export PATH=$PREFIX/bin:$PATH

HOSTPREFIX=$TOOLCHAINSPATH_GNU/$HOST/$HOST
HOSTPREFIXTARGET=$HOSTPREFIX/$HOST

export PATH=$TOOLCHAINSPATH_GNU/$BUILD/$CANADIANHOST/bin:$PATH
CANADIANHOSTPREFIX=$TOOLCHAINSPATH_GNU/$CANADIANHOST/$HOST
CANADIANHOSTPREFIXTARGET=$CANADIANHOSTPREFIX/$HOST

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
	rm -rf ${CANADIANHOSTPREFIX}
	rm -rf $CANADIANHOSTPREFIX.tar.xz
	echo "restart done"
fi

mkdir -p ${currentpath}

CROSSTRIPLETTRIPLETS="--build=$BUILD --host=$BUILD --target=$HOST"
CANADIANTRIPLETTRIPLETS="--build=$BUILD --host=$HOST --target=$HOST"
CANADIANCROSSTRIPLETTRIPLETS="--build=$BUILD --host=$CANADIANHOST --target=$HOST"
MULTILIBLISTS="--with-multilib-list=m64"
GCCCONFIGUREFLAGSCOMMON="--disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib $MULTILIBLISTS --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --enable-libstdcxx-threads --enable-libstdcxx-backtrace"
MUSLREPOPATH="$TOOLCHAINS_BUILD/musl"

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

cd "$relpath"
./clonegccbinutils.sh

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/mingw-w64" ]; then
git clone https://git.code.sf.net/p/mingw-w64/mingw-w64
fi
cd "$TOOLCHAINS_BUILD/mingw-w64"
git pull --quiet

if [ ! -d "$MUSLREPOPATH" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git://git.etalabs.net/musl "$MUSLREPOPATH"
fi
cd "$MUSLREPOPATH"
git pull --quiet

if [ ! -d "$TOOLCHAINS_BUILD/linux" ]; then
cd "$TOOLCHAINS_BUILD"
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
fi
cd "$TOOLCHAINS_BUILD/linux"
git pull --quiet

cd $currentpath
mkdir -p ${currentpath}/targetbuild
mkdir -p ${currentpath}/targetbuild/$HOST
cd ${currentpath}/targetbuild/$HOST
mkdir -p ${currentpath}/targetbuild/$HOST/binutils-gdb
cd ${currentpath}/targetbuild/$HOST/binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --with-python3 --enable-gold $CROSSTRIPLETTRIPLETS --prefix=$PREFIX
fi
if [ ! -d $PREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi

mkdir -p ${currentpath}/targetbuild/$HOST/gcc_phase1
cd ${currentpath}/targetbuild/$HOST/gcc_phase1
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX $CROSSTRIPLETTRIPLETS --disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib $MULTILIBLISTS --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --disable-libstdcxx-threads --disable-libstdcxx-backtrace --disable-hosted-libstdcxx --without-headers --disable-shared --disable-threads --disable-libsanitizer --disable-libquadmath --disable-libatomic --disable-libssp
make all-gcc -j$(nproc)
make all-target-libgcc -j$(nproc)
make install-strip-gcc -j
make install-strip-target-libgcc -j
fi

cd ${currentpath}
mkdir -p build
if [ ! -d "${currentpath}/install/musl" ]; then
	linuxkernelheaders=${currentpath}/install/linux

	if [ ! -d $linuxkernelheaders ]; then
		cd "$TOOLCHAINS_BUILD/linux"
		make headers_install ARCH=x86_64 -j INSTALL_HDR_PATH=$linuxkernelheaders
	fi

	mkdir -p ${currentpath}/build/musl
	cd ${currentpath}/build/musl
	if [ ! -f Makefile ]; then
		CC="${HOST}-gcc" CXX="${HOST}-g++" $MUSLREPOPATH/configure --disable-nls --disable-werror --prefix=$currentpath/install/musl --build=$HOST --with-headers=$linuxkernelheaders/include --without-selinux --host=$HOST
		make -j$(nproc)
		make install -j$(nproc)
		${HOST}-strip --strip-unneeded $currentpath/install/musl/*
	fi

	if [ ! -f $PREFIXTARGET/include/stdio.h ]; then
		cp -r ${currentpath}/install/linux/* $PREFIXTARGET/
		cp -r ${currentpath}/install/musl/* $PREFIXTARGET/
	fi
fi


if [ ! -d $PREFIXTARGET/include/c++ ]; then
	mkdir -p ${currentpath}/targetbuild/$HOST/gcc
	cd ${currentpath}/targetbuild/$HOST/gcc
	if [ ! -f Makefile ]; then
		$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX ${CROSSTRIPLETTRIPLETS} ${GCCCONFIGUREFLAGSCOMMON}
	fi
	make -j$(nproc)
	make install-strip -j$(nproc)
	cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > `dirname $(${HOST}-gcc -print-libgcc-file-name)`/include/limits.h
fi

GCCVERSIONSTR=$(${HOST}-gcc -dumpversion)

if ! [ -x "$(command -v ${CANADIANHOST}-g++)" ];
then
        echo "${CANADIANHOST}-g++ not found. we won't build canadian cross toolchain"
        exit 0
fi

mkdir -p ${currentpath}/hostbuild
mkdir -p ${currentpath}/hostbuild/$HOST
cd ${currentpath}/hostbuild/$HOST
mkdir -p ${currentpath}/hostbuild/$HOST/binutils-gdb
cd ${currentpath}/hostbuild/$HOST/binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --enable-gold $CANADIANTRIPLETTRIPLETS --prefix=$HOSTPREFIX
fi

if [ ! -d $HOSTPREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi
cd ${currentpath}/hostbuild/$HOST

mkdir -p ${currentpath}/hostbuild/$HOST/gcc
cd ${currentpath}/hostbuild/$HOST/gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$HOSTPREFIXTARGET/include/c++/v1 --prefix=$HOSTPREFIX $CANADIANTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON
fi
if [ ! -d $HOSTPREFIX/lib/gcc ]; then
make -j$(nproc)
make install-strip -j$(nproc)
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > $HOSTPREFIX/lib/gcc/$HOST/$GCCVERSIONSTR/include/limits.h
fi

if [ ! -f $HOSTPREFIX/include/stdio.h ]; then
	cp -r ${currentpath}/install/linux/* $HOSTPREFIX/
	cp -r ${currentpath}/install/musl/include $HOSTPREFIX/
	mkdir -p $HOSTPREFIX/runtimes
	cp -r ${currentpath}/install/musl/* $HOSTPREFIX/runtimes/
fi

cd $TOOLCHAINSPATH_GNU/$HOST
if [ ! -f $HOST.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
	chmod 755 $HOST.tar.xz
fi

if ! [ -x "$(command -v ${CANADIANHOST}-g++)" ];
then
        echo "${CANADIANHOST}-g++ not found. we won't build canadian cross toolchain"
        exit 0
fi

mkdir -p ${currentpath}/canadianbuild
mkdir -p ${currentpath}/canadianbuild/$HOST
cd ${currentpath}/canadianbuild/$HOST
mkdir -p ${currentpath}/canadianbuild/$HOST/binutils-gdb
cd ${currentpath}/canadianbuild/$HOST/binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --enable-gold $CANADIANCROSSTRIPLETTRIPLETS --prefix=$CANADIANHOSTPREFIX
fi

if [ ! -d $CANADIANHOSTPREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
make install-strip
fi
cd ${currentpath}/canadianbuild/$HOST

mkdir -p ${currentpath}/canadianbuild/$HOST/gcc
cd ${currentpath}/canadianbuild/$HOST/gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$CANADIANHOSTPREFIXTARGET/include/c++/v1 --prefix=$CANADIANHOSTPREFIX $CANADIANCROSSTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON
fi
if [ ! -d $CANADIANHOSTPREFIX/lib/gcc ]; then
make -j$(nproc)
make install-strip -j$(nproc)
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > $CANADIANHOSTPREFIX/lib/gcc/$HOST/$GCCVERSIONSTR/include/limits.h
fi

if [ ! -f $CANADIANHOSTPREFIXTARGET/include/stdio.h ]; then
	cp -r ${currentpath}/install/linux/* $CANADIANHOSTPREFIXTARGET/
	cp -r ${currentpath}/install/musl/* $CANADIANHOSTPREFIXTARGET/
fi

cd ${CANADIANHOSTPREFIX}/..
if [ ! -f ${HOST}.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
	chmod 755 $HOST.tar.xz
fi


if [ -z ${CANADIAN2HOST+x} ]; then
	CANADIAN2HOST=x86_64-generic-linux-gnu
fi
export PATH=$TOOLCHAINSPATH_GNU/$BUILD/$CANADIAN2HOST/bin:$PATH
CANADIAN2HOSTPREFIX=$TOOLCHAINSPATH_GNU/$CANADIAN2HOST/$HOST
CANADIAN2HOSTPREFIXTARGET=$CANADIAN2HOSTPREFIX/$HOST
CANADIAN2CROSSTRIPLETTRIPLETS="--build=$BUILD --host=$CANADIAN2HOST --target=$HOST"


if ! [ -x "$(command -v ${CANADIAN2HOST}-g++)" ];
then
        echo "${CANADIAN2HOST}-g++ not found. we won't build canadian cross toolchain2"
        exit 0
fi

mkdir -p ${currentpath}/canadian2build
mkdir -p ${currentpath}/canadian2build/$HOST
cd ${currentpath}/canadian2build/$HOST
mkdir -p ${currentpath}/canadian2build/$HOST/binutils-gdb
cd ${currentpath}/canadian2build/$HOST/binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --enable-gold $CANADIAN2CROSSTRIPLETTRIPLETS --prefix=$CANADIAN2HOSTPREFIX
fi

if [ ! -d $CANADIAN2HOSTPREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
make install-strip
fi
cd ${currentpath}/canadian2build/$HOST

mkdir -p ${currentpath}/canadian2build/$HOST/gcc
cd ${currentpath}/canadian2build/$HOST/gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$CANADIAN2HOSTPREFIXTARGET/include/c++/v1 --prefix=$CANADIAN2HOSTPREFIX $CANADIAN2CROSSTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON
fi
if [ ! -d $CANADIAN2HOSTPREFIX/lib/gcc ]; then
make -j$(nproc)
make install-strip -j$(nproc)
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > $CANADIAN2HOSTPREFIX/lib/gcc/$HOST/$GCCVERSIONSTR/include/limits.h
fi

if [ ! -f $CANADIAN2HOSTPREFIXTARGET/include/stdio.h ]; then
	cp -r ${currentpath}/install/linux/* $CANADIAN2HOSTPREFIXTARGET/
	cp -r ${currentpath}/install/musl/* $CANADIAN2HOSTPREFIXTARGET/
fi

cd ${CANADIAN2HOSTPREFIX}/..
if [ ! -f ${HOST}.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
	chmod 755 $HOST.tar.xz
fi