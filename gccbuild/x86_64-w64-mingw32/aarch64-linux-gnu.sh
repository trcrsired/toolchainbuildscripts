#!/bin/bash
relpath=$(realpath .)
currentpath=$relpath/artifacts
if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$currentpath/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$currentpath/toolchains
fi

if [ -z ${HOST+x} ]; then
	HOST=aarch64-linux-gnu
fi
if [ -z ${CANDADIANHOST+x} ]; then
	CANDADIANHOST=x86_64-w64-mingw32
fi

if [ -z ${GCCVERSIONSTR} ]; then
	GCCVERSIONSTR="14.0.0"
fi

BUILD=$(gcc -dumpmachine)
TARGET=$BUILD
PREFIX=$TOOLCHAINSPATH/$BUILD/$HOST
PREFIXTARGET=$PREFIX/$HOST
export PATH=$PREFIX/bin:$PATH

HOSTPREFIX=$TOOLCHAINSPATH/$HOST/$HOST
HOSTPREFIXTARGET=$HOSTPREFIX/$HOST

CANADIANHOST=x86_64-w64-mingw32
export PATH=$TOOLCHAINSPATH/$BUILD/$CANADIANHOST/bin:$PATH
CANADIANHOSTPREFIX=$TOOLCHAINSPATH/$CANADIANHOST/$HOST
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

if [ ! -d ${currentpath} ]; then
	mkdir ${currentpath}
	cd ${currentpath}
fi

CROSSTRIPLETTRIPLETS="--build=$BUILD --host=$BUILD --target=$HOST"
CANADIANTRIPLETTRIPLETS="--build=$BUILD --host=$HOST --target=$HOST"
CANADIANCROSSTRIPLETTRIPLETS="--build=$BUILD --host=$CANADIANHOST --target=$HOST"
GCCCONFIGUREFLAGSCOMMON="--disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib  --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --enable-libstdcxx-threads --enable-libstdcxx-backtrace"

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
make -j16
make install-strip -j
fi

mkdir -p ${currentpath}/targetbuild/$HOST/gcc_phase1
cd ${currentpath}/targetbuild/$HOST/gcc_phase1
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX $CROSSTRIPLETTRIPLETS --disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib  --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --disable-libstdcxx-threads --disable-libstdcxx-backtrace --disable-hosted-libstdcxx --without-headers --disable-shared --disable-threads --disable-libsanitizer --disable-libquadmath --disable-libatomic --disable-libssp
fi

if [ ! -d $PREFIX/lib/gcc ]; then
make all-gcc -j16
make all-target-libgcc -j16
make install-strip-gcc -j
make install-strip-target-libgcc -j
fi

