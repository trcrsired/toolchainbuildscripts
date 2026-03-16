#!/bin/bash

GCC_DIR="$1"

if [ -z "$GCC_DIR" ]; then
    echo "Usage: $0 <gcc source directory>"
    exit 1
fi

FILE="$GCC_DIR/libgcc/config/i386/gthr-win32.h"

# Exact block to match (must match file content exactly)
read -r -d '' BLOCK << 'EOF'
#if _WIN32_WINNT >= 0x0600
#define __GTHREAD_HAS_COND 1
#define __GTHREADS_CXX0X 1
#endif
EOF

# Replacement block (only #if and #endif commented)
read -r -d '' BLOCK_NEW << 'EOF'
//#if _WIN32_WINNT >= 0x0600
#define __GTHREAD_HAS_COND 1
#define __GTHREADS_CXX0X 1
//#endif
EOF

# Perform replacement only if exact block exists
if grep -Fq "$BLOCK" "$FILE"; then
    echo "Applying Win32 gthread condition‑variable patch..."
    sed -i "s|$BLOCK|$BLOCK_NEW|" "$FILE"
    echo "Patch applied."
else
    echo "Expected block not found. No changes made."
fi
