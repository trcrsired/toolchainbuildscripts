#!/usr/bin/env bash
set -e

build_all() {
    local build_main="x86_64-linux-gnu"
    local triplets=(
        "$build_main x86_64-linux-gnu x86_64-linux-gnu"
        "$build_main x86_64-w64-mingw32 x86_64-w64-mingw32"
        "$build_main aarch64-linux-gnu aarch64-linux-gnu"
        "$build_main x86_64-w64-mingw32 aarch64-linux-gnu"
        "$build_main loongarch64-linux-gnu loongarch64-linux-gnu"
        "$build_main x86_64-w64-mingw32 loongarch64-linux-gnu"
        "$build_main riscv64-linux-gnu riscv64-linux-gnu"
        "$build_main x86_64-w64-mingw32 riscv64-linux-gnu"
        "$build_main x86_64-w64-mingw32 x86_64-elf"
    )

    for t in "${triplets[@]}"; do
        set -- $t
        local build=$1
        local host=$2
        local target=$3

        echo "=== Building for build=$build host=$host target=$target ==="

        BUILD_TRIPLET=$build \
        HOST_TRIPLET=$host \
        TARGET_TRIPLET=$target \
        ./build_common "$@"
    done
}

build_all "$@"

