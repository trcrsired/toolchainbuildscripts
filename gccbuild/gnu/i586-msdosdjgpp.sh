#!/bin/bash

if [ -z ${HOST+x} ]; then
	HOST=i586-msdosdjgpp
fi

if [ -z ${CANADIANHOST+x} ]; then
	CANADIANHOST=x86_64-w64-mingw32
fi

HOST=${HOST} CANADIANHOST=${CANADIANHOST} ./riscv64-linux-gnu.sh
