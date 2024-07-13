#!/bin/bash

if ! [ -x "$(command -v g++)" ];
then
        echo "g++ not found. build failure"
        exit 1
fi

TARGETTRIPLE=$(g++ -dumpmachine)
currentpath=$(realpath .)/.llvmartifacts/${TARGETTRIPLE}

mkdir -p ${currentpath}
cd ${currentpath}

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
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

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/binutils-gdb" ]; then
git clone git://sourceware.org/git/binutils-gdb.git
fi
cd "$TOOLCHAINS_BUILD/binutils-gdb"
git pull --quiet

if [ ! -d "${currentpath}/llvm" ]; then
mkdir -p ${currentpath}/llvm
cd ${currentpath}/llvm
cmake -GNinja $LLVMPROJECTPATH/llvm \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCMAKE_ASM_COMPILER=gcc \
	-DCMAKE_INSTALL_PREFIX=${LLVMINSTALLPATH} \
	-DBUILD_SHARED_LIBS=On \
	-DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;lldb" \
	-DLLVM_BINUTILS_INCDIR="$TOOLCHAINS_BUILD/binutils-gdb/include"
fi

if [ ! -d "${LLVMINSTALLPATH}" ]; then
cd "${currentpath}/llvm"
ninja install/strip
fi

export PATH=$LLVMINSTALLPATH/bin:$PATH

if ! [ -x "$(command -v clang)" ];
then
        echo "clang not found. we won't build runtimes"
        exit 0
fi

clang_path=`which clang`
clang_directory=$(dirname "$clang_path")
clang_version=$(clang --version | grep -oP '\d+\.\d+\.\d+')
clang_major_version="${clang_version%%.*}"
llvm_install_directory="$clang_directory/.."
clangbuiltin="$llvm_install_directory/lib/clang/$clang_major_version"

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
	-DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
	-DLIBCXXABI_SILENT_TERMINATE=On
fi

if [ ! -d "${LLVMRUNTIMESINSTALLPATH}" ]; then
cd ${currentpath}/runtimes
ninja install/strip
fi

if [ -d "${LLVMRUNTIMESINSTALLPATH}" ]; then
cd "${LLVMRUNTIMESINSTALLPATH}/lib"
rm libc++.so
ln -s libc++.so.1 libc++.so
fi

if [ ! -f ${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz ]; then
	if [ -f "$clang_directory/clang.cfg" ]; then
		rm "$clang_directory/clang.cfg"
	fi
	cd $TOOLCHAINS_LLVMPATH
	XZ_OPT=-e9T0 tar cJf ${TARGETTRIPLE}.tar.xz ${TARGETTRIPLE}
	chmod 755 ${TARGETTRIPLE}.tar.xz
fi


if [ ! -f "$clang_directory/clang.cfg" ]; then
gcc_path=`which g++`
gcc_bin_directory=$(dirname "$gcc_path")
gcc_directory=$(dirname "$gcc_bin_directory")
echo "--gcc-toolchain=$gcc_directory" > "$clang_directory/clang.cfg"
cp "$clang_directory/clang.cfg" "$clang_directory/clang++.cfg"
cp -r --preserve=links "${LLVMRUNTIMESINSTALLPATH}"/* "${gcc_directory}/"
fi
