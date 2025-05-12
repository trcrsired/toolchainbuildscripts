#!/bin/bash

if [ -z ${HOST_TRIPLET+x} ]; then
echo "HOST_TRIPLET is not set. Please set the HOST_TRIPLET environment variable to the target triplet."
exit 1
fi

if [ -z ${TARGET_TRIPLET+x} ]; then
echo "TARGET_TRIPLET is not set. Please set the TARGET_TRIPLET environment variable to the target triplet."
exit 1
fi

currentpath="$(realpath .)/.artifacts/gcc/${HOST_TRIPLET}/${TARGET_TRIPLET}"
if [[ "x${GENERATE_CMAKE_ONLY}" == "xyes" ]]; then
SKIP_DEPENDENCY_CHECK=yes
fi
mkdir -p "$currentpath"
cd ../common
source ./common.sh

cd "$currentpath"

parse_triplet $HOST_TRIPLET HOST_CPU HOST_VENDOR HOST_OS HOST_ABI
if [ $? -ne 0 ]; then
echo "Failed to parse the host triplet: $HOST_TRIPLET"
exit 1
fi

if [[ "x$CLONE_IN_CHINA" == "xyes" ]]; then
echo "Clone in China enabled. We are going to use Chinese mirror first"
fi

if [[ "$HOST_OS" == mingw* ]]; then
HOST_TRIPLET=$HOST_CPU-windows-gnu
unset HOST_VENDOR
HOST_OS=windows
HOST_ABI=gnu
fi

if [[ "$HOST_OS" == windows && "$HOST_ABI" == gnu ]]; then
HOST_GCC_TRIPLET=$HOST_CPU-w64-mingw32
fi

if [ -z ${HOST_GCC_TRIPLET+x} ]; then
HOST_GCC_TRIPLET=$HOST_TRIPLET
fi


