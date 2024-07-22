#!/bin/bash


if [ -z ${HOST+x} ]; then
	HOST=loongarch64-linux-gnu
fi
if [ -z ${ARCH+x} ]; then
	ARCH=loongarch
fi
HOST=$HOST ARCH=$ARCH ./riscv64-linux-gnu.sh "$@"