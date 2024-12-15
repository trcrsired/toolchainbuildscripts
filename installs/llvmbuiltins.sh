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

# Loop through all subdirectories in TOOLCHAINSPATH_LLVM and copy files if subdirectory contains 'compiler-rt' or 'builtins'
for llvm_subdir in "$TOOLCHAINSPATH_LLVM"/*; do
    if [[ -d "$llvm_subdir/lib/clang" ]]; then
        for clang_version_dir in "$llvm_subdir/lib/clang/"*; do
            if [[ -d "$clang_version_dir" ]]; then
                echo "Found clang directory: $clang_version_dir"
                if [[ -d "$llvm_subdir/compiler-rt" ]]; then
                    echo "Copying files from $llvm_subdir/compiler-rt/ to $clang_version_dir/"
                    cp -a "$llvm_subdir/compiler-rt/"* "$clang_version_dir/"
                elif [[ -d "$llvm_subdir/builtins" ]]; then
                    echo "Copying files from $llvm_subdir/builtins/ to $clang_version_dir/"
                    cp -a "$llvm_subdir/builtins/"* "$clang_version_dir/"
                fi
            fi
        done
    fi
done

echo "Files copied successfully to subdirectories of $TOOLCHAINSPATH_LLVM containing llvm/lib/clang/{version}/"
