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
if [ -z ${ANDROIDAPIVERSION+x} ]; then
ANDROIDAPIVERSION=30
fi
TARGETTRIPLENOVERSION=${TARGETTRIPLE_CPU}-linux-android
TARGETTRIPLE=${TARGETTRIPLENOVERSION}${ANDROIDAPIVERSION}
TARGETUNKNOWNTRIPLE=${TARGETTRIPLE_CPU}-unknown-linux-android${ANDROIDAPIVERSION}
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

if [ -z ${ANDROIDNDKVERSION+x} ]; then
ANDROIDNDKVERSION=r28
fi
ANDROIDNDKVERSIONSHORTNAME=android-ndk-${ANDROIDNDKVERSION}
ANDROIDNDKVERSIONFULLNAME=android-ndk-${ANDROIDNDKVERSION}-linux


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
if [ ! -d "$TOOLCHAINS_BUILD/libxml2" ]; then
git clone https://gitlab.gnome.org/GNOME/libxml2.git
if [ $? -ne 0 ]; then
echo "libxml2 clone failure"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/libxml2"
git pull --quiet

BUILTINSINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/builtins
COMPILERRTINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/compiler-rt
ANDROIDSYSROOTPATH="$TOOLCHAINS_LLVMSYSROOTSPATH/${TARGETTRIPLE}"
SYSROOTPATH="${ANDROIDSYSROOTPATH}/usr"

mkdir -p ${currentpath}
mkdir -p ${SYSROOTPATH}

