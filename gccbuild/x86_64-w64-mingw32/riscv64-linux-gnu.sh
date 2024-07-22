#!/bin/bash

./dependencycheck.sh
if [ $? -ne 0 ]; then
exit 1
fi

relpath=$(realpath .)
if [ -z ${HOST+x} ]; then
	HOST=riscv64-linux-gnu
fi
if [ -z ${ARCH+x} ]; then
	ARCH=riscv
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


if [ ! -f ${currentpath}/targetbuild/$HOST/binutils-gdb/.configuresuccess ]; then
mkdir -p ${currentpath}/targetbuild/$HOST/binutils-gdb
cd ${currentpath}/targetbuild/$HOST/binutils-gdb
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --with-python3 --enable-gold $CROSSTRIPLETTRIPLETS --prefix=$PREFIX
if [ $? -ne 0 ]; then
echo "binutils-gdb build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/binutils-gdb/.configuresuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/binutils-gdb/.buildsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/binutils-gdb
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "binutils-gdb build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/binutils-gdb/.buildsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/binutils-gdb/.installsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/binutils-gdb
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
echo "binutils-gdb install-strip failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/binutils-gdb/.installsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.configuresuccesss ]; then
mkdir -p ${currentpath}/targetbuild/$HOST/gcc_phase1
cd ${currentpath}/targetbuild/$HOST/gcc_phase1
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX $CROSSTRIPLETTRIPLETS --disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib  --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --disable-libstdcxx-threads --disable-libstdcxx-backtrace --disable-hosted-libstdcxx --without-headers --disable-shared --disable-threads --disable-libsanitizer --disable-libquadmath --disable-libatomic --disable-libssp
if [ $? -ne 0 ]; then
echo "gcc phase1 configure failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.configuresuccesss
fi
if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.buildgccsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/gcc_phase1
make all-gcc -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc phase1 build gcc failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.buildgccsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.buildlibgccsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/gcc_phase1
make all-target-libgcc -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc phase1 build libgccgcc failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.buildlibgccsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.installstripgccsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/gcc_phase1
make install-strip-gcc -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc phase1 install strip gcc failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.installstripgccsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.installstripgccsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/gcc_phase1
make install-strip-gcc -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc phase1 install strip gcc failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.installstripgccsuccess
fi


if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.installstriplibgccsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/gcc_phase1
make install-strip-target-libgcc -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc phase1 install strip libgcc failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.installstriplibgccsuccess
fi

cd ${currentpath}
mkdir -p build

linuxkernelheaders=${currentpath}/install/sysroot
SYSROOT=${currentpath}/install/sysroot
mkdir -p $SYSROOT

if [ ! -f ${currentpath}/install/.linuxkernelheadersinstallsuccess ]; then
	cd "$TOOLCHAINS_BUILD/linux"
	make headers_install ARCH=$ARCH -j INSTALL_HDR_PATH=$linuxkernelheaders
	if [ $? -ne 0 ]; then
	echo "linux kernel headers install failure"
	exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.linuxkernelheadersinstallsuccess
fi

