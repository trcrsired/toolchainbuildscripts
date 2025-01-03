#!/bin/bash

if [ -z ${HOST+x} ]; then
	HOST=arm-none-eabi
fi
if [ -z ${ARCH+x} ]; then
	ARCH=arm
fi

if [ -z ${FREESTANDINGBUILD+x} ]; then
	FREESTANDINGBUILD=yes
fi

if [ -z ${USE_NEWLIB+x} ]; then
	USE_NEWLIB=yes
fi

HOST=$HOST ARCH=$ARCH FREESTANDINGBUILD=$FREESTANDINGBUILD USE_NEWLIB=$USE_NEWLIB ./riscv64-linux-gnu.sh "$@"

if [ $? -ne 0 ]; then
exit 1
fi
