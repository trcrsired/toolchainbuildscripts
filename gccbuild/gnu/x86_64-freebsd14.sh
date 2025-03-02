#!/bin/bash
if [ -z ${ARCH+x} ]; then
	ARCH=x86_64
fi
if [ -z ${HOSTNOVERRSION+x} ]; then
	HOSTNOVERRSION=$ARCH-freebsd
fi

if [ -z ${FREEBSDVERSION+x} ]; then
    FREEBSDVERSION=14
fi

if [ -z ${HOST+x} ]; then
	HOST=${HOSTNOVERRSION}${FREEBSDVERSION}
fi

if [ -z ${CANADIANHOST+x} ]; then
	CANADIANHOST=x86_64-w64-mingw32
fi

HOST=${HOST} ARCH=$ARCH CANADIANHOST=$CANADIANHOST ./riscv64-linux-gnu.sh
