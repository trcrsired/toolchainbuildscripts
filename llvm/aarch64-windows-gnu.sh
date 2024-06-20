#!/bin/bash

if [ -z ${ARCH+x} ]; then
ARCH=aarch64
fi

ARCH=$ARCH ./x86_64-windows-gnu.sh "$@"