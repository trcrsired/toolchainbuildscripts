#!/bin/bash

if [ -z ${TARGET+x} ]; then
	TARGET=loongarch64-elf
fi
if [ -z ${ARCH+x} ]; then
	ARCH=loongarch
fi
TARGET=$HOST ARCH=$ARCH ./x86_64-elf.sh "$@"

if [ $? -ne 0 ]; then
exit 1
fi
