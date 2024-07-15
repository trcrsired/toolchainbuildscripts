#!/bin/bash

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -z ${SOFTWARESPATH+x} ]; then
	SOFTWARESPATH=$HOME/softwares
fi

if [ -z ${CC+x} ]; then
    CC=gcc
fi

if [ -z ${CXX+x} ]; then
    CXX=g++
fi

if [ -z ${ARCH} ]; then
    ARCH=x86_64
fi

if [[ ${ARCH} == "aarch64" ]]; then
ENABLEDARCHS=arm64
else
ENABLEDARCHS=i386,x86_64
fi

PREFIX=$SOFTWARESPATH/$HOST
BUILD=$(CC -dumpmachine)
HOST=$BUILD
TARGET=$BUILD
currentpath=$(realpath .)/.wineartifacts/$HOST
currentwinepath=${currentpath}/wine

if [[ $1 == "clean" ]]; then
	echo "cleaning"
	rm -rf ${currentpath}
	rm -f $SOFTWARESPATH/wine-$HOST.tar.xz
	echo "cleaning done"
    exit 0
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf ${currentpath}
	rm -f $SOFTWARESPATH/wine-$HOST.tar.xz
	echo "restart done"
fi

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/wine" ]; then
git clone git@gitlab.winehq.org:wine/wine.git
if [ $? -ne 0 ]; then
echo "wine clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/wine"
git pull --quiet


mkdir -p ${currentwinepath}

if [ ! -f ${currentwinepath}/Makefile ]; then
cd $currentwinepath
$TOOLCHAINS_BUILD/wine/configure --disable-nls --disable-werror --prefix=$PREFIX/wine --enable-archs=$ENABLEDARCHS
if [ $? -ne 0 ]; then
echo "wine configure failure"
exit 1
fi
fi

if [ ! -f ${currentwinepath}/.buildsuccess ]; then
cd ${currentwinepath}
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "wine build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentwinepath}/.buildsuccess
fi

if [ ! -f ${currentwinepath}/.installsuccess ]; then
cd ${currentwinepath}
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "wine install failure"
exit 1
fi
mkdir -p $PREFIX/wine/share/wine
cp -r --preserve=links ${currentwinepath}/nls $PREFIX/wine/share/wine/
echo "$(date --iso-8601=seconds)" > ${currentwinepath}/.installsuccess
fi

if [ ! -f $SOFTWARESPATH/wine-$HOST.tar.xz ]; then
cd ${$SOFTWARESPATH}
XZ_OPT=-e9T0 tar cJf wine-$HOST.tar.xz $HOST
chmod 755 wine-$HOST.tar.xz
fi