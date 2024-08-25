#!/bin/bash

currentpath=$(realpath .)/.llvmwindowsmsvclibcxxartifacts/${TARGETTRIPLE}
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

if [ -z ${LLVMPROJECTPATH+x} ]; then
LLVMPROJECTPATH=$TOOLCHAINS_BUILD/llvm-project
fi

if [ ! -d "$LLVMPROJECTPATH" ]; then
cd $TOOLCHAINS_BUILD
git clone git@github.com:llvm/llvm-project.git $LLVMPROJECTPATH
fi
cd "$LLVMPROJECTPATH"
git pull --quiet


if [ -z ${WINDOWSSYSROOT+x} ]; then
WINDOWSSYSROOT=$TOOLCHAINSPATH/windows-msvc-sysroot
fi

if [ ! -d "$WINDOWSSYSROOT" ]; then
cd $TOOLCHAINSPATH
git clone git@github.com:trcrsired/windows-msvc-sysroot.git
fi
cd "$WINDOWSSYSROOT"
git pull --quiet

mkdir -p ${currentpath}
CURRENTTRIPLEPATH=${currentpath}

if [ ! -f "${currentpath}/runtimes/.runtimesconfigure" ]; then
mkdir -p ${currentpath}/runtimes
cd ${currentpath}/runtimes
cmake -GNinja $LLVMPROJECTPATH/runtimes \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DLLVM_ENABLE_LLD=On -DLLVM_ENABLE_LTO=thin -DCMAKE_INSTALL_PREFIX=${currentpath}/installs/x86_64-windows-msvc \
	-DLLVM_ENABLE_RUNTIMES="libcxx" -DCMAKE_SYSTEM_PROCESSOR="x86_64" -DCMAKE_C_COMPILER_TARGET=x86_64-windows-msvc \
    -DCMAKE_CXX_COMPILER_TARGET=x86_64-windows-msvc -DCMAKE_ASM_COMPILER_TARGET=x86_64-windows-msvc -DCMAKE_C_COMPILER_WORKS=On \
	-DLIBCXXABI_SILENT_TERMINATE=On -DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DLIBCXX_CXX_ABI=vcruntime
if [ $? -ne 0 ]; then
echo "runtimesconfigure build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/runtimes/.runtimesconfigure
fi


if [ ! -f "${currentpath}/runtimes/.runtimesninja" ]; then
mkdir -p ${currentpath}/runtimes
cd ${currentpath}/runtimes
ninja
if [ $? -ne 0 ]; then
echo "runtimesconfigure build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/runtimes/.runtimesninja
fi

if [ ! -f "${currentpath}/runtimes/.runtimesninjainstall" ]; then
mkdir -p ${currentpath}/runtimes
cd ${currentpath}/runtimes
ninja install/strip
if [ $? -ne 0 ]; then
echo "runtimesconfigure build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/runtimes/.runtimesninjainstall
fi