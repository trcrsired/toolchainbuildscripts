#!/bin/bash

if [ -z ${ARCH+x} ]; then
ARCH=aarch64
ARCHALTERNATIVE=arm64
fi
TARGETTRIPLE_CPU=${ARCH}
if [[ ${TARGETTRIPLE_CPU} == "aarch64" ]]; then
TARGETTRIPLE_CPU_ALIAS=aarch64
else
TARGETTRIPLE_CPU_ALIAS=${TARGETTRIPLE_CPU}
fi

TARGETTRIPLENOVERSION=${TARGETTRIPLE_CPU}-linux-ohos
TARGETTRIPLE=${TARGETTRIPLENOVERSION}
TARGETUNKNOWNTRIPLE=${TARGETTRIPLE_CPU}-unknown-linux-ohos
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
SYSTEMNAME=Linux

if [[ ${NEEDSUDOCOMMAND} == "yes" ]]; then
sudocommand="sudo "
else
sudocommand=
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "${currentpath}"
	rm -rf "${TOOLCHAINS_LLVMSYSROOTSPATH}"
	rm "${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz"
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

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/zlib" ]; then
git clone git@github.com:trcrsired/zlib.git
fi
cd "$TOOLCHAINS_BUILD/zlib"
git pull --quiet

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/ohos_third_party_musl" ]; then
git clone https://gitee.com/openharmony/third_party_musl.git ohos_third_party_musl
fi
cd "$TOOLCHAINS_BUILD/ohos_third_party_musl"
git pull --quiet

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


if [ ! -d "$TOOLCHAINS_BUILD/fortify-headers" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git@github.com:jvoisin/fortify-headers.git
if [ $? -ne 0 ]; then
echo "linux clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/fortify-headers"
git pull --quiet

BUILTINSINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/builtins
COMPILERRTINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/compiler-rt
ANDROIDSYSROOTPATH="$TOOLCHAINS_LLVMSYSROOTSPATH/${TARGETTRIPLE}"
SYSROOTPATH="${ANDROIDSYSROOTPATH}"

CURRENTTRIPLEPATH=${currentpath}

mkdir -p ${currentpath}
mkdir -p ${SYSROOTPATH}

if [ ! -f ${currentpath}/.linuxkernelheadersinstallsuccess ]; then
	cd "$TOOLCHAINS_BUILD/linux"
	make headers_install ARCH=$ARCHALTERNATIVE -j INSTALL_HDR_PATH=$SYSROOTPATH
	if [ $? -ne 0 ]; then
	echo "linux kernel headers install failure"
	exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${currentpath}/.linuxkernelheadersinstallsuccess
fi

if [ ! -f ${currentpath}/.fortify-headers-installedsuccess ]; then
	cd "$TOOLCHAINS_BUILD/fortify-headers"
	make install -j PREFIX=$SYSROOTPATH
	if [ $? -ne 0 ]; then
	echo "fortify-headers install failure"
	exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${currentpath}/.fortify-headers-installedsuccess
fi

if [ ! -f ${currentpath}/musl_build/.muslconfiguresuccess ]; then
mkdir -p ${currentpath}/musl_build
cd ${currentpath}/musl_build
STRIP=llvm-strip NM=llvm-nm CXXFILT=llvm-cxxfilt OBJDUMP=llvm-objdump AR=llvm-ar RANLIB=llvm-ranlib DLLTOOL=llvm-dlltool WINDRES=llvm-windres CC="clang --target=$TARGETTRIPLE -fuse-ld=lld" CXX="clang++ --target=$TARGETTRIPLE -fuse-ld=lld"  ${TOOLCHAINS_BUILD}/ohos_third_party_musl/configure --disable-nls --disable-werror --target=$TARGETTRIPLE --sysroot=$SYSROOTPATH
if [ $? -ne 0 ]; then
echo "OpenHarmony Musl configure failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/musl_build/.muslconfiguresuccess
fi

if [ ! -f ${currentpath}/musl_build/.muslbuildsuccess ]; then
mkdir -p ${currentpath}/musl_build
cd ${currentpath}/musl_build
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "OpenHarmony Musl build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/musl_build/.muslbuildsuccess
fi
if [ ! -f ${currentpath}/musl_build/.muslinstallsuccess ]; then
mkdir -p ${currentpath}/musl_build
cd ${currentpath}/musl_build
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
echo "OpenHarmony Musl install failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/musl_build/.muslinstallsuccess
fi


if [ ! -f "${BUILTINSINSTALLPATH}/lib/${TARGETUNKNOWNTRIPLE}/libclang_rt.builtins.a" ]; then
mkdir -p "$CURRENTTRIPLEPATH/builtins"
cd $CURRENTTRIPLEPATH/builtins
cmake $LLVMPROJECTPATH/compiler-rt/lib/builtins \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$ANDROIDSYSROOTPATH -DCMAKE_INSTALL_PREFIX=${BUILTINSINSTALLPATH} \
		-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU_ALIAS \
	-DCMAKE_C_FLAGS="-fuse-ld=lld -flto=thin -Wno-unused-command-line-argument" -DCMAKE_CXX_FLAGS="-fuse-ld=lld -flto=thin -Wno-unused-command-line-argument" -DCMAKE_ASM_FLAGS="-fuse-ld=lld -flto=thin -Wno-unused-command-line-argument" \
	-DCMAKE_SYSTEM_NAME=${SYSTEMNAME} \
	-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
	-DLLVM_ENABLE_LTO=thin \
	-DLLVM_ENABLE_LLD=On \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTPATH} \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
