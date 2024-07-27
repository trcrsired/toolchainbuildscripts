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

if [[ $1 == "clean" ]]; then
	echo "cleaning"
	rm -rf ${currentpath}
	echo "clean done"
	exit 0
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf ${currentpath}
	rm -rf ${PREFIX}
	rm -f ${PREFIX}.tar.xz
	rm -rf ${CANADIANHOSTPREFIX}
	rm -f ${CANADIANHOSTPREFIX}.tar.xz
	rm -rf ${HOSTPREFIXTARGET}
	rm -f ${HOSTPREFIXTARGET}.tar.xz
	echo "restart done"
fi

if [ ! -d ${currentpath} ]; then
	mkdir ${currentpath}
	cd ${currentpath}
fi

CROSSTRIPLETTRIPLETS="--build=$BUILD --host=$BUILD --target=$HOST"
if [[ ${ARCH} == "x86_64" ]]; then
MULTILIBLISTS="--with-multilib-list=m32,mx32,m64"
else
MULTILIBLISTS=
fi
GCCCONFIGUREFLAGSCOMMON="--disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib $MULTILIBLISTS --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --enable-libstdcxx-threads --enable-libstdcxx-backtrace"

if [[ ${ARCH} == "arm64" ]]; then
GCCCONFIGUREFLAGSCOMMON="$GCCCONFIGUREFLAGSCOMMON --disable-libsanitizer"
fi

if [[ ${ARCH} == "loongarch" ]]; then
ENABLEGOLD=
else
ENABLEGOLD="--enable-gold"
fi

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

if [ ! -d "$TOOLCHAINS_BUILD/glibc" ]; then
cd "$TOOLCHAINS_BUILD"
git clone -b stableabi https://github.com/trcrsired/glibc.git
if [ $? -ne 0 ]; then
echo "glibc clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/glibc"
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
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --with-python3 $ENABLEGOLD $CROSSTRIPLETTRIPLETS --prefix=$PREFIX
if [ $? -ne 0 ]; then
echo "binutils-gdb configure failure"
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
STRIP=strip STRIP_FOR_TARGET=$HOST-strip $TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX $MULTILIBLISTS $CROSSTRIPLETTRIPLETS --disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib  --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --disable-libstdcxx-threads --disable-libstdcxx-backtrace --disable-hosted-libstdcxx --without-headers --disable-shared --disable-threads --disable-libsanitizer --disable-libquadmath --disable-libatomic --disable-libssp
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

