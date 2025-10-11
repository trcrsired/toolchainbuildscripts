#!/bin/bash

set -e

# --- Setup paths ---
if [ -z "${TOOLCHAINSPATH+x}" ]; then
  TOOLCHAINSPATH="$HOME/toolchains"
fi

if [ -z "${WINDOWSMSVCSYSROOT+x}" ]; then
  WINDOWSMSVCSYSROOT="$TOOLCHAINSPATH/windows-msvc-sysroot"
fi

# --- Clone if missing ---
if [ ! -d "$WINDOWSMSVCSYSROOT" ]; then
  cd "$TOOLCHAINSPATH"
  git clone git@github.com:trcrsired/windows-msvc-sysroot.git
  if [ $? -ne 0 ]; then
    echo "windows-msvc-sysroot clone failure"
    exit 1
  fi
fi

cd "$WINDOWSMSVCSYSROOT"
git pull --quiet

# --- Timestamp and tag ---
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%9NZ")
DATE=$(echo "$TIMESTAMP" | cut -c 1-10 | tr -d "-")
WINDOWSMSVCSYSROOT_TAG="$DATE"

# --- Pack windows-msvc-sysroot ---
cd "$TOOLCHAINSPATH"
XZ_OPT=-e9T0 tar --exclude='windows-msvc-sysroot/.*' -cJf windows-msvc-sysroot.tar.xz windows-msvc-sysroot

# --- Build release notes ---
WINDOWSMSVCSYSROOT_NOTES=$(mktemp)
{
  echo "Automatically uploaded windows-msvc-sysroot at $TIMESTAMP"
  FILENAME="windows-msvc-sysroot.tar.xz"
  echo "File: $FILENAME"
} > "$WINDOWSMSVCSYSROOT_NOTES"

WINDOWSMSVCSYSROOT_REPO="${GITHUB_BUILD_WINDOWSMSVCSYSROOT_REPO:-trcrsired/windows-msvc-sysroot}"

# --- Create release if missing ---
if ! gh release view "$WINDOWSMSVCSYSROOT_TAG" --repo "$WINDOWSMSVCSYSROOT_REPO" >/dev/null 2>&1; then
  gh release create "$WINDOWSMSVCSYSROOT_TAG" --repo "$WINDOWSMSVCSYSROOT_REPO" --title "$WINDOWSMSVCSYSROOT_TAG" --notes-file "$WINDOWSMSVCSYSROOT_NOTES"
fi

# --- Upload tarball ---
echo "Uploading windows-msvc-sysroot file: windows-msvc-sysroot.tar.xz"
gh release upload "$WINDOWSMSVCSYSROOT_TAG" windows-msvc-sysroot.tar.xz --repo "$WINDOWSMSVCSYSROOT_REPO"

echo "windows-msvc-sysroot release uploaded successfully! 🚀"
