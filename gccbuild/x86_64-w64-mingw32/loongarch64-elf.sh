#!/bin/bash

if [ -z ${HOST+x} ]; then
	HOST=loongarch64-elf
fi
if [ -z ${ARCH+x} ]; then
	ARCH=loongarch
fi
HOST=$HOST ARCH=$ARCH ./x86_64-elf.sh "$@"

if [ $? -ne 0 ]; then
exit 1
fi
