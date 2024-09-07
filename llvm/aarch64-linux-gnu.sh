#!/bin/bash

if [ -z ${ARCH+x} ]; then
ARCH=aarch64
fi
TARGETTRIPLE_CPU=${ARCH}
if [ -z ${TARGETTRIPLE+x} ]; then
TARGETTRIPLE=${TARGETTRIPLE_CPU}-linux-gnu
fi
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
mkdir -p $TOOLCHAINSPATH
TOOLCHAINS_LLVMPATH=$TOOLCHAINSPATH/llvm
mkdir -p $TOOLCHAINS_LLVMPATH

TOOLCHAINS_LLVMSYSROOTSPATH="$TOOLCHAINS_LLVMPATH/${TARGETTRIPLE}"

mkdir -p $TOOLCHAINS_LLVMSYSROOTSPATH

mkdir -p $TOOLCHAINS_BUILD
mkdir -p $TOOLCHAINSPATH


LLVMINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/llvm
LLVMCOMPILERRTINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/compiler-rt
LLVMRUNTIMESINSTALLPATH=${TOOLCHAINS_LLVMSYSROOTSPATH}/runtimes

if [[ $1 == "clean" ]]; then
	echo "restarting"
	rm -rf "${currentpath}"
	if [[ $NO_TOOLCHAIN_DELETION != "yes" ]]; then
		rm -rf "${TOOLCHAINS_LLVMSYSROOTSPATH}"
	fi
	rm -f "${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz"
	echo "restart done"
	exit 1
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "${currentpath}"
	if [[ $NO_TOOLCHAIN_DELETION != "yes" ]]; then
		rm -rf "${TOOLCHAINS_LLVMSYSROOTSPATH}"
	fi
	rm -f "${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz"
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


if ! command -v "$TARGETTRIPLE-gcc" &> /dev/null
then
    echo "$TARGETTRIPLE-gcc not exists"
    exit 1
fi

gccnativetriplet=$(gcc -dumpmachine)

gccpath=$(command -v "$TARGETTRIPLE-gcc")
gccbinpath=$(dirname "$gccpath")
SYSROOTPATH=$(dirname "$gccbinpath")
if [ -f $SYSROOTPATH/bin/g++ ]; then
SYSROOTTRIPLEPATH=$SYSROOTPATH
else
SYSROOTTRIPLEPATH=$SYSROOTPATH/$TARGETTRIPLE
fi
CURRENTTRIPLEPATH=${currentpath}

if [ ! -f "$CURRENTTRIPLEPATH/zlib/.zlibconfigure" ]; then
mkdir -p "$CURRENTTRIPLEPATH/zlib"
cd $CURRENTTRIPLEPATH/zlib
cmake -GNinja ${TOOLCHAINS_BUILD}/zlib -DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_RC_COMPILER=llvm-windres \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DCMAKE_INSTALL_PREFIX=$SYSROOTTRIPLEPATH \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTTRIPLEPATH} \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_POSITION_INDEPENDENT_CODE=On \
	-DCMAKE_C_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_CXX_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_ASM_COMPILER_TARGET=$TARGETTRIPLE \
	-DCMAKE_RC_COMPILER_TARGET=$TARGETTRIPLE
if [ $? -ne 0 ]; then
rm -rf $CURRENTTRIPLEPATH/zlib
mkdir -p "$CURRENTTRIPLEPATH/zlib"
cd $CURRENTTRIPLEPATH/zlib
cmake -GNinja ${TOOLCHAINS_BUILD}/zlib -DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_RC_COMPILER=llvm-windres \
	-DCMAKE_C_COMPILER=$TARGETTRIPLE-gcc -DCMAKE_CXX_COMPILER=$TARGETTRIPLE-g++ -DCMAKE_ASM_COMPILER=$TARGETTRIPLE-gcc \
	-DCMAKE_INSTALL_PREFIX=$SYSROOTTRIPLEPATH \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTTRIPLEPATH} \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_POSITION_INDEPENDENT_CODE=On \
	-DCMAKE_RC_COMPILER_TARGET=$TARGETTRIPLE
