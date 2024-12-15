#!/bin/bash

# Check if the argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <release_version>"
    exit 1
fi

# Release version passed as argument
RELEASE_VERSION="$1"

# Check if TOOLCHAINSPATH environment variable is set, otherwise use $HOME/toolchains
if [ -z ${TOOLCHAINSPATH+x} ]; then
    TOOLCHAINSPATH="$HOME/toolchains"
fi

# Create necessary directories
mkdir -p "$TOOLCHAINSPATH"

# Check if TOOLCHAINSPATH_LLVM environment variable is set, otherwise use $TOOLCHAINSPATH/llvm
if [ -z ${TOOLCHAINSPATH_LLVM+x} ]; then
    TOOLCHAINSPATH_LLVM="$TOOLCHAINSPATH/llvm"
fi

# Create necessary directories
mkdir -p "$TOOLCHAINSPATH_LLVM"

# Set the base URL for downloads
BASE_URL="https://github.com/trcrsired/llvm-releases/releases/download/$RELEASE_VERSION"

# Determine the list of files to download
if [ "$DOWNLOAD_ALL" == "yes" ]; then
    FILES=(
        "aarch64-windows-gnu.tar.xz"
        "aarch64-linux-gnu.tar.xz"
        "aarch64-linux-android30.tar.xz"
        "x86_64-windows-gnu.tar.xz"
        "x86_64-linux-gnu.tar.xz"
        "x86_64-linux-android30.tar.xz"
        "wasm-sysroots.tar.xz"
    )
else
    # Determine TRIPLE if not set
    if [ -z ${TRIPLE+x} ]; then
        if command -v clang > /dev/null; then
            TRIPLE=$(clang -dumpmachine)
        elif command -v gcc > /dev/null; then
            TRIPLE=$(gcc -dumpmachine)
        else
            echo "Neither clang nor gcc is installed. Please install one of them or set the TRIPLE environment variable."
            exit 1
        fi
    fi
    
    # Remove 'pc' or 'unknown' from TRIPLE if present
    IFS='-' read -r -a parts <<< "$TRIPLE"
    if [ "${#parts[@]}" -eq 4 ] && [[ "${parts[1]}" == "pc" || "${parts[1]}" == "unknown" ]]; then
        TRIPLE="${parts[0]}-${parts[2]}-${parts[3]}"
    fi

    # Extract ARCH from TRIPLE
    ARCH=$(echo $TRIPLE | cut -d'-' -f1)

    FILES=(
        "$ARCH-windows-gnu.tar.xz"
        "$TRIPLE.tar.xz"
        "wasm-sysroots.tar.xz"
    )
fi

# Download files using curl or wget
download_file() {
    local url=$1
    local dest=$2

    if command -v curl > /dev/null; then
        curl -L -o "$dest" "$url"
    elif command -v wget > /dev/null; then
        wget -O "$dest" "$url"
    else
        echo "Neither curl nor wget is installed. Please install one of them to proceed."
        exit 1
    fi
}

for file in "${FILES[@]}"; do
    echo "Downloading $file to $TOOLCHAINSPATH_LLVM"
    download_file "$BASE_URL/$file" "$TOOLCHAINSPATH_LLVM/$file"
done

echo "Downloads completed successfully to $TOOLCHAINSPATH_LLVM"

# Run the script to extract and copy files
# Please ensure the script is saved as "llvmbuiltins.sh" and is executable
./llvmbuiltins.sh
