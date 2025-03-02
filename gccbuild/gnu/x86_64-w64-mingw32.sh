#!/bin/bash
if [ -z ${ARCH+x} ]; then
	ARCH=x86_64
fi

if [ -z ${HOST+x} ]; then
	HOST=${ARCH}-w64-mingw32
fi

if [ -z ${CANADIANHOST+x} ]; then
	CANADIANHOST=x86_64-w64-mingw32
fi

HOST=${HOST} ARCH=$ARCH CANADIANHOST=$CANADIANHOST ./riscv64-linux-gnu.sh
