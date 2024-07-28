#!/bin/bash

if [ -z ${ARCH+x} ]; then
ARCH=loongarch64
fi
TARGETTRIPLE_CPU=${ARCH}
TARGETTRIPLE=${TARGETTRIPLE_CPU}-linux-musl
currentpath=$(realpath .)/.llvmartifacts/${TARGETTRIPLE}
if [ ! -d ${currentpath} ]; then
	mkdir -p ${currentpath}
	cd ${currentpath}
fi

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$currentpath/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$currentpath/toolchains
fi

mkdir -p $TOOLCHAINSPATH
TOOLCHAINS_LLVMPATH=$TOOLCHAINSPATH/llvm
mkdir -p $TOOLCHAINS_LLVMPATH


TOOLCHAINS_LLVMSYSROOTSPATH="$TOOLCHAINS_LLVMPATH/${TARGETTRIPLE}"

mkdir -p $TOOLCHAINS_LLVMSYSROOTSPATH

mkdir -p $TOOLCHAINS_BUILD
mkdir -p $TOOLCHAINSPATH

clang_path=`which clang`
clang_directory=$(dirname "$clang_path")
clang_version=$(clang --version | grep -oP '\d+\.\d+\.\d+')
clang_major_version="${clang_version%%.*}"
llvm_install_directory="$clang_directory/.."
clangbuiltin="$llvm_install_directory/lib/clang/$clang_major_version"
LLVMINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/llvm

if [[ ${NEEDSUDOCOMMAND} == "yes" ]]; then
sudocommand="sudo "
else
sudocommand=
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "${currentpath}"
	rm -rf "${TOOLCHAINS_LLVMSYSROOTSPATH}"
	rm -f "${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz"
	echo "restart done"
fi

if [ -z ${LLVMPROJECTPATH+x} ]; then
LLVMPROJECTPATH=$TOOLCHAINS_BUILD/llvm-project
fi

if [ ! -d "$LLVMPROJECTPATH" ]; then
git clone git@github.com:llvm/llvm-project.git $LLVMPROJECTPATH
fi
cd "$LLVMPROJECTPATH"
git pull --quiet

#if [ -z ${MINGWW64PATH+x} ]; then
#MINGWW64PATH=$TOOLCHAINS_BUILD/mingw-w64
#fi

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/musl" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git@github.com:bminor/musl.git
if [ $? -ne 0 ]; then
echo "musl clone failed"
exit 1
fi
cd "$TOOLCHAINS_BUILD/musl"
git pull --quiet

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/zlib" ]; then
git clone git@github.com:trcrsired/zlib.git
fi
cd "$TOOLCHAINS_BUILD/zlib"
git pull --quiet

BUILTINSINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/builtins
COMPILERRTINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/compiler-rt
SYSROOTPATH="$TOOLCHAINS_LLVMSYSROOTSPATH/${TARGETTRIPLE}"
SYSROOT=$SYSROOTPATH

if [ ! -f ${currentpath}/install/.linuxkernelheadersinstallsuccess ]; then
	cd "$TOOLCHAINS_BUILD/linux"
	make headers_install ARCH=$ARCH -j INSTALL_HDR_PATH=$SYSROOT
	if [ $? -ne 0 ]; then
	echo "linux kernel headers install failure"
	exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.linuxkernelheadersinstallsuccess
fi

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
			STRIP=llvm-strip CC="clang --target=$host" CXX="clang++ --target=$host" AS=llvm-as RANLIB=llvm-ranlib CXXFILT=llvm-cxxfilt NM=llvm-nm $TOOLCHAINS_BUILD/musl/configure --disable-nls --disable-werror --prefix=$currentpath/install/musl/$item --build=$BUILD --with-headers=$SYSROOT/include --disable-shared --enable-static --without-selinux --host=$host
		else
			(export -n LD_LIBRARY_PATH; STRIP=$HOST-strip CC="$HOST-gcc$marchitem" CXX="$HOST-g++$marchitem" $TOOLCHAINS_BUILD/musl/configure --disable-nls --disable-werror --prefix=$currentpath/install/musl/$item --build=$BUILD --with-headers=$SYSROOT/include --disable-shared --enable-static --without-selinux --host=$host )
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
		$HOST-strip --strip-unneeded $currentpath/install/musl/$item/lib/*
		echo "$(date --iso-8601=seconds)" > ${currentpath}/build/musl/$item/.stripsuccess
	fi
	if [ ! -f ${currentpath}/build/musl/$item/.sysrootsuccess ]; then
		cp -r --preserve=links ${currentpath}/install/musl/$item/include $SYSROOT/
		mkdir -p $SYSROOT/$libdir
		cp -r --preserve=links ${currentpath}/install/musl/$item/lib/* $SYSROOT/$libdir
		echo "$(date --iso-8601=seconds)" > ${currentpath}/build/musl/$item/.sysrootsuccess
	fi
	unset item
	unset marchitem
	unset libdir
	unset host
	unset libingccdir
	echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.muslinstallsuccess
fi
