#!/bin/bash

GCC_DIR="$1"

if [ -z "$GCC_DIR" ]; then
    echo "Usage: $0 <gcc source directory>"
    exit 1
fi

TFILE="$GCC_DIR/gcc/config/i386/t-x86_64-elf"

# Write multilib file
cat > "$TFILE" << 'EOF'
# Add libgcc multilib variant without red-zone requirement
MULTILIB_OPTIONS += mno-red-zone
MULTILIB_DIRNAMES += no-red-zone
EOF

CONFIG_GCC="$GCC_DIR/gcc/config.gcc"

# Insert t-x86_64-elf into x86_64-*-elf* block
sed -i '/x86_64-\*-elf\*)/a\
    tmake_file="${tmake_file} i386/t-x86_64-elf"' "$CONFIG_GCC"

echo "libgcc multilib no‑red‑zone patch applied."
