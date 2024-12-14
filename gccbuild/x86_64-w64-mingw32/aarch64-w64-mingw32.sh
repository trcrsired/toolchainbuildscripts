#!/bin/bash
if [ -z ${HOST+x} ]; then
	HOST=aarch64-w64-mingw32
fi
HOST=$HOST ./x86_64-w64-mingw32.sh
