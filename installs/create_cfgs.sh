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

if [ -z ${LIBRARIES+x} ]; then
    LIBRARIES="$HOME/libraries"
fi

if [ -z ${CFGS+x} ]; then
    CFGS="$HOME/cfgs"
fi

# Create necessary directories
mkdir -p "$TOOLCHAINSPATH_LLVM"
mkdir -p "$CFGS/c"
mkdir -p "$LIBRARIES"

# Absolute paths
ABS_HOME=$(realpath "$HOME")
ABS_TOOLCHAINSPATH=$(realpath "$TOOLCHAINSPATH")
ABS_TOOLCHAINSPATH_LLVM=$(realpath "$TOOLCHAINSPATH_LLVM")
ABS_LIBRARIES=$(realpath "$LIBRARIES")

# Function to create a config file for C and C++
create_cfg_file() {
    local cfg_name=$1
    local target=$2
    local sysroot=$3
    local standard_flags_c=$4
    local standard_flags_cpp=$5
    local extra_flags=$6

    # C config
    cat <<EOL > "$CFGS/c/$cfg_name"
-std=c23 --target=$target --sysroot=$sysroot $standard_flags_c $extra_flags -I$ABS_LIBRARIES/fast_io/include
EOL

    # C++ config
    cat <<EOL > "$CFGS/$cfg_name"
-std=c++26 -fuse-ld=lld --target=$target --sysroot=$sysroot $standard_flags_cpp $extra_flags -I$ABS_LIBRARIES/fast_io/include
EOL
}

# Standard flags for C
STANDARD_FLAGS_C="-rtlib=compiler-rt \
--unwindlib=libunwind"

# Standard flags for C++ without libunwin
STANDARD_FLAGS_CPP_NOLIBUNWIND="-rtlib=compiler-rt \
--unwindlib=libunwind \
-stdlib=libc++ \
-lc++abi"

# Standard flags for C++
STANDARD_FLAGS_CPP="$STANDARD_FLAGS_CPP_NOLIBUNWIND \
-lunwind"

# Flags for Darwin
FLAGS_DARWIN="-fuse-lipo=llvm-lipo -arch x86_64 -arch arm64"

# Create .cfg files for different triples
create_cfg_file "x86_64-windows-gnu-libcxx.cfg" "x86_64-windows-gnu" "$ABS_TOOLCHAINSPATH_LLVM/x86_64-windows-gnu/x86_64-windows-gnu" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP" "-lntdll"
create_cfg_file "aarch64-windows-gnu-libcxx.cfg" "aarch64-windows-gnu" "$ABS_TOOLCHAINSPATH_LLVM/aarch64-windows-gnu/aarch64-windows-gnu" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP" "-lntdll"
create_cfg_file "x86_64-linux-gnu-libcxx.cfg" "x86_64-linux-gnu" "$ABS_TOOLCHAINSPATH_LLVM/x86_64-linux-gnu/x86_64-linux-gnu" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP" ""
create_cfg_file "aarch64-linux-gnu-libcxx.cfg" "aarch64-linux-gnu" "$ABS_TOOLCHAINSPATH_LLVM/aarch64-linux-gnu/aarch64-linux-gnu" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP" ""
create_cfg_file "aarch64-linux-android30-libcxx.cfg" "aarch64-linux-android30" "$ABS_TOOLCHAINSPATH_LLVM/aarch64-linux-android30/aarch64-linux-android30" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP" ""
create_cfg_file "x86_64-linux-android30-libcxx.cfg" "x86_64-linux-android30" "$ABS_TOOLCHAINSPATH_LLVM/x86_64-linux-android30/x86_64-linux-android30" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP" ""
create_cfg_file "loongarch64-linux-gnu-libcxx.cfg" "loongarch64-linux-gnu" "$ABS_TOOLCHAINSPATH_LLVM/loongarch64-linux-gnu/loongarch64-linux-gnu" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP" ""
create_cfg_file "riscv64-linux-gnu-libcxx.cfg" "riscv64-linux-gnu" "$ABS_TOOLCHAINSPATH_LLVM/riscv64-linux-gnu/riscv64-linux-gnu" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP" ""

create_cfg_file "aarch64-apple-darwin24.cfg" "aarch64-apple-darwin24" "$ABS_TOOLCHAINSPATH_LLVM/aarch64-apple-darwin24/aarch64-apple-darwin24" "" "" "$FLAGS_DARWIN"