if [ ! -f ${currentpath}/install/.glibcinstallsuccess ]; then
	if [[ ${ARCH} == "riscv" ]]; then
		multilibs=(default lp64 lp64d ilp32 ilp32d)
		multilibsoptions=("" " -march=lp64" " -march=lp64d" " -march=ilp32" " -march=ilp32d")
		multilibsdir=("lib64" "lib64/lp64" "lib64/lp64d" "lib32/ilp32" "lib32/ilp32d")
		multilibshost=("riscv64-linux-gnu" "riscv64-linux-gnu" "riscv64-linux-gnu" "riscv64-linux-gnu" "riscv64-linux-gnu")
	else
		multilibs=(default)
		multilibsoptions=("")
		multilibsdir=("lib64")
		multilibshost=($HOST)
	fi
	glibcfiles=(libm.a libm.so libc.so)


	mkdir -p ${currentpath}/build/glibc
	mkdir -p ${currentpath}/install/sysroot

	for i in "${!multilibs[@]}"; do
		local item=${multilibs[$i]}
		local marchitem=${multilibsoptions[$i]}
		local libdir=${multilibsdir[$i]}
		local host=${multilibshost[$i]}
		mkdir -p ${currentpath}/build/glibc/$item
		cd ${currentpath}/build/glibc/$item
		
		if [ ! -f ${currentpath}/build/glibc/$item/.configuresuccess ]; then
			(export -n LD_LIBRARY_PATH; STRIP=$HOST-strip CC="$HOST-gcc$marchitem" CXX="$HOST-gcc$marchitem" $GLIBCREPOPATH/configure --disable-nls --disable-werror --prefix=$currentpath/install/glibc/${item} --build=$BUILD --with-headers=$SYSROOT/include --without-selinux --host=$HOST )
			if [ $? -ne 0 ]; then
				echo "glibc ($item) configure failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.configuresuccess
		fi
		if [ ! -f ${currentpath}/build/glibc/$item/.buildsuccess ]; then
			(export -n LD_LIBRARY_PATH; make -j$(nproc))
			if [ $? -ne 0 ]; then
				echo "glibc ($item) build failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.buildsuccess
		fi
		if [ ! -f ${currentpath}/build/glibc/$item/.installsuccess ]; then
			(export -n LD_LIBRARY_PATH; make install -j$(nproc))
			if [ $? -ne 0 ]; then
				echo "glibc ($item) install failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.installsuccess
		fi
		if [ ! -f ${currentpath}/build/glibc/$item/.stripsuccess ]; then
			$HOST-strip --strip-unneeded $currentpath/install/glibc/${item}/lib/* $currentpath/install/glibc/${item}/lib/audit/* $currentpath/install/glibc/${item}/lib/gconv/*
			if [ $? -ne 0 ]; then
				echo "glibc ($item) strip failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.stripsuccess
		fi
		if [ ! -f ${currentpath}/build/glibc/$item/.sysrootsuccess ]; then
			mkdir -p $SYSROOT/$libdir
			cp -r --preserve=links ${currentpath}/build/glibc/$item/include $SYSROOT/
			cp -r --preserve=links ${currentpath}/build/glibc/$item/lib $SYSROOT/$libdir
			echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.sysrootsuccess
		fi
	done
	echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.glibcinstallsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.copysysrootsuccess ]; then
cp -r --preserve=links $SYSROOT $PREFIXTARGET
if [ $? -ne 0 ]; then
echo "gcc phase1 copysysroot failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.copysysrootsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.generatelimitssuccess ]; then
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > `dirname $(${HOST}-gcc -print-libgcc-file-name)`/include/limits.h
if [ $? -ne 0 ]; then
echo "gcc phase1 generate limits failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.generatelimitssuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.configuresuccesss ]; then
mkdir -p ${currentpath}/targetbuild/$HOST/gcc_phase2
cd ${currentpath}/targetbuild/$HOST/gcc_phase2
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX $CROSSTRIPLETTRIPLETS ${CROSSTRIPLETTRIPLETS} ${GCCCONFIGUREFLAGSCOMMON}
if [ $? -ne 0 ]; then
echo "gcc phase2 configure failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.configuresuccesss
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.buildgccsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/gcc_phase2
make all-gcc -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc phase2 build gcc failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.buildgccsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.installstripgccsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/gcc_phase2
make install-strip-gcc -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc phase2 install strip gcc failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.installstripgccsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.generatelimitssuccess ]; then
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > `dirname $(${HOST}-gcc -print-libgcc-file-name)`/include/limits.h
if [ $? -ne 0 ]; then
echo "gcc phase2 generate limits failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.generatelimitssuccess
fi

GCCVERSIONSTR=$(${HOST}-gcc -dumpversion)

if ! [ -x "$(command -v ${CANADIANHOST}-g++)" ];
then
        echo "${CANADIANHOST}-g++ not found. we need another cross compiler to get around gcc bug. failed"
        exit 1
fi

exit 0

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
	cp -r ${currentpath}/install/glibc/canadian/* $CANADIANHOSTPREFIXTARGET/
fi

cd ${CANADIANHOSTPREFIX}/..
if [ ! -f ${HOST}.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
	chmod 755 $HOST.tar.xz
fi







mkdir -p ${currentpath}/hostbuild
mkdir -p ${currentpath}/hostbuild/$HOST
cd ${currentpath}/hostbuild/$HOST
mkdir -p ${currentpath}/hostbuild/$HOST/binutils-gdb
cd ${currentpath}/hostbuild/$HOST/binutils-gdb
if [ ! -f Makefile ]; then
STRIP=$HOST-strip $TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --enable-gold $CANADIANTRIPLETTRIPLETS --prefix=$HOSTPREFIX
if [ $? -ne 0 ]; then
	echo "binutils configure failure"
	exit 1
fi
fi

if [ ! -d $HOSTPREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
if [ $? -ne 0 ]; then
	echo "gcc build failure"
	exit 1
fi
make install -j$(nproc)
if [ $? -ne 0 ]; then
	echo "gcc install failure"
	exit 1
fi
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
	echo "gcc install-strip failure"
	exit 1
fi
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
make -j$(nproc)
make install-strip -j$(nproc)
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
