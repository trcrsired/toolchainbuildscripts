#!/bin/bash

if [ -z ${ARCH+x} ]; then
ARCH=x86_64
fi
TARGETTRIPLE_CPU=${ARCH}
TARGETTRIPLE=${TARGETTRIPLE_CPU}-windows-gnu
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


TARGETMINGWTRIPLE=${TARGETTRIPLE_CPU}-w64-mingw32
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
if [ $? -ne 0 ]; then
echo "llvm-project clone failure"
exit 1
fi
fi
cd "$LLVMPROJECTPATH"
git pull --quiet

if [ -z ${MINGWW64PATH+x} ]; then
MINGWW64PATH=$TOOLCHAINS_BUILD/mingw-w64
fi

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/mingw-w64" ]; then
git clone https://git.code.sf.net/p/mingw-w64/mingw-w64
if [ $? -ne 0 ]; then
echo "mingw-w64 clone failure"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/mingw-w64"
git pull --quiet

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/zlib" ]; then
git clone git@github.com:trcrsired/zlib.git
if [ $? -ne 0 ]; then
echo "zlib clone failure"
exit 1
fi
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

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/cppwinrt" ]; then
git clone https://github.com/microsoft/cppwinrt.git
if [ $? -ne 0 ]; then
echo "cppwinrt clone failure"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/cppwinrt"
git pull --quiet

BUILTINSINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/builtins
COMPILERRTINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/compiler-rt
SYSROOTPATH="$TOOLCHAINS_LLVMSYSROOTSPATH/${TARGETTRIPLE}"

if [[ ${TARGETTRIPLE_CPU} == "x86_64" ]]; then
MINGWW64COMMON="--host=${TARGETMINGWTRIPLE} --disable-lib32 --enable-lib64 --prefix=${SYSROOTPATH}"
elif [[ ${TARGETTRIPLE_CPU} == "aarch64" ]]; then
MINGWW64COMMON="--host=${TARGETMINGWTRIPLE} --disable-lib32 --disable-lib64 --disable-libarm32 --enable-libarm64 --prefix=${SYSROOTPATH}"
fi

MINGWW64COMMONENV="CC=\"clang --target=\${TARGETTRIPLE} -fuse-ld=lld --sysroot=\${SYSROOTPATH}\" CXX=\"clang++ --target=\${TARGETTRIPLE} -fuse-ld=lld --sysroot=\${SYSROOTPATH}\" LD=lld NM=llvm-nm RANLIB=llvm-ranlib AR=llvm-ar DLLTOOL=llvm-dlltool AS=llvm-as STRIP=llvm-strip OBJDUMP=llvm-objdump WINDRES=llvm-windres"

mkdir -p ${currentpath}

if [ ! -f ${SYSROOTPATH}/include/stdio.h ]; then
cd ${currentpath}
mkdir -p mingw-w64-headers
cd mingw-w64-headers
if [ ! -f Makefile ]; then
eval ${MINGWW64COMMONENV} $TOOLCHAINS_BUILD/mingw-w64/mingw-w64-headers/configure ${MINGWW64COMMON}
fi
make -j$(nproc)
make install-strip -j$(nproc)
fi

if [ ! -f ${SYSROOTPATH}/lib/libntdll.a ]; then
cd ${currentpath}
mkdir -p mingw-w64-crt
cd mingw-w64-crt
if [ ! -f Makefile ]; then
eval ${MINGWW64COMMONENV} $TOOLCHAINS_BUILD/mingw-w64/mingw-w64-crt/configure ${MINGWW64COMMON}
fi
make -j$(nproc)
make install-strip -j$(nproc)
fi

CURRENTTRIPLEPATH=${currentpath}

if [ ! -f "$CURRENTTRIPLEPATH/builtins/.builtinconfigsuccess" ]; then
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
	-DCMAKE_SYSTEM_NAME=Windows \
	-DCOMPILER_RT_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DLLVM_ENABLE_LTO=thin \
	-DLLVM_ENABLE_LLD=On \
	-DCMAKE_C_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_CXX_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_ASM_LINKER_DEPFILE_SUPPORTED=FALSE
