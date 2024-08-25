#!/bin/bash

currentpath=$(realpath .)/.llvmwindowsmsvclibcxxartifacts
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

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "${currentpath}"
	echo "restart done"
fi

if [ ! -d "$LLVMPROJECTPATH" ]; then
cd $TOOLCHAINS_BUILD
git clone git@github.com:llvm/llvm-project.git $LLVMPROJECTPATH
if [ $? -ne 0 ]; then
echo "llvm clone failure"
exit 1
fi
fi
cd "$LLVMPROJECTPATH"
git pull --quiet


if [ -z ${WINDOWSSYSROOT+x} ]; then
WINDOWSSYSROOT=$TOOLCHAINSPATH/windows-msvc-sysroot
fi

if [ ! -d "$WINDOWSSYSROOT" ]; then
cd $TOOLCHAINSPATH
git clone git@github.com:trcrsired/windows-msvc-sysroot.git
if [ $? -ne 0 ]; then
echo "windows-msvc-sysroot clone failure"
exit 1
fi
fi
cd "$WINDOWSSYSROOT"
git pull --quiet

mkdir -p ${currentpath}
CURRENTTRIPLEPATH=${currentpath}

function handlebuild
{
local hosttriple=$1
local buildprefix=${currentpath}/$hosttriple-windows-msvc
if [ ! -f "${buildprefix}/runtimes/.runtimesconfigure" ]; then
mkdir -p ${buildprefix}/runtimes
cd ${buildprefix}/runtimes
cmake -GNinja $LLVMPROJECTPATH/runtimes \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DLLVM_ENABLE_LLD=On -DLLVM_ENABLE_LTO=thin -DCMAKE_INSTALL_PREFIX=${buildprefix}/installs/$hosttriple-windows-msvc \
	-DLLVM_ENABLE_RUNTIMES="libcxx" -DCMAKE_SYSTEM_PROCESSOR="$hosttriple" -DCMAKE_C_COMPILER_TARGET=$hosttriple-windows-msvc \
    -DCMAKE_CXX_COMPILER_TARGET=$hosttriple-windows-msvc -DCMAKE_ASM_COMPILER_TARGET=$hosttriple-windows-msvc -DCMAKE_C_COMPILER_WORKS=On \
	-DLIBCXXABI_SILENT_TERMINATE=On -DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DLIBCXX_CXX_ABI=vcruntime \
    -DCMAKE_SYSROOT=$WINDOWSSYSROOT \
    -DCMAKE_C_FLAGS="-fuse-ld=lld -flto=thin -D_DLL=1 -stdlib=libc++ -Wno-unused-command-line-argument --sysroot=$WINDOWSSYSROOT" \
    -DCMAKE_CXX_FLAGS="-fuse-ld=lld -flto=thin -D_DLL=1 -stdlib=libc++ -Wno-unused-command-line-argument --sysroot=$WINDOWSSYSROOT" \
    -DCMAKE_ASM_FLAGS="-fuse-ld=lld -flto=thin -D_DLL=1 -stdlib=libc++ -Wno-unused-command-line-argument --sysroot=$WINDOWSSYSROOT" \
    -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_CROSSCOMPILING=On -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DLLVM_ENABLE_ASSERTIONS=Off -DLLVM_INCLUDE_EXAMPLES=Off -DLLVM_ENABLE_BACKTRACES=Off \
    -DLLVM_INCLUDE_TESTS=Off -DLIBCXX_INCLUDE_BENCHMARKS=Off 
if [ $? -ne 0 ]; then
echo "runtimesconfigure build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${buildprefix}/runtimes/.runtimesconfigure
fi


if [ ! -f "${buildprefix}/runtimes/.runtimesninja" ]; then
mkdir -p ${buildprefix}/runtimes
cd ${buildprefix}/runtimes
ninja
if [ $? -ne 0 ]; then
echo "runtimes build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${buildprefix}/runtimes/.runtimesninja
fi

if [ ! -f "${buildprefix}/runtimes/.runtimesninjainstall" ]; then
mkdir -p ${buildprefix}/runtimes
cd ${buildprefix}/runtimes
ninja install/strip
if [ $? -ne 0 ]; then
echo "runtimes install failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${buildprefix}/runtimes/.runtimesninjainstall
fi

if [ ! -f "${buildprefix}/runtimes/.runtimescopied" ]; then
echo cp -r ${buildprefix}/installs/$hosttriple-windows-msvc/include $WINDOWSSYSROOT/
echo cp -r ${buildprefix}/installs/$hosttriple-windows-msvc/lib/* $WINDOWSSYSROOT/lib/$hosttriple-unknown-windows-msvc/
echo cp -r ${buildprefix}/installs/$hosttriple-windows-msvc/bin/* $WINDOWSSYSROOT/bin/$hosttriple-unknown-windows-msvc/
fi

}

handlebuild x86_64
handlebuild i686
handlebuild aarch64