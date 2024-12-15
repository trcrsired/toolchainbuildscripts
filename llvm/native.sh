#!/bin/bash

if ! [ -x "$(command -v clang++)" ];
then
        echo "clang++ not found. build failure"
        exit 1
fi

if [ -z ${TARGETTRIPLE+x} ]; then
TARGETTRIPLE=$(clang++ -dumpmachine)
fi
currentpath=$(realpath .)/.llvmartifacts/${TARGETTRIPLE}

if [ -z ${ARCH+x} ]; then
	ARCH=$(echo $TARGETTRIPLE | cut -d'-' -f1)
fi
TARGETTRIPLE=$TARGETTRIPLE ARCH=$ARCH NO_TOOLCHAIN_DELETION=yes ./aarch64-linux-gnu.sh "$@"

if [ $? -ne 0 ]; then
exit 1
fi