if [ $? -ne 0 ]; then
echo "builtin config failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > "$CURRENTTRIPLEPATH/builtins/.builtinconfigsuccess"
fi

if [ ! -f "$CURRENTTRIPLEPATH/builtins/.builtinninjasuccess" ]; then
ninja
if [ $? -ne 0 ]; then
echo "builtin ninja failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > "$CURRENTTRIPLEPATH/builtins/.builtinninjasuccess"
fi

if [ ! -f "$CURRENTTRIPLEPATH/builtins/.builtinninjastripsuccess" ]; then
ninja install/strip
if [ $? -ne 0 ]; then
echo "builtin ninja installstrip failure"
exit 1
fi
${sudocommand} cp -r --preserve=links "${BUILTINSINSTALLPATH}"/* "${clangbuiltin}/"
echo "$(date --iso-8601=seconds)" > "$CURRENTTRIPLEPATH/builtins/.builtinninjastripsuccess"
fi

THREADS_FLAGS="-DLIBCXXABI_ENABLE_THREADS=On \
	-DLIBCXXABI_HAS_PTHREAD_API=Off \
	-DLIBCXXABI_HAS_WIN32_THREAD_API=On \
	-DLIBCXXABI_HAS_EXTERNAL_THREAD_API=Off \
	-DLIBCXX_ENABLE_THREADS=On \
	-DLIBCXX_HAS_PTHREAD_API=Off \
	-DLIBCXX_HAS_WIN32_THREAD_API=On \
	-DLIBCXX_HAS_EXTERNAL_THREAD_API=Off \
	-DLIBUNWIND_ENABLE_THREADS=On \
	-DLIBUNWIND_HAS_PTHREAD_API=Off \
	-DLIBUNWIND_HAS_WIN32_THREAD_API=On \
	-DLIBUNWIND_HAS_EXTERNAL_THREAD_API=Off"

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
	-DCMAKE_SYSTEM_NAME=Windows \
	-DLLVM_ENABLE_RUNTIMES=$EHBUILDLIBS \
	-DLIBCXXABI_SILENT_TERMINATE=On \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_ENABLE_SHARED=On \
	-DLIBCXX_ABI_VERSION=1 \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS="${LLVMPROJECTPATH}/libcxxabi/include" \
	${THREADS_FLAGS} \
	-DLIBCXX_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXX_ENABLE_RTTI=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_RTTI=${ENABLE_EH} \
	-DLLVM_ENABLE_ASSERTIONS=Off -DLLVM_INCLUDE_EXAMPLES=Off -DLLVM_ENABLE_BACKTRACES=Off -DLLVM_INCLUDE_TESTS=Off -DLIBCXX_INCLUDE_BENCHMARKS=Off \
	-DLIBCXX_ENABLE_SHARED=On -DLIBCXXABI_ENABLE_SHARED=On \
	-DLIBUNWIND_ENABLE_SHARED=On \
	-DLIBCXX_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals" -DLIBCXXABI_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals" -DLIBUNWIND_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -Wno-macro-redefined" \
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
	-DCMAKE_C_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_CXX_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_ASM_LINKER_DEPFILE_SUPPORTED=FALSE
ninja -C . cxx_static
ninja
ninja install/strip
fi

if [ ! -f "${COMPILERRTINSTALLPATH}/lib/windows/libclang_rt.builtins-${TARGETTRIPLE_CPU}.a" ]; then
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
	-DCMAKE_SYSTEM_NAME=Windows \
	-DCOMPILER_RT_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCOMPILER_RT_USE_BUILTINS_LIBRARY=On \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On \
	-DCMAKE_C_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_CXX_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_ASM_LINKER_DEPFILE_SUPPORTED=FALSE
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
	-DCMAKE_SYSTEM_NAME=Windows \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_FLAGS="--target=$TARGETTRIPLE -I${SYSROOTPATH}/include" \
	-DCMAKE_C_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin" \
	-DCMAKE_CXX_FLAGS="-rtlib=compiler-rt -stdlib=libc++ -fuse-ld=lld -flto=thin -lc++abi" \
	-DCMAKE_ASM_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin" \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On \
	-DCMAKE_C_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_CXX_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_ASM_LINKER_DEPFILE_SUPPORTED=FALSE
ninja install/strip
fi

if [ ! -f $CURRENTTRIPLEPATH/libxml2/.installsuccess ]; then
mkdir -p "$CURRENTTRIPLEPATH/libxml2"
cd $CURRENTTRIPLEPATH/libxml2
cmake -GNinja ${TOOLCHAINS_BUILD}/libxml2 -DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_RC_COMPILER=llvm-windres \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=$SYSROOTPATH \
	-DCMAKE_INSTALL_PREFIX=${SYSROOTPATH} \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_SYSTEM_NAME=Windows \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_FLAGS="--target=$TARGETTRIPLE -I${SYSROOTPATH}/include" \
	-DCMAKE_C_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin" \
	-DCMAKE_CXX_FLAGS="-rtlib=compiler-rt -stdlib=libc++ -fuse-ld=lld -flto=thin -lc++abi" \
	-DCMAKE_ASM_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin" \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On \
	-DLIBXML2_WITH_ICONV=Off \
	-DLIBXML2_WITH_PYTHON=Off \
	-DLIBXML2_WITH_RELAXNG=On \
	-DCMAKE_C_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_CXX_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_ASM_LINKER_DEPFILE_SUPPORTED=FALSE
if [ $? -ne 0 ]; then
echo "cmake failed"
exit 1
fi
ninja install/strip
if [ $? -ne 0 ]; then
echo "ninja install/strip failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $CURRENTTRIPLEPATH/libxml2/.installsuccess
fi


if [ ! -f "${SYSROOTPATH}/bin/cppwinrt.exe" ]; then
mkdir -p "$CURRENTTRIPLEPATH/cppwinrt"
cd $CURRENTTRIPLEPATH/cppwinrt
cmake -GNinja $TOOLCHAINS_BUILD/cppwinrt -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang -DCMAKE_RC_COMPILER=llvm-windres \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=$SYSROOTPATH \
	-DCMAKE_CROSSCOMPILING=On -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_SYSTEM_NAME=Windows \
	-DCMAKE_C_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_CXX_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_ASM_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_RC_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_FLAGS="--target=$TARGETTRIPLE -I${SYSROOTPATH}/include" \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On \
	-DCMAKE_C_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin -Wno-unused-command-line-argument" \
	-DCMAKE_CXX_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin -stdlib=libc++ -lc++abi -Wno-unused-command-line-argument -lunwind" \
	-DCMAKE_ASM_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin -Wno-unused-command-line-argument" \
	-DCMAKE_C_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_CXX_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_ASM_LINKER_DEPFILE_SUPPORTED=FALSE
	ninja
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
	-DCMAKE_SYSTEM_NAME=Windows \
	-DBUILD_SHARED_LIBS=On \
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
	-DZLIB_LIBRARY=$SYSROOTPATH/lib/libzlib.dll.a \
	-DLLVM_ENABLE_LIBXML2=FORCE_ON \
	-DLIBXML2_INCLUDE_DIR=$SYSROOTPATH/include/libxml2 \
	-DLIBXML2_LIBRARY=$SYSROOTPATH/lib/libxml2.dll.a \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DCMAKE_C_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_CXX_LINKER_DEPFILE_SUPPORTED=FALSE \
	-DCMAKE_ASM_LINKER_DEPFILE_SUPPORTED=FALSE
fi
cd $CURRENTTRIPLEPATH/llvm
ninja
ninja install/strip
fi

if [ -d "$LLVMINSTALLPATH" ]; then
canadianclangbuiltin="${LLVMINSTALLPATH}/lib/clang/${clang_major_version}"
if [ ! -f "${canadianclangbuiltin}/lib/windows/libclang_rt.builtins-${TARGETTRIPLE_CPU}.a" ]; then
${sudocommand} cp -r --preserve=links "${COMPILERRTINSTALLPATH}"/* "${canadianclangbuiltin}/"
fi

if [ ! -f ${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz ]; then
	cd $TOOLCHAINS_LLVMPATH
	XZ_OPT=-e9T0 tar cJf ${TARGETTRIPLE}.tar.xz ${TARGETTRIPLE}
	chmod 755 ${TARGETTRIPLE}.tar.xz
fi
fi
