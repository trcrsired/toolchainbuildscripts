#!/bin/bash

TARGETTRIPLE=$(clang -print-target-triple)
currentpath=$(realpath .)/.llvmartifacts/${TARGETTRIPLE}

mkdir -p ${currentpath}
cd ${currentpath}

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$currentpath/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$currentpath/toolchains
fi

mkdir -p $TOOLCHAINSPATH
TOOLCHAINS_LLVMPATH=$TOOLCHAINSPATH/llvm
mkdir -p $TOOLCHAINS_LLVMPATH
TOOLCHAINS_LLVMSYSROOTSPATH=${TOOLCHAINS_LLVMPATH}/${TARGETTRIPLE}
mkdir -p $TOOLCHAINS_LLVMSYSROOTSPATH

mkdir -p $TOOLCHAINS_BUILD
mkdir -p $TOOLCHAINSPATH

LLVMINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/llvm
LLVMRUNTIMESINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes
LLVMCOMPILERRTINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/compiler-rt

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

if ! [ -x "$(command -v g++)" ];
then
        echo "g++ not found. build failure"
        exit 1
fi

if [ ! -d "${currentpath}/llvm" ]; then
mkdir -p ${currentpath}/llvm
cd ${currentpath}/llvm
cmake -GNinja $LLVMPROJECTPATH/llvm \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCMAKE_ASM_COMPILER=gcc \
	-DLLVM_ENABLE_LLD=On -DLLVM_ENABLE_LTO=thin -DCMAKE_INSTALL_PREFIX=${LLVMINSTALLPATH} \
	-DBUILD_SHARED_LIBS=On \
	-DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;lldb"
fi

if [ ! -d "${LLVMINSTALLPATH}" ]; then
cd "${currentpath}/llvm"
ninja install/strip
fi

export PATH=$LLVMINSTALLPATH/bin:$PATH

clang_path=`which clang`
clang_directory=$(dirname "$clang_path")
clang_version=$(clang --version | grep -oP '\d+\.\d+\.\d+')
clang_major_version="${clang_version%%.*}"
llvm_install_directory="$clang_directory/.."
clangbuiltin="$llvm_install_directory/lib/clang/$clang_major_version"

if ! [ -x "$(command -v clang)" ];
then
        echo "clang not found. we won't build runtimes"
        exit 0
fi

if [ ! -d "${currentpath}/compiler-rt" ]; then
mkdir -p ${currentpath}/compiler-rt
cd ${currentpath}/compiler-rt
cmake -GNinja $LLVMPROJECTPATH/compiler-rt \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DLLVM_ENABLE_LLD=On -DLLVM_ENABLE_LTO=thin -DCMAKE_INSTALL_PREFIX=${LLVMCOMPILERRTINSTALLPATH}
fi

if [ ! -d "${LLVMCOMPILERRTINSTALLPATH}" ]; then
cd "${currentpath}/compiler-rt"
ninja install/strip
cp -r --preserve=links "${LLVMCOMPILERRTINSTALLPATH}"/* "${clangbuiltin}/"
fi

if [ ! -d "${currentpath}/runtimes" ]; then
mkdir -p ${currentpath}/runtimes
cd ${currentpath}/runtimes
cmake -GNinja $LLVMPROJECTPATH/runtimes \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DLLVM_ENABLE_LLD=On -DLLVM_ENABLE_LTO=thin -DCMAKE_INSTALL_PREFIX=${LLVMRUNTIMESINSTALLPATH} \
	-DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind;compiler-rt" \
	-DLIBCXXABI_SILENT_TERMINATE=On
fi

cd "${LLVMRUNTIMESINSTALLPATH}/lib"
rm libc++.so
ln -s libc++.so.1 libc++.so

if [ ! -f ${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz ]; then
	cd $TOOLCHAINS_LLVMPATH
	XZ_OPT=-e9T0 tar cJf ${TARGETTRIPLE}.tar.xz ${TARGETTRIPLE}
	chmod 755 ${TARGETTRIPLE}.tar.xz
fi
