#!/bin/bash

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -z ${SOFTWARESPATH+x} ]; then
	SOFTWARESPATH=$HOME/softwares/mono
fi

if [ -z ${HOST+x} ]; then
	HOST=$(${CC} -dumpmachine)
fi

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/mono" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git@github.com:mono/mono.git
if [ $? -ne 0 ]; then
echo "mono clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/mono"
git pull --quiet

MONOARTIFACTSDIR=$(realpath .)/.monoartifacts

currentpath=$MONOARTIFACTSDIR/$HOST
currentmonopath=$currentpath/mono
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

mkdir -p ${currentmonopath}

if [ ! -f "${currentmonopath}/.monoconfigure" ]; then
cd ${currentmonopath}
STRIP=llvm-strip ${TOOLCHAINS_BUILD}/mono/configure --disable-nls --disable-werror --prefix=$SOFTWARESPATH/$HOST --host=$HOST --enable-llvm --enable-optimize $EXTRACONFIGUREFLAGS
if [ $? -ne 0 ]; then
echo "mono configure failed"
exit 1
fi
echo "$(date +%s)" > "${currentmonopath}/.monoconfigure"
fi

if [ ! -f "${currentmonopath}/.monobuild" ]; then
cd ${currentmonopath}
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "mono build failed"
exit 1
fi
echo "$(date +%s)" > "${currentmonopath}/.monobuild"
fi

if [ ! -f "${currentmonopath}/.monoinstallstrip" ]; then
cd ${currentmonopath}
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
echo "mono install-strip failed"
exit 1
fi
echo "$(date +%s)" > "${currentmonopath}/.monoinstallstrip"
fi

if [ ! -f "${currentmonopath}/.monopackaging" ]; then
cd ${SOFTWARESPATH}
rm -f $HOST.tar.xz
XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
if [ $? -ne 0 ]; then
echo "tar failed"
exit 1
fi
chmod 755 $HOST.tar.xz
echo "$(date +%s)" > "${currentmonopath}/.monopackaging"
fi
