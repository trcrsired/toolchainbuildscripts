#!/usr/bin/env bash
set -e

# List of all Linux target triples to build.
# Add or remove triples here as needed.
HOSTS=(
    aarch64-linux-gnu
    aarch64-linux-musl
    riscv64-linux-gnu
    riscv64-linux-musl
    loongarch64-linux-gnu
    loongarch64-linux-musl
    x86_64-linux-gnu
    x86_64-linux-musl
#    i686-linux-gnu
#    i686-linux-musl
)

# The build script to invoke for each HOST.
# Despite the name, this script is generic and handles all triples.
TARGET_SCRIPT=./loongarch64-linux-gnu.sh

for host in "${HOSTS[@]}"; do
    HOST="$host" "$TARGET_SCRIPT" "$@"
    if [ $? -ne 0 ]; then
        echo "WAVM $host failed"
    fi
done

