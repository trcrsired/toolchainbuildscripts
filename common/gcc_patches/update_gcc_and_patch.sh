#!/bin/bash

GCC_DIR="$1"

if [ -z "$GCC_DIR" ]; then
    echo "Usage: $0 <gcc source directory>"
    exit 1
fi

cd "$GCC_DIR" || exit 1

echo "Fetching GCC..."
git fetch --all --prune

echo "Checking for updates..."
LOCAL_HASH=$(git rev-parse HEAD)
REMOTE_HASH=$(git rev-parse origin/master)

if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then
    echo "No updates found. Exiting."
    exit 0
fi

echo "Updates detected. Resetting..."
git reset --hard origin/master

echo "Pulling without hooks..."
git pull --no-edit --no-verify

SCRIPT_DIR="$(dirname "$0")"

echo "Applying Canadian Cross red‑zone patch..."
"$SCRIPT_DIR/patch_redzone.sh" "$GCC_DIR"

echo "Applying libgcc multilib no‑red‑zone patch..."
"$SCRIPT_DIR/patch_libgcc_multilib.sh" "$GCC_DIR"

echo "Applying Win32 gthread condition‑variable patch..."
"$SCRIPT_DIR/patch_win32_gthread.sh" "$GCC_DIR"

echo "All GCC post‑pull patches applied."
