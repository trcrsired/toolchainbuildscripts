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
export -n LD_LIBRARY_PATH
HOSTPREFIX=$TOOLCHAINSPATH_GNU/$HOST/$HOST
HOSTPREFIXTARGET=$HOSTPREFIX/$HOST

export PATH=$TOOLCHAINSPATH_GNU/$BUILD/$CANADIANHOST/bin:$PATH
CANADIANHOSTPREFIX=$TOOLCHAINSPATH_GNU/$CANADIANHOST/$HOST

NEW_BUILD=$(echo "$BUILD" | sed 's/-pc//g')

if [[ "${NEW_BUILD}" == "${HOST}" ]]; then
    echo "here"
    export PATH="$TOOLCHAINSPATH_GNU/${TARGET}/${TARGET}/bin:$PATH"
fi

echo "gcc=$(which gcc)
cc=$(which cc)
g++=$(which g++)
PATH=$PATH
HOST=${HOST}
TARGET=$TARGET
NEWBUILD=${NEW_BUILD}"

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

if [[ ${FREESTANDINGBUILD} == "yes" ]]; then
MULTILIBLISTS="--disable-shared \
--disable-threads \
--disable-nls \
--disable-werror \
--enable-languages=c,c++ \
--enable-multilib \
--disable-bootstrap \
--disable-libstdcxx-verbose \
--with-libstdcxx-eh-pool-obj-count=0 \
--disable-sjlj-exceptions"
if [[ ${USE_NEWLIB} == "yes" ]]; then
MULTILIBLISTS="$MULTILIBLISTS --with-newlib"
else
MULTILIBLISTS="$MULTILIBLISTS \
--disable-hosted-libstdcxx \
--disable-libssp \
--disable-libquadmath \
--disable-libbacktarce"
fi
elif [[ ${MUSLLIBC} == "yes" ]]; then
MULTILIBLISTS="--disable-multilib --disable-shared --enable-static"
else
if [[ ${ARCH} == "x86_64" ]]; then
MULTILIBLISTS="--with-multilib-list=m64"
else
MULTILIBLISTS=
fi
if [[ ${ARCH} == "sparc" ]]; then
MULTILIBLISTS="--disable-multilib"
else
MULTILIBLISTS="--disable-multilib $MULTILIBLISTS"
fi
fi

if [[ ${FREESTANDINGBUILD} == "yes" ]]; then
GCCCONFIGUREFLAGSCOMMON="--disable-nls \
--disable-werror \
--enable-languages=c,c++ \
$MULTILIBLISTS \
--disable-bootstrap \
--with-libstdcxx-eh-pool-obj-count=0 \
--disable-sjlj-exceptions"
else
GCCCONFIGUREFLAGSCOMMON="--disable-nls \
--disable-werror \
--enable-languages=c,c++ \
$MULTILIBLISTS \
--disable-bootstrap \
--disable-libstdcxx-verbose \
--with-libstdcxx-eh-pool-obj-count=0 \
--disable-sjlj-exceptions \
--enable-libstdcxx-threads \
--enable-libstdcxx-backtrace"
fi

