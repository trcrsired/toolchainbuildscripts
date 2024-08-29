#!/bin/bash

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
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

if [ -z ${HOST+x} ]; then
	HOST=$(${CC} -dumpmachine)
fi

if [ -z ${SYSROOT+x} ]; then
gccpath=$(command -v "$HOST-gcc")
gccbinpath=$(dirname "$gccpath")
SYSROOTPATH=$(dirname "$gccbinpath")
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

if [[ $SYSROOTPATH != "" ]];
SYSROOT_SETTING="-DCMAKE_SYSROOT=$SYSROOTPATH"
fi

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/wavm" ]; then
cd "$TOOLCHAINS_BUILD"
git clone -b mt-2 https://github.com/trcrsired/WAVM
if [ $? -ne 0 ]; then
echo "wavm clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/wavm"
git pull --quiet

mkdir -p "$currentwavmpath"

if [ ! -f "${currentwavmpath}/.wavmconfiguresuccess" ]; then
cd $currentwavmpath
cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -DCMAKE_ASM_COMPILER=$CC \
	-DCMAKE_C_COMPILER_TARGET=$HOST -DCMAKE_CXX_COMPILER_TARGET=$HOST -DCMAKE_ASM_COMPILER_TARGET=$CC -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_FLAGS="-fuse-ld=lld" -DCMAKE_ASM_FLAGS="-fuse-ld=lld" -DCMAKE_CXX_FLAGS="-fuse-ld=lld" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=On \
	$SYSROOT_SETTING $EXTRAFLAGS
echo "$(date --iso-8601=seconds)" > "${currentwavmpath}/.wavmconfiguresuccess"
fi

if [ ! -f "${currentwavmpath}/.wavmninjasuccess" ]; then
cd $currentwavmpath
ninja
echo "$(date --iso-8601=seconds)" > "${currentwavmpath}/.wavmninjasuccess"
fi

if [ ! -f "${currentwavmpath}/.wavmninjainstallstripsuccess" ]; then
cd $currentwavmpath
ninja install/strip
echo "$(date --iso-8601=seconds)" > "${currentwavmpath}/.wavmninjainstallstripsuccess"
fi

if [ ! -f "${currentwavmpath}/.wavmpackagingsuccess" ]; then
cd ${SOFTWARESPATH}
rm -f $HOST.tar.xz
XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
chmod 755 $HOST.tar.xz
echo "$(date --iso-8601=seconds)" > "${currentwavmpath}/.wavmninjainstallstripsuccess"
fi