if [ $? -ne 0 ]; then
echo "zlib configure failure"
exit 1
fi
fi
echo "$(date --iso-8601=seconds)" > $CURRENTTRIPLEPATH/zlib/.zlibconfigure
fi

if [ ! -f "$CURRENTTRIPLEPATH/zlib/.zlibinstallconfigure" ]; then
cd $CURRENTTRIPLEPATH/zlib
ninja install/strip
if [ $? -ne 0 ]; then
echo "zlib install/strip failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $CURRENTTRIPLEPATH/zlib/.zlibinstallconfigure
fi

function buildllvm
{

if [ ! -f "$CURRENTTRIPLEPATH/llvm/.configuresuccess" ]; then
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
	-DCMAKE_SYSTEM_NAME=Linux \
	-DBUILD_SHARED_LIBS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTTRIPLEPATH} \
	-DLLVM_ENABLE_LLD=On \
	-DLLVM_ENABLE_LTO=thin \
	-DCMAKE_POSITION_INDEPENDENT_CODE=On \
	-DCMAKE_C_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_CXX_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_ASM_COMPILER_TARGET=${TARGETTRIPLE} \
	-DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;lldb" \
	-DLLVM_ENABLE_ZLIB=FORCE_ON \
	-DZLIB_INCLUDE_DIR=$SYSROOTTRIPLEPATH/include \
	-DHAVE_ZLIB=On \
	-DZLIB_LIBRARY=$SYSROOTTRIPLEPATH/lib/libz.a \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
if [ $? -ne 0 ]; then
rm -rf $CURRENTTRIPLEPATH/llvm
mkdir -p "$CURRENTTRIPLEPATH/llvm"
cd $CURRENTTRIPLEPATH/llvm
cmake $LLVMPROJECTPATH/llvm \
	-GNinja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=$TARGETTRIPLE-gcc -DCMAKE_CXX_COMPILER=$TARGETTRIPLE-g++ -DCMAKE_ASM_COMPILER=$TARGETTRIPLE-gcc \
	-DCMAKE_SYSROOT=$SYSROOTPATH -DCMAKE_INSTALL_PREFIX=$LLVMINSTALLPATH \
	-DCMAKE_CROSSCOMPILING=On \
	-DLLVM_HOST_TRIPLE=$TARGETTRIPLE \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGETTRIPLE \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DBUILD_SHARED_LIBS=On \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTTRIPLEPATH} \
	-DCMAKE_POSITION_INDEPENDENT_CODE=On \
	-DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;lldb" \
	-DLLVM_ENABLE_ZLIB=FORCE_ON \
	-DZLIB_INCLUDE_DIR=$SYSROOTTRIPLEPATH/include \
	-DHAVE_ZLIB=On \
	-DZLIB_LIBRARY=$SYSROOTTRIPLEPATH/lib/libz.a \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
if [ $? -ne 0 ]; then
echo "llvm configure failure"
exit 1
fi
fi
echo "$(date --iso-8601=seconds)" > ${CURRENTTRIPLEPATH}/llvm/.configuresuccess
fi

if [ ! -f "$CURRENTTRIPLEPATH/llvm/.buildsuccess" ]; then
cd $CURRENTTRIPLEPATH/llvm
ninja
if [ $? -ne 0 ]; then
echo "llvm build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${CURRENTTRIPLEPATH}/llvm/.buildsuccess
fi

if [ ! -f "$CURRENTTRIPLEPATH/llvm/.installsuccess" ]; then
cd $CURRENTTRIPLEPATH/llvm
ninja install/strip
if [ $? -ne 0 ]; then
echo "llvm install failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${CURRENTTRIPLEPATH}/llvm/.installsuccess
fi

}

buildllvm

if [ ! -f "${currentpath}/compiler-rt/.compilerrtconfigure" ]; then
mkdir -p ${currentpath}/compiler-rt
cd ${currentpath}/compiler-rt
cmake -GNinja $LLVMPROJECTPATH/compiler-rt \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DLLVM_ENABLE_LLD=On -DLLVM_ENABLE_LTO=thin -DCMAKE_INSTALL_PREFIX=${LLVMCOMPILERRTINSTALLPATH} \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTTRIPLEPATH} \
	-DLLVM_ENABLE_LLD=On \
	-DLLVM_ENABLE_LTO=thin \
	-DCMAKE_POSITION_INDEPENDENT_CODE=On \
	-DCMAKE_C_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_CXX_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_ASM_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_SYSROOT=$SYSROOTPATH \
	-DCMAKE_CROSSCOMPILING=On
