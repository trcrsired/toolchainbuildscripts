#!/bin/bash

if [ -z ${HOSTTRIPLET+x} ]; then
echo "HOSTTRIPLET is not set. Please set the HOSTTRIPLET environment variable to the target triplet."
exit 1
fi

if [ -z ${TARGETTRIPLET+x} ]; then
echo "TARGETTRIPLET is not set. Please set the TARGETTRIPLET environment variable to the target triplet."
exit 1
fi

currentpath="$(realpath .)/.artifacts/llvm/${HOSTTRIPLET}/${TARGETTRIPLET}"
if [[ "x${GENERATE_CMAKE_ONLY}" == "xyes" ]]; then
SKIP_DEPENDENCY_CHECK=yes
fi
mkdir -p "$currentpath"
cd ../common
source ./common.sh

cd "$currentpath"
# Parse the target triplet

parse_triplet $HOST_TRIPLET HOST_CPU HOST_VENDOR HOST_OS HOST_ABI

if [[ "$OS" == mingw* ]]; then
HOST_TRIPLET=$CPU-windows-gnu
unset HOST_VENDOR
HOST_OS=windows
HOST_ABI=gnu
fi

if [ $? -ne 0 ]; then
echo "Failed to parse the host triplet: $HOST_TRIPLET"
exit 1
fi
HOST_ABI_NO_VERSION="${HOST_ABI//[0-9]/}"
HOST_ABI_VERSION=${HOST_ABI//[!0-9]/}

echo "HOST_TRIPLET: $HOST_TRIPLET"
echo "HOST_CPU: $HOST_CPU"
echo "HOST_VENDOR: $HOST_VENDOR"
echo "HOST_OS: $HOST_OS"
echo "HOST_ABI: $HOST_ABI"
echo "HOST_ABI_NO_VERSION: $HOST_ABI_NO_VERSION"

parse_triplet $TARGET_TRIPLET TARGET_CPU TARGET_VENDOR TARGET_OS TARGET_ABI

if [[ "$OS" == mingw* ]]; then
TARGET_TRIPLET=$CPU-windows-gnu
unset TARGET_VENDOR
TARGET_OS=windows
TARGET_ABI=gnu
fi

if [ $? -ne 0 ]; then
echo "Failed to parse the host triplet: $TARGET_TRIPLET"
exit 1
fi
TARGET_ABI_NO_VERSION="${TARGET_ABI//[0-9]/}"
TARGET_ABI_VERSION=${TARGET_ABI//[!0-9]/}

echo "TARGET_TRIPLET: $TARGET_TRIPLET"
echo "TARGET_CPU: $TARGET_CPU"
echo "TARGET_VENDOR: $TARGET_VENDOR"
echo "TARGET_OS: $TARGET_OS"
echo "TARGET_ABI: $TARGET_ABI"
echo "TARGET_ABI_NO_VERSION: $TARGET_ABI_NO_VERSION"


