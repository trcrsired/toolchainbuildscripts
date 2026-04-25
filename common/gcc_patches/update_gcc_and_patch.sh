#!/bin/bash

GCC_DIR="$1"

if [ -z "$GCC_DIR" ]; then
    echo "Usage: $0 <gcc source directory>"
    exit 1
fi

cd "$GCC_DIR" || exit 1

echo "Fetching GCC..."
git fetch --all --prune

if [ "$FORCE_GCC_UPDATE_AND_PATCH" = "yes" ]; then
    echo "FORCE_GCC_UPDATE_AND_PATCH=yes, forcing update."
else
    echo "Checking for updates..."

    if [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/master)" ]; then
        echo "No updates found. Exiting."
        exit 0
    fi

    echo "Updates detected."
fi

echo "Resetting gcc..."
git reset --hard origin/master
git clean -fdx

echo "Pulling without hooks..."
git pull --no-edit --no-verify

SCRIPT_DIR="$(dirname "$0")"

echo "Applying GCC x86 canadian patch..."
python3 "$SCRIPT_DIR/gccx86canadianfix.py" "$GCC_DIR"

echo "Applying libgcc multilib no‑red‑zone patch..."
"$SCRIPT_DIR/patch_libgcc_multilib.sh" "$GCC_DIR"

echo "Applying Win32 gthread condition‑variable patch..."
python3 "$SCRIPT_DIR/patch_win32_gthread.py" "$GCC_DIR"

echo "GCC's ./contrib/download_prerequisites (--no-isl)"
cd "$GCC_DIR" || exit 1
./contrib/download_prerequisites --no-isl

# Link binutils-gdb dependencies using relative paths
BINUTILS_DIR="$(dirname "$GCC_DIR")/binutils-gdb"

if [ -d "$BINUTILS_DIR" ] && [ -f "$BINUTILS_DIR/configure" ]; then
    echo "Found binutils-gdb at $BINUTILS_DIR"

    for dep in gmp mpfr mpc; do
        SRC="../$(basename "$GCC_DIR")/$dep"
        DEST="$BINUTILS_DIR/$dep"

        # Try to create symlink directly; if it fails, skip
        if ln -s "$SRC" "$DEST" 2>/dev/null; then
            echo "Linking $dep -> $SRC"
        else
            echo "Skipping $dep (already exists)"
        fi
    done
fi

cd "$GCC_DIR" || exit 1
git apply "$SCRIPT_DIR/woafix.diff"
if [ $? -ne 0 ]; then
    echo "git apply $SCRIPT_DIR/woafix.diff failed"
    exit 1
fi

git apply "$SCRIPT_DIR/0001-libsanitizer-Cherry-pick-from-LLVM-for-GCC-build.patch"
if [ $? -ne 0 ]; then
    echo "git apply $SCRIPT_DIR/0001-libsanitizer-Cherry-pick-from-LLVM-for-GCC-build.patch failed"
    exit 1
fi


echo "All GCC post‑pull patches applied."
