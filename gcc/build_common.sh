#!/bin/bash

if [ -z ${HOST_TRIPLET+x} ]; then
echo "HOST_TRIPLET is not set. Please set the HOST_TRIPLET environment variable to the target triplet."
exit 1
fi

if [ -z ${TARGET_TRIPLET+x} ]; then
echo "TARGET_TRIPLET is not set. Please set the TARGET_TRIPLET environment variable to the target triplet."
exit 1
fi
artifactspath="$(realpath .)/.artifacts"
currentpathnohosttriplet="${artifactspath}/gcc"
currentpath="${currentpathnohosttriplet}/${HOST_TRIPLET}/${TARGET_TRIPLET}"
if [[ "x${GENERATE_CMAKE_ONLY}" == "xyes" ]]; then
SKIP_DEPENDENCY_CHECK=yes
fi
mkdir -p "$currentpath"
cd ../common
source ./common.sh

# Determine the number of CPU threads to use for the Ninja build

# Get the total number of logical CPU cores on the system
# Detect total logical CPU cores with fallback and verbose output
if command -v nproc >/dev/null 2>&1; then
    echo "Using nproc to detect core count..."
    TOTAL_CORES=$(nproc)
    echo "Detected TOTAL_CORES = ${TOTAL_CORES}"
elif command -v sysctl >/dev/null 2>&1; then
    echo "nproc not found, using sysctl instead..."
    TOTAL_CORES=$(sysctl -n hw.logicalcpu)
    echo "Detected TOTAL_CORES = ${TOTAL_CORES}"
fi

if [ -z "$TOTAL_CORES" ]; then
    echo "Neither nproc nor sysctl succeeded, defaulting to 6 cores..."
    TOTAL_CORES=6
fi

JOBS=${TOTAL_CORES}

# If NINJA_MAX_JOBS is explicitly set, use that value
if [[ -n "$NINJA_MAX_JOBS" ]]; then
    JOBS="$NINJA_MAX_JOBS"
    echo "📌 Using NINJA_MAX_JOBS=$JOBS"
# If REDUCE_BUILDING_POWER_FOR_TEMPERATURE is set, reduce thread count by half
elif [[ -n "$REDUCE_BUILDING_POWER_FOR_TEMPERATURE" ]]; then
    JOBS=$((TOTAL_CORES / 2))
    
    # Clamp JOBS to range [1, 4]
    if [[ "$JOBS" -lt 1 ]]; then
        JOBS=1
#    elif [[ "$JOBS" -gt 4 ]]; then
#        JOBS=4
    fi

    echo "🌞 REDUCE_BUILDING_POWER_FOR_TEMPERATURE detected — using $JOBS threads (half of $TOTAL_CORES)"
# Otherwise, use all available cores
else
    echo "⚡ No throttling — using all $TOTAL_CORES threads"
fi

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

if [ -z ${TOOLCHAINS_BUILD_SHARED_STORAGE+x} ]; then
    TOOLCHAINS_BUILD_SHARED_STORAGE="${TOOLCHAINS_BUILD}/.shared_storage"
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

export PATH="${TOOLCHAINSPATH_GNU}/${BUILD_GCC_TRIPLET}/${HOST_GCC_TRIPLET}/bin:${TOOLCHAINSPATH_GNU}/${BUILD_GCC_TRIPLET}/${TARGET_GCC_TRIPLET}/bin:$PATH"

GCC_TWO_PHASE=0

# Check if NO_CLONE_OR_UPDATE is set to "yes"
if [ "$NO_CLONE_OR_UPDATE" != "yes" ]; then
    clone_or_update_dependency binutils-gdb
    clone_or_update_dependency gcc
else
    echo "NO_CLONE_OR_UPDATE is set to 'yes'; skipping dependency clone/update."
fi

