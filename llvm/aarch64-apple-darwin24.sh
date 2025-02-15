#!/bin/bash

if [ -z ${ARCH+x} ]; then
ARCH=aarch64
fi
TARGETTRIPLE_CPU=${ARCH}
if [[ ${TARGETTRIPLE_CPU} == "aarch64" ]]; then
TARGETTRIPLE_CPU_ALIAS=aarch64
else
TARGETTRIPLE_CPU_ALIAS=${TARGETTRIPLE_CPU}
fi
if [ -z ${CMAKE_SIZEOF_VOID_P+x} ]; then
CMAKE_SIZEOF_VOID_P=8
fi
if [ -z ${DARWINVERSION+x} ]; then
DARWINVERSION=24
fi
TARGETTRIPLENOVERSION=${TARGETTRIPLE_CPU}-apple-darwin
TARGETTRIPLE=${TARGETTRIPLENOVERSION}${DARWINVERSION}
TARGETUNKNOWNTRIPLE=${TARGETTRIPLE_CPU}-unknown-apple-darwin${DARWINVERSION}
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

if [ -z ${DARWINVERSIONDATE+x} ]; then
  DARWINVERSIONDATE=$(git ls-remote --tags git@github.com:trcrsired/apple-darwin-sysroot.git | tail -n 1 | sed 's/.*\///')
fi

if [ -z ${SYSTEMVERSION+x} ]; then
  SYSTEMVERSION="15.2"
fi

if [ -z $ARCHITECTURES ]; then
  ARCHITECTURES="arm64;x86_64"
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
SYSTEMNAME=Darwin

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "${currentpath}"
	rm -rf "${TOOLCHAINS_LLVMSYSROOTSPATH}"
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

BUILTINSINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/builtins
COMPILERRTINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/compiler-rt
DARWINSYSROOTPATH="$TOOLCHAINS_LLVMSYSROOTSPATH/${TARGETTRIPLE}"
SYSROOTPATH="${DARWINSYSROOTPATH}/usr"

LIBTOOLPATH="$(which llvm-libtool-darwin)"
LIPOPATH="$(which llvm-lipo)"
INSTALL_NAME_TOOLPATH="$(which llvm-install-name-tool)"
ARPATH="$(which llvm-ar)"
RANLIBPATH="$(which llvm-ranlib)"
STRIPPATH="$(which llvm-strip)"
NMPATH="$(which llvm-nm)"

# This is a universal binary for x86_64/aarch64
FLAGSCOMMON="-fuse-ld=lld -fuse-lipo=llvm-lipo -flto=thin -Wno-unused-command-line-argument"
FLAGSCOMMONRUNTIMES="-fuse-ld=lld;-fuse-lipo=llvm-lipo;-flto=thin;-Wno-unused-command-line-argument"

mkdir -p "${currentpath}/downloads"
mkdir -p ${SYSROOTPATH}

if [ ! -f ${SYSROOTPATH}/include/stdio.h ]; then
cd "${currentpath}/downloads"
wget https://github.com/trcrsired/apple-darwin-sysroot/releases/download/${DARWINVERSIONDATE}/${TARGETTRIPLE}.tar.xz
chmod 755 ${TARGETTRIPLE}.tar.xz
tar -xf "${TARGETTRIPLE}.tar.xz" -C "$TOOLCHAINS_LLVMSYSROOTSPATH"
fi

CURRENTTRIPLEPATH=${currentpath}

