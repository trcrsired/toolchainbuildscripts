#!/bin/bash

if [ -z ${HOST+x} ]; then
	HOST=x86_64-elf
fi

if [ -z ${CANADIANHOST+x} ]; then
	CANADIANHOST=x86_64-w64-mingw32
fi

if [ -z ${FREESTANDINGBUILD+x} ]; then
	FREESTANDINGBUILD=yes
fi


HOST=${HOST} CANADIANHOST=${CANADIANHOST} FREESTANDINGBUILD=${FREESTANDINGBUILD} ./riscv64-linux-gnu.sh
