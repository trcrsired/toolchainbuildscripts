#!/bin/bash

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
if [ -z ${TOOLCHAINS_LLVMPATH+x} ]; then
TOOLCHAINS_LLVMPATH=$TOOLCHAINSPATH/llvm
fi

if [ -z ${SOFTWARESPATH+x} ]; then
	SOFTWARESPATH=$HOME/softwares/wavm
fi

if [ -z ${CC+x} ]; then
	CC=clang
fi

if [ -z ${CXX+x} ]; then
	CXX=clang++
fi

if [ -z ${AR+x} ]; then
	AR=llvm-ar
fi

if [ -z ${HOST+x} ]; then
	HOST=$(${CC} -dumpmachine)
fi

if [ -z ${ARCH} ]; then
    ARCH=${HOST%%-*}
fi

if [ -z ${LLVMINSTALLPATH+x} ]; then
	LLVMINSTALLPATH=$TOOLCHAINS_LLVMPATH/$HOST
fi

if [ -z ${SYSROOT+x} ]; then
gccpath=$(command -v "clang --target=$HOST")
SYSROOTPATH=$TOOLCHAINS_LLVMPATH/$HOST/$HOST
fi

WAVMRTIFACTSDIR=$(realpath .)/.wavmartifacts
currentpath=$WAVMRTIFACTSDIR/$HOST
currentwavmpath=${currentpath}/wavm

if [[ $1 == "clean" ]]; then
	echo "cleaning"
	rm -rf ${currentpath}
	rm -f $SOFTWARESPATH/$HOST.tar.xz
	echo "cleaning done"
    exit 0
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf ${currentpath}
	rm -f $SOFTWARESPATH/$HOST.tar.xz
	echo "restart done"
fi

if [ -z ${EXTRACFLAGS+x} ]; then 
EXTRACFLAGS="-rtlib=compiler-rt --unwindlib=libunwind -lunwind"
fi

if [ -z ${EXTRACXXFLAGS+x} ]; then 
EXTRACXXFLAGS="-rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -lc++abi -lunwind"
fi

if [ -z ${EXTRAASMFLAGS+x} ]; then 
EXTRAASMFLAGS=$EXTRACFLAGS
fi


if [[ $SYSROOTPATH != "" ]]; then
SYSROOT_SETTING="-DCMAKE_SYSROOT=${SYSROOTPATH} \
	-DCMAKE_FIND_ROOT_PATH=$LLVMINSTALLPATH \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DCMAKE_CROSSCOMPILING=On"
	if [ -z ${SYSTEMNAME+x} ]; then
		echo "cross compiling needs to set SYSTEMNAME, we assume it is Linux"
		SYSTEMNAME=Linux
		EXTRACXXFLAGS=" -stdlib=libc++ -rtlib=compiler-rt --unwindlib=libunwind -lc++abi -lunwind $EXTRACXXFLAGS"
	elif [[ ${SYSTEMNAME} == "Android" ]]; then
		if [ ! -f "$currentpath/templibs/librt.a" ]; then
		mkdir -p "$currentpath/templibs"
		$AR rc "$currentpath/templibs/librt.a"
		chmod 755 "$currentpath/templibs/librt.a"
		fi
		EXTRACXXFLAGS="-L\"$currentpath/templibs\" -lc++abi -lunwind $EXTRACXXFLAGS"
		SYSTEMNAME=Linux
	elif [[ ${SYSTEMNAME} == "Darwin" ]]; then
		SYSROOT_SETTINGS="$SYSROOT_SETTINGS -DCMAKE_CURRENT_OSX_VERSION=10.5 -DCMAKE_OSX_DEPLOYMENT_TARGET=10.5"
	fi
fi

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/WAVM" ]; then
cd "$TOOLCHAINS_BUILD"
git clone -b mt-2 https://github.com/trcrsired/WAVM
if [ $? -ne 0 ]; then
echo "WAVM clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/WAVM"
git pull --quiet

mkdir -p "$currentwavmpath"

if [ ! -f "${currentwavmpath}/.wavmconfiguresuccess" ]; then
cd $currentwavmpath
cmake "$TOOLCHAINS_BUILD/WAVM" -Wno-dev -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -DCMAKE_ASM_COMPILER=$CC \
	-DCMAKE_C_COMPILER_TARGET=$HOST -DCMAKE_CXX_COMPILER_TARGET=$HOST -DCMAKE_ASM_COMPILER_TARGET=$HOST \
	-DCMAKE_C_FLAGS="-fuse-ld=lld -Wno-unused-command-line-argument $EXTRACFLAGS  -mmacosx-version-min=11.0" \
	-DCMAKE_ASM_FLAGS="-fuse-ld=lld -Wno-unused-command-line-argument $EXTRAASMFLAGS  -mmacosx-version-min=11.0" \
	-DCMAKE_CXX_FLAGS="-fuse-ld=lld -Wno-unused-command-line-argument $EXTRACXXFLAGS  -mmacosx-version-min=11.0" \
	-DCMAKE_LINKER_TYPE=LLD -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On -DCMAKE_SYSTEM_PROCESSOR=$ARCH -DCMAKE_SYSTEM_NAME=$SYSTEMNAME \
	-DCMAKE_INSTALL_PREFIX="$SOFTWARESPATH/$HOST" \
	$SYSROOT_SETTING $EXTRAFLAGS -DCMAKE_CURRENT_OSX_VERSION=10.5 -DCMAKE_SYSTEM_VERSION=24 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 -DCMAKE_OSX_ARCHITECTURES="arm64" -DCMAKE_SHARED_LIBRARY_RUNTIME_C_FLAG=""
if [ $? -ne 0 ]; then
echo "WAVM configure failed"
exit 1
fi
echo "$(date +%s)" > "${currentwavmpath}/.wavmconfiguresuccess"
fi

if [ ! -f "${currentwavmpath}/.wavmninjasuccess" ]; then
cd $currentwavmpath
ninja
if [ $? -ne 0 ]; then
echo "WAVM build failed"
exit 1
fi
echo "$(date +%s)" > "${currentwavmpath}/.wavmninjasuccess"
fi

if [ ! -f "${currentwavmpath}/.wavmninjainstallstripsuccess" ]; then
cd $currentwavmpath
ninja install/strip
if [ $? -ne 0 ]; then
echo "WAVM install and strip failed"
exit 1
fi
echo "$(date +%s)" > "${currentwavmpath}/.wavmninjainstallstripsuccess"
fi

if [ ! -f "${currentwavmpath}/.wavmpackagingsuccess" ]; then
cd ${SOFTWARESPATH}
rm -f $HOST.tar.xz
XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
if [ $? -ne 0 ]; then
echo "tar failed"
exit 1
fi
chmod 755 $HOST.tar.xz
echo "$(date +%s)" > "${currentwavmpath}/.wavmninjainstallstripsuccess"
fi