# Create wasm .cfg files
create_cfg_file "wasm64-wasip1.cfg" "wasm64-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-memtag-sysroot/wasm64-wasip1" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP" "-fsanitize=memtag -fwasm-exceptions"
create_cfg_file "wasm32-wasip1.cfg" "wasm32-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-memtag-sysroot/wasm32-wasip1" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP" "-fsanitize=memtag -fwasm-exceptions"
create_cfg_file "wasm64-wasip1-noeh.cfg" "wasm64-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-noeh-memtag-sysroot/wasm64-wasip1" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP_NOLIBUNWIND" "-fsanitize=memtag"
create_cfg_file "wasm32-wasip1-noeh.cfg" "wasm32-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-noeh-memtag-sysroot/wasm32-wasip1" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP_NOLIBUNWIND" "-fsanitize=memtag"
create_cfg_file "wasm64-wasip1-nomtg.cfg" "wasm64-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-memtag-sysroot/wasm64-wasip1" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP" "-fwasm-exceptions"
create_cfg_file "wasm32-wasip1-nomtg.cfg" "wasm32-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-memtag-sysroot/wasm32-wasip1" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP" "-fwasm-exceptions"
create_cfg_file "wasm64-wasip1-noeh-nomtg.cfg" "wasm64-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-noeh-memtag-sysroot/wasm64-wasip1" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP_NOLIBUNWIND" ""
create_cfg_file "wasm32-wasip1-noeh-nomtg.cfg" "wasm32-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-noeh-memtag-sysroot/wasm32-wasip1" "$STANDARD_FLAGS_C" "$STANDARD_FLAGS_CPP_NOLIBUNWIND" ""

# Create msvc .cfg files
create_cfg_file "x86_64-windows-msvc.cfg" "x86_64-windows-msvc" "$ABS_TOOLCHAINSPATH/windows-msvc-sysroot" "" "" "-D_DLL=1 -lmsvcrt"
create_cfg_file "aarch64-windows-msvc.cfg" "aarch64-windows-msvc" "$ABS_TOOLCHAINSPATH/windows-msvc-sysroot" "" "" "-D_DLL=1 -lmsvcrt"
create_cfg_file "i686-windows-msvc.cfg" "i686-windows-msvc" "$ABS_TOOLCHAINSPATH/windows-msvc-sysroot" "" "" "-D_DLL=1 -lmsvcrt"

# Create msvc .cfg files with libcxx
create_cfg_file "x86_64-windows-msvc-libcxx.cfg" "x86_64-windows-msvc" "$ABS_TOOLCHAINSPATH/windows-msvc-sysroot" "" "" "-D_DLL=1 -lmsvcrt -stdlib=libc++"
create_cfg_file "aarch64-windows-msvc-libcxx.cfg" "aarch64-windows-msvc" "$ABS_TOOLCHAINSPATH/windows-msvc-sysroot" "" "" "-D_DLL=1 -lmsvcrt -stdlib=libc++"
create_cfg_file "i686-windows-msvc-libcxx.cfg" "i686-windows-msvc" "$ABS_TOOLCHAINSPATH/windows-msvc-sysroot" "" "" "-D_DLL=1 -lmsvcrt -stdlib=libc++"

if [ ! -d "$LIBRARIES/fast_io" ]; then
git clone --quiet git@github.com:trcrsired/fast_io.git "$LIBRARIES/fast_io"
if [ $? -ne 0 ]; then
git clone --quiet --branch next git@github.com:cppfastio/fast_io.git "$LIBRARIES/fast_io"
if [ $? -ne 0 ]; then
git clone --quiet git@github.com:cppfastio/fast_io.git "$LIBRARIES/fast_io"
if [ $? -ne 0 ]; then
git clone --quiet --branch next git@gitee.com:qabeowjbtkwb/fast_io.git "$LIBRARIES/fast_io"
if [ $? -ne 0 ]; then
git clone --quiet git@gitee.com:qabeowjbtkwb/fast_io.git "$LIBRARIES/fast_io"
if [ $? -ne 0 ]; then
echo "fast_io clone failure"
exit 1
fi
fi
fi
fi
fi
fi
cd "$LIBRARIES/fast_io"
git pull --quiet
