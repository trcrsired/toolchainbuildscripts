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

echo "Pulling without hooks..."
git pull --no-edit --no-verify

SCRIPT_DIR="$(dirname "$0")"

echo "Applying GCC x86 canadian patch..."
python3 "$SCRIPT_DIR/gccx86canadianfix.py" "$GCC_DIR"

echo "Applying libgcc multilib no‑red‑zone patch..."
"$SCRIPT_DIR/patch_libgcc_multilib.sh" "$GCC_DIR"

echo "Applying Win32 gthread condition‑variable patch..."
"$SCRIPT_DIR/patch_win32_gthread.sh" "$GCC_DIR"

echo "All GCC post‑pull patches applied."
