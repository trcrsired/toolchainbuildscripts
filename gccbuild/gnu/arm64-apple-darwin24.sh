#!/bin/bash
if [ -z ${ARCH+x} ]; then
	ARCH=arm64
fi
if [ -z ${HOSTNOVERRSION+x} ]; then
	HOSTNOVERRSION=$ARCH-apple-darwin
fi

if [ -z ${DARWINVERSION+x} ]; then
DARWINVERSION=24
fi

if [ -z ${HOST+x} ]; then
	HOST=${HOSTNOVERRSION}${DARWINVERSION}
fi

if [ -z ${CANADIANHOST+x} ]; then
	CANADIANHOST=x86_64-w64-mingw32
fi

HOST=${HOST} ARCH=$ARCH CANADIANHOST=$CANADIANHOST ./riscv64-linux-gnu.sh