ninja
ninja install/strip
cd ${BUILTINSINSTALLPATH}/lib
mv linux ${TARGETUNKNOWNTRIPLE}
cd ${TARGETUNKNOWNTRIPLE}
for file in *-aarch64*; do
    new_name="${file//-aarch64/}"
    mv "$file" "$new_name"
done
${sudocommand} cp -r --preserve=links "${BUILTINSINSTALLPATH}"/* "${clangbuiltin}/"
fi

THREADS_FLAGS="-DLIBCXXABI_ENABLE_THREADS=On \
	-DLIBCXX_ENABLE_THREADS=On \
	-DLIBUNWIND_ENABLE_THREADS=On"

EHBUILDLIBS="libcxx;libcxxabi;libunwind"
ENABLE_EH=On

if [ ! -d "${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes/lib" ]; then

mkdir -p "$CURRENTTRIPLEPATH/runtimes"
cd $CURRENTTRIPLEPATH/runtimes

cmake $LLVMPROJECTPATH/runtimes \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT="$ANDROIDSYSROOTPATH" -DCMAKE_INSTALL_PREFIX="${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes" \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU_ALIAS \
	-DCMAKE_SYSTEM_NAME=${SYSTEMNAME} \
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
	-DLIBCXX_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals" -DLIBCXXABI_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals -Wno-unused-command-line-argument" -DLIBUNWIND_ADDITIONAL_COMPILE_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -Wno-macro-redefined -Wno-unused-command-line-argument" \
	-DLIBCXX_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -nostdinc++ -Wno-macro-redefined -Wno-user-defined-literals -L$CURRENTTRIPLEPATH/runtimes/lib -Wno-unused-command-line-argument" \
	-DLIBCXXABI_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-user-defined-literals -Wno-unused-command-line-argument -L$CURRENTTRIPLEPATH/runtimes/lib" \
	-DLIBUNWIND_ADDITIONAL_LIBRARIES="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-macro-redefined -Wno-unused-command-line-argument" \
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
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
ninja -C . cxx_static
ninja
ninja install/strip
cd ${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes/lib
rm libc++.so
ln -s libc++.so.1 libc++.so
cp -r --preserve=links "${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes"/* "${SYSROOTPATH}/"
fi
<<COMMENT

if [ ! -f "${COMPILERRTINSTALLPATH}/lib/${TARGETUNKNOWNTRIPLE}/libclang_rt.builtins.a" ]; then
mkdir -p "$CURRENTTRIPLEPATH/compiler-rt"
cd $CURRENTTRIPLEPATH/compiler-rt
cmake $LLVMPROJECTPATH/compiler-rt \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSROOT=$ANDROIDSYSROOTPATH -DCMAKE_INSTALL_PREFIX=${COMPILERRTINSTALLPATH} \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU_ALIAS \
	-DCOMPILER_RT_DEFAULT_TARGET_ARCH=${TARGETTRIPLE_CPU_ALIAS} \
	-DCOMPILER_RT_USE_LIBCXX=On \
	-DCMAKE_C_FLAGS="-fuse-ld=lld -flto=thin -stdlib=libc++ -rtlib=compiler-rt -Wno-unused-command-line-argument" -DCMAKE_CXX_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-unused-command-line-argument -lc++abi -lunwind" -DCMAKE_ASM_FLAGS="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -stdlib=libc++ -Wno-unused-command-line-argument" \
	-DCMAKE_SYSTEM_NAME=${SYSTEMNAME} \
	-DCOMPILER_RT_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCOMPILER_RT_USE_BUILTINS_LIBRARY=On \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On
ninja
ninja install/strip
cd ${COMPILERRTINSTALLPATH}/lib
mv linux ${TARGETUNKNOWNTRIPLE}
cd ${TARGETUNKNOWNTRIPLE}
for file in *-aarch64*; do
    new_name="${file//-aarch64/}"
    mv "$file" "$new_name"
done
${sudocommand} cp -r --preserve=links "${COMPILERRTINSTALLPATH}"/* "${clangbuiltin}/"

COMMENT
if [ ! -f "${SYSROOTPATH}/lib/libz.a" ]; then
mkdir -p "$CURRENTTRIPLEPATH/zlib"
cd $CURRENTTRIPLEPATH/zlib
cmake -GNinja ${TOOLCHAINS_BUILD}/zlib -DCMAKE_SYSROOT=$ANDROIDSYSROOTPATH -DCMAKE_RC_COMPILER=llvm-windres \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_INSTALL_PREFIX=$SYSROOTPATH \
	-DCMAKE_INSTALL_PREFIX=${SYSROOTPATH} \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU_ALIAS \
	-DCMAKE_SYSTEM_NAME=${SYSTEMNAME} \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_FLAGS="--target=$TARGETTRIPLE -I${SYSROOTPATH}/include" \
	-DCMAKE_C_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin -fPIC" \
	-DCMAKE_CXX_FLAGS="-rtlib=compiler-rt -stdlib=libc++ -fuse-ld=lld -flto=thin -lc++abi -fPIC -I${SYSROOTPATH}/include" \
	-DCMAKE_ASM_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin -fPIC" \
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
	-DCMAKE_SYSROOT=$ANDROIDSYSROOTPATH -DCMAKE_INSTALL_PREFIX=$LLVMINSTALLPATH \
	-DCMAKE_CROSSCOMPILING=On \
	-DLLVM_HOST_TRIPLE=$TARGETTRIPLE \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU_ALIAS \
	-DCMAKE_SYSTEM_NAME=${SYSTEMNAME} \
	-DBUILD_SHARED_LIBS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU_ALIAS \
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
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DHAVE_CXX_ATOMICS_WITHOUT_LIB=On \
	-DHAVE_CXX_ATOMICS64_WITHOUT_LIB=On
fi
cd $CURRENTTRIPLEPATH/llvm
ninja
ninja install/strip
fi

if [ -d "$LLVMINSTALLPATH" ]; then
canadianclangbuiltin="${LLVMINSTALLPATH}/lib/clang/${clang_major_version}"
if [ ! -f "${canadianclangbuiltin}/lib/${TARGETUNKNOWNTRIPLE}/libclang_rt.builtins-${TARGETTRIPLE_CPU}.a" ]; then
${sudocommand} cp -r --preserve=links "${BUILTINSINSTALLPATH}"/* "${canadianclangbuiltin}/"
fi

if [ ! -f ${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz ]; then
	cd $TOOLCHAINS_LLVMPATH
	XZ_OPT=-e9T0 tar cJf ${TARGETTRIPLE}.tar.xz ${TARGETTRIPLE}
	chmod 755 ${TARGETTRIPLE}.tar.xz
fi
fi
