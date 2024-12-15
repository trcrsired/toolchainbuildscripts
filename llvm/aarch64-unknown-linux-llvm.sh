#!/bin/bash

if [ -z ${ARCH+x} ]; then
ARCH=aarch64
fi
TARGETTRIPLE_CPU=${ARCH}
if [[ ${TARGETTRIPLE_CPU} == "aarch64" ]]; then
TARGETTRIPLE_CPU_ALIAS=arm64
else
TARGETTRIPLE_CPU_ALIAS=${TARGETTRIPLE_CPU}
fi
if [ -z ${CMAKE_SIZEOF_VOID_P+x} ]; then
CMAKE_SIZEOF_VOID_P=8
fi
if [ -z ${TARGETTRIPLE+x} ]; then
TARGETTRIPLE=${TARGETTRIPLE_CPU}-unknown-linux-llvm
fi
currentpath=$(realpath .)/.llvmartifacts/${TARGETTRIPLE}
if [ ! -d ${currentpath} ]; then
	mkdir -p ${currentpath}
	cd ${currentpath}
fi
if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
mkdir -p $TOOLCHAINSPATH
TOOLCHAINS_LLVMPATH=$TOOLCHAINSPATH/llvm
mkdir -p $TOOLCHAINS_LLVMPATH

TOOLCHAINS_LLVMSYSROOTSPATH="$TOOLCHAINS_LLVMPATH/${TARGETTRIPLE}"

mkdir -p $TOOLCHAINS_LLVMSYSROOTSPATH

mkdir -p $TOOLCHAINS_BUILD
mkdir -p $TOOLCHAINSPATH
LLVMINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/llvm

clang_path=$(command -v clang)

if [[ -z $clang_path ]]; then
    echo "clang not exists"
    exit 1
fi

if [ -z ${NO_TOOLCHAIN_DELETION+x} ]; then
if [[ $clang_path == "${TOOLCHAINS_LLVMSYSROOTSPATH}/llvm/bin/clang" ]]; then
NO_TOOLCHAIN_DELETION="yes"
fi
fi

if [[ $NO_TOOLCHAIN_DELETION == "yes" ]]; then
LLVMINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/llvm_temp
fi

if [[ $1 == "clean" || $1 == "restart" ]]; then
	echo "cleaning"
	rm -rf "${currentpath}"
	if [[ $NO_TOOLCHAIN_DELETION != "yes" ]]; then
		rm -rf "${TOOLCHAINS_LLVMSYSROOTSPATH}"
	else
		cd "${TOOLCHAINS_LLVMSYSROOTSPATH}"
		if [ $? -ne 0 ]; then
			for item in *; do
			if [ "$item" != "runtimes" ] && [ "$item" != "llvm" ]; then
				echo rm -rf "${TOOLCHAINS_LLVMSYSROOTSPATH}/$item"
			fi
			done
		fi
	fi
	rm -f "${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz"
	echo "clean done"
	if [[ $1 == "restart" ]]; then
		echo "restart"
	else
		exit 1
	fi
fi

BUILD_C_COMPILER=clang
BUILD_CXX_COMPILER=clang++
BUILD_ASM_COMPILER=clang

if [ -z ${LLVMPROJECTPATH+x} ]; then
LLVMPROJECTPATH=$TOOLCHAINS_BUILD/llvm-project
fi

if [ ! -d "$LLVMPROJECTPATH" ]; then
git clone git@github.com:llvm/llvm-project.git $LLVMPROJECTPATH
fi
cd "$LLVMPROJECTPATH"
git pull --quiet

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/zlib" ]; then
git clone git@github.com:trcrsired/zlib.git
fi
cd "$TOOLCHAINS_BUILD/zlib"
git pull --quiet
cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/libxml2" ]; then
git clone https://gitlab.gnome.org/GNOME/libxml2.git
if [ $? -ne 0 ]; then
echo "libxml2 clone failure"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/libxml2"
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

clang_directory=$(dirname "$clang_path")
clang_version=$(clang --version | grep -oP '\d+\.\d+\.\d+')
clang_major_version="${clang_version%%.*}"
llvm_install_directory="$clang_directory/.."
clangbuiltin="$llvm_install_directory/lib/clang/$clang_major_version"
LLVMINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/llvm
SYSTEMNAME=Linux

