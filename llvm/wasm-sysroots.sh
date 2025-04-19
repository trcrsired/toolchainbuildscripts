#!/bin/bash
currentpath=$(realpath .)/.artifacts/wasm-wasis
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
TOOLCHAINS_LLVMSYSROOTSPATH="$TOOLCHAINS_LLVMPATH/wasm-sysroots"

mkdir -p $TOOLCHAINS_LLVMSYSROOTSPATH

mkdir -p $TOOLCHAINS_BUILD
mkdir -p $TOOLCHAINSPATH

clang_path=`which clang`
clang_directory=$(dirname "$clang_path")
clang_version=$(clang --version | grep -oP '\d+\.\d+\.\d+')
clang_major_version="${clang_version%%.*}"
llvm_install_directory="$clang_directory/.."
clangbuiltin="$llvm_install_directory/lib/clang/$clang_major_version"


if [[ ${NEEDSUDOCOMMAND} == "yes" ]]; then
sudocommand="sudo "
else
sudocommand=
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "${currentpath}/wasm-sysroots"
	rm -rf "${TOOLCHAINS_LLVMSYSROOTSPATH}"
	rm "${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz"
	${sudocommand} rm -rf "${clangbuiltin}/lib/wasip1"
	${sudocommand} rm -rf "${clangbuiltin}/lib/wasip2"
	echo "restart done"
fi

if [ -z ${LLVMPROJECTPATH+x} ]; then
LLVMPROJECTPATH=$TOOLCHAINS_BUILD/llvm-project
fi

if [ -z ${WASILIBCPATH+x} ]; then
WASILIBCPATH=$TOOLCHAINS_BUILD/wasi-libc
fi

if [ ! -d ${LLVMPROJECTPATH} ]; then
git clone -b mt-2-msvc git@github.com:trcrsired/llvm-project.git $LLVMPROJECTPATH
fi
cd $LLVMPROJECTPATH
git pull --quiet

if [ ! -d ${WASILIBCPATH} ]; then
git clone -b mt-2 git@github.com:trcrsired/wasi-libc.git $WASILIBCPATH
fi
cd $WASILIBCPATH
git pull --quiet

BUILTINSINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/builtins

MULTITARGETS=(wasm32-wasip1 wasm32-wasip2 wasm32-wasip1-threads wasm32-wasip2-threads wasm64-wasip1 wasm64-wasip1-threads)

