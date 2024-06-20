#!/bin/bash

if [ -z ${ARCH+x} ]; then
ARCH=aarch64
fi

./x86_64-windows-gnu.sh "$@" ARCH="$ARCH