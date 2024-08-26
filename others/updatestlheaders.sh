#!/bin/bash

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

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

if [ ! -d "$TOOLCHAINS_BUILD/STL" ]; then
cd $TOOLCHAINS_BUILD
git clone https://github.com/microsoft/STL
if [ $? -ne 0 ]; then
echo "Microsoft STL clone failure"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/STL"
git pull --quiet

rm -rf "$WINDOWSSYSROOT/include/c++/stl"
cp -r --preserve=links "$TOOLCHAINS_BUILD/STL/stl/inc" "$WINDOWSSYSROOT/include/c++/stl"

cd "$WINDOWSSYSROOT/include/c++/stl"
git add *
git commit -m "Update Microsoft STL headers from source"
git push --quiet