function createsysroot() {
SYSROOT_NAME=$1
ENABLE_EH=$2
ENABLE_MEMTAG=$3

for TARGETTRIPLE in "${MULTITARGETS[@]}"; do

MYWASICOMMAND=$WASICOMMAND

CURRENTTRIPLEPATH="$currentpath/wasm-sysroots/$SYSROOT_NAME/$TARGETTRIPLE"

IFS='-' read -ra TARGETTRIPLE_PARTS <<< "$TARGETTRIPLE"

TARGETTRIPLE_CPU="${TARGETTRIPLE_PARTS[0]}"
TARGETTRIPLE_ABI="${TARGETTRIPLE_PARTS[1]}"

if [ ${#TARGETTRIPLE_PARTS[@]} -ge 3 ]; then
TARGETTRIPLE_THREADS="${TARGETTRIPLE_PARTS[2]}"
else
TARGETTRIPLE_THREADS=
fi

if [[ $ENABLE_MEMTAG == "On" ]]; then
MYWASICOMMAND="$MYWASICOMMAND MEMTAG=yes"
fi

if [[ $TARGETTRIPLE_CPU == "wasm64" ]]; then
MYWASICOMMAND="$MYWASICOMMAND WASM64=yes"
fi

if [[ $TARGETTRIPLE_THREADS == "threads" ]]; then
MYWASICOMMAND="$MYWASICOMMAND THREAD_MODEL=posix"
fi

MYWASICOMMAND="$MYWASICOMMAND WASI_SNAPSHOT=${TARGETTRIPLE_ABI:4}"

mkdir -p "$CURRENTTRIPLEPATH"

if [ ! -d "$CURRENTTRIPLEPATH/install/wasi-libc/sysroot" ]; then
cd "$WASILIBCPATH"
rm -rf sysroot build
make -j$(nproc) ${MYWASICOMMAND}
rm -rf build
fi

mkdir -p "$CURRENTTRIPLEPATH/install/wasi-libc"

cd $CURRENTTRIPLEPATH/install/wasi-libc
if [ ! -d "$CURRENTTRIPLEPATH/install/wasi-libc/sysroot" ]; then
cp -r --preserve=links "$WASILIBCPATH/sysroot" "$CURRENTTRIPLEPATH/install/wasi-libc/" 
fi

SYSROOTPATH="$TOOLCHAINS_LLVMSYSROOTSPATH/$SYSROOT_NAME/${TARGETTRIPLE}"
mkdir -p ${SYSROOTPATH}
if [ ! -d "${SYSROOTPATH}/include/${TARGETTRIPLE}" ]; then
cp -r --preserve=links "$CURRENTTRIPLEPATH/install/wasi-libc/sysroot"/* ${SYSROOTPATH}/
fi

if [ ! -f "${BUILTINSINSTALLPATH}/lib/${TARGETTRIPLE_ABI}/libclang_rt.builtins-${TARGETTRIPLE_CPU}.a" ]; then
mkdir -p "$CURRENTTRIPLEPATH/build/compiler-rt"
cd $CURRENTTRIPLEPATH/build/compiler-rt
cmake $LLVMPROJECTPATH/compiler-rt/lib/builtins \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=${BUILTINSINSTALLPATH} \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU -DCOMPILER_RT_BAREMETAL_BUILD=On \
	-DCMAKE_SYSTEM_NAME=wasi \
	-DCOMPILER_RT_OS_DIR=${TARGETTRIPLE_ABI} \
	-DCOMPILER_RT_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE
ninja
ninja install/strip
${sudocommand} cp -r --preserve=links "${BUILTINSINSTALLPATH}"/* "${clangbuiltin}/"
fi
unset COMPILE_LLVM_RUNTIME_ADDITIONAL_COMPILE_FLAGS

if [[ $TARGETTRIPLE_THREADS == "threads" ]]; then
THREADS_FLAGS="-DLIBCXXABI_ENABLE_THREADS=On \
	-DLIBCXXABI_HAS_PTHREAD_API=On \
	-DLIBCXXABI_HAS_WIN32_THREAD_API=Off \
	-DLIBCXXABI_HAS_EXTERNAL_THREAD_API=Off \
	-DLIBCXX_ENABLE_THREADS=On \
	-DLIBCXX_HAS_PTHREAD_API=On \
	-DLIBCXX_HAS_WIN32_THREAD_API=Off \
	-DLIBCXX_HAS_EXTERNAL_THREAD_API=Off \
	-DLIBUNWIND_ENABLE_THREADS=On"
COMPILE_LLVM_RUNTIME_ADDITIONAL_COMPILE_FLAGS="-D_REENTRANT"
else
THREADS_FLAGS="-DLIBCXXABI_ENABLE_THREADS=Off \
	-DLIBCXXABI_HAS_PTHREAD_API=Off \
	-DLIBCXXABI_HAS_WIN32_THREAD_API=Off \
	-DLIBCXXABI_HAS_EXTERNAL_THREAD_API=Off \
	-DLIBCXX_ENABLE_THREADS=Off \
	-DLIBCXX_HAS_PTHREAD_API=Off \
	-DLIBCXX_HAS_WIN32_THREAD_API=Off \
	-DLIBCXX_HAS_EXTERNAL_THREAD_API=Off \
	-DLIBUNWIND_ENABLE_THREADS=Off"
COMPILE_LLVM_RUNTIME_ADDITIONAL_COMPILE_FLAGS="-D_WASI_EMULATED_PTHREAD"
fi

if [[ $ENABLE_EH == "On" ]]; then
EHBUILDLIBS="libcxx;libcxxabi;libunwind"
COMPILE_LLVM_RUNTIME_ADDITIONAL_COMPILE_FLAGS="-fwasm-exceptions;$COMPILE_LLVM_RUNTIME_ADDITIONAL_COMPILE_FLAGS"
else
EHBUILDLIBS="libcxx;libcxxabi"
fi


RUNTIMESINSTALLPATH="$CURRENTTRIPLEPATH/install/runtimes"

if [ ! -d "$RUNTIMESINSTALLPATH" ]; then

mkdir -p "$CURRENTTRIPLEPATH/build/runtimes"
cd $CURRENTTRIPLEPATH/build/runtimes

cmake $LLVMPROJECTPATH/runtimes \
	-G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=$RUNTIMESINSTALLPATH \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE -DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_SYSTEM_NAME=Generic \
	-DLLVM_ENABLE_RUNTIMES=$EHBUILDLIBS \
	-DLIBCXXABI_SILENT_TERMINATE=On \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_ENABLE_SHARED=Off \
	-DLIBCXX_ABI_VERSION=2 \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS="${LLVMPROJECTPATH}/libcxxabi/include" \
	${THREADS_FLAGS} \
	-DLIBCXX_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_EXCEPTIONS=${ENABLE_EH} \
	-DLIBCXX_ENABLE_RTTI=${ENABLE_EH} \
	-DLIBCXXABI_ENABLE_RTTI=${ENABLE_EH} \
	-DLLVM_ENABLE_ASSERTIONS=Off -DLLVM_INCLUDE_EXAMPLES=Off -DLLVM_ENABLE_BACKTRACES=Off -DLLVM_INCLUDE_TESTS=Off -DLIBCXX_INCLUDE_BENCHMARKS=Off \
	-DLIBCXX_ENABLE_SHARED=Off -DLIBCXXABI_ENABLE_SHARED=Off \
	-DLIBUNWIND_ENABLE_SHARED=Off -DLIBCXXABI_USE_LLVM_UNWINDER=$ENABLE_EH \
	-DLIBUNWIND_ADDITIONAL_COMPILE_FLAGS="$COMPILE_LLVM_RUNTIME_ADDITIONAL_COMPILE_FLAGS" \
	-DLIBCXX_ADDITIONAL_COMPILE_FLAGS="$COMPILE_LLVM_RUNTIME_ADDITIONAL_COMPILE_FLAGS" \
	-DLIBCXXABI_ADDITIONAL_COMPILE_FLAGS="$COMPILE_LLVM_RUNTIME_ADDITIONAL_COMPILE_FLAGS"
if [ $? -ne 0 ]; then
echo "runtimes configure failure"
rm -rf "$CURRENTTRIPLEPATH/build/runtimes"
exit 1
fi
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "runtimes build failure"
exit 1
fi
make -j$(nproc) install/strip
if [ $? -ne 0 ]; then
echo "runtimes install/strip failure"
exit 1
fi

if [ -d "$RUNTIMESINSTALLPATH/include" ]; then

mkdir -p "$RUNTIMESINSTALLPATH/include_temp"
mv "$RUNTIMESINSTALLPATH/include" "$RUNTIMESINSTALLPATH/include_temp/"
mv "$RUNTIMESINSTALLPATH/include_temp" "$RUNTIMESINSTALLPATH/include"
mv "$RUNTIMESINSTALLPATH/include/include" "$RUNTIMESINSTALLPATH/include/$TARGETTRIPLE"
mv "$RUNTIMESINSTALLPATH/include/$TARGETTRIPLE/c++" "$RUNTIMESINSTALLPATH/include/"

mkdir -p "$RUNTIMESINSTALLPATH/lib_temp"
mv "$RUNTIMESINSTALLPATH/lib" "$RUNTIMESINSTALLPATH/lib_temp/"
mv "$RUNTIMESINSTALLPATH/lib_temp" "$RUNTIMESINSTALLPATH/lib"
mv "$RUNTIMESINSTALLPATH/lib/lib" "$RUNTIMESINSTALLPATH/lib/$TARGETTRIPLE"

#mkdir -p "$RUNTIMESINSTALLPATH/share_temp"
#mv "$RUNTIMESINSTALLPATH/share" "$RUNTIMESINSTALLPATH/share_temp/"
#mv "$RUNTIMESINSTALLPATH/share_temp" "$RUNTIMESINSTALLPATH/share"
#mv "$RUNTIMESINSTALLPATH/share/share" "$RUNTIMESINSTALLPATH/share/$TARGETTRIPLE"

cp -r --preserve=links "$RUNTIMESINSTALLPATH"/* "${SYSROOTPATH}/"

fi

fi

done

}

createsysroot wasm-sysroot On Off
createsysroot wasm-memtag-sysroot On On
createsysroot wasm-noeh-sysroot Off Off
createsysroot wasm-noeh-memtag-sysroot Off On

if [ ! -f ${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz ]; then
	cd $TOOLCHAINS_LLVMPATH
	XZ_OPT=-e9T0 tar cJf wasm-sysroots.tar.xz wasm-sysroots
	chmod 755 wasm-sysroots.tar.xz
fi
