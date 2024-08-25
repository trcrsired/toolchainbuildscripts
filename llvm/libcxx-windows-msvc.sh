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

if [ -z ${USELIBCXXABI+x} ]; then
EHBUILDLIBS="libcxx"
else
EHBUILDLIBS="libcxx;libcxxabi"
fi

function handlebuild
{
local hostarch=$1
local hosttriple=$1-unknown-windows-msvc
local buildprefix=${currentpath}/$hosttriple
local flags
local runtimes
if [ -z ${USELIBCXXABI+x} ]; then
flags="-fuse-ld=lld -flto=thin -D_DLL=1 -stdlib=libc++ -Wno-unused-command-line-argument -lmsvcrt -lmsvcprt --sysroot=$WINDOWSSYSROOT"
runtimes=vcruntime
else
flags="-fuse-ld=lld -flto=thin -D_DLL=1 -stdlib=libc++ -Wno-unused-command-line-argument -lmsvcrt -sysroot=$WINDOWSSYSROOT"
runtimes=libcxxabi
fi

if [ ! -f "${buildprefix}/runtimes/.runtimesconfigure" ]; then
mkdir -p ${buildprefix}/runtimes
cd ${buildprefix}/runtimes
cmake -GNinja $LLVMPROJECTPATH/runtimes \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DLLVM_ENABLE_LLD=On -DCMAKE_INSTALL_PREFIX=${buildprefix}/installs/$hosttriple \
    -DLLVM_ENABLE_RUNTIMES=$EHBUILDLIBS \
	-DCMAKE_SYSTEM_PROCESSOR="$hosttriple" -DCMAKE_C_COMPILER_TARGET=$hosttriple \
    -DCMAKE_CXX_COMPILER_TARGET=$hosttriple -DCMAKE_ASM_COMPILER_TARGET=$hosttriple -DCMAKE_C_COMPILER_WORKS=On \
	-DLIBCXXABI_SILENT_TERMINATE=On -DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DLIBCXX_CXX_ABI=$runtimes \
    -DCMAKE_SYSROOT=$WINDOWSSYSROOT \
    -DLIBCXX_CXX_ABI_INCLUDE_PATHS="${LLVMPROJECTPATH}/libcxxabi/include" \
    ${THREADS_FLAGS} \
    -DCMAKE_C_FLAGS="$flags" \
    -DCMAKE_CXX_FLAGS="$flags" \
    -DCMAKE_ASM_FLAGS="$flags" \
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

if [ ! -f "${buildprefix}/runtimes/.runtimesmodulefix" ]; then
echo sed -i "s|../share/|../../share/${hosttriple}/|g" "${buildprefix}/installs/${hosttriple}/lib/libc++.modules.json"
sed -i "s|../share/|../../share/${hosttriple}/|g" "${buildprefix}/installs/${hosttriple}/lib/libc++.modules.json"
if [ $? -ne 0 ]; then
echo "runtimes fix rename failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${buildprefix}/runtimes/.runtimesmodulefix
fi

if [ ! -f "${buildprefix}/runtimes/.runtimescopied" ]; then
cp -r --preserve=links ${buildprefix}/installs/$hosttriple/include $WINDOWSSYSROOT/
cp -r --preserve=links ${buildprefix}/installs/$hosttriple/lib/* $WINDOWSSYSROOT/lib/$hosttriple/
cp -r --preserve=links ${buildprefix}/installs/$hosttriple/bin/* $WINDOWSSYSROOT/bin/$hosttriple/
cp -r --preserve=links ${buildprefix}/installs/$hosttriple/share/* $WINDOWSSYSROOT/share/$hosttriple/
fi

if [ ! -f "${buildprefix}/runtimes/.runtimesupdated" ]; then
cd $WINDOWSSYSROOT
git add $WINDOWSSYSROOT/include/c++/v1/*
git add $WINDOWSSYSROOT/lib/$hosttriple/*
git add $WINDOWSSYSROOT/bin/$hosttriple/*
git add $WINDOWSSYSROOT/share/$hosttriple/*
echo "$(date --iso-8601=seconds)" > ${buildprefix}/runtimes/.runtimesupdated
fi

}

handlebuild x86_64
handlebuild i686
handlebuild aarch64

if [ ! -f "${currentpath}/.runtimespushed" ]; then
cd $WINDOWSSYSROOT
git commit -m "auto update libc++ from LLVM source"
git push
echo "$(date --iso-8601=seconds)" > ${buildprefix}/runtimes/.runtimespushed
fi