CURRENTTRIPLEPATH=${currentpath}
SYSROOTPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/${TARGETTRIPLE}
BUILTINSINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/builtins
COMPILERRTINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/compiler-rt
RUNTIMESINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes
if [[ $NO_TOOLCHAIN_DELETION == "yes" ]]; then
RUNTIMESINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes_temp
fi


EHBUILDLIBS_PHASE1="libc;compiler-rt"
ENABLE_EH=On

if [ ! -f ${CURRENTTRIPLEPATH}/.linuxkernelheadersinstallsuccess ]; then
    cd "$TOOLCHAINS_BUILD/linux"
    make headers_install ARCH=$TARGETTRIPLE_CPU_ALIAS -j$(nproc) INSTALL_HDR_PATH=$SYSROOTPATH/usr
    if [ $? -ne 0 ]; then
    echo "linux kernel headers install failure"
    exit 1
    fi
    echo "$(date --iso-8601=seconds)" > ${CURRENTTRIPLEPATH}/.linuxkernelheadersinstallsuccess
fi

if [ ! -f "$CURRENTTRIPLEPATH/runtimes_phase1/.buildsuccess" ]; then

mkdir -p "$CURRENTTRIPLEPATH/runtimes_phase1"
cd $CURRENTTRIPLEPATH/runtimes_phase1

cmake $LLVMPROJECTPATH/runtimes \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=${RUNTIMESINSTALLPATH} \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_SYSTEM_NAME=Linux \
    -DLLVM_LIBC_FULL_BUILD=ON \
    -DLLVM_RUNTIME_TARGETS=$TARGETTRIPLE \
    -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
	-DLLVM_ENABLE_RUNTIMES="$EHBUILDLIBS_PHASE1" \
    -DRUNTIMES_${TARGETTRIPLE}_LLVM_ENABLE_RUNTIMES="$EHBUILDLIBS_PHASE1" \
    -DRUNTIMES_${TARGETTRIPLE}_LLVM_LIBC_FULL_BUILD=ON               \
    -DRUNTIMES_${TARGETTRIPLE}_LLVM_LIBC_INCLUDE_SCUDO=ON            \
    -DLLVM_HOST_TRIPLE=${TARGETTRIPLE} \
    -DLLVM_DEFAULT_TARGET_TRIPLE=${TARGETTRIPLE} \
    -DLLVM_TARGETS_TO_BUILD=$TARGETTRIPLE_CPU \
    -DRUNTIMES_${TARGETTRIPLE}_COMPILER_RT_BUILD_SCUDO_STANDALONE_WITH_LLVM_LIBC=ON \
    -DRUNTIMES_${TARGETTRIPLE}_COMPILER_RT_BUILD_GWP_ASAN=OFF                       \
    -DRUNTIMES_${TARGETTRIPLE}_COMPILER_RT_SCUDO_STANDALONE_BUILD_SHARED=OFF        \
	-DLIBCXXABI_SILENT_TERMINATE=On \
	-DLIBCXX_CXX_ABI=libcxxabi \
    -DLLVM_LIBC_FULL_BUILD=ON \
    -DCOMPILER_RT_BAREMETAL_BUILD=ON \
    -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
    -DLLVM_LIBC_INCLUDE_SCUDO=ON \
    -DCOMPILER_RT_BUILD_SCUDO_STANDALONE_WITH_LLVM_LIBC=ON \
    -DCOMPILER_RT_BUILD_GWP_ASAN=OFF                       \
    -DCOMPILER_RT_SCUDO_STANDALONE_BUILD_SHARED=OFF        \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCOMPILER_RT_BUILD_SANITIZERS=Off \
    -DCOMPILER_RT_BUILD_XRAY=Off \
    -DCOMPILER_RT_BUILD_LIBFUZZER=Off \
    -DCOMPILER_RT_BUILD_PROFILE=Off \
    -DCOMPILER_RT_BUILD_ORC=Off \
    -DCOMPILER_RT_BUILD_GWP_ASAN=Off \
    -DCOMPILER_RT_BUILD_CTX_PROFILE=Off \
    -DLLVM_ENABLE_SPHINX=Off -DLIBC_INCLUDE_DOCS=Off \
    -DLIBC_CMAKE_VERBOSE_LOGGING=ON \
	-DLIBCXX_ENABLE_SHARED=On \
	-DLIBCXX_ABI_VERSION=1 \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS="${LLVMPROJECTPATH}/libcxxabi/include" \
	-DLIBCXX_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXX_ENABLE_RTTI=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_RTTI=${ENABLE_EH} \
	-DLLVM_ENABLE_ASSERTIONS=Off -DLLVM_INCLUDE_EXAMPLES=Off -DLLVM_ENABLE_BACKTRACES=Off -DLLVM_INCLUDE_TESTS=Off -DLIBCXX_INCLUDE_BENCHMARKS=Off \
	-DLIBCXX_ENABLE_SHARED=On -DLIBCXXABI_ENABLE_SHARED=On \
	-DLIBUNWIND_ENABLE_SHARED=On \
	-DLIBCXX_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals" -DLIBCXXABI_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals" -DLIBUNWIND_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -Wno-macro-redefined -Wno-user-defined-literals" \
	-DLIBCXX_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -nostdinc++ -Wno-macro-redefined -Wno-user-defined-literals -L$CURRENTTRIPLEPATH/runtimes/lib" -DLIBCXXABI_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals -L$CURRENTTRIPLEPATH/runtimes/lib" -DLIBUNWIND_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined" \
	-DLIBCXX_USE_COMPILER_RT=On \
	-DLIBCXXABI_USE_COMPILER_RT=On \
	-DLIBCXX_USE_LLVM_UNWINDER=On \
	-DLIBCXXABI_USE_LLVM_UNWINDER=On \
	-DLIBUNWIND_USE_COMPILER_RT=On \
	-DLLVM_HOST_TRIPLE=$TARGETTRIPLE \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DCOMPILER_RT_USE_LIBCXX=Off \
	-DCOMPILER_RT_USE_BUILTINS_LIBRARY=On \
	-DCOMPILER_RT_DEFAULT_TARGET_ONLY=$TARGETTRIPLE
