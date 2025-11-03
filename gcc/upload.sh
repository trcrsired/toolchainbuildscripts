#!/usr/bin/env bash

set -euo pipefail

# === Allow user to override TOOLCHAINSPATH ===
# If TOOLCHAINSPATH is not set, default to $HOME/toolchains
if [ -z "${TOOLCHAINSPATH+x}" ]; then
  TOOLCHAINSPATH="$HOME/toolchains"
fi

# === Allow user to override TOOLCHAINSPATH_GNU ===
# If TOOLCHAINSPATH_GNU is not set, default to $TOOLCHAINSPATH/gnu
if [ -z "${TOOLCHAINSPATH_GNU+x}" ]; then
  TOOLCHAINSPATH_GNU="$TOOLCHAINSPATH/gnu"
fi

# === Generate UTC date tag in YYYYMMDD format ===
TAG="$(date -u +%Y%m%d)"
REPO="trcrsired/gcc-releases"

# === Create release if it doesn't exist ===

if ! gh release view "$TAG" --repo "$REPO" &>/dev/null; then
  echo "Creating release: $TAG"
  gh release create "$TAG" --repo "$REPO" --title "$TAG" --notes "Auto-uploaded toolchain release for $TAG"
else
  echo "Release $TAG already exists"
fi

# === Define regex: match x.y.tar.xz where x and y contain at least one dash ===
regex='^.+-.+\..+-.+\.tar\.xz$'

# === Recursively find and upload matching files ===
find "$TOOLCHAINSPATH_GNU" -type f -name '*.tar.xz' | while read -r file; do
  filename="$(basename "$file")"
  if [[ "$filename" =~ $regex ]]; then
    echo "Uploading $filename"
    gh release upload "$TAG" "$file" --repo "$REPO" --clobber
  fi
done
