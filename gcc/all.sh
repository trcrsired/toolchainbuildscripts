#!/bin/bash
set -e

ROOT_DIR="$(dirname "$0")"
COMMON_BUILD="${ROOT_DIR}/build_common.sh"

# Detect native triplet
NATIVE_TRIPLET="$(gcc -dumpmachine)"

echo "Detected native GCC triplet: $NATIVE_TRIPLET"

# ---------------------------------------------------------
# Manually listed host-target pairs (flat list)
# ---------------------------------------------------------
BUILD_JOBS=(
    # Always build these two first
    "x86_64-linux-gnu x86_64-linux-gnu"
    "x86_64-w64-mingw32 x86_64-w64-mingw32"

    # x86_64-linux-gnu host
    "x86_64-linux-gnu aarch64-linux-gnu"
    "x86_64-linux-gnu loongarch64-linux-gnu"
    "x86_64-linux-gnu x86_64-linux-musl"
    "x86_64-linux-gnu aarch64-linux-musl"
    "x86_64-linux-gnu loongarch64-linux-musl"
    "x86_64-linux-gnu i686-w64-mingw32"
    "x86_64-linux-gnu x86_64-elf"
    "x86_64-linux-gnu i586-msdosdjgpp"
    "x86_64-linux-gnu x86_64-freebsd14"

    # x86_64-w64-mingw32 host
    "x86_64-w64-mingw32 aarch64-linux-gnu"
    "x86_64-w64-mingw32 loongarch64-linux-gnu"
    "x86_64-w64-mingw32 x86_64-linux-musl"
    "x86_64-w64-mingw32 aarch64-linux-musl"
    "x86_64-w64-mingw32 loongarch64-linux-musl"
    "x86_64-w64-mingw32 i686-w64-mingw32"
    "x86_64-w64-mingw32 x86_64-elf"
    "x86_64-w64-mingw32 i586-msdosdjgpp"
    "x86_64-w64-mingw32 x86_64-freebsd14"
)

# ---------------------------------------------------------
# Insert native builds at the top (without replacing first two)
# ---------------------------------------------------------

# Native → native (only if not one of the first two)
if [[ "$NATIVE_TRIPLET" != "x86_64-linux-gnu" && "$NATIVE_TRIPLET" != "x86_64-w64-mingw32" ]]; then
    BUILD_JOBS=( "${NATIVE_TRIPLET} ${NATIVE_TRIPLET}" "${BUILD_JOBS[@]}" )
fi

# Native → x86_64-linux-gnu
if [[ "$NATIVE_TRIPLET" != "x86_64-linux-gnu" ]]; then
    BUILD_JOBS=( "${NATIVE_TRIPLET} x86_64-linux-gnu" "${BUILD_JOBS[@]}" )
fi

# Native → x86_64-w64-mingw32
if [[ "$NATIVE_TRIPLET" != "x86_64-w64-mingw32" ]]; then
    BUILD_JOBS=( "${NATIVE_TRIPLET} x86_64-w64-mingw32" "${BUILD_JOBS[@]}" )
fi

# ---------------------------------------------------------
# Print job list
# ---------------------------------------------------------
echo "Final build job list:"
for JOB in "${BUILD_JOBS[@]}"; do
    echo "  $JOB"
done

# ---------------------------------------------------------
# Execute builds
# ---------------------------------------------------------
for JOB in "${BUILD_JOBS[@]}"; do
    HOST_TRIPLET="${JOB%% *}"
    TARGET_TRIPLET="${JOB##* }"

    echo "=============================================="
    echo " Building toolchain:"
    echo "   HOST   = $HOST_TRIPLET"
    echo "   TARGET = $TARGET_TRIPLET"
    echo "=============================================="

    export HOST_TRIPLET TARGET_TRIPLET
    bash "$COMMON_BUILD"
done