if [ $? -ne 0 ]; then
echo "llvm runtimes phase1 cmake failed"
exit 1
fi
ninja libc libm
if [ $? -ne 0 ]; then
echo "llvm runtimes libc libm phase1 build failed"
exit 1
fi
ninja
if [ $? -ne 0 ]; then
echo "llvm runtimes phase1 build failed"
exit 1
fi
ninja install/strip
if [ $? -ne 0 ]; then
echo "llvm runtimes phase1 install/strip failed"
exit 1
fi
mkdir -p ${SYSROOTPATH}/usr
cp -r --preserve=links "${RUNTIMESINSTALLPATH}"/* "${SYSROOTPATH}/usr/"
echo "$(date --iso-8601=seconds)" > $CURRENTTRIPLEPATH/runtimes/.buildsuccess
fi

exit 1
EHBUILDLIBS="libcxx;libcxxabi;libunwind"

if [ ! -f "$CURRENTTRIPLEPATH/runtimes/.buildsuccess" ]; then

mkdir -p "$CURRENTTRIPLEPATH/runtimes"
cd $CURRENTTRIPLEPATH/runtimes

cmake $LLVMPROJECTPATH/runtimes \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=${RUNTIMESINSTALLPATH} \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DLLVM_ENABLE_RUNTIMES=$EHBUILDLIBS \
	-DLIBCXXABI_SILENT_TERMINATE=On \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_ENABLE_SHARED=On \
	-DLIBCXX_ABI_VERSION=1 \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS="${LLVMPROJECTPATH}/libcxxabi/include" \
	-DLIBCXX_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXX_ENABLE_RTTI=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_RTTI=${ENABLE_EH} \
	-DLLVM_ENABLE_ASSERTIONS=Off -DLLVM_INCLUDE_EXAMPLES=Off -DLLVM_ENABLE_BACKTRACES=Off -DLLVM_INCLUDE_TESTS=Off -DLIBCXX_INCLUDE_BENCHMARKS=Off \
	-DLIBCXX_ENABLE_SHARED=On -DLIBCXXABI_ENABLE_SHARED=On \
	-DLIBUNWIND_ENABLE_SHARED=On \
	-DLIBCXX_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals" -DLIBCXXABI_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals" -DLIBUNWIND_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -Wno-macro-redefined -Wno-user-defined-literals" \
	-DLIBCXX_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -nostdinc++ -Wno-macro-redefined -Wno-user-defined-literals -L$CURRENTTRIPLEPATH/runtimes/lib" -DLIBCXXABI_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals -L$CURRENTTRIPLEPATH/runtimes/lib" -DLIBUNWIND_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined" \
	-DLIBCXX_USE_COMPILER_RT=On \
	-DLIBCXXABI_USE_COMPILER_RT=On \
	-DLIBCXX_USE_LLVM_UNWINDER=On \
	-DLIBCXXABI_USE_LLVM_UNWINDER=On \
	-DLIBUNWIND_USE_COMPILER_RT=On \
	-DLLVM_HOST_TRIPLE=$TARGETTRIPLE \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DCOMPILER_RT_USE_LIBCXX=Off \
	-DCOMPILER_RT_USE_BUILTINS_LIBRARY=On \
	-DCOMPILER_RT_DEFAULT_TARGET_ONLY=$TARGETTRIPLE
if [ $? -ne 0 ]; then
echo "llvm runtimes cmake failed"
exit 1
fi
ninja -C . cxx_static
if [ $? -ne 0 ]; then
echo "llvm runtimes build static failed"
exit 1
fi
ninja
if [ $? -ne 0 ]; then
echo "llvm runtimes build failed"
exit 1
fi
ninja install/strip
if [ $? -ne 0 ]; then
echo "llvm runtimes install/strip failed"
exit 1
fi
mkdir -p ${SYSROOTPATH}/usr
cp -r --preserve=links "${RUNTIMESINSTALLPATH}"/* "${SYSROOTPATH}/usr/"
echo "$(date --iso-8601=seconds)" > $CURRENTTRIPLEPATH/runtimes/.buildsuccess
fi

if [ ! -f "$CURRENTTRIPLEPATH/compiler-rt/.buildsuccess" ]; then

mkdir -p "$CURRENTTRIPLEPATH/compiler-rt"
cd $CURRENTTRIPLEPATH/compiler-rt

cmake $LLVMPROJECTPATH/compiler-rt \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=${COMPILERRTINSTALLPATH} \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DLLVM_ENABLE_RUNTIMES=$EHBUILDLIBS \
	-DLIBCXXABI_SILENT_TERMINATE=On \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_ENABLE_SHARED=On \
	-DLIBCXX_ABI_VERSION=1 \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS="${LLVMPROJECTPATH}/libcxxabi/include" \
	-DLIBCXX_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXX_ENABLE_RTTI=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_RTTI=${ENABLE_EH} \
	-DLLVM_ENABLE_ASSERTIONS=Off -DLLVM_INCLUDE_EXAMPLES=Off -DLLVM_ENABLE_BACKTRACES=Off -DLLVM_INCLUDE_TESTS=Off -DLIBCXX_INCLUDE_BENCHMARKS=Off \
	-DLIBCXX_ENABLE_SHARED=On -DLIBCXXABI_ENABLE_SHARED=On \
	-DLIBUNWIND_ENABLE_SHARED=On \
	-DLIBCXX_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals" -DLIBCXXABI_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals" -DLIBUNWIND_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -Wno-macro-redefined -Wno-user-defined-literals" \
	-DLIBCXX_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -nostdinc++ -Wno-macro-redefined -Wno-user-defined-literals -L$CURRENTTRIPLEPATH/runtimes/lib" -DLIBCXXABI_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals -L$CURRENTTRIPLEPATH/runtimes/lib" -DLIBUNWIND_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined" \
	-DLIBCXX_USE_COMPILER_RT=On \
	-DLIBCXXABI_USE_COMPILER_RT=On \
	-DLIBCXX_USE_LLVM_UNWINDER=On \
	-DLIBCXXABI_USE_LLVM_UNWINDER=On \
	-DLIBUNWIND_USE_COMPILER_RT=On \
	-DLLVM_HOST_TRIPLE=$TARGETTRIPLE \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DCOMPILER_RT_USE_LIBCXX=Off \
	-DCOMPILER_RT_USE_BUILTINS_LIBRARY=On \
	-DCMAKE_C_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -Wno-unused-command-line-argument" \
	-DCMAKE_CXX_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -Wno-unused-command-line-argument -lc++abi -lunwind" \
	-DCMAKE_ASM_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -Wno-unused-command-line-argument" \
	-DCOMPILER_RT_DEFAULT_TARGET_ONLY=$TARGETTRIPLE
if [ $? -ne 0 ]; then
echo "compiler-rt cmake failed"
exit 1
fi
ninja
if [ $? -ne 0 ]; then
echo "compiler-rt ninja failed"
exit 1
fi
ninja install/strip
if [ $? -ne 0 ]; then
echo "compiler-rt ninja install failed"
exit 1
fi
cd ${COMPILERRTINSTALLPATH}/lib
cp -r --preserve=links "${BUILTINSINSTALLPATH}"/* "${clangbuiltin}/"
echo "$(date --iso-8601=seconds)" > $CURRENTTRIPLEPATH/compiler-rt/.buildsuccess
fi


if [ ! -f "$CURRENTTRIPLEPATH/zlib/.zlibconfigure" ]; then
mkdir -p "$CURRENTTRIPLEPATH/zlib"
cd $CURRENTTRIPLEPATH/zlib
cmake -GNinja ${TOOLCHAINS_BUILD}/zlib -DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_RC_COMPILER=llvm-windres \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_INSTALL_PREFIX=${RUNTIMESINSTALLPATH} \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTPATH} \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_C_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -Wno-unused-command-line-argument" \
	-DCMAKE_CXX_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -Wno-unused-command-line-argument -lc++abi -lunwind" \
	-DCMAKE_ASM_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -Wno-unused-command-line-argument" \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_POSITION_INDEPENDENT_CODE=On \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_COMPILER_TARGET=$TARGETTRIPLE
if [ $? -ne 0 ]; then
echo "zlib configure failure"
exit 1
fi

echo "$(date --iso-8601=seconds)" > $CURRENTTRIPLEPATH/zlib/.zlibconfigure
fi

if [ ! -f "$CURRENTTRIPLEPATH/zlib/.zlibinstallconfigure" ]; then
cd $CURRENTTRIPLEPATH/zlib
ninja install/strip
if [ $? -ne 0 ]; then
echo "zlib install/strip failure"
exit 1
fi

mkdir -p ${SYSROOTPATH}/usr
cp -r --preserve=links "${RUNTIMESINSTALLPATH}"/* "${SYSROOTPATH}/usr/"
echo "$(date --iso-8601=seconds)" > $CURRENTTRIPLEPATH/zlib/.zlibinstallconfigure
fi

if [ ! -f "$CURRENTTRIPLEPATH/libxml2/.libxml2configure" ]; then
mkdir -p "$CURRENTTRIPLEPATH/libxml2"
cd $CURRENTTRIPLEPATH/libxml2
cmake -GNinja ${TOOLCHAINS_BUILD}/libxml2 -DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_RC_COMPILER=llvm-windres \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_INSTALL_PREFIX=$RUNTIMESINSTALLPATH \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTPATH} \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_C_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -Wno-unused-command-line-argument" \
	-DCMAKE_CXX_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -Wno-unused-command-line-argument -lc++abi -lunwind" \
	-DCMAKE_ASM_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -Wno-unused-command-line-argument" \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_POSITION_INDEPENDENT_CODE=On \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_COMPILER_TARGET=$TARGETTRIPLE \
	-DLIBXML2_WITH_ICONV=Off \
	-DLIBXML2_WITH_PYTHON=Off
if [ $? -ne 0 ]; then
echo "libxml2 configure failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $CURRENTTRIPLEPATH/libxml2/.libxml2configure
fi

if [ ! -f "$CURRENTTRIPLEPATH/libxml2/.libxml2installconfigure" ]; then
cd $CURRENTTRIPLEPATH/libxml2
ninja install/strip
if [ $? -ne 0 ]; then
echo "libxml2 install/strip failure"
exit 1
fi
mkdir -p ${SYSROOTPATH}/usr
cp -r --preserve=links "${RUNTIMESINSTALLPATH}"/* "${SYSROOTPATH}/usr/"
echo "$(date --iso-8601=seconds)" > $CURRENTTRIPLEPATH/libxml2/.libxml2installconfigure
fi

if [[ $NO_TOOLCHAIN_DELETION == "yes" ]]; then
if [ -d ${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes_temp ]; then
if [ -d ${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes ]; then
rm -rf ${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes
fi
cd ${TOOLCHAINS_LLVMSYSROOTSPATH}
mv runtimes_temp runtimes
fi
fi

if [ ! -f "$CURRENTTRIPLEPATH/llvm/.configuresuccess" ]; then
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
	-DBUILD_SHARED_LIBS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTPATH} \
	-DLLVM_ENABLE_LLD=On \
	-DLLVM_ENABLE_LIBCXX=On \
	-DLLVM_ENABLE_LTO=thin \
	-DCMAKE_POSITION_INDEPENDENT_CODE=On \
	-DCMAKE_C_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_CXX_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_ASM_COMPILER_TARGET=${TARGETTRIPLE} \
	-DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;lldb" \
	-DCMAKE_C_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -Wno-unused-command-line-argument" \
	-DCMAKE_CXX_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -Wno-unused-command-line-argument -lc++abi -lunwind" \
	-DCMAKE_ASM_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -Wno-unused-command-line-argument" \
	-DLLVM_ENABLE_ZLIB=FORCE_ON \
	-DZLIB_INCLUDE_DIR=$SYSROOTPATH/usr/include \
	-DHAVE_ZLIB=On \
	-DZLIB_LIBRARY=$SYSROOTPATH/usr/lib/libz.a \
	-DLLVM_ENABLE_LIBXML2=FORCE_ON \
	-DLIBXML2_INCLUDE_DIR=$SYSROOTPATH/usr/include/libxml2 \
	-DLIBXML2_LIBRARY=$SYSROOTPATH/usr/lib/libxml2.so \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
if [ $? -ne 0 ]; then
echo "llvm configure failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${CURRENTTRIPLEPATH}/llvm/.configuresuccess
fi

if [ ! -f "$CURRENTTRIPLEPATH/llvm/.buildsuccess" ]; then
cd $CURRENTTRIPLEPATH/llvm
ninja
if [ $? -ne 0 ]; then
echo "llvm build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${CURRENTTRIPLEPATH}/llvm/.buildsuccess
fi

if [ ! -f "$CURRENTTRIPLEPATH/llvm/.installsuccess" ]; then
cd $CURRENTTRIPLEPATH/llvm
ninja install/strip
if [ $? -ne 0 ]; then
echo "llvm install failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${CURRENTTRIPLEPATH}/llvm/.installsuccess
fi

if [[ $NO_TOOLCHAIN_DELETION == "yes" ]]; then
if [ -d ${TOOLCHAINS_LLVMSYSROOTSPATH}/llvm_temp ]; then
cd ${TOOLCHAINS_LLVMSYSROOTSPATH}
rm -rf ${TOOLCHAINS_LLVMSYSROOTSPATH}/llvm
fi
if [ -d ${TOOLCHAINS_LLVMSYSROOTSPATH}/llvm_temp ]; then
mv llvm_temp llvm
fi
fi

if [ ! -f "$CURRENTTRIPLEPATH/llvm/.packagingsuccess" ]; then
	cd $TOOLCHAINS_LLVMPATH
	rm -f ${TARGETTRIPLE}.tar.xz
	XZ_OPT=-e9T0 tar cJf ${TARGETTRIPLE}.tar.xz ${TARGETTRIPLE}
	if [ $? -ne 0 ]; then
		echo "llvm packaging failure"
		exit 1
	fi
	chmod 755 ${TARGETTRIPLE}.tar.xz
	echo "$(date --iso-8601=seconds)" > ${CURRENTTRIPLEPATH}/llvm/.packagingsuccess
fi
