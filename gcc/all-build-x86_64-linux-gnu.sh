#!/usr/bin/env bash
set -e

if [ -z ${TOOLCHAINSPATH+x} ]; then
    TOOLCHAINSPATH="$HOME/toolchains"
fi

if [ -z ${TOOLCHAINSPATH_GNU+x} ]; then
    TOOLCHAINSPATH_GNU="$TOOLCHAINSPATH/gnu"
fi

REALPATHCURRENT="$(realpath .)"

if [[ $1 == "restart" ]]; then
    echo "restarting"
    rm -rf "$REALPATHCURRENT/.artifacts"
    rm -rf "${TOOLCHAINSPATH_GNU}"
    echo "restart done"
fi

build_all() {
    local triplets_file="${TRIPLETS_FILE:-$(dirname "$0")/triplet-x86_64-linux-gnu.sh}"

    source "$triplets_file"

    local triplets=("${GCCTRIPLETS[@]}")

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

if [[ "$UPLOAD_GCC" == "yes" ]]; then
cd "$REALPATHCURRENT"
./upload.sh
fi