if [ $? -ne 0 ]; then
echo "compile-rt configure failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $CURRENTTRIPLEPATH/compiler-rt/.compilerrtconfigure
fi

if [ ! -f "${currentpath}/compiler-rt/.compilerrtninja" ]; then
cd "${currentpath}/compiler-rt"
ninja install/strip
if [ $? -ne 0 ]; then
echo "ninja install/strip failure"
exit 1
fi
fi

if [ ! -f "${currentpath}/runtimes/.runtimesconfigure" ]; then
mkdir -p ${currentpath}/runtimes
cd ${currentpath}/runtimes
cmake -GNinja $LLVMPROJECTPATH/runtimes \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_ASM_COMPILER=clang \
	-DLLVM_ENABLE_LLD=On -DLLVM_ENABLE_LTO=thin -DCMAKE_INSTALL_PREFIX=${LLVMRUNTIMESINSTALLPATH} \
	-DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
	-DLIBCXXABI_SILENT_TERMINATE=On \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_SYSTEM_PROCESSOR=$TARGETTRIPLE_CPU \
	-DCMAKE_FIND_ROOT_PATH=${SYSROOTTRIPLEPATH} \
	-DLLVM_ENABLE_LLD=On \
	-DLLVM_ENABLE_LTO=thin \
	-DCMAKE_POSITION_INDEPENDENT_CODE=On \
	-DCMAKE_C_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_CXX_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_ASM_COMPILER_TARGET=${TARGETTRIPLE} \
	-DCMAKE_SYSROOT=$SYSROOTPATH \
	-DCMAKE_CROSSCOMPILING=On
if [ $? -ne 0 ]; then
echo "runtimesconfigure build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/runtimes/.runtimesconfigure
fi

if [ ! -f "${currentpath}/runtimes/.runtimesbuild" ]; then
cd ${currentpath}/runtimes
ninja install/strip
if [ $? -ne 0 ]; then
echo "ninja install/strip failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/runtimes/.runtimesbuild
fi

if [ ! -f "${currentpath}/runtimes/.runtimesln" ]; then
cd "${LLVMRUNTIMESINSTALLPATH}/lib"
rm libc++.so
ln -s libc++.so.1 libc++.so
echo "$(date --iso-8601=seconds)" > ${currentpath}/runtimes/.runtimesln
fi

buildllvm

if [ ! -f "${currentpath}/compiler-rt/.compilerrtcopy" ]; then
clang_path=`which clang`
clang_directory=$(dirname "$clang_path")
clang_version=$(clang --version | grep -oP '\d+\.\d+\.\d+')
clang_major_version="${clang_version%%.*}"
llvm_install_directory="$clang_directory/.."
clangbuiltin="$llvm_install_directory/lib/clang/$clang_major_version"
cp -r --preserve=links "${LLVMCOMPILERRTINSTALLPATH}"/* "${clangbuiltin}/"
if [ $? -ne 0 ]; then
echo "compilerrt copy failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $CURRENTTRIPLEPATH/compiler-rt/.compilerrtcopy
fi

if [ ! -f "$CURRENTTRIPLEPATH/llvm/.packagingsuccess" ]; then
	cd $TOOLCHAINS_LLVMPATH
	rm -f ${TARGETTRIPLE}.tar.xz
	XZ_OPT=-e9T0 tar cJf ${TARGETTRIPLE}.tar.xz ${TARGETTRIPLE}
	if [ $? -ne 0 ]; then
		echo "llvm packaging failure"
		exit 1
	fi
	chmod 755 ${TARGETTRIPLE}.tar.xz
	echo "$(date --iso-8601=seconds)" > ${CURRENTTRIPLEPATH}/llvm/.packagingsuccess
fi