if [ ! -f "${COMPILERRTINSTALLPATH}/lib/darwin/libclang_rt.osx.a" ]; then
mkdir -p "$CURRENTTRIPLEPATH/compiler-rt"
cd $CURRENTTRIPLEPATH/compiler-rt
cmake $LLVMPROJECTPATH/compiler-rt \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$DARWINSYSROOTPATH -DCMAKE_INSTALL_PREFIX=${COMPILERRTINSTALLPATH} \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU_ALIAS \
	-DCMAKE_C_FLAGS="$FLAGSCOMMON" \
	-DCMAKE_CXX_FLAGS="$FLAGSCOMMON" \
	-DCMAKE_ASM_FLAGS="$FLAGSCOMMON" \
	-DCMAKE_SYSTEM_NAME=${SYSTEMNAME} \
	-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
	-DLLVM_ENABLE_LTO=thin \
	-DLLVM_ENABLE_LLD=On \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTPATH} \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DCMAKE_SYSTEM_VERSION=${SYSTEMVERSION} \
	-DCMAKE_SIZEOF_VOID_P=$CMAKE_SIZEOF_VOID_P \
	-DCMAKE_OSX_ARCHITECTURES=$ARCHITECTURES \
	-DDARWIN_macosx_CACHED_SYSROOT=${DARWINSYSROOTPATH} \
	-DDARWIN_macosx_OVERRIDE_SDK_VERSION=${DARWINVERSION} \
	-DCMAKE_LIBTOOL=$LIBTOOLPATH \
	-DCMAKE_LIPO=$LIPOPATH \
	-DMACOS_ARM_SUPPORT=On \
	-DCMAKE_STRIP="$STRIPPATH" \
	-DCMAKE_AR="$LIBTOOLPATH;-static" \
	-DCMAKE_RANLIB="$LIBTOOLPATH;-static" \
	-DCMAKE_NM="$NMPATH" \
	-DCOMPILER_RT_HAS_G_FLAG=On
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
cp -r --preserve=links "${COMPILERRTINSTALLPATH}"/* "${clangbuiltin}/"
fi

THREADS_FLAGS="-DLIBCXXABI_ENABLE_THREADS=On \
	-DLIBCXX_ENABLE_THREADS=On \
	-DLIBUNWIND_ENABLE_THREADS=On"

EHBUILDLIBS="libcxx;libcxxabi;libunwind"
ENABLE_EH=On

mkdir -p "$CURRENTTRIPLEPATH/runtimes"
cd $CURRENTTRIPLEPATH/runtimes

if [ ! -f "$CURRENTTRIPLEPATH/runtimes/.configuresuccess" ]; then
mkdir -p "$CURRENTTRIPLEPATH/runtimes"
cmake $LLVMPROJECTPATH/runtimes \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT="$DARWINSYSROOTPATH" -DCMAKE_INSTALL_PREFIX="${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes_rpath" \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU_ALIAS \
	-DCMAKE_SYSTEM_NAME=${SYSTEMNAME} \
	-DLLVM_ENABLE_RUNTIMES=$EHBUILDLIBS \
	-DLIBCXXABI_SILENT_TERMINATE=On \
	-DLIBCXX_CXX_ABI=system-libcxxabi \
	-DLIBCXX_ENABLE_SHARED=On \
	-DLIBCXX_ABI_VERSION=1 \
	-DLLVM_ENABLE_LTO=thin \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS="${LLVMPROJECTPATH}/libcxxabi/include" \
	${THREADS_FLAGS} \
	-DLIBCXX_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXX_ENABLE_RTTI=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_RTTI=${ENABLE_EH} \
	-DLLVM_ENABLE_ASSERTIONS=Off -DLLVM_INCLUDE_EXAMPLES=Off -DLLVM_ENABLE_BACKTRACES=Off -DLLVM_INCLUDE_TESTS=Off -DLIBCXX_INCLUDE_BENCHMARKS=Off \
	-DLIBCXX_ENABLE_SHARED=On -DLIBCXXABI_ENABLE_SHARED=On \
	-DLIBUNWIND_ENABLE_SHARED=On \
	-DLIBCXX_ADDITIONAL_COMPILE_FLAGS="$FLAGSCOMMONRUNTIMES;-rtlib=compiler-rt;-nostdinc++;-stdlib=libc++;-Wno-macro-redefined;-Wno-user-defined-literals" \
	-DLIBCXXABI_ADDITIONAL_COMPILE_FLAGS="$FLAGSCOMMONRUNTIMES;-rtlib=compiler-rt;-nostdinc++;-stdlib=libc++;-Wno-macro-redefined;-Wno-user-defined-literals;-Wno-unused-command-line-argument" \
	-DLIBUNWIND_ADDITIONAL_COMPILE_FLAGS="$FLAGSCOMMONRUNTIMES;-rtlib=compiler-rt;-nostdinc++;-Wno-macro-redefined" \
	-DLIBCXX_ADDITIONAL_LIBRARIES="-fuse-ld=lld;-fuse-lipo=llvm-lipo;-rtlib=compiler-rt;-stdlib=libc++;-nostdinc++;-Wno-macro-redefined;-Wno-user-defined-literals;-L$CURRENTTRIPLEPATH/runtimes_rpath/lib" \
	-DLIBCXXABI_ADDITIONAL_LIBRARIES="-fuse-ld=lld;-fuse-lipo=llvm-lipo;-rtlib=compiler-rt;-stdlib=libc++;-nostdinc++;-Wno-macro-redefined;-Wno-user-defined-literals;-L$CURRENTTRIPLEPATH/runtimes_rpath/lib" \
	-DLIBUNWIND_ADDITIONAL_LIBRARIES="-fuse-ld=lld;-fuse-lipo=llvm-lipo;-rtlib=compiler-rt;-stdlib=libc++;-nostdinc++;-Wno-macro-redefined" \
	-DLIBCXX_USE_COMPILER_RT=On \
	-DLIBCXXABI_USE_COMPILER_RT=On \
	-DLIBCXX_USE_LLVM_UNWINDER=On \
	-DLIBCXXABI_USE_LLVM_UNWINDER=On \
	-DLIBUNWIND_USE_COMPILER_RT=On \
	-DLLVM_HOST_TRIPLE=$TARGETTRIPLE \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCMAKE_SYSTEM_NAME=${SYSTEMNAME} \
	-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTPATH} \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DCMAKE_POSITION_INDEPENDENT_CODE=On \
	-DCMAKE_SYSTEM_VERSION=${SYSTEMVERSION} \
	-DCMAKE_OSX_ARCHITECTURES=$ARCHITECTURES \
	-DDARWIN_macosx_CACHED_SYSROOT=${DARWINSYSROOTPATH} \
	-DDARWIN_macosx_OVERRIDE_SDK_VERSION=${DARWINVERSION} \
	-DCMAKE_LIBTOOL=$LIBTOOLPATH \
	-DCMAKE_LIPO=$LIPOPATH \
	-DMACOS_ARM_SUPPORT=On \
	-DCMAKE_STRIP="$STRIPPATH" \
	-DCMAKE_NM="$NMPATH" \
	-DCMAKE_RANLIB="" \
	-DCMAKE_STRIP="$STRIPPATH" \
	-DCOMPILER_RT_HAS_G_FLAG=On \
	-DLLVM_EXTERNALIZE_DEBUGINFO=On
if [ $? -ne 0 ]; then
echo "cmake	failed to configure runtimes"
exit 1
fi
echo "$(date --iso-8601=seconds)" > "$CURRENTTRIPLEPATH/runtimes/.configuresuccess"
fi

if [ ! -f "$CURRENTTRIPLEPATH/runtimes/.buildsuccess" ]; then
cd $CURRENTTRIPLEPATH/runtimes
ninja -C . cxx_static
if [ $? -ne 0 ]; then
echo "ninja failed to build static runtimes"
exit 1
fi
ninja
if [ $? -ne 0 ]; then
echo "ninja failed to build runtimes"
exit 1
fi
ninja install/strip
if [ $? -ne 0 ]; then
echo "ninja failed to install runtimes"
exit 1
fi
cp -r --preserve=links "${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes_rpath"/* "${SYSROOTPATH}/"
echo "$(date --iso-8601=seconds)" > "$CURRENTTRIPLEPATH/runtimes/.buildsuccess"
fi

if [ ! -f "$CURRENTTRIPLEPATH/llvm/.configuresuccess" ]; then
mkdir -p "$CURRENTTRIPLEPATH/llvm"
cd "$CURRENTTRIPLEPATH/llvm"
cmake $LLVMPROJECTPATH/llvm \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$DARWINSYSROOTPATH -DCMAKE_INSTALL_PREFIX=$LLVMINSTALLPATH \
	-DCMAKE_CROSSCOMPILING=On \
	-DLLVM_HOST_TRIPLE=$TARGETTRIPLE \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU_ALIAS \
	-DCMAKE_SYSTEM_NAME=${SYSTEMNAME} \
	-DBUILD_SHARED_LIBS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU_ALIAS \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTPATH} \
	-DLLVM_ENABLE_LLD=On \
	-DLLVM_ENABLE_LTO=thin \
	-DLLVM_ENABLE_LIBCXX=On \
	-DCMAKE_C_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_CXX_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_ASM_COMPILER_TARGET=${TARGETTRIPLE} \
	-DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;lldb" \
	-DCMAKE_C_FLAGS="$FLAGSCOMMON -rtlib=compiler-rt" \
	-DCMAKE_CXX_FLAGS="$FLAGSCOMMON -rtlib=compiler-rt" \
	-DCMAKE_ASM_FLAGS="$FLAGSCOMMON -rtlib=compiler-rt" \
	-DLLVM_ENABLE_ZLIB=FORCE_ON \
	-DZLIB_INCLUDE_DIR=$SYSROOTPATH/include \
	-DZLIB_LIBRARY=$SYSROOTPATH/lib/libz.tbd \
	-DLLVM_ENABLE_LIBXML2=FORCE_ON \
	-DLIBXML2_INCLUDE_DIR=$SYSROOTPATH/include/libxml \
	-DLIBXML2_LIBRARY=$SYSROOTPATH/lib/libxml2.tbd \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DCMAKE_SYSTEM_VERSION=${SYSTEMVERSION} \
	-DDARWIN_macosx_CACHED_SYSROOT=${DARWINSYSROOTPATH} \
	-DDARWIN_macosx_OVERRIDE_SDK_VERSION=${DARWINVERSION} \
	-DCMAKE_OSX_ARCHITECTURES=$ARCHITECTURES \
	-DCMAKE_LIBTOOL="$LIBTOOLPATH" \
	-DCMAKE_LIPO="$LIPOPATH" \
	-DMACOS_ARM_SUPPORT=On \
	-DLLDB_INCLUDE_TESTS=Off \
	-DLLDB_USE_SYSTEM_DEBUGSERVER=On \
	-DCMAKE_INSTALL_NAME_TOOL="${INSTALL_NAME_TOOLPATH}" \
	-DCMAKE_AR="$ARPATH" \
	-DCMAKE_RANLIB="$RANLIBPATH" \
	-DCMAKE_STRIP="$STRIPPATH" \
	-DCMAKE_NM="$NMPATH" \
	-DCMAKE_INSTALL_RPATH="@executable_path/../lib"
if [ $? -ne 0 ]; then
echo "cmake failed to configure llvm"
exit 1
fi
echo "$(date --iso-8601=seconds)" > "$CURRENTTRIPLEPATH/llvm/.configuresuccess"
fi

if [ ! -f "$CURRENTTRIPLEPATH/llvm/.buildsuccess" ]; then
cd $CURRENTTRIPLEPATH/llvm
ninja
if [ $? -ne 0 ]; then
echo "ninja failed to build llvm"
exit 1
fi
ninja install/strip
if [ $? -ne 0 ]; then
echo "ninja failed to install llvm"
exit 1
fi
echo "$(date --iso-8601=seconds)" > "$CURRENTTRIPLEPATH/llvm/.buildsuccess"
fi

if [ -d "$LLVMINSTALLPATH" ]; then
canadianclangbuiltin="${LLVMINSTALLPATH}/lib/clang/${clang_major_version}"
if [ ! -f "${canadianclangbuiltin}/lib/darwin/libclang_rt.osx.a" ]; then
cp -r --preserve=links "${COMPILERRTINSTALLPATH}"/* "${canadianclangbuiltin}/"
fi

if [ ! -f "$CURRENTTRIPLEPATH/llvm/.packagesuccess" ]; then
	cd $TOOLCHAINS_LLVMPATH
	rm -f ${TARGETTRIPLE}.tar.xz
	XZ_OPT=-e9T0 tar cJf ${TARGETTRIPLE}.tar.xz ${TARGETTRIPLE}
	chmod 755 ${TARGETTRIPLE}.tar.xz
	echo "$(date --iso-8601=seconds)" > "$CURRENTTRIPLEPATH/llvm/.packagesuccess"
fi
fi