cd ${currentpath}
mkdir -p build
if [ ! -d "${currentpath}/install/glibc" ]; then
	multilibs=(m64)
	multilibsdir=(lib)
	glibcfiles=(libm.a libm.so libc.so)

	linuxkernelheaders=${currentpath}/install/linux

	if [ ! -d $linuxkernelheaders ]; then
		cd "$TOOLCHAINS_BUILD/linux"
		make headers_install ARCH=arm64 -j INSTALL_HDR_PATH=$linuxkernelheaders
	fi

	mkdir -p ${currentpath}/build/glibc
	mkdir -p ${currentpath}/install/glibc

	for item in "${multilibs[@]}"; do
		mkdir -p ${currentpath}/build/glibc/$item
		cd ${currentpath}/build/glibc/$item
		host=aarch64-linux-gnu
		if [ ! -f Makefile ]; then
			$TOOLCHAINS_BUILD/glibc/configure --disable-nls --disable-werror --prefix=$currentpath/install/glibc/${item} --build=$BUILD --with-headers=$linuxkernelheaders/include --without-selinux --host=$HOST
		fi
		if [[ ! -d $currentpath/install/glibc/${item} ]]; then
			make -j16
			make install -j16
		fi
	done

	mkdir -p ${currentpath}/install/glibc
	cd ${currentpath}/install/glibc
	mkdir -p ${currentpath}/install/glibc/canadian
	mkdir -p ${currentpath}/install/glibc/.canadiantemp
	for item in "${multilibs[@]}"; do
		cd ${currentpath}/install/glibc
		glibclibname=lib
		cp -r $item/include canadian/
		cp -r $item/lib .canadiantemp/
		mv .canadiantemp/lib .canadiantemp/$glibclibname
		mv .canadiantemp/$glibclibname canadian/
		strip --strip-unneeded canadian/$glibclibname/* canadian/$glibclibname/audit/* canadian/$glibclibname/gconv/*
		canadianreplacedstring=$currentpath/install/glibc/${item}/lib/

		for file in canadian/$glibclibname/*; do
			if [[ ! -d "$file" ]]; then
				getfilesize=$(wc -c <"$file")
				if [ $getfilesize -lt 1024 ]; then
					for file2 in "${glibcfiles[@]}"; do
						if [[ $file == "canadian/$glibclibname/$file2" ]]; then
							sed -i "s%${canadianreplacedstring}%%g" $file
							break
						fi
					done
				fi
				unset getfilesize
			fi
		done
	done
fi

if [ ! -f $PREFIXTARGET/include/stdio.h ]; then
	cp -r ${currentpath}/install/linux/* $PREFIXTARGET/
	cp -r ${currentpath}/install/glibc/canadian/* $PREFIXTARGET/
fi

if [ ! -d $PREFIXTARGET/include/c++ ]; then
	mkdir -p ${currentpath}/targetbuild/$HOST/gcc
	cd ${currentpath}/targetbuild/$HOST/gcc
	if [ ! -f Makefile ]; then
		$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX ${CROSSTRIPLETTRIPLETS} ${GCCCONFIGUREFLAGSCOMMON}
	fi
	make -j16
	make install-strip -j
	cp "$relpath/limits.h" "$PREFIX/lib/gcc/$HOST/$GCCVERSIONSTR/include/"
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
make -j16
make install-strip -j
fi
cd ${currentpath}/hostbuild/$HOST

mkdir -p ${currentpath}/hostbuild/$HOST/gcc
cd ${currentpath}/hostbuild/$HOST/gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$HOSTPREFIXTARGET/include/c++/v1 --prefix=$HOSTPREFIX $CANADIANTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON
fi
if [ ! -d $HOSTPREFIX/lib/gcc ]; then
make -j16
make install-strip -j
cp "$relpath/limits.h" "$HOSTPREFIX/lib/gcc/$HOST/$GCCVERSIONSTR/include/"
fi

if [ ! -f $HOSTPREFIX/include/stdio.h ]; then
	cp -r ${currentpath}/install/linux/* $HOSTPREFIX/
	cp -r ${currentpath}/install/glibc/canadian/include $HOSTPREFIX/
	mkdir -p $HOSTPREFIX/runtimes
	cp -r ${currentpath}/install/glibc/canadian/* $HOSTPREFIX/runtimes/
fi

cd $TOOLCHAINSPATH/$HOST
if [ ! -f $HOST.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
	chmod 755 $HOST.tar.xz
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
make -j16
make install-strip
fi
cd ${currentpath}/canadianbuild/$HOST

mkdir -p ${currentpath}/canadianbuild/$HOST/gcc
cd ${currentpath}/canadianbuild/$HOST/gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$CANADIANHOSTPREFIXTARGET/include/c++/v1 --prefix=$CANADIANHOSTPREFIX $CANADIANCROSSTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON
fi
if [ ! -d $CANADIANHOSTPREFIX/lib/gcc ]; then
make -j16
make install-strip -j
cp "$relpath/limits.h" "$CANADIANHOSTPREFIX/lib/gcc/$HOST/$GCCVERSIONSTR/include"
fi

if [ ! -f $CANADIANHOSTPREFIXTARGET/include/stdio.h ]; then
	cp -r ${currentpath}/install/linux/* $CANADIANHOSTPREFIXTARGET/
	cp -r ${currentpath}/install/glibc/canadian/* $CANADIANHOSTPREFIXTARGET/
fi

cd ${CANADIANHOSTPREFIX}/..
if [ ! -f ${HOST}.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
	chmod 755 $HOST.tar.xz
fi

