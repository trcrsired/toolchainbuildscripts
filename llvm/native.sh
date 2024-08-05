#!/bin/bash

if ! [ -x "$(command -v g++)" ];
then
        echo "g++ not found. build failure"
        exit 1
fi

TARGETTRIPLE=$(g++ -dumpmachine)
currentpath=$(realpath .)/.llvmartifacts/${TARGETTRIPLE}

if [ -z ${ARCH+x} ]; then
	ARCH=(cut -d'-' -f1)
fi
TARGETTRIPLE=$TARGETTRIPLE ARCH=$ARCH NO_TOOLCHAIN_DELETION=yes ./aarch64-linux-gnu.sh "$@"

if [ $? -ne 0 ]; then
exit 1
fi