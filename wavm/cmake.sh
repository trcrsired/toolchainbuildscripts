#!/bin/bash

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -z ${SOFTWARESPATH+x} ]; then
	SOFTWARESPATH=$HOME/softwares/cmake
fi

if [ -z ${CC+x} ]; then
	CC=clang
fi

if [ -z ${CXX+x} ]; then
	CXX=clang++
fi

if [ -z ${HOST+x} ]; then
	HOST=$(${CC} -dumpmachine)
fi

if [ -z ${ARCH} ]; then
    ARCH=${HOST%%-*}
fi

if [ -z ${SYSROOT+x} ]; then
gccpath=$(command -v "$HOST-gcc")
gccbinpath=$(dirname "$gccpath")
SYSROOTPATH=$(dirname "$gccbinpath")
fi

CMKRTIFACTSDIR=$(realpath .)/.cmakeartifacts
currentpath=$CMKRTIFACTSDIR/$HOST
currentcmakepath=${currentpath}/cmake
currentninjapath=${currentpath}/ninja

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

if [[ $SYSROOTPATH != "" ]]; then
SYSROOT_SETTING="-DCMAKE_SYSROOT=$SYSROOTPATH"
fi

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/CMake" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git@github.com:Kitware/CMake.git
if [ $? -ne 0 ]; then
echo "CMake clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/CMake"
git pull --quiet


cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/ninja" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git@github.com:ninja-build/ninja.git
if [ $? -ne 0 ]; then
echo "ninja clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/ninja"
git pull --quiet

mkdir -p "$currentcmakepath"

if [ ! -f "${currentcmakepath}/.cmakeconfiguresuccess" ]; then
cd $currentcmakepath
cmake "$TOOLCHAINS_BUILD/CMake" -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -DCMAKE_ASM_COMPILER=$CC \
	-DCMAKE_C_COMPILER_TARGET=$HOST -DCMAKE_CXX_COMPILER_TARGET=$HOST -DCMAKE_ASM_COMPILER_TARGET=$HOST -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_FLAGS="-fuse-ld=lld -Wno-unused-command-line-argument $EXTRACFLAGS" \
	-DCMAKE_ASM_FLAGS="-fuse-ld=lld -Wno-unused-command-line-argument $EXTRAASMFLAGS" \
	-DCMAKE_CXX_FLAGS="-fuse-ld=lld -Wno-unused-command-line-argument $EXTRACXXFLAGS" \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On \
	-DCMAKE_INSTALL_PREFIX="$SOFTWARESPATH/$HOST" -DCMAKE_SYSTEM_PROCESSOR=$ARCH -DCMAKE_CROSSCOMPILING=On \
	$SYSROOT_SETTING $EXTRAFLAGS
if [ $? -ne 0 ]; then
echo "CMake configure failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > "${currentcmakepath}/.cmakeconfiguresuccess"
fi

if [ ! -f "${currentcmakepath}/.cmakeninjasuccess" ]; then
cd $currentcmakepath
ninja
if [ $? -ne 0 ]; then
echo "CMake build failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > "${currentcmakepath}/.cmakeninjasuccess"
fi

if [ ! -f "${currentcmakepath}/.cmakeninjainstallstripsuccess" ]; then
cd $currentcmakepath
ninja install/strip
if [ $? -ne 0 ]; then
echo "CMake install and strip failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > "${currentcmakepath}/.cmakeninjainstallstripsuccess"
fi

mkdir -p "$currentninjapath"

if [ ! -f "${currentninjapath}/.ninjaconfiguresuccess" ]; then
cd $currentninjapath
cmake "$TOOLCHAINS_BUILD/ninja" -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -DCMAKE_ASM_COMPILER=$CC \
	-DCMAKE_C_COMPILER_TARGET=$HOST -DCMAKE_CXX_COMPILER_TARGET=$HOST -DCMAKE_ASM_COMPILER_TARGET=$HOST -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_FLAGS="-fuse-ld=lld -Wno-unused-command-line-argument $EXTRACFLAGS" \
	-DCMAKE_ASM_FLAGS="-fuse-ld=lld -Wno-unused-command-line-argument $EXTRAASMFLAGS" \
	-DCMAKE_CXX_FLAGS="-fuse-ld=lld -Wno-unused-command-line-argument $EXTRACXXFLAGS" \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On \
	-DCMAKE_INSTALL_PREFIX="$SOFTWARESPATH/$HOST" -DCMAKE_SYSTEM_PROCESSOR=$ARCH -DCMAKE_CROSSCOMPILING=On \
	$SYSROOT_SETTING $EXTRAFLAGS
if [ $? -ne 0 ]; then
echo "ninja configure failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > "${currentninjapath}/.ninjaconfiguresuccess"
fi

if [ ! -f "${currentninjapath}/.ninjaninjasuccess" ]; then
cd $currentninjapath
ninja
if [ $? -ne 0 ]; then
echo "ninja build failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > "${currentninjapath}/.ninjaninjasuccess"
fi

if [ ! -f "${currentninjapath}/.ninjaninjainstallstripsuccess" ]; then
cd $currentninjapath
ninja install/strip
if [ $? -ne 0 ]; then
echo "ninja install and strip failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > "${currentninjapath}/.ninjaninjainstallstripsuccess"
fi

if [ ! -f "${currentcmakepath}/.cmakepackagingsuccess" ]; then
cd ${SOFTWARESPATH}
rm -f $HOST.tar.xz
XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
if [ $? -ne 0 ]; then
echo "tar failed"
exit 1
fi
chmod 755 $HOST.tar.xz
echo "$(date --iso-8601=seconds)" > "${currentcmakepath}/.cmakepackagingsuccess"
fi