duplicating_runtimes()
{
    local project_name="$1"
    local build_prefix_project="$2"
    local target_triplet="$3"
    local sysroot_prefix="$4"
    local duplicating_runtimes_phase_file=".${project_name}_duplicating_runtimes_phase"

    # Skip if phase already completed
    if [ -f "${build_prefix_project}/${duplicating_runtimes_phase_file}" ]; then
        return 0
    fi

    mkdir -p "${sysroot_prefix}/runtimes" || {
        echo "Error: Failed to create ${sysroot_prefix}/runtimes"
        exit 1
    }

    # Step 1: Build whitelist from all files under GCC build root
    local -A gcc_so_whitelist=()
    local gcc_build_root="${build_prefix_project}/${target_triplet}"

    while IFS= read -r entry; do
        local fname="$(basename "$entry")"
        gcc_so_whitelist["$fname"]=1
    done < <(find "$gcc_build_root" -type f -o -type l)

    # Step 2: Copy matching runtime files from sysroot_prefix/lib*
    for libdir in "${sysroot_prefix}"/lib*; do
        [ -d "${libdir}" ] || continue
        [ "$(basename "${libdir}")" = "libexec" ] && continue

        if [ "$(basename "${libdir}")" = "lib" ]; then
            [ -d "${libdir}/gcc" ] && continue
            [ -d "${libdir}/bfd-plugins" ] && continue
        fi

        mapfile -t all_named_files < <(find "${libdir}" -maxdepth 1)

        local runtime_files=()
        for f in "${all_named_files[@]}"; do
            fname="$(basename "$f")"
            if [[ -n "${gcc_so_whitelist[$fname]}" ]]; then
                runtime_files+=("$f")
            fi
        done

        if [ "${#runtime_files[@]}" -gt 0 ]; then
            local target_dir="${sysroot_prefix}/runtimes/$(basename "${libdir}")"
            mkdir -p "${target_dir}" || {
                echo "Error: Failed to create ${target_dir}"
                exit 1
            }
            cp -a "${runtime_files[@]}" "${target_dir}/" || {
                echo "Error: Failed to copy files from ${libdir} to ${target_dir}"
                exit 1
            }
        fi
    done

    # Step 3: Create lib → libXX symlink in runtimes if lib is missing
    if [ ! -d "${sysroot_prefix}/runtimes/lib" ]; then
        mkdir -p "${sysroot_prefix}/runtimes"
        cd "${sysroot_prefix}/runtimes"
        local best=""
        local max=-1
        for d in lib[0-9]*; do
            [ -d "$d" ] || continue
            local suffix="${d#lib}"
            if [[ "$suffix" =~ ^[0-9]+$ ]]; then
                if (( suffix > max )); then
                    max=$suffix
                    best="$d"
                fi
            fi
        done

        if [ -n "$best" ]; then
            ln -s "$best" lib || {
                echo "Error: Failed to create symlink lib → $best"
                exit 1
            }
        fi
    fi

    # Step 4: Mark phase complete
    echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${duplicating_runtimes_phase_file}" || {
        echo "Error: Failed to write phase completion file"
        exit 1
    }
}

