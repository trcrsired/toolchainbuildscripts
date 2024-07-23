#!/bin/bash

if [ -z ${HOST+x} ]; then
	HOST=loongarch64-generic-linux-gnu
fi
if [ -z ${ARCH+x} ]; then
	ARCH=loongarch
fi
HOST=$HOST ARCH=$ARCH ./riscv64-linux-gnu.sh "$@"

if [ $? -ne 0 ]; then
exit 1
fi