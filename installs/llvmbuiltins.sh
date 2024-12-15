#!/bin/bash

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

# Extract and clean up tar.xz files
for tar_file in "$TOOLCHAINSPATH_LLVM"/*.tar.xz; do
    # Skip if no tar.xz files found
    [ -e "$tar_file" ] || continue

    # Extract tar.xz file
    tar_dir="${tar_file%.tar.xz}"
    if [ -d "$tar_dir" ]; then
        echo "Removing existing directory $tar_dir"
        rm -rf "$tar_dir"
    fi
    echo "Extracting $tar_file to $TOOLCHAINSPATH_LLVM"
    tar -xf "$tar_file" -C "$TOOLCHAINSPATH_LLVM"
done

# Copy files from TOOLCHAINSPATH_LLVM subdirectories containing 'compiler-rt' or 'builtins' to destination directories
for llvm_dir in "$TOOLCHAINSPATH_LLVM"/*/lib/clang/*; do
    if [[ -d "$llvm_dir" ]]; then
        for dir in "$TOOLCHAINSPATH_LLVM"/*; do
            if [[ -d "$dir/compiler-rt" ]]; then
                echo "Copying files from $dir/compiler-rt/ to $llvm_dir/"
                cp -a "$dir/compiler-rt/"* "$llvm_dir/"
            elif [[ -d "$dir/builtins" ]]; then
                echo "Copying files from $dir/builtins/ to $llvm_dir/"
                cp -a "$dir/builtins/"* "$llvm_dir/"
            fi
        done
    fi
done

echo "Files copied successfully to subdirectories of $TOOLCHAINSPATH_LLVM containing llvm/lib/clang/{version}/"
