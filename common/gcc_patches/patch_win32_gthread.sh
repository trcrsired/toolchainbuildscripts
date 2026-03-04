#!/bin/bash

GCC_DIR="$1"

if [ -z "$GCC_DIR" ]; then
    echo "Usage: $0 <gcc source directory>"
    exit 1
fi

FILE="$GCC_DIR/libgcc/config/i386/gthr-win32.h"

# Replace the #if guard with commented-out version
sed -i 's/^#if _WIN32_WINNT >= 0x0600/\/\/#if _WIN32_WINNT >= 0x0600/' "$FILE"
sed -i 's/^#endif/\/\/#endif/' "$FILE"

echo "Win32 gthread condition‑variable patch applied."
