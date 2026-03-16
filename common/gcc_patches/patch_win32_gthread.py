#!/usr/bin/env python3
import sys
import os

if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} <gcc source directory>")
    sys.exit(1)

gcc_dir = sys.argv[1]
path = os.path.join(gcc_dir, "libgcc/config/i386/gthr-win32.h")

# Exact block to match
BLOCK = """#if _WIN32_WINNT >= 0x0600
#define __GTHREAD_HAS_COND 1
#define __GTHREADS_CXX0X 1
#endif"""

# Replacement block
BLOCK_NEW = """//#if _WIN32_WINNT >= 0x0600
#define __GTHREAD_HAS_COND 1
#define __GTHREADS_CXX0X 1
//#endif"""

# Read file
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace only if exact block exists
if BLOCK in content:
    print("Applying Win32 gthread condition‑variable patch...")
    content = content.replace(BLOCK, BLOCK_NEW)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Patch applied.")
else:
    print("Expected block not found. No changes made.")