HOST_ABI_NO_VERSION="${HOST_ABI//[0-9]/}"
HOST_ABI_VERSION=${HOST_ABI//[!0-9]/}

echo "HOST_TRIPLET: $HOST_TRIPLET"
echo "HOST_CPU: $HOST_CPU"
echo "HOST_VENDOR: $HOST_VENDOR"
echo "HOST_OS: $HOST_OS"
echo "HOST_ABI: $HOST_ABI"
echo "HOST_ABI_NO_VERSION: $HOST_ABI_NO_VERSION"
echo "HOST_GCC_TRIPLET: $HOST_GCC_TRIPLET"

parse_triplet $TARGET_TRIPLET TARGET_CPU TARGET_VENDOR TARGET_OS TARGET_ABI
if [ $? -ne 0 ]; then
echo "Failed to parse the host triplet: $TARGET_TRIPLET"
exit 1
fi

if [[ "$TARGET_OS" == mingw* ]]; then
TARGET_TRIPLET=$TARGET_CPU-windows-gnu
unset TARGET_VENDOR
TARGET_OS=windows
TARGET_ABI=gnu
fi

if [[ "$TARGET_OS" == windows && "$TARGET_ABI" == gnu ]]; then
TARGET_TRIPLET=$TARGET_CPU-w64-mingw32
fi

if [ -z ${TARGET_GCC_TRIPLET+x} ]; then
TARGET_GCC_TRIPLET=$TARGET_TRIPLET
fi

TARGET_ABI_NO_VERSION="${TARGET_ABI//[0-9]/}"
TARGET_ABI_VERSION=${TARGET_ABI//[!0-9]/}

echo "TARGET_TRIPLET: $TARGET_TRIPLET"
echo "TARGET_CPU: $TARGET_CPU"
echo "TARGET_VENDOR: $TARGET_VENDOR"
echo "TARGET_OS: $TARGET_OS"
echo "TARGET_ABI: $TARGET_ABI"
echo "TARGET_GCC_TRIPLET: $TARGET_GCC_TRIPLET"


if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD="$HOME/toolchains_build"
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH="$HOME/toolchains"
fi

if [ -z ${TOOLCHAINSPATH_GNU+x} ]; then
	TOOLCHAINSPATH_GNU="$TOOLCHAINSPATH/gnu"
fi

mkdir -p "${TOOLCHAINSPATH_GNU}"

if [ -z ${BUILD_TRIPLET+x} ]; then

if ! command -v gcc >/dev/null 2>&1; then
    echo "failed to find gcc"
    exit 1
fi

BUILD_TRIPLET="$(gcc -dumpmachine)"
BUILD_GCC_TRIPLET="$BUILD_TRIPLET"

fi

parse_triplet $BUILD_TRIPLET BUILD_CPU BUILD_VENDOR BUILD_OS BUILD_ABI
if [ $? -ne 0 ]; then
echo "Failed to parse the host triplet: $BUILD_TRIPLET"
exit 1
fi

if [[ "$BUILD_OS" == linux && "$BUILD_ABI" == gnu ]]; then

if ! command -v $BUILD_CPU-$BUILD_OS-$BUILD_ABI-gcc >/dev/null 2>&1; then
    echo "failed to find $BUILD_CPU-$BUILD_OS-$BUILD_ABI-gcc"
    exit 1
fi

BUILD_TRIPLET=$BUILD_CPU-$BUILD_OS-$BUILD_ABI
BUILD_VENDOR=
BUILD_GCC_TRIPLET=$BUILD_TRIPLET
fi

if [[ "$BUILD_OS" == windows && "$BUILD_ABI" == gnu ]]; then
BUILD_GCC_TRIPLET=$BUILD_CPU-w64-mingw32
fi

if [ -z ${BUILD_GCC_TRIPLET+x} ]; then
BUILD_GCC_TRIPLET=$BUILD_TRIPLET
fi

echo "BUILD_TRIPLET: $BUILD_TRIPLET"
echo "BUILD_CPU: $BUILD_CPU"
echo "BUILD_VENDOR: $BUILD_VENDOR"
echo "BUILD_OS: $BUILD_OS"
echo "BUILD_ABI: $BUILD_ABI"
echo "BUILD_GCC_TRIPLET: $BUILD_GCC_TRIPLET"

GCC_TWO_PHASE=0

clone_or_update_dependency binutils-gdb
clone_or_update_dependency gcc

build_project_gnu() {
local project_name=$1
local host_triplet=$2
local target_triplet=$3
local prefix="$TOOLCHAINSPATH_GNU/$2/$3"
local build_prefix="$currentpath/$2/$3"
local build_prefix_project="$build_prefix/$project_name"
local configure_phase_file=".${project_name}_phase_configure"
local build_phase_file=".${project_name}_phase_build"
local build_all_gcc_phase_file=".${project_name}_all_gcc_phase_build"
local install_phase_file=".${project_name}_phase_install"
local strip_phase_file=".${project_name}_phase_strip"
local current_phase_file=".${project_name}_phase_done"

local configures="--build=$BUILD_TRIPLET --host=$host_triplet --target=$target_triplet"

if [[ "x$project_name" == "xgcc_phase1" ]]; then
configures="$configures --disable-libstdcxx-verbose --enable-languages=c,c++ --disable-sjlj-exceptions --with-libstdcxx-eh-pool-obj-count=0 --enable-multilib --disable-hosted-libstdcxx --without-headers --disable-threads --disable-shared --disable-libssp --disable-libquadmath --disable-libbacktrace --disable-libatomics --disable-libsanitizer"
elif [[ "x$project_name" == "xgcc" ]]; then
configures="$configures --disable-libstdcxx-verbose --enable-languages=c,c++ --disable-sjlj-exceptions --with-libstdcxx-eh-pool-obj-count=0 --enable-multilib"
elif [[ "x$project_name" == "xbinutils-gdb" ]]; then
configures="$configures --disable-tui --without-debuginfod"
fi

if [ ! -f "${build_prefix_project}/${current_phase_file}" ]; then

    mkdir -p "$build_prefix_project"

    if [ ! -f "${build_prefix_project}/${configure_phase_file}" ]; then
        cd "$build_prefix_project"
        "$TOOLCHAINS_BUILD"/$project_name/configure --disable-nls --disable-werror --disable-bootstrap --prefix="$prefix" $configures
        if [ $? -ne 0 ]; then
            echo "$project_name: configure failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
            exit 1
        fi
        echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${configure_phase_file}"
    fi

    if [[ "x$project_name" == "xgcc" || "x$project_name" == "xgcc_phase1" ]]; then
        if [ ! -f "${build_prefix_project}/${build_all_gcc_phase_file}" ]; then
            make all-gcc -j$(nproc)
            if [ $? -ne 0 ]; then
                echo "$project_name: make all-gcc failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
                exit 1
            fi
            cat "$TOOLCHAINS_BUILD/gcc/gcc/limitx.h" "$TOOLCHAINS_BUILD/gcc/gcc/glimits.h" "$TOOLCHAINS_BUILD/gcc/gcc/limity.h" > "${build_prefix_project}/gcc/include/limits.h"
            echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${build_all_gcc_phase_file}"
        fi
    fi
    if [[ "x$project_name" == "xgcc_phase1" ]]; then
        make all-target-libgcc -j$(nproc)
        if [ $? -ne 0 ]; then
            echo "$project_name: make all-target-libgcc failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
            exit 1
        fi
        make install-gcc -j$(nproc)
        if [ $? -ne 0 ]; then
            echo "$project_name: make install-gcc failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
            exit 1
        fi
        make install-target-libgcc -j$(nproc)
        if [ $? -ne 0 ]; then
            echo "$project_name: make install-target-libgcc failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
            exit 1
        fi

    else
        if [ ! -f "${build_prefix_project}/${build_phase_file}" ]; then
            make -j$(nproc)
            if [ $? -ne 0 ]; then
                echo "$project_name: make failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
                exit 1
            fi
            echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${build_phase_file}"
        fi

        if [ ! -f "${build_prefix_project}/${install_phase_file}" ]; then
            make install -j$(nproc)
            if [ $? -ne 0 ]; then
                echo "$project_name: make install failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
                exit 1
            fi
            echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${install_phase_file}"
        fi
    fi

    if [ ! -f "${build_prefix_project}/${strip_phase_file}" ]; then
        safe_llvm_strip "$prefix"
        echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${strip_phase_file}"
    fi

    echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${current_phase_file}"
fi

}

build_binutils_gdb() {
    build_project_gnu "binutils-gdb" $1 $2
}

build_gcc() {
    build_project_gnu "gcc" $1 $2
}

build_gcc_phase1() {
    build_project_gnu "gcc_phase1" $1 $2
}

build_binutils_gdb_and_gcc() {
    build_project_gnu "binutils-gdb" $1 $2
    build_project_gnu "gcc" $1 $2
}

build_cross_toolchain() {
    local host_triplet=$1
    local target_triplet=$2
    local target_cpu
    local target_vendor
    local target_os
    local target_abi
    parse_triplet $target_triplet target_cpu target_vendor target_os target_abi
    if [[ $target_os == "linux" && $target_abi == "gnu" ]]; then
        build_binutils_gdb  $host_triplet $target_triplet
        build_gcc_phase1 $host_triplet $target_triplet
        build_gcc $host_triplet $target_triplet
    else
        install_libc $target_triplet "${currentpath}/libc" "${currentpath}/install/libc" "${TOOLCHAINSPATH_GNU}/$host_triplet/${target_triplet}/${target_triplet}" "yes"
        build_binutils_gdb_and_gcc $host_triplet $target_triplet
    fi
}

if [[ ${BUILD_GCC_TRIPLET} == ${HOST_GCC_TRIPLET} && ${HOST_GCC_TRIPLET} == ${TARGET_GCC_TRIPLET} ]]; then
# native compiler
build_binutils_gdb_and_gcc $HOST_GCC_TRIPLET $HOST_GCC_TRIPLET
else
if ! command -v $HOST_GCC_TRIPLET-gcc >/dev/null 2>&1; then
    build_cross_toolchain $BUILD_GCC_TRIPLET $HOST_GCC_TRIPLET
fi
if [[ ${BUILD_GCC_TRIPLET} != ${HOST_GCC_TRIPLET} && ${BUILD_GCC_TRIPLET} == ${TARGET_GCC_TRIPLET} ]]; then
# crossback
install_libc $BUILD_GCC_TRIPLET "${currentpath}/libc" "${currentpath}/install/libc" "${TOOLCHAINSPATH_GNU}/$HOST_GCC_TRIPLET/${TARGET_GCC_TRIPLET}/${TARGET_GCC_TRIPLET}" "no"
build_binutils_gdb_and_gcc $HOST_GCC_TRIPLET $TARGET_GCC_TRIPLET
#else
# ${BUILD_GCC_TRIPLET} != ${HOST_GCC_TRIPLET}
fi

fi