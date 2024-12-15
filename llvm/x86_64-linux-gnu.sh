#!/bin/bash

if [ -z ${ARCH+x} ]; then
	ARCH=x86_64
fi
if [ -z ${TARGETTRIPLE+x} ]; then
	TARGETTRIPLE=$ARCH-linux-gnu
fi
TARGETTRIPLE=$TARGETTRIPLE ARCH=$ARCH ./aarch64-linux-gnu.sh "$@"

if [ $? -ne 0 ]; then
exit 1
fi