if [ ! -f ${SYSROOTPATH}/include/stdio.h ]; then
mkdir -p ${currentpath}/bionic
cd ${currentpath}/bionic
wget https://dl.google.com/android/repository/${ANDROIDNDKVERSIONFULLNAME}.zip
chmod 755 ${ANDROIDNDKVERSIONFULLNAME}.zip
unzip ${ANDROIDNDKVERSIONFULLNAME}.zip
cp -r --preserve=links ${currentpath}/bionic/${ANDROIDNDKVERSIONSHORTNAME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${TARGETTRIPLENOVERSION}/${ANDROIDAPIVERSION} ${SYSROOTPATH}/lib
cp -r --preserve=links ${currentpath}/bionic/${ANDROIDNDKVERSIONSHORTNAME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include ${SYSROOTPATH}/
cp -r --preserve=links ${SYSROOTPATH}/include/${TARGETTRIPLENOVERSION}/asm ${SYSROOTPATH}/include/
fi

CURRENTTRIPLEPATH=${currentpath}

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
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DANDROID=On \
	-DCMAKE_SIZEOF_VOID_P=$CMAKE_SIZEOF_VOID_P
if [ $? -ne 0 ]; then
echo "compiler-rt builtins cmake failed"
exit 1
fi
ninja
if [ $? -ne 0 ]; then
echo "compiler-rt builtins ninja failed"
exit 1
fi
ninja install/strip
if [ $? -ne 0 ]; then
echo "compiler-rt builtins ninja install failed"
exit 1
fi
cd ${BUILTINSINSTALLPATH}/lib
mv linux ${TARGETUNKNOWNTRIPLE}
cd ${TARGETUNKNOWNTRIPLE}
for file in *-${TARGETTRIPLE_CPU}*; do
    new_name="${file//-${TARGETTRIPLE_CPU}-android/}"
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

if [ ! -f "${COMPILERRTINSTALLPATH}/lib/${TARGETUNKNOWNTRIPLE}/libclang_rt.builtins.a" ]; then
mkdir -p "$CURRENTTRIPLEPATH/compiler-rt"
cd $CURRENTTRIPLEPATH/compiler-rt
cmake $LLVMPROJECTPATH/compiler-rt \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$ANDROIDSYSROOTPATH -DCMAKE_INSTALL_PREFIX=${COMPILERRTINSTALLPATH} \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU_ALIAS \
	-DCOMPILER_RT_DEFAULT_TARGET_ARCH=${TARGETTRIPLE_CPU_ALIAS} \
	-DCMAKE_SYSTEM_NAME=${SYSTEMNAME} \
	-DCOMPILER_RT_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCOMPILER_RT_USE_BUILTINS_LIBRARY=On \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On
if [ $? -ne 0 ]; then
echo "compiler-rt cmake failure"
exit 1
fi
ninja
if [ $? -ne 0 ]; then
echo "compiler-rt ninja failure"
exit 1
fi
ninja install/strip
if [ $? -ne 0 ]; then
echo "compiler-rt ninja install/strip failure"
exit 1
fi
cd ${COMPILERRTINSTALLPATH}/lib
mv linux ${TARGETUNKNOWNTRIPLE}
cd ${TARGETUNKNOWNTRIPLE}
for file in *-${TARGETTRIPLE_CPU}*; do
    new_name="${file//-${TARGETTRIPLE_CPU}-android/}"
    mv "$file" "$new_name"
done
for file in *.so; do
	filename="${file%.so}"
	ln -s "$file" "${filename}-${TARGETTRIPLE_CPU}-android.so"
done

${sudocommand} cp -r --preserve=links "${COMPILERRTINSTALLPATH}"/* "${clangbuiltin}/"
fi

if [ ! -f "${SYSROOTPATH}/lib/libz.a" ]; then
mkdir -p "$CURRENTTRIPLEPATH/zlib"
cd $CURRENTTRIPLEPATH/zlib
cmake ${TOOLCHAINS_BUILD}/zlib -DCMAKE_SYSROOT=$ANDROIDSYSROOTPATH -DCMAKE_RC_COMPILER=llvm-windres \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_INSTALL_PREFIX=$SYSROOTPATH \
	-DCMAKE_INSTALL_PREFIX=${SYSROOTPATH} \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTPATH} \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
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
make install/strip -j$(nproc)
if [ $? -ne 0 ]; then
echo "zlib make install/strip failure"
exit 1
fi
fi

if [ ! -f "${SYSROOTPATH}/lib/libxml2.a" ]; then
mkdir -p "$CURRENTTRIPLEPATH/libxml2"
cd $CURRENTTRIPLEPATH/libxml2
cmake -GNinja ${TOOLCHAINS_BUILD}/libxml2 -DCMAKE_SYSROOT=$ANDROIDSYSROOTPATH -DCMAKE_RC_COMPILER=llvm-windres \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_INSTALL_PREFIX=$SYSROOTPATH \
	-DCMAKE_INSTALL_PREFIX=${SYSROOTPATH} \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU_ALIAS \
	-DCMAKE_SYSTEM_NAME=${SYSTEMNAME} \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_SHARED_LIBS=Off \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_FLAGS="--target=$TARGETTRIPLE -I${SYSROOTPATH}/include" \
	-DCMAKE_C_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin -fPIC" \
	-DCMAKE_CXX_FLAGS="-rtlib=compiler-rt -stdlib=libc++ -fuse-ld=lld -flto=thin -lc++abi -fPIC -I${SYSROOTPATH}/include" \
	-DCMAKE_ASM_FLAGS="-rtlib=compiler-rt -fuse-ld=lld -flto=thin -fPIC" \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On \
	-DLIBXML2_WITH_ICONV=Off \
	-DLIBXML2_WITH_PYTHON=Off \
	-DLIBXML2_WITH_RELAXNG=On
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
	-DLLVM_ENABLE_LIBXML2=FORCE_ON \
	-DLIBXML2_INCLUDE_DIR=$SYSROOTPATH/include/libxml2 \
	-DLIBXML2_LIBRARY=$SYSROOTPATH/lib/libxml2.a \
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
if [ ! -f "${canadianclangbuiltin}/lib/${TARGETUNKNOWNTRIPLE}/libclang_rt.builtins.a" ]; then
${sudocommand} cp -r --preserve=links "${BUILTINSINSTALLPATH}"/* "${canadianclangbuiltin}/"
fi

if [ ! -f ${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz ]; then
	cd $TOOLCHAINS_LLVMPATH
	XZ_OPT=-e9T0 tar cJf ${TARGETTRIPLE}.tar.xz ${TARGETTRIPLE}
	chmod 755 ${TARGETTRIPLE}.tar.xz
fi
fi
