#!/bin/bash

if [ -z ${HOST+x} ]; then
	HOST=loongarch64-elf
fi
if [ -z ${ARCH+x} ]; then
	ARCH=loongarch
fi

if [ -z ${FREESTANDINGBUILD+x} ]; then
	FREESTANDINGBUILD=yes
fi

HOST=$HOST ARCH=$ARCH FREESTANDINGBUILD=yes ./riscv64-linux-gnu.sh "$@"

if [ $? -ne 0 ]; then
exit 1
fi