SYSROOT=${currentpath}/install/sysroot
linuxkernelheaders=${SYSROOT}
GCCSYSROOT=${currentpath}/install/gccsysroot
mkdir -p $SYSROOT
mkdir -p $GCCSYSROOT

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
		multilibsoptions=("" " -march=rv64imac -mabi=lp64" " -march=rv64imafdc -mabi=lp64d" " -march=rv32imac -mabi=ilp32" " -march=rv32imafdc -mabi=ilp32d")
		multilibsdir=("lib64" "lib64/lp64" "lib64/lp64d" "lib32/ilp32" "lib32/ilp32d")
		multilibsingccdir=("" "lib64/lp64" "lib64/lp64d" "lib32/ilp32" "lib32/ilp32d")
		multilibshost=("riscv64-linux-gnu" "riscv64-linux-gnu" "riscv64-linux-gnu" "riscv32-linux-gnu" "riscv32-linux-gnu")
	elif [[ ${ARCH} == "x86_64" ]]; then
		multilibs=(m64 m32 mx32)
		multilibsoptions=(" -m64" " -m32" " -mx32")
		multilibsdir=("lib64" "lib" "libx32")
		multilibsingccdir=("" "32" "x32")
		multilibshost=("x86_64-linux-gnu" "i686-linux-gnu" "x86_64-linux-gnux32")
	else
		multilibs=(default)
		multilibsoptions=("")
		multilibsdir=("lib")
		multilibsingccdir=("")
		multilibshost=("$HOST")
	fi
	glibcfiles=(libm.a libm.so libc.so)


	mkdir -p ${currentpath}/build/glibc
	mkdir -p ${currentpath}/install/sysroot

	for i in "${!multilibs[@]}"; do
		item=${multilibs[$i]}
		marchitem=${multilibsoptions[$i]}
		libdir=${multilibsdir[$i]}
		host=${multilibshost[$i]}
		libingccdir=${multilibsingccdir[$i]}
		mkdir -p ${currentpath}/build/glibc/$item
		cd ${currentpath}/build/glibc/$item
		if [ ! -f ${currentpath}/build/glibc/$item/.configuresuccess ]; then
			(export -n LD_LIBRARY_PATH; STRIP=$HOST-strip CC="$HOST-gcc$marchitem" CXX="$HOST-g++$marchitem" $TOOLCHAINS_BUILD/glibc/configure --disable-nls --disable-werror --prefix=$currentpath/install/glibc/${item} --build=$BUILD --with-headers=$SYSROOT/include --without-selinux --host=$host )
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

		if [ ! -f ${currentpath}/build/glibc/$item/.removehardcodedpathsuccess ]; then
			canadianreplacedstring=$currentpath/install/glibc/${item}/lib/
			for file in "${glibcfiles[@]}"; do
				filepath=$canadianreplacedstring/$file
				if [ -f "$filepath" ]; then
					getfilesize=$(wc -c <"$filepath")
					echo $getfilesize
					if [ $getfilesize -lt 1024 ]; then
						sed -i "s%${canadianreplacedstring}%%g" $filepath
						echo "removed hardcoded path: $filepath"
					fi
				fi
				unset filepath
			done
			unset canadianreplacedstring
			echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.removehardcodedpathsuccess
		fi

		if [ ! -f ${currentpath}/build/glibc/$item/.stripsuccess ]; then
			$HOST-strip --strip-unneeded $currentpath/install/glibc/${item}/lib/* $currentpath/install/glibc/${item}/lib/audit/* $currentpath/install/glibc/${item}/lib/gconv/*
			echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.stripsuccess
		fi
		if [ ! -f ${currentpath}/build/glibc/$item/.sysrootsuccess ]; then
			cp -r --preserve=links ${currentpath}/install/glibc/$item/include $SYSROOT/
			mkdir -p $SYSROOT/$libdir
			cp -r --preserve=links ${currentpath}/install/glibc/$item/lib/* $SYSROOT/$libdir
			mkdir -p $GCCSYSROOT/$libingccdir
			cp -r --preserve=links ${currentpath}/install/glibc/$item/lib/* $GCCSYSROOT/$libingccdir
			echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.sysrootsuccess
		fi
		unset item
		unset marchitem
		unset libdir
		unset host
	done
	echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.glibcinstallsuccess
fi

GCCVERSIONSTR=$(${HOST}-gcc -dumpversion)

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.copysysrootsuccess ]; then
cp -r --preserve=links $SYSROOT/include $PREFIXTARGET/
cp -r --preserve=links $GCCSYSROOT/* `dirname $(${HOST}-gcc -print-libgcc-file-name)`/
if [ $? -ne 0 ]; then
echo "gcc phase1 copysysroot failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.copysysrootsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.configuresuccesss ]; then
mkdir -p ${currentpath}/targetbuild/$HOST/gcc_phase2
cd ${currentpath}/targetbuild/$HOST/gcc_phase2
STRIP=strip STRIP_FOR_TARGET=$HOST-strip $TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX $CROSSTRIPLETTRIPLETS ${GCCCONFIGUREFLAGSCOMMON} --with-build-sysroot=$SYSROOT
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

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.generatelimitssuccess ]; then
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > ${currentpath}/targetbuild/$HOST/gcc_phase2/gcc/include/limits.h
if [ $? -ne 0 ]; then
echo "gcc phase2 generate limits failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.generatelimitssuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.buildsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/gcc_phase2
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc phase2 build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.buildsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.installstripsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/gcc_phase2
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
make install -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc phase2 install strip failure"
exit 1
fi
${BUILD}-strip --strip-unneeded $prefix/bin/* $prefixtarget/bin/*
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.installstripsuccess
fi

function handlebuild
{
local hosttriple=$1
local build_prefix=${currentpath}/${hosttriple}/${HOST}
local prefix=${TOOLCHAINSPATH}/${hosttriple}/${HOST}
local prefixtarget=${prefix}/${HOST}

mkdir -p ${build_prefix}

if [ ! -f ${build_prefix}/binutils-gdb/.configuresuccess ]; then
mkdir -p ${build_prefix}/binutils-gdb
cd $build_prefix/binutils-gdb
STRIP=${hosttriple}-strip STRIP_FOR_TARGET=$HOST-strip $TOOLCHAINS_BUILD/binutils-gdb/configure  --disable-nls --disable-werror $ENABLEGOLD --prefix=$prefix --build=$BUILD --host=$hosttriple --target=$HOST
if [ $? -ne 0 ]; then
echo "binutils-gdb (${hosttriple}/${HOST}) configure failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${build_prefix}/binutils-gdb/.configuresuccess
fi

if [ ! -f ${build_prefix}/binutils-gdb/.buildsuccess ]; then
cd $build_prefix/binutils-gdb
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "binutils-gdb (${hosttriple}/${HOST}) build failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${build_prefix}/binutils-gdb/.buildsuccess
fi

if [ ! -f ${build_prefix}/binutils-gdb/.installsuccess ]; then
cd $build_prefix/binutils-gdb
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
make install -j$(nproc)
if [ $? -ne 0 ]; then
echo "binutils-gdb (${hosttriple}/${HOST}) install failed"
exit 1
fi
$hosttriple-strip --strip-unneeded $prefix/bin/* $prefixtarget/bin/*
fi
echo "$(date --iso-8601=seconds)" > ${build_prefix}/binutils-gdb/.installsuccess
fi

if [ ! -f ${build_prefix}/gcc/.configuresuccess ]; then
mkdir -p ${build_prefix}/gcc
cd $build_prefix/gcc
STRIP=${hosttriple}-strip STRIP_FOR_TARGET=$HOST-strip $TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$prefixtarget/include/c++/v1 --prefix=$prefix --build=$BUILD --host=$hosttriple --target=$HOST $GCCCONFIGUREFLAGSCOMMON
if [ $? -ne 0 ]; then
echo "gcc (${hosttriple}/${HOST}) configure failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.configuresuccess
fi

if [ ! -f ${build_prefix}/gcc/.buildsuccess ]; then
cd $build_prefix/gcc
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc (${hosttriple}/${HOST}) build failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.buildsuccess
fi

if [ ! -f ${build_prefix}/gcc/.installsuccess ]; then
cd $build_prefix/gcc
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
make install -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc (${hosttriple}/${HOST}) install failed"
exit 1
fi
$hosttriple-strip --strip-unneeded $prefix/bin/* $prefixtarget/bin/*
fi
echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.installsuccess
fi

if [ ! -f ${build_prefix}/.installsysrootsuccess ]; then
local prefixcross=$prefix

if [[ ${hosttriple} != ${HOST} ]]; then
prefixcross=$prefix/$HOST
fi
cp -r --preserve=links $SYSROOT/include ${prefixcross}/
cp -r --preserve=links $GCCSYSROOT/* ${prefix}/lib/gcc/$HOST/$GCCVERSIONSTR/
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > ${prefix}/lib/gcc/$HOST/$GCCVERSIONSTR/include/limits.h

echo "$(date --iso-8601=seconds)" > ${build_prefix}/.installsysrootsuccess
fi
if [ ! -f ${build_prefix}/.packagingsuccess ]; then
	cd ${TOOLCHAINSPATH}/${hosttriple}
	rm -f $HOST.tar.xz
	XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
	chmod 755 $HOST.tar.xz
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/.packagingsuccess
fi
}


if [[ ${ARCH} == "loongarch" ]]; then
echo "loongarch hasn't yet got supported. skip"
else
handlebuild ${HOST}
fi

if [ -x "$(command -v ${CANADIANHOST}-g++)" ]; then
handlebuild ${CANADIANHOST}
else
echo "${CANADIANHOST}-g++ not found. skipped"
fi