build_project_gnu_cookie() {
local project_name=$1
local host_triplet=$2
local target_triplet=$3
local cookie=${4:-0}
local prefix="$TOOLCHAINSPATH_GNU/$2/$3"
local build_prefix="$currentpathnohosttriplet/$2/$3"
local configure_phase_file=".${project_name}_phase_configure"
local build_phase_file=".${project_name}_phase_build"
local build_all_gcc_phase_file=".${project_name}_all_gcc_phase_build"
local build_target_libgcc_phase_file=".${project_name}_build_target_libgcc_phase_build"
local install_gcc_phase_file=".${project_name}_install_gcc_phase_build"
local install_target_libgcc_phase_file=".${project_name}_install_target_libgcc_phase_build"
local generate_gcc_limits_phase_file=".${project_name}_generate_gcc_limits"
local install_phase_file=".${project_name}_phase_install"
local strip_phase_file=".${project_name}_phase_strip"
local current_phase_file=".${project_name}_phase_done"
local configure_project_name="$project_name"
local configures="--build=$BUILD_TRIPLET --host=$host_triplet --target=$target_triplet"

local multilibsettings="yes"

local is_native_or_canadian_native="no"
local is_native_cross="no"
local is_canadian_cross="no"
local libc_install_prefix="${TOOLCHAINSPATH_GNU}/${host_triplet}/${target_triplet}"
if [[ "$host_triplet" == "$target_triplet" ]]; then
    is_native_or_canadian_native="yes"
else
    libc_install_prefix="${libc_install_prefix}/${target_triplet}"
    if [[ "$BUILD_TRIPLET" == "$host_triplet" ]] then
        is_native_cross="yes"
    else
        is_canadian_cross="yes"
    fi
fi

local is_freestanding_build="no"
local is_two_phase_build="no"
local is_freestanding_or_two_phase_build="no"
local is_between_build="no"

if [[ "x$project_name" == "xgcc" ]]; then

local target_cpu
local target_vendor
local target_os
local target_abi
parse_triplet $target_triplet target_cpu target_vendor target_os target_abi


if [[ $cookie -eq 0 ]];then

if [[ $target_os == "linux" && ( $target_abi == "gnu" || $target_abi == "musl" ) ]]; then
if [[ "x${is_native_cross}" == "xyes" ]]; then
    is_two_phase_build="yes"
fi
is_freestanding_or_two_phase_build="$is_two_phase_build"
elif [[ $target_os == mingw* ]]; then
if [[ "x${is_native_cross}" == "xyes" ]]; then
    is_between_build="yes"
fi
elif [[ $target_os == "elf" ]]; then
    is_freestanding_build="yes"
    is_freestanding_or_two_phase_build="${is_freestanding_build}"
else
install_libc "${TOOLCHAINS_BUILD_SHARED_STORAGE}" $host_triplet $target_triplet "${build_prefix}/libc" "${build_prefix}/install/libc" "${libc_install_prefix}" "no" "no" "${multilibsettings}" "${is_native_cross}" "yes"
fi

fi

local is_duplicating_runtime="yes"
if [[ "$target_os" =~ ^mingw ]] || [[ "$target_os" == "elf" ]] || [[ "$target_os" == "msdosdjgpp" ]]; then
    is_duplicating_runtime="no"
fi

if [[ $is_freestanding_or_two_phase_build == "yes" ]];then
configures="$configures --disable-libstdcxx-verbose --enable-languages=c,c++ --disable-sjlj-exceptions --with-libstdcxx-eh-pool-obj-count=0 --disable-hosted-libstdcxx --without-headers --disable-threads --disable-shared --disable-libssp --disable-libquadmath --disable-libatomic --disable-libsanitizer"
if [[ $is_two_phase_build == "yes" ]]; then
configure_project_name="${configure_project_name}_phase1"
fi
else
configures="$configures --disable-libstdcxx-verbose --enable-languages=c,c++ --disable-sjlj-exceptions --with-libstdcxx-eh-pool-obj-count=0"
fi

if [[ "$target_triplet" == *-linux-gnu ]]; then
# We disable mulitlib for *-linux-gnu since it is a total mess
configures="$configures --disable-multilib"
multilibsettings="no"
elif [[ "x$target_os" == "xmsdosdjgpp" ]]; then
configures="$configures --disable-threads --disable-libquadmath"
else
configures="$configures --enable-multilib"
fi

elif [[ "x$project_name" == "xbinutils-gdb" ]]; then
configures="$configures --disable-tui --without-debuginfod"
fi

local is_to_build_install_libc="no"

if [[ "x$project_name" == "xgcc" && "${is_freestanding_build}" != "yes" ]]; then
is_to_build_install_libc="yes"
fi

local build_prefix_project="$build_prefix/$configure_project_name"

local configure_env_vars=(
  STRIP=llvm-strip
  ac_cv_path_STRIP_FOR_TARGET=llvm-strip
)

if [[ "$BUILD_TRIPLET" == "$target_triplet" && "$BUILD_TRIPLET" != "$host_triplet" ]]; then
# Fix up the bug related to crossback since GCC would try to use cc instead of gcc which does not exist
  configure_env_vars+=(CC_FOR_TARGET="${target_triplet}-gcc")
fi

if [ -f "${build_prefix_project}/${current_phase_file}" ]; then
    if [[ "${is_two_phase_build}" == "yes" ]]; then
        build_project_gnu_cookie $1 $2 $3 1
    fi
    return
fi

mkdir -p "$build_prefix_project"

if [ ! -f "${build_prefix_project}/${configure_phase_file}" ]; then
    cd "$build_prefix_project"
    env "${configure_env_vars[@]}" "$TOOLCHAINS_BUILD"/${project_name}/configure --disable-nls --disable-werror --disable-bootstrap --prefix="$prefix" $configures
    if [ $? -ne 0 ]; then
        echo "$configure_project_name: configure failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
        exit 1
    fi
    echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${configure_phase_file}"
fi

if [[ "x$project_name" == "xgcc" ]]; then
    if [ ! -f "${build_prefix_project}/${build_all_gcc_phase_file}" ]; then
        cd "$build_prefix_project"
        make all-gcc -j "${JOBS}"
        if [ $? -ne 0 ]; then
            echo "$configure_project_name: make all-gcc failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
            exit 1
        fi
        echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${build_all_gcc_phase_file}"
    fi
fi
if [[ "x$project_name" == "xgcc" && "x$is_freestanding_or_two_phase_build" == "xyes" ]]; then
    cd "$build_prefix_project"
#        freestanding should not deal with this?
#        if [ ! -f "${build_prefix_project}/${generate_gcc_limits_phase_file}" ]; then
#            cat "$TOOLCHAINS_BUILD/gcc/gcc/limitx.h" "$TOOLCHAINS_BUILD/gcc/gcc/glimits.h" "$TOOLCHAINS_BUILD/gcc/gcc/limity.h" > "${build_prefix_project}/gcc/include/limits.h"
#            echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${generate_gcc_limits_phase_file}"
#        fi
    if [ ! -f "${build_prefix_project}/${build_target_libgcc_phase_file}" ]; then
        make all-target-libgcc -j "${JOBS}"
        if [ $? -ne 0 ]; then
            echo "$configure_project_name: make all-target-libgcc failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
            exit 1
        fi
        echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${build_target_libgcc_phase_file}"
    fi
    if [ ! -f "${build_prefix_project}/${install_gcc_phase_file}" ]; then
        cd "$build_prefix_project"
        make install-strip-gcc
        if [ $? -ne 0 ]; then
            echo "$configure_project_name: make install-gcc failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
            exit 1
        fi
        echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${install_gcc_phase_file}"
    fi
    if [ ! -f "${build_prefix_project}/${install_target_libgcc_phase_file}" ]; then
        make install-strip-target-libgcc
        if [ $? -ne 0 ]; then
            echo "$configure_project_name: make install-target-libgcc failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
            exit 1
        fi
    fi
    if [[ "${is_to_build_install_libc}" == "yes" && "x$is_native_cross" == "xyes" ]]; then
        install_libc "${TOOLCHAINS_BUILD_SHARED_STORAGE}" $host_triplet $target_triplet "${build_prefix}/libc" "${build_prefix}/install/libc" "${libc_install_prefix}" "no" "no" "${multilibsettings}" "${is_native_cross}" "yes"
    fi
    cd "$build_prefix_project"
    if [[ "${is_two_phase_build}" == "yes" ]]; then
        echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${current_phase_file}"
        build_project_gnu_cookie $1 $2 $3 1
        return
    fi
else
    if [[ "x$project_name" == "xgcc" ]]; then
        if [[ "x$is_between_build" == "xyes" ]]; then
            cd "$build_prefix_project"
            if [ ! -f "${build_prefix_project}/${install_gcc_phase_file}" ]; then
                cd "$build_prefix_project"
                make install-strip-gcc
                if [ $? -ne 0 ]; then
                    echo "$configure_project_name: make install-gcc failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
                    exit 1
                fi
                echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${install_gcc_phase_file}"
            fi
            if [[ "${is_to_build_install_libc}" == "yes" && "x$is_native_cross" == "xyes" ]]; then
                install_libc "${TOOLCHAINS_BUILD_SHARED_STORAGE}" $host_triplet $target_triplet "${build_prefix}/libc" "${build_prefix}/install/libc" "${libc_install_prefix}" "no" "no" "${multilibsettings}" "${is_native_cross}" "yes"
            fi
        fi
        if [ ! -f "${build_prefix_project}/${generate_gcc_limits_phase_file}" ]; then
            cat "$TOOLCHAINS_BUILD/gcc/gcc/limitx.h" "$TOOLCHAINS_BUILD/gcc/gcc/glimits.h" "$TOOLCHAINS_BUILD/gcc/gcc/limity.h" > "${build_prefix_project}/gcc/include/limits.h"
            echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${generate_gcc_limits_phase_file}"
        fi
    fi
fi

if [ ! -f "${build_prefix_project}/${build_phase_file}" ]; then
    cd "$build_prefix_project"
    make -j "${JOBS}"
    if [ $? -ne 0 ]; then
        echo "$configure_project_name: make failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
        exit 1
    fi
    echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${build_phase_file}"
fi

if [ ! -f "${build_prefix_project}/${install_phase_file}" ]; then
    cd "$build_prefix_project"
    make install
    if [ $? -ne 0 ]; then
        echo "$configure_project_name: make install failed build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
        exit 1
    fi
    cd "$build_prefix_project"
    if [[ "x$project_name" == "xbinutils-gdb" ]]; then
        STRIP_TRANSFORM_NAME=${host_triplet}-strip make install-strip
    else
        make install-strip
    fi
    if [ $? -ne 0 ]; then
        echo "$configure_project_name: make install-strip failed {build:$BUILD_TRIPLET, host:$host_triplet, target:$target_triplet}"
    fi
    echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${install_phase_file}"
fi

if [[ "x${project_name}" == "xgcc" ]]; then
    if [[ "x${is_to_build_install_libc}" == "xyes" ]]; then
        if [[ "x${is_native_cross}" != "xyes" ]]; then
            install_libc "${TOOLCHAINS_BUILD_SHARED_STORAGE}" $host_triplet $target_triplet "${build_prefix}/libc" "${build_prefix}/install/libc" "${libc_install_prefix}" "no" "no" "${multilibsettings}" "${is_native_cross}" "yes"
        fi
        if [[ "x${is_duplicating_runtime}" == "xyes" ]]; then
            duplicating_runtimes "${project_name}" "${build_prefix_project}" "${target_triplet}" "${libc_install_prefix}"
        fi
    fi
fi
echo "$(date --iso-8601=seconds)" > "${build_prefix_project}/${current_phase_file}"

}

