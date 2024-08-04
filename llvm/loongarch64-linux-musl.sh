#!/bin/bash

if [ -z ${ARCH+x} ]; then
ARCH=loongarch
fi
TARGETTRIPLE_CPU=${ARCH}64
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

mkdir -p ${currentpath}/install
mkdir -p ${currentpath}/build

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
	host=$TARGETTRIPLE
	libingccdir=""
	mkdir -p ${currentpath}/build/musl/$item
	cd ${currentpath}/build/musl/$item
	if [ ! -f ${currentpath}/build/musl/$item/.configuresuccess ]; then
		STRIP=llvm-strip AR=llvm-ar CC="clang --target=$host" CXX="clang++ --target=$host" AS=llvm-as RANLIB=llvm-ranlib CXXFILT=llvm-cxxfilt NM=llvm-nm $TOOLCHAINS_BUILD/musl/configure --disable-nls --disable-werror --prefix=$currentpath/install/musl/$item --build=$BUILD --with-headers=$SYSROOT/include --disable-shared --enable-static --without-selinux --host=$host
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
		llvm-strip --strip-unneeded $currentpath/install/musl/$item/lib/*
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

CURRENTTRIPLEPATH=${currentpath}

if [ ! -f "${BUILTINSINSTALLPATH}/lib/linux/libclang_rt.builtins-${TARGETTRIPLE_CPU}.a" ]; then
mkdir -p "$CURRENTTRIPLEPATH/builtins"
cd $CURRENTTRIPLEPATH/builtins
cmake $LLVMPROJECTPATH/compiler-rt/lib/builtins \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=${BUILTINSINSTALLPATH} \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU -DCOMPILER_RT_BAREMETAL_BUILD=On \
	-DCMAKE_C_FLAGS="-fuse-ld=lld -flto=thin -fuse-ld=lld -flto=thin" -DCMAKE_CXX_FLAGS="-fuse-ld=lld -flto=thin -fuse-ld=lld -flto=thin" -DCMAKE_ASM_FLAGS="-fuse-ld=lld -flto=thin -fuse-ld=lld -flto=thin" \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCOMPILER_RT_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DLLVM_ENABLE_LTO=thin \
	-DLLVM_ENABLE_LLD=On
ninja
ninja install/strip
${sudocommand} cp -r --preserve=links "${BUILTINSINSTALLPATH}"/* "${clangbuiltin}/"
fi

THREADS_FLAGS=""

EHBUILDLIBS="libcxx;libcxxabi;libunwind"
ENABLE_EH=On

if [ ! -d "${SYSROOTPATH}/include/c++/v1" ]; then

mkdir -p "$CURRENTTRIPLEPATH/runtimes"
cd $CURRENTTRIPLEPATH/runtimes

cmake $LLVMPROJECTPATH/runtimes \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=${SYSROOTPATH} \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DLLVM_ENABLE_RUNTIMES=$EHBUILDLIBS \
	-DLIBCXXABI_SILENT_TERMINATE=On \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_ABI_VERSION=2 \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS="${LLVMPROJECTPATH}/libcxxabi/include" \
	${THREADS_FLAGS} \
	-DLIBCXX_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXX_ENABLE_RTTI=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_RTTI=${ENABLE_EH} \
	-DLLVM_ENABLE_ASSERTIONS=Off -DLLVM_INCLUDE_EXAMPLES=Off -DLLVM_ENABLE_BACKTRACES=Off -DLLVM_INCLUDE_TESTS=Off -DLIBCXX_INCLUDE_BENCHMARKS=Off \
	-DLIBCXX_ENABLE_SHARED=Off -DLIBCXXABI_ENABLE_SHARED=Off \
	-DLIBUNWIND_ENABLE_SHARED=Off \
	-DLIBCXX_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals" -DLIBCXXABI_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals" -DLIBUNWIND_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -Wno-macro-redefined" \
	-DLIBCXX_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -nostdinc++ -Wno-macro-redefined -Wno-user-defined-literals -L$CURRENTTRIPLEPATH/runtimes/lib" -DLIBCXXABI_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals -L$CURRENTTRIPLEPATH/runtimes/lib" -DLIBUNWIND_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined" \
	-DLIBCXX_USE_COMPILER_RT=On \
	-DLIBCXXABI_USE_COMPILER_RT=On \
	-DLIBCXX_USE_LLVM_UNWINDER=On \
	-DLIBCXXABI_USE_LLVM_UNWINDER=On \
	-DLIBUNWIND_USE_COMPILER_RT=On \
	-DLIBCXX_HAS_MUSL_LIBC=On \
	-DLLVM_HOST_TRIPLE=$TARGETTRIPLE \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
ninja -C . cxx_static
ninja
ninja install/strip
fi

if [ ! -f "${COMPILERRTINSTALLPATH}/lib/linux/libclang_rt.builtins-${TARGETTRIPLE_CPU}.a" ]; then
mkdir -p "$CURRENTTRIPLEPATH/compiler-rt"
cd $CURRENTTRIPLEPATH/compiler-rt
cmake $LLVMPROJECTPATH/compiler-rt \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=${COMPILERRTINSTALLPATH} \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCOMPILER_RT_USE_LIBCXX=On \
	-DCMAKE_C_FLAGS="-fuse-ld=lld -flto=thin -stdlib=libc++ -rtlib=compiler-rt -Wno-unused-command-line-argument" -DCMAKE_CXX_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-unused-command-line-argument -lc++abi" -DCMAKE_ASM_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-unused-command-line-argument" \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCOMPILER_RT_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCOMPILER_RT_USE_BUILTINS_LIBRARY=On \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On
ninja
ninja install/strip
${sudocommand} cp -r --preserve=links "${COMPILERRTINSTALLPATH}"/* "${clangbuiltin}/"
fi

if [ ! -f "${SYSROOTPATH}/include/zlib.h" ]; then
mkdir -p "$CURRENTTRIPLEPATH/zlib"
cd $CURRENTTRIPLEPATH/zlib
cmake -GNinja ${TOOLCHAINS_BUILD}/zlib -DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_RC_COMPILER=llvm-windres \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=$SYSROOTPATH \
	-DCMAKE_INSTALL_PREFIX=${SYSROOTPATH} \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_FLAGS="--target=$TARGETTRIPLE -I${SYSROOTPATH}/include" \
	-DCMAKE_C_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin" \
	-DCMAKE_CXX_FLAGS="-rtlib=compiler-rt -stdlib=libc++ -fuse-ld=lld -flto=thin -lc++abi" \
	-DCMAKE_ASM_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin" \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On
ninja install/strip
fi

if [ ! -d "$LLVMINSTALLPATH" ]; then
if [ ! -d "$CURRENTTRIPLEPATH/llvm" ]; then
mkdir -p "$CURRENTTRIPLEPATH/llvm"
cd $CURRENTTRIPLEPATH/llvm
cmake $LLVMPROJECTPATH/llvm \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=$LLVMINSTALLPATH \
	-DCMAKE_CROSSCOMPILING=On \
	-DLLVM_HOST_TRIPLE=$TARGETTRIPLE \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTPATH} \
	-DLLVM_ENABLE_LLD=On \
	-DLLVM_ENABLE_LIBCXX=On \
	-DLLVM_ENABLE_LTO=thin \
	-DCMAKE_C_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_CXX_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_ASM_COMPILER_TARGET=${TARGETTRIPLE} \
	-DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;lldb" \
	-DCMAKE_C_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -Wno-unused-command-line-argument" \
	-DCMAKE_CXX_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -stdlib=libc++ -lc++abi -Wno-unused-command-line-argument -lunwind" \
	-DCMAKE_ASM_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -Wno-unused-command-line-argument" \
	-DLLVM_ENABLE_ZLIB=FORCE_ON \
	-DZLIB_INCLUDE_DIR=$SYSROOTPATH/include \
	-DZLIB_LIBRARY=$SYSROOTPATH/lib/libz.a \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
fi
cd $CURRENTTRIPLEPATH/llvm
ninja
ninja install/strip
fi

if [ -d "$LLVMINSTALLPATH" ]; then
canadianclangbuiltin="${LLVMINSTALLPATH}/lib/clang/${clang_major_version}"
if [ ! -f "${canadianclangbuiltin}/lib/linux/libclang_rt.builtins-${TARGETTRIPLE_CPU}.a" ]; then
${sudocommand} cp -r --preserve=links "${COMPILERRTINSTALLPATH}"/* "${canadianclangbuiltin}/"
fi

if [ ! -f ${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz ]; then
	cd $TOOLCHAINS_LLVMPATH
	XZ_OPT=-e9T0 tar cJf ${TARGETTRIPLE}.tar.xz ${TARGETTRIPLE}
	chmod 755 ${TARGETTRIPLE}.tar.xz
fi
fi
