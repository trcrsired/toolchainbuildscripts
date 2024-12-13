#!/bin/bash

if [ -z ${HOST+x} ]; then
	HOST=x86_64-linux-gnu
fi
if [ -z ${ARCH+x} ]; then
	ARCH=x86_64
fi
HOST=$HOST ARCH=$ARCH ./riscv64-linux-gnu.sh "$@"

if [ $? -ne 0 ]; then
exit 1
fi