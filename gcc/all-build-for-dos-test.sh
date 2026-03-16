#!/usr/bin/env bash
set -e

restart_artifacts()
{
    local toolchainspath
    local toolchains_path_gnu
    if [ -z ${TOOLCHAINSPATH+x} ]; then
        toolchainspath="$HOME/toolchains"
    fi

    if [ -z ${TOOLCHAINSPATH_GNU+x} ]; then
        toolchains_path_gnu="$toolchainspath/gnu"
    fi

    echo "restarting"
    rm -rf "$(realpath .)/.artifacts"
    rm -rf "${toolchains_path_gnu}"
    echo "restart done"
}

if [[ $1 == "restart" ]]; then
restart_artifacts()
fi

build_all() {
    local build_main="x86_64-linux-gnu"
    local triplets=(
        "$build_main x86_64-w64-mingw32 i586-msdosdjgpp"
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
        ./build_common.sh "$@"
    done
}

build_all "$@"

