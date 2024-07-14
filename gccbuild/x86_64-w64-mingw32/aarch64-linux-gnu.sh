#!/bin/bash
relpath=$(realpath .)
if [ -z ${HOST+x} ]; then
	HOST=aarch64-linux-gnu
fi
currentpath=$relpath/.gnuartifacts/$HOST
mkdir -p ${currentpath}
if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi


if [ -z ${CANADIANHOST+x} ]; then
	CANADIANHOST=x86_64-w64-mingw32
fi


BUILD=$(gcc -dumpmachine)
TARGET=$BUILD
PREFIX=$TOOLCHAINSPATH/$BUILD/$HOST
PREFIXTARGET=$PREFIX/$HOST
export PATH=$PREFIX/bin:$PATH
export -n LD_LIBRARY_PATH
HOSTPREFIX=$TOOLCHAINSPATH/$HOST/$HOST
HOSTPREFIXTARGET=$HOSTPREFIX/$HOST

export PATH=$TOOLCHAINSPATH/$BUILD/$CANADIANHOST/bin:$PATH
CANADIANHOSTPREFIX=$TOOLCHAINSPATH/$CANADIANHOST/$HOST
CANADIANHOSTPREFIXTARGET=$CANADIANHOSTPREFIX/$HOST

if [ -z ${GLIBCVERSION+x} ]; then
GLIBCVERSION="2.31"
fi
if [ -z ${GLIBCBRANCH+x} ]; then
GLIBCBRANCH="release/$GLIBCVERSION/master"
fi
if [ -z ${GLIBCREPOPATH+x} ]; then
GLIBCREPOPATH="$TOOLCHAINS_BUILD/glibc"
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
if [ $? -ne 0 ]; then
echo "binutils-gdb clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/binutils-gdb"
git pull --quiet

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/gcc" ]; then
git clone git://gcc.gnu.org/git/gcc.git
if [ $? -ne 0 ]; then
echo "gcc clone failed"
exit 1
fi
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
if [ $? -ne 0 ]; then
echo "mingw-w64 clone failed"
fi
fi
cd "$TOOLCHAINS_BUILD/mingw-w64"
git pull --quiet

if [ ! -d "$GLIBCREPOPATH" ]; then
cd "$TOOLCHAINS_BUILD"
git clone -b $GLIBCBRANCH git://sourceware.org/git/glibc.git "$GLIBCREPOPATH"
if [ $? -ne 0 ]; then
echo "glibc clone failed"
exit 1
fi
fi
cd "$GLIBCREPOPATH"
git pull --quiet

if [ ! -d "$TOOLCHAINS_BUILD/linux" ]; then
cd "$TOOLCHAINS_BUILD"
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
if [ $? -ne 0 ]; then
echo "linux clone failed"
exit 1
fi
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

linuxkernelheaders=${currentpath}/install/linux

if [ ! -d $linuxkernelheaders ]; then
	cd "$TOOLCHAINS_BUILD/linux"
	make headers_install ARCH=arm64 -j INSTALL_HDR_PATH=$linuxkernelheaders
fi

if [ ! -d "${currentpath}/install/glibc" ]; then
	multilibs=(m64)
	multilibsdir=(lib)
	glibcfiles=(libm.a libm.so libc.so)


	mkdir -p ${currentpath}/build/glibc
	mkdir -p ${currentpath}/install/glibc

	for item in "${multilibs[@]}"; do
		mkdir -p ${currentpath}/build/glibc/$item
		cd ${currentpath}/build/glibc/$item
		host=aarch64-linux-gnu
		if [ ! -f Makefile ]; then
			(export -n LD_LIBRARY_PATH; $GLIBCREPOPATH/configure --disable-nls --disable-werror --prefix=$currentpath/install/glibc/${item} --build=$BUILD --with-headers=$linuxkernelheaders/include --without-selinux --host=$HOST )
		fi
		if [[ ! -d $currentpath/install/glibc/${item} ]]; then
			(export -n LD_LIBRARY_PATH; make -j16)
			(export -n LD_LIBRARY_PATH; make install -j16)
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
	cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > `dirname $(${HOST}-gcc -print-libgcc-file-name)`/include/limits.h
fi

GCCVERSIONSTR=$(${HOST}-gcc -dumpversion)

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
make install -j
make install-strip -j
${HOST}-strip --strip-unneeded $HOSTPREFIX/bin/*
${HOST}-strip --strip-unneeded $HOSTPREFIX/lib/*
${HOST}-strip --strip-unneeded $HOSTPREFIX/lib64/*
${HOST}-strip --strip-unneeded $HOSTPREFIX/$HOST/bin/*
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
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > $HOSTPREFIX/lib/gcc/$HOST/$GCCVERSIONSTR/include/limits.h
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
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > $CANADIANHOSTPREFIX/lib/gcc/$HOST/$GCCVERSIONSTR/include/limits.h
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

