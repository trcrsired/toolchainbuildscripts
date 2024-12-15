#!/bin/bash

# Ensure directories exist
mkdir -p "$HOME/cfgs"
mkdir -p "$HOME/libraries/fast_io/include"

# Absolute paths
ABS_HOME=$(realpath "$HOME")
ABS_TOOLCHAINSPATH_LLVM=$(realpath "$TOOLCHAINSPATH_LLVM")

# Function to create a config file
create_cfg_file() {
    local cfg_name=$1
    local target=$2
    local sysroot=$3
    local standard_flags=$4
    local extra_flags=$5

    cat <<EOL > "$HOME/cfgs/$cfg_name"
-std=c++26 \\
-fuse-ld=lld \\
--target=$target \\
--sysroot=$sysroot \\
$standard_flags \\
$extra_flags \\
-I$ABS_HOME/libraries/fast_io/include
EOL
}

# Standard flags
STANDARD_FLAGS="
-rtlib=compiler-rt \\
--unwindlib=libunwind \\
-stdlib=libc++ \\
-lunwind \\
-lc++abi"

# Create .cfg files for different triples
create_cfg_file "x86_64-windows-gnu-libcxx.cfg" "x86_64-windows-gnu" "$ABS_TOOLCHAINSPATH_LLVM/x86_64-windows-gnu/x86_64-windows-gnu" "$STANDARD_FLAGS" ""
create_cfg_file "aarch64-windows-gnu-libcxx.cfg" "aarch64-windows-gnu" "$ABS_TOOLCHAINSPATH_LLVM/aarch64-windows-gnu/aarch64-windows-gnu" "$STANDARD_FLAGS" ""
create_cfg_file "x86_64-linux-gnu-libcxx.cfg" "x86_64-linux-gnu" "$ABS_TOOLCHAINSPATH_LLVM/x86_64-linux-gnu/x86_64-linux-gnu" "$STANDARD_FLAGS" ""
create_cfg_file "aarch64-linux-gnu-libcxx.cfg" "aarch64-linux-gnu" "$ABS_TOOLCHAINSPATH_LLVM/aarch64-linux-gnu/aarch64-linux-gnu" "$STANDARD_FLAGS" ""
create_cfg_file "aarch64-linux-android30-libcxx.cfg" "aarch64-linux-android30" "$ABS_TOOLCHAINSPATH_LLVM/aarch64-linux-android30/aarch64-linux-android30" "$STANDARD_FLAGS" ""
create_cfg_file "x86_64-linux-android30-libcxx.cfg" "x86_64-linux-android30" "$ABS_TOOLCHAINSPATH_LLVM/x86_64-linux-android30/x86_64-linux-android30" "$STANDARD_FLAGS" ""

# Create wasm .cfg files
create_cfg_file "wasm64-wasip1.cfg" "wasm64-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-memtag-sysroot/wasm64-wasip1" "$STANDARD_FLAGS" "-fsanitize=memtag"
create_cfg_file "wasm32-wasip1.cfg" "wasm32-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-memtag-sysroot/wasm32-wasip1" "$STANDARD_FLAGS" "-fsanitize=memtag"
create_cfg_file "wasm64-wasip1-noeh.cfg" "wasm64-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-noeh-memtag-sysroot/wasm64-wasip1" "$STANDARD_FLAGS" "-fsanitize=memtag -fno-exceptions -fno-rtti"
create_cfg_file "wasm32-wasip1-noeh.cfg" "wasm32-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-noeh-memtag-sysroot/wasm32-wasip1" "$STANDARD_FLAGS" "-fsanitize=memtag -fno-exceptions -fno-rtti"

# Create msvc .cfg files
create_cfg_file "x86_64-windows-msvc.cfg" "x86_64-windows-msvc" "$ABS_TOOLCHAINSPATH_LLVM/windows-msvc-sysroot" "" "-D_DLL=1 -lmsvcrt"
create_cfg_file "aarch64-windows-msvc.cfg" "aarch64-windows-msvc" "$ABS_TOOLCHAINSPATH_LLVM/windows-msvc-sysroot" "" "-D_DLL=1 -lmsvcrt"

# Create msvc .cfg files with libcxx
create_cfg_file "x86_64-windows-msvc-libcxx.cfg" "x86_64-windows-msvc" "$ABS_TOOLCHAINSPATH_LLVM/windows-msvc-sysroot" "" "-D_DLL=1 -lmsvcrt -stdlib=libc++"
create_cfg_file "aarch64-windows-msvc-libcxx.cfg" "aarch64-windows-msvc" "$ABS_TOOLCHAINSPATH_LLVM/windows-msvc-sysroot" "" "-D_DLL=1 -lmsvcrt -stdlib=libc++"

echo "Configuration files created in $HOME/cfgs"
