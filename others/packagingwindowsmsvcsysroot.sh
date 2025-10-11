#!/bin/bash

set -e

# --- Setup paths ---
if [ -z "${TOOLCHAINSPATH+x}" ]; then
  TOOLCHAINSPATH="$HOME/toolchains"
fi

if [ -z "${WINDOWSSYSROOT+x}" ]; then
  WINDOWSSYSROOT="$TOOLCHAINSPATH/windows-msvc-sysroot"
fi

# --- Clone if missing ---
if [ ! -d "$WINDOWSSYSROOT" ]; then
  cd "$TOOLCHAINSPATH"
  git clone git@github.com:trcrsired/windows-msvc-sysroot.git
  if [ $? -ne 0 ]; then
    echo "windows-msvc-sysroot clone failure"
    exit 1
  fi
fi

cd "$WINDOWSSYSROOT"
git pull --quiet

# --- Timestamp and tag ---
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%9NZ")
DATE=$(echo "$TIMESTAMP" | cut -c 1-10 | tr -d "-")
SYSROOT_TAG="$DATE"

# --- Pack sysroot ---
cd "$TOOLCHAINSPATH"
XZ_OPT=-e9T0 tar --exclude='windows-msvc-sysroot/.*' -cJf windows-msvc-sysroot.tar.xz windows-msvc-sysroot

# --- Build release notes ---
SYSROOT_NOTES=$(mktemp)
{
  echo "Automatically uploaded MSVC sysroot at $TIMESTAMP"
  FILENAME="windows-msvc-sysroot.tar.xz"
  SHA512=$(sha512sum "$FILENAME" | awk '{print $1}')
  echo "File: $FILENAME"
  echo "SHA-512: $SHA512"
} > "$SYSROOT_NOTES"

# --- Create release if missing ---
if ! gh release view "$SYSROOT_TAG" --repo "$SYSROOT_REPO" >/dev/null 2>&1; then
  gh release create "$SYSROOT_TAG" --repo "$SYSROOT_REPO" --title "$SYSROOT_TAG" --notes-file "$SYSROOT_NOTES"
fi

# --- Upload tarball ---
echo "Uploading sysroot file: windows-msvc-sysroot.tar.xz"
gh release upload "$SYSROOT_TAG" windows-msvc-sysroot.tar.xz --repo "$SYSROOT_REPO"

echo "Sysroot release uploaded successfully! 🚀"