if [[ ${ARCH} == "arm64" || ${ARCH} == "riscv" || ${MUSLLIBC} == "yes" ]]; then
GCCCONFIGUREFLAGSCOMMON="$GCCCONFIGUREFLAGSCOMMON --disable-libsanitizer"
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
if [[ ${FREESTANDINGBUILD} != "yes" ]]; then
if [[ ${MUSLLIBC} == "yes" ]]; then
if [ ! -d "$TOOLCHAINS_BUILD/musl" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git@github.com:bminor/musl.git
if [ $? -ne 0 ]; then
echo "musl clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/musl"
git pull --quiet
else
if [ ! -d "$TOOLCHAINS_BUILD/glibc" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git://sourceware.org/git/glibc.git
if [ $? -ne 0 ]; then
echo "glibc clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/glibc"
git pull --quiet
fi
fi

if [[ ${USE_NEWLIB} == "yes" ]]; then

if [ -z "${CUSTOM_BUILD_SYSROOT}" ]; then
if [ ! -d "$TOOLCHAINS_BUILD/newlib-cygwin" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git@github.com:mirror/newlib-cygwin.git
if [ $? -ne 0 ]; then
echo "newlib-cygwin clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/newlib-cygwin"
git pull --quiet
fi

fi
if [[ ${FREESTANDINGBUILD} != "yes" ]]; then
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
fi

if [[ ${USELLVM} == "yes" ]]; then
HOSTSTRIP=llvm-strip
else
HOSTSTRIP=$HOST-strip
fi
isnativebuild=
if [[ $BUILD == $HOST ]]; then
isnativebuild=yes
fi

if [[ $isnativebuild != "yes" ]]; then

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

	if [[ ${FREESTANDINGBUILD} == "yes" ]]; then
		if [ ! -f ${currentpath}/targetbuild/$HOST/gcc/.configuresuccesss ]; then
			mkdir -p ${currentpath}/targetbuild/$HOST/gcc
			cd ${currentpath}/targetbuild/$HOST/gcc
			STRIP=strip STRIP_FOR_TARGET=$HOSTSTRIP $TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIX/usr/include/c++/v1 --prefix=$PREFIX $MULTILIBLISTS $CROSSTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON
			if [ $? -ne 0 ]; then
				echo "gcc configure failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc/.configuresuccesss
		fi
	else
		if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.configuresuccesss ]; then
			mkdir -p ${currentpath}/targetbuild/$HOST/gcc_phase1
			cd ${currentpath}/targetbuild/$HOST/gcc_phase1
			STRIP=strip STRIP_FOR_TARGET=$HOSTSTRIP $TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIX/include/c++/v1 --prefix=$PREFIX $MULTILIBLISTS $CROSSTRIPLETTRIPLETS --disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib  --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --disable-libstdcxx-threads --disable-libstdcxx-backtrace --disable-hosted-libstdcxx --without-headers --disable-shared --disable-threads --disable-libsanitizer --disable-libquadmath --disable-libatomic --disable-libssp
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
				echo "gcc phase1 build libgcc failure"
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
	fi
fi

if [[ ${USE_NEWLIB} == "yes" ]]; then
	if [ ! -f ${currentpath}/targetbuild/$HOST/gcc/.buildgccsuccess ]; then
		cd ${currentpath}/targetbuild/$HOST/gcc
		make all-gcc -j$(nproc)
		if [ $? -ne 0 ]; then
			echo "gcc build gcc failure"
			exit 1
		fi
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc/.buildgccsuccess
	fi

	if [ ! -f ${currentpath}/targetbuild/$HOST/gcc/.buildinstallstripgccsuccess ]; then
		cd ${currentpath}/targetbuild/$HOST/gcc
		make install-strip-gcc -j$(nproc)
		if [ $? -ne 0 ]; then
			echo "gcc install-strip gcc failure"
			exit 1
		fi
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc/.buildinstallstripgccsuccess
	fi

	SYSROOT=${PREFIXTARGET}
	GCCVERSIONSTR=$(${HOST}-gcc -dumpversion)
	mkdir -p ${SYSROOT}/usr
	mkdir -p ${currentpath}/targetbuild/$HOST/newlib-cygwin

	if [ -z "${CUSTOM_BUILD_SYSROOT}" ]; then
		if [ ! -f ${currentpath}/targetbuild/$HOST/newlib-cygwin/.configurenewlibsuccess ]; then
			cd ${currentpath}/targetbuild/$HOST/newlib-cygwin
			$TOOLCHAINS_BUILD/newlib-cygwin/configure --disable-werror --disable-nls --build=$BUILD --target=$HOST --prefix=${currentpath}/install/newlib-cygwin
			if [ $? -ne 0 ]; then
				echo "configure newlib-cygwin failure"
				exit 1
			fi
			cp -r --preserve=links ${currentpath}/install/newlib-cygwin/$HOST/* $SYSROOT/usr/
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/newlib-cygwin/.configurenewlibsuccess
		fi

		if [ ! -f ${currentpath}/targetbuild/$HOST/newlib-cygwin/.makenewlibsuccess ]; then
			cd ${currentpath}/targetbuild/$HOST/newlib-cygwin
			make -j$(nproc)
			if [ $? -ne 0 ]; then
				echo "make newlib-cygwin failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/newlib-cygwin/.makenewlibsuccess
		fi

		if [ ! -f ${currentpath}/targetbuild/$HOST/newlib-cygwin/.installstripnewlibsuccess ]; then
			cd ${currentpath}/targetbuild/$HOST/newlib-cygwin
			make install-strip -j$(nproc)
			if [ $? -ne 0 ]; then
				echo "make install-strip newlib-cygwin failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/newlib-cygwin/.installstripnewlibsuccess
		fi

		if [ ! -f ${currentpath}/targetbuild/$HOST/newlib-cygwin/.copysysrootsuccess ]; then
			cp -r --preserve=links ${currentpath}/install/newlib-cygwin/$HOST/* $SYSROOT/usr/
			cp -r --preserve=links ${currentpath}/install/newlib-cygwin/share $SYSROOT/usr/
			if [ $? -ne 0 ]; then
				echo "copy newlib-cygwin failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/newlib-cygwin/.copysysrootsuccess
		fi
	else
		if [ ! -f ${currentpath}/targetbuild/$HOST/newlib-cygwin/.newlibsysrootcopied ]; then
			cp -r --preserve=links "${CUSTOM_BUILD_SYSROOT}/include" $SYSROOT/usr/
			if [ $? -ne 0 ]; then
				echo "copy build sysroot include failed"
				exit 1
			fi
			cp -r --preserve=links "${CUSTOM_BUILD_SYSROOT}/lib" $SYSROOT/usr/
			if [ $? -ne 0 ]; then
				echo "copy build sysroot lib failed"
				exit 1
			fi
			rm -rf "$SYSROOT/include/c++"
			rm -rf "$SYSROOT/lib/ldscripts"
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/newlib-cygwin/.newlibsysrootcopied
		fi
	fi

	if [ ! -f ${currentpath}/targetbuild/$HOST/newlib-cygwin/.installsysrootsuccess ]; then
		cp -r --preserve=links $SYSROOT/* $PREFIX/sysroot/
		if [ $? -ne 0 ]; then
			echo "copy newlib-cygwin failure"
			exit 1
		fi
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/newlib-cygwin/.installsysrootsuccess
	fi
fi

if [[ ${FREESTANDINGBUILD} == "yes" ]]; then
	if [ ! -f ${currentpath}/targetbuild/$HOST/gcc/.buildsuccess ]; then
		cd ${currentpath}/targetbuild/$HOST/gcc
		cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > ${currentpath}/targetbuild/$HOST/gcc/lib/gcc/$HOST/$GCCVERSIONSTR/include/limits.h
		make -j$(nproc)
		if [ $? -ne 0 ]; then
			echo "gcc build failure"
			exit 1
		fi
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc/.buildsuccess
	fi
	if [ ! -f ${currentpath}/targetbuild/$HOST/gcc/.installstripsuccess ]; then
		cd ${currentpath}/targetbuild/$HOST/gcc
		make install-strip -j$(nproc)
		if [ $? -ne 0 ]; then
		echo "gcc install-strip failure"
		exit 1
		fi
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc/.installstripsuccess
	fi
	if [ ! -f ${currentpath}/targetbuild/$HOST/gcc/.packagingsuccess ]; then
		cd ${TOOLCHAINSPATH_GNU}/${BUILD}
		rm -f $HOST.tar.xz
		XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
		chmod 755 $HOST.tar.xz
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc/.packagingsuccess
	fi
else

	cd ${currentpath}
	mkdir -p build

	SYSROOT=${currentpath}/install/sysroot
	linuxkernelheaders=${SYSROOT}
	mkdir -p $SYSROOT

	if [ ! -f ${currentpath}/install/.linuxkernelheadersinstallsuccess ]; then
		cd "$TOOLCHAINS_BUILD/linux"
		make headers_install ARCH=$ARCH -j INSTALL_HDR_PATH=${SYSROOT}/usr
		if [ $? -ne 0 ]; then
			echo "linux kernel headers install failure"
			exit 1
		fi
		echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.linuxkernelheadersinstallsuccess
	fi

	if [[ ${ARCH} == "riscv" ]]; then
		multilibs=(default lp64 lp64d ilp32 ilp32d)
		multilibsoptions=("" " -march=rv64imac -mabi=lp64" " -march=rv64imafdc -mabi=lp64d" " -march=rv32imac -mabi=ilp32" " -march=rv32imafdc -mabi=ilp32d")
		multilibsdir=("lib64" "lib64/lp64" "lib64/lp64d" "lib32/ilp32" "lib32/ilp32d")
		multilibsingccdir=("" "lib64/lp64" "lib64/lp64d" "lib32/ilp32" "lib32/ilp32d")
		multilibshost=("riscv64-linux-gnu" "riscv64-linux-gnu" "riscv64-linux-gnu" "riscv32-linux-gnu" "riscv32-linux-gnu")
	elif [[ ${ARCH} == "x86_64" ]]; then
# 32 bit and x32 are phased out from linux kernel. There are completely useless. Just use wine if you need 32 bit
#		multilibs=(m64 m32 mx32)
#		multilibsoptions=(" -m64" " -m32" " -mx32")
#		multilibsdir=("lib64" "lib" "libx32")
#		multilibsingccdir=("" "32" "x32")
#		multilibshost=("x86_64-linux-gnu" "i686-linux-gnu" "x86_64-linux-gnux32")


#		multilibs=(m64 m32 mx32)
#		multilibsoptions=(" -m64" " -m32" " -mx32")
#		multilibsdir=("lib" "lib32" "libx32")
#		multilibsingccdir=("" "32" "x32")
#		multilibshost=("x86_64-linux-gnu" "i686-linux-gnu" "x86_64-linux-gnux32")

		multilibs=(m64)
		multilibsoptions=(" -m64")
		multilibsdir=("lib")
		multilibsingccdir=("")
		multilibshost=("x86_64-linux-gnu")
	elif [[ ${ARCH} == "loongarch64" ]]; then
		multilibs=(m64)
		multilibsoptions=("")
		multilibsdir=("lib64")
		multilibsingccdir=("")
		multilibshost=("loongarch64-linux-gnu")
	else
		multilibs=(default)
		multilibsoptions=("")
		multilibsdir=("lib")
		multilibsingccdir=("")
		multilibshost=("$HOST")
	fi

	if [[ ${MUSLLIBC} == "yes" ]]; then
		if [ ! -f ${currentpath}/install/.muslinstallsuccess ]; then
			item="default"
			marchitem=""
			libdir="lib"
			host=$HOST
			libingccdir=""
			mkdir -p ${currentpath}/build/musl/$item
			cd ${currentpath}/build/musl/$item

			if [ ! -f ${currentpath}/build/musl/$item/.configuresuccess ]; then
				if [[ ${USELLVM} == "yes" ]]; then
					STRIP=llvm-strip AR=llvm-ar CC="clang --target=$host" CXX="clang++ --target=$host" AS=llvm-as RANLIB=llvm-ranlib CXXFILT=llvm-cxxfilt NM=llvm-nm $TOOLCHAINS_BUILD/musl/configure --disable-nls --disable-werror --prefix=$currentpath/install/musl/$item --build=$BUILD --with-headers=$SYSROOT/usr/include --disable-shared --enable-static --without-selinux --host=$host
				else
					(export -n LD_LIBRARY_PATH; STRIP=$HOSTSTRIP CC="$HOST-gcc$marchitem" CXX="$HOST-g++$marchitem" $TOOLCHAINS_BUILD/musl/configure --disable-nls --disable-werror --prefix=$currentpath/install/musl/$item --build=$BUILD --with-headers=$SYSROOT/usr/include --disable-shared --enable-static --without-selinux --host=$host )
				fi
				if [ $? -ne 0 ]; then
					echo "musl configure failure"
					exit 1
				fi
				echo "$(date --iso-8601=seconds)" > ${currentpath}/build/musl/$item/.configuresuccess
			fi
			if [ ! -f ${currentpath}/build/musl/$item/.buildsuccess ]; then
				(export -n LD_LIBRARY_PATH; make -j$(nproc))
				if [ $? -ne 0 ]; then
					echo "musl build failure"
					exit 1
				fi
				echo "$(date --iso-8601=seconds)" > ${currentpath}/build/musl/$item/.buildsuccess
			fi
			if [ ! -f ${currentpath}/build/musl/$item/.installsuccess ]; then
				(export -n LD_LIBRARY_PATH; make install -j$(nproc))
				if [ $? -ne 0 ]; then
					echo "musl install failure"
					exit 1
				fi
				echo "$(date --iso-8601=seconds)" > ${currentpath}/build/musl/$item/.installsuccess
			fi
			if [ ! -f ${currentpath}/build/musl/$item/.stripsuccess ]; then
				$HOSTSTRIP --strip-unneeded $currentpath/install/musl/$item/lib/*
				echo "$(date --iso-8601=seconds)" > ${currentpath}/build/musl/$item/.stripsuccess
			fi
			if [ ! -f ${currentpath}/build/musl/$item/.sysrootsuccess ]; then
				cp -r --preserve=links ${currentpath}/install/musl/$item/include $SYSROOT/
				mkdir -p $SYSROOT/$libdir
				cp -r --preserve=links ${currentpath}/install/musl/$item/lib/* $SYSROOT/$libdir
	#			mkdir -p $GCCSYSROOT/$libingccdir
	#			cp -r --preserve=links ${currentpath}/install/musl/$item/lib/* $GCCSYSROOT/$libingccdir
				echo "$(date --iso-8601=seconds)" > ${currentpath}/build/musl/$item/.sysrootsuccess
			fi
			unset item
			unset marchitem
			unset libdir
			unset host
			unset libingccdir
			echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.muslinstallsuccess
		fi
	elif [ ! -f ${currentpath}/install/.glibcinstallsuccess ]; then
		glibcfiles=(libm.a libm.so libc.so)

		mkdir -p ${currentpath}/build/glibc
		mkdir -p ${currentpath}/install/sysroot/usr

		for i in "${!multilibs[@]}"; do
			item=${multilibs[$i]}
			marchitem=${multilibsoptions[$i]}
			libdir=${multilibsdir[$i]}
			host=${multilibshost[$i]}
			libingccdir=${multilibsingccdir[$i]}
			mkdir -p ${currentpath}/build/glibc/$item
			cd ${currentpath}/build/glibc/$item
			if [ ! -f ${currentpath}/build/glibc/$item/.configuresuccess ]; then
				(export -n LD_LIBRARY_PATH; STRIP=$HOSTSTRIP CC="$HOST-gcc$marchitem" CXX="$HOST-g++$marchitem" $TOOLCHAINS_BUILD/glibc/configure --disable-nls --disable-werror --prefix=$currentpath/install/glibc/${item} --build=$BUILD --with-headers=$SYSROOT/usr/include --without-selinux --host=$host )
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
				$HOSTSTRIP --strip-unneeded $currentpath/install/glibc/${item}/lib/* $currentpath/install/glibc/${item}/lib/audit/* $currentpath/install/glibc/${item}/lib/gconv/*
				echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.stripsuccess
			fi
			if [ ! -f ${currentpath}/build/glibc/$item/.sysrootsuccess ]; then
				cp -r --preserve=links ${currentpath}/install/glibc/$item/include $SYSROOT/usr/
				mkdir -p $SYSROOT/usr/$libdir
				cp -r --preserve=links ${currentpath}/install/glibc/$item/lib/* $SYSROOT/usr/$libdir
#				mkdir -p $GCCSYSROOT/$libingccdir
#				cp -r --preserve=links ${currentpath}/install/glibc/$item/lib/* $GCCSYSROOT/$libingccdir
				echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.sysrootsuccess
			fi
			unset item
			unset marchitem
			unset libdir
			unset host
		done
		echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.glibcinstallsuccess
	fi
fi
GCCVERSIONSTR=$(${HOST}-gcc -dumpversion)

if [[ $isnativebuild != "yes" ]]; then
	mkdir -p $PREFIX/sysroot
	if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.copysysrootsuccess ]; then
		echo cp -r --preserve=links $SYSROOT/usr $PREFIX/sysroot/
		cp -r --preserve=links $SYSROOT/usr $PREFIX/sysroot/
		if [ $? -ne 0 ]; then
			echo "gcc phase1 copysysroot failure"
			exit 1
		fi
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.copysysrootsuccess
	fi

	mkdir -p ${currentpath}/targetbuild/$HOST/gcc_phase2
	if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.configuresuccesss ]; then
		cd ${currentpath}/targetbuild/$HOST/gcc_phase2
		STRIP=strip STRIP_FOR_TARGET=$HOSTSTRIP $TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIX/include/c++/v1 --prefix=$PREFIX $CROSSTRIPLETTRIPLETS ${GCCCONFIGUREFLAGSCOMMON} --with-sysroot=$PREFIX/sysroot
		mkdir -p ${currentpath}/targetbuild/$HOST/gcc_phase2
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

	if [[ ${FREESTANDINGBUILD} != "yes" ]]; then
		TOOLCHAINS_BUILD=$TOOLCHAINS_BUILD TOOLCHAINSPATH_GNU=$TOOLCHAINSPATH_GNU GMPMPFRMPCHOST=$HOST GMPMPFRMPCBUILD=${currentpath}/targetbuild/$HOST GMPMPFRMPCPREFIX=$PREFIX/sysroot/usr $relpath/buildgmpmpfrmpc.sh
		if [ $? -ne 0 ]; then
			echo "$HOST gmp mpfr mpc build failed"
			exit 1
		fi
		SYSROOT=$PREFIX/sysroot
	fi

	if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.packagingsuccess ]; then
		cd ${TOOLCHAINSPATH_GNU}/${BUILD}
		rm -f $HOST.tar.xz
		XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
		chmod 755 $HOST.tar.xz
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.packagingsuccess
	fi
fi


function handlebuild
{
local hosttriple=$1
local build_prefix=${currentpath}/${hosttriple}/${HOST}
local prefix=${TOOLCHAINSPATH_GNU}/${hosttriple}/${HOST}
local prefixtarget=${prefix}/${HOST}

mkdir -p ${build_prefix}

echo $build_prefix
echo $prefix
echo $prefixtarget


if [[ ${FREESTANDINGBUILD} != "yes" ]]; then
	if [ ! -f ${build_prefix}/.installsysrootsuccess ]; then
		mkdir -p ${prefix}/sysroot
		cp -r --preserve=links $SYSROOT/* ${prefix}/sysroot/

		echo "$(date --iso-8601=seconds)" > ${build_prefix}/.installsysrootsuccess
	fi
fi

if [ ! -f ${build_prefix}/binutils-gdb/.configuresuccess ]; then
	mkdir -p ${build_prefix}/binutils-gdb
	cd $build_prefix/binutils-gdb
	echo $build_prefix/binutils-gdb
	local extra_binutils_configure_flags=
	local hostarch=${hosttriple%%-*}
	if [[ ${hostarch} == loongarch* ]]; then
	# see issue https://sourceware.org/bugzilla/show_bug.cgi?id=32031
		extra_binutils_configure_flags="--disable-gdbserver --disable-gdb"
	fi
	if [[ ${hosttriple} == ${HOST} && ${MUSLLIBC} == "yes" ]]; then
		extra_binutils_configure_flags="--disable-plugins $extra_binutils_configure_flags"
	fi
	STRIP=${hosttriple}-strip STRIP_FOR_TARGET=$HOSTSTRIP $TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror $ENABLEGOLD --prefix=$prefix --build=$BUILD --host=$hosttriple --target=$HOST $extra_binutils_configure_flags --with-sysroot=${prefix}/sysroot
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
	STRIP=${hosttriple}-strip STRIP_FOR_TARGET=$HOSTSTRIP $TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$prefix/include/c++/v1 --prefix=$prefix --build=$BUILD --host=$hosttriple --target=$HOST $GCCCONFIGUREFLAGSCOMMON --with-sysroot=$prefix/sysroot
	if [ $? -ne 0 ]; then
		echo "gcc (${hosttriple}/${HOST}) configure failed"
		exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.configuresuccess
fi


if [ ! -f ${build_prefix}/gcc/.buildallgccsuccess ]; then
	cd $build_prefix/gcc
	make all-gcc -j$(nproc)
	if [ $? -ne 0 ]; then
		echo "gcc (${hosttriple}/${HOST}) all-gcc build failed"
		exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.buildallgccsuccess
fi

if [ ! -f ${build_prefix}/gcc/.generatelimitssuccess ]; then
	cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > ${build_prefix}/gcc/gcc/include/limits.h
	if [ $? -ne 0 ]; then
		echo "gcc (${hosttriple}/${HOST}) generate limits failure"
		exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.generatelimitssuccess
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

if [ ! -f "${build_prefix}/gcc/.symlinksuccess" ]; then
if [[ "${hosttriple}" == "{$HOST}" ]]; then
  cd "${prefix}/bin"
	if [[ -e "${prefix}/bin/gcc" ]]; then
	  ln -s gcc cc
	elif [[ -e "${prefix}/bin/gcc.exe" ]]; then
	  ln gcc.exe cc.exe
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.symlinksuccess
fi
fi

if [ ! -f ${build_prefix}/.packagingsuccess ]; then
	cd ${TOOLCHAINSPATH_GNU}/${hosttriple}
	rm -f $HOST.tar.xz
	XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
	chmod 755 $HOST.tar.xz
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/.packagingsuccess
fi
}

if [[ ${FREESTANDINGBUILD} != "yes" ]]; then
handlebuild ${HOST}
fi

if [[ ${CANADIANHOST} == ${HOST} ]]; then
exit 0
fi

if [ -x "$(command -v ${CANADIANHOST}-g++)" ]; then
handlebuild ${CANADIANHOST}
else
echo "${CANADIANHOST}-g++ not found. skipped"
fi