packaging_toolchain() {
    local host_triplet=$1
    local target_triplet=$2
    local prefix_parent="${TOOLCHAINSPATH_GNU}/${host_triplet}"
    local prefix="${prefix_parent}/${target_triplet}"
    local build_prefix="${currentpathnohosttriplet}/${host_triplet}/${target_triplet}"
    if [ ! -f "$build_prefix/.packagesuccess" ]; then
        rm -f "${prefix}.tar.xz"
        cd "$prefix_parent"
        XZ_OPT=-e9T0 tar cJf ${target_triplet}.${host_triplet}.tar.xz ${target_triplet}
        chmod 755 ${target_triplet}.${host_triplet}.tar.xz
        mkdir -p "${build_prefix}"
        echo "$(date --iso-8601=seconds)" > "$build_prefix/.packagesuccess"
    fi
}

build_toolchain() {
    build_project_gnu_cookie "binutils-gdb" $1 $2
    build_project_gnu_cookie "gcc" $1 $2
    packaging_toolchain $1 $2
}


if [[ ${BUILD_GCC_TRIPLET} != ${HOST_GCC_TRIPLET} ]]; then
# canadian
    build_toolchain $BUILD_GCC_TRIPLET $HOST_GCC_TRIPLET
    if [[ ${BUILD_GCC_TRIPLET} != ${TARGET_GCC_TRIPLET} && ${HOST_GCC_TRIPLET} != ${TARGET_GCC_TRIPLET} ]]; then
# canadian cross (non crossback)
        build_toolchain $BUILD_GCC_TRIPLET $TARGET_GCC_TRIPLET
    fi
fi

build_toolchain $HOST_GCC_TRIPLET $TARGET_GCC_TRIPLET
