#!/bin/bash

# Set toolchains path with user-configurable environment variable
TOOLCHAINSPATH="${TOOLCHAINSPATH:-$HOME/toolchains}"
TOOLCHAINS_LLVMPATH="${TOOLCHAINS_LLVMPATH:-$TOOLCHAINSPATH/llvm}"

# Set WAVM software path from environment variable or default
SOFTWARES_WAVMPATH="${SOFTWARES_WAVMPATH:-$HOME/softwares/wavm}"

# Get the current timestamp in nanosecond-precision ISO 8601 format
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%9NZ")

# Extract YYYYMMDD from the same timestamp
DATE=$(echo "$TIMESTAMP" | cut -c 1-10 | tr -d "-")

# Get the major Clang version
if ! command -v clang >/dev/null 2>&1; then
    echo "Error: clang is not installed. Please install clang before running this script."
    exit 1
fi

# Verify if clang's path contains TOOLCHAINS_LLVMPATH
CLANG_PATH=$(command -v clang)
if [[ "$CLANG_PATH" != *"$TOOLCHAINS_LLVMPATH"* ]]; then
    echo "Error: clang is installed at '$CLANG_PATH', but expected under '$TOOLCHAINS_LLVMPATH'."
    exit 1
fi

CLANG_VERSION=$(clang --version | awk 'NR==1 {print $3}' | sed 's/\([0-9]\+\).*/\1/')

# Define GitHub repositories with environment variable overrides
LLVM_REPO="${GITHUB_BUILD_LLVM_REPO:-trcrsired/llvm-releases}"
WAVM_REPO="${GITHUB_BUILD_WAVM_REPO:-trcrsired/wavm-releases}"

# Authenticate GitHub CLI (optional, ensure login)
gh auth login

# --- Upload LLVM release ---
LLVM_TAG="llvm${CLANG_VERSION}-${DATE}"

if ! gh release view "$LLVM_TAG" --repo "$LLVM_REPO" >/dev/null 2>&1; then
    gh release create "$LLVM_TAG" --repo "$LLVM_REPO" --title "LLVM ${CLANG_VERSION} Toolchains Release" --notes "Automatically uploaded LLVM toolchains at $TIMESTAMP"
fi

for file in "$TOOLCHAINS_LLVMPATH"/*.tar.xz; do
    if [ -f "$file" ]; then
        echo "Uploading LLVM file: $file"
        gh release upload "$LLVM_TAG" "$file" --repo "$LLVM_REPO"
    fi
done

# --- Upload WAVM release ---
WAVM_TAG="$DATE"

if ! gh release view "$WAVM_TAG" --repo "$WAVM_REPO" >/dev/null 2>&1; then
    gh release create "$WAVM_TAG" --repo "$WAVM_REPO" --title "WAVM Release $DATE" --notes "Automatically uploaded WAVM binaries at $TIMESTAMP"
fi

for file in "$SOFTWARES_WAVMPATH"/*.tar.xz; do
    if [ -f "$file" ]; then
        echo "Uploading WAVM file: $file"
        gh release upload "$WAVM_TAG" "$file" --repo "$WAVM_REPO"
    fi
done

echo "All releases have been uploaded successfully! 🚀"
