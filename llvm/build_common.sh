#!/bin/bash

if [ -z ${TRIPLET+x} ]; then
echo "TRIPLET is not set. Please set the TRIPLET environment variable to the target triplet."
exit 1
fi
currentpath="$(realpath .)/.artifacts/llvm/${TRIPLET}"
if [[ "x${GENERATE_CMAKE_ONLY}" == "xyes" ]]; then
SKIP_DEPENDENCY_CHECK=yes
fi
mkdir -p "$currentpath"
cd ../common
source ./common.sh

if [[ "x$CLONE_IN_CHINA" == "xyes" ]]; then
echo "Clone in China enabled. We are going to use Chinese mirror first"
fi

cd "$currentpath"
# Parse the target triplet

parse_triplet $TRIPLET CPU VENDOR OS ABI

if [[ "$OS" == mingw* ]]; then
TRIPLET=$CPU-windows-gnu
unset VENDOR
OS=windows
ABI=gnu
fi

if [ $? -ne 0 ]; then
echo "Failed to parse the target triplet: $TRIPLET"
exit 1
fi
ABI_NO_VERSION="${ABI//[0-9]/}"
ABI_VERSION=${ABI//[!0-9]/}

echo "TRIPLET: $TRIPLET"
echo "CPU: $CPU"
echo "VENDOR: $VENDOR"
echo "OS: $OS"
echo "ABI: $ABI"
echo "ABI_NO_VERSION: $ABI_NO_VERSION"

# Parse the host triplet


if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -z ${TOOLCHAINS_LLVMPATH+x} ]; then
    TOOLCHAINS_LLVMPATH="$TOOLCHAINSPATH/llvm"
fi

if [ -z ${TOOLCHAINS_LLVMTRIPLETPATH+x} ]; then
    TOOLCHAINS_LLVMTRIPLETPATH="$TOOLCHAINS_LLVMPATH/${TRIPLET}"
fi

if [ -z ${NO_TOOLCHAIN_DELETION+x} ]; then
check_clang_location
if [ $? -eq 0 ]; then
NO_TOOLCHAIN_DELETION=yes
fi
fi

SYSROOTPATH="$TOOLCHAINS_LLVMTRIPLETPATH/${TRIPLET}"
SYSROOTPATHUSR="${SYSROOTPATH}/usr"
if [[ $OS == "darwin"* ]]; then
    RUNTIMES_USE_RPATH=1
else
    RUNTIMES_USE_RPATH=0
fi

CURRENTTRIPLEPATH_RUNTIMES="${currentpath}/runtimes"

TOOLCHAINS_LLVMTRIPLETPATH_LLVM="${TOOLCHAINS_LLVMTRIPLETPATH}/llvm"
TOOLCHAINS_LLVMTRIPLETPATH_RUNTIMES="${TOOLCHAINS_LLVMTRIPLETPATH}/runtimes"

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "${currentpath}"
    if [[ "x$NO_TOOLCHAIN_DELETION" == "xyes" ]]; then
        find "${TOOLCHAINS_LLVMTRIPLETPATH}" -mindepth 1 -maxdepth 1 -type d ! -name "llvm" ! -name "runtimes" -exec rm -rf {} +
    else
        rm -rf "${TOOLCHAINS_LLVMTRIPLETPATH}"
    fi
	echo "restart done"
fi

# Determine the number of CPU threads to use for the Ninja build

# Get the total number of logical CPU cores on the system
TOTAL_CORES=$(nproc)

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

LLVMPROJECTPATH=$TOOLCHAINS_BUILD/llvm-project

mkdir -p "${currentpath}"
cd "${currentpath}"
mkdir -p $TOOLCHAINSPATH
mkdir -p $TOOLCHAINS_LLVMPATH
mkdir -p $TOOLCHAINS_LLVMTRIPLETPATH

capitalize() {
    echo "$1" | sed 's/.*/\L&/; s/[a-z]*/\u&/g'
}

if [ -z ${SYSTEMNAME+x} ]; then
    SYSTEMNAME=$(capitalize "${OS}")
    if [[ "$SYSTEMNAME" =~ ([a-zA-Z]+)([0-9]*) ]]; then
        SYSTEMNAME=$(capitalize "${BASH_REMATCH[1]}")
        if [ -n "${BASH_REMATCH[2]}" ]; then
            if [ -z ${SYSTEMVERSION+x} ]; then
                SYSTEMVERSION=${BASH_REMATCH[2]}
            fi
        fi
    fi
fi

LIBC_HEADERS_PHASE=0
LIBC_PHASE=1
BUILTINS_PHASE=1
RUNTIMES_PHASE=1
COMPILER_RT_PHASE=1
ZLIB_PHASE=1
LIBXML2_PHASE=1
CPPWINRT_PHASE=0
LLVM_PHASE=1
COPY_COMPILER_RT_WITH_SPECIAL_NAME=0
USE_EMULATED_TLS=0
USE_RUNTIMES_RPATH=0
USE_LLVM_LIBS=1
BUILD_LIBC_WITH_LLVM="yes"
USE_LLVM_LINK_DYLIB=0

if [[ "$OS" == "darwin"* ]]; then
    echo "Operating System: macOS (Darwin)"
    BUILTINS_PHASE=0
    COMPILER_RT_PHASE=2
    ZLIB_PHASE=0
    LIBXML2_PHASE=0
    macosxs_SDK_VERSION=15.2
    if [[ -z "${BUILD_CURRENT_OSX_VERSION+x}" ]]; then
        BUILD_CURRENT_OSX_VERSION=10.5
    fi
    USE_RUNTIMES_RPATH=1
    RUNTIMES_PHASE=2
    if [[ "$CPU" == "aarch64" ]]; then
        DARWINARCHITECTURES="arm64;x86_64"
    else
        DARWINARCHITECTURES="$CPU"
    fi
else
    echo "Operating System: $OS with ABI: $ABI"
    if [[ "$OS" == "windows" ]]; then
        CPPWINRT_PHASE=1
        SYSROOTPATHUSR="$SYSROOTPATH"
        if [[ "$ABI" == "msvc" ]]; then
            BUILTINS_PHASE=0
            COMPILER_RT_PHASE=0
            RUNTIMES_PHASE=0
            USE_LLVM_LIBS=0
            CPPWINRT_PHASE=0
        fi
    elif [[ "$OS" == "linux" ]]; then
        if [[ "$ABI" == "android"* ]]; then
            COPY_COMPILER_RT_WITH_SPECIAL_NAME=1
        elif [[ "$ABI" == "musl" ]]; then
            LIBC_HEADERS_PHASE=1
            COMPILER_RT_PHASE=0
            BUILTINS_PHASE=2
        elif [[ "$ABI" == "gnu" ]]; then
            if [[ "x$BUILD_GLIBC_WITH_LLVM"  == "xyes" ]]; then
                LIBC_HEADERS_PHASE=1
                COMPILER_RT_PHASE=0
                BUILTINS_PHASE=2
            else
                BUILD_LIBC_WITH_LLVM="no"
            fi
        fi
#       clang should understand it is emulated-tls based on triplet
#        if [[ -n ${ABI_VERSION} && ${ABI_VERSION} -lt 29 ]]; then
#            USE_EMULATED_TLS=1
#        fi
    fi
fi

if [[ -z "$ABI" ]]; then
    TRIPLET_WITH_UNKNOWN="$CPU-unknown-$OS"
else
    TRIPLET_WITH_UNKNOWN="$CPU-unknown-$OS-$ABI"
fi

#rm $currentpath/common_cmake.cmake
if [ ! -f "$currentpath/common_cmake.cmake" ]; then

cat << EOF > $currentpath/common_cmake.cmake
set(CMAKE_BUILD_TYPE "Release")
set(CMAKE_C_COMPILER clang)
set(CMAKE_ASM_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_SYSROOT "${SYSROOTPATH}")
set(CMAKE_C_COMPILER_TARGET "${TRIPLET}")
set(CMAKE_CXX_COMPILER_TARGET "\${CMAKE_C_COMPILER_TARGET}")
set(CMAKE_ASM_COMPILER_TARGET "\${CMAKE_C_COMPILER_TARGET}")
set(CMAKE_SYSTEM_NAME "${SYSTEMNAME}")
set(CMAKE_SYSTEM_PROCESSOR "${CPU}")
set(CMAKE_CROSSCOMPILING On)
set(CMAKE_FIND_ROOT_PATH "${SYSROOTPATHUSR}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM "NEVER")
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY "ONLY")
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE "ONLY")

find_program(CMAKE_LIPO llvm-lipo)
if (NOT CMAKE_LIPO)
    message(FATAL_ERROR "llvm-lipo not found")
endif()

find_program(CMAKE_STRIP llvm-strip)
if (NOT CMAKE_STRIP)
    message(FATAL_ERROR "llvm-strip not found")
endif()

find_program(CMAKE_NM llvm-nm)
if (NOT CMAKE_NM)
    message(FATAL_ERROR "llvm-nm not found")
endif()

find_program(CMAKE_AR llvm-ar)
if (NOT CMAKE_AR)
    message(FATAL_ERROR "llvm-ar not found")
endif()

find_program(CMAKE_RANLIB llvm-ranlib)
if (NOT CMAKE_RANLIB)
    message(FATAL_ERROR "llvm-ranlib not found")
endif()

find_program(CMAKE_INSTALL_NAME_TOOL llvm-install-name-tool)
if (NOT CMAKE_INSTALL_NAME_TOOL)
    message(FATAL_ERROR "llvm-install-name-tool not found")
endif()

find_program(CMAKE_RC_COMPILER llvm-windres)
if (NOT CMAKE_RC_COMPILER)
    message(CMAKE_RC_COMPILER "llvm-windres not found")
endif()
set(CMAKE_RC_FLAGS "--target=\${CMAKE_C_COMPILER_TARGET} -I\${CMAKE_FIND_ROOT_PATH}/include")

set(CMAKE_POSITION_INDEPENDENT_CODE On)
set(LLVM_ENABLE_LTO thin)
set(LLVM_ENABLE_LLD On)
set(CMAKE_LINKER_TYPE LLD)
set(CMAKE_C_FLAGS_INIT "-fuse-ld=lld -fuse-lipo=llvm-lipo -flto=thin -Wno-unused-command-line-argument")
set(CMAKE_CXX_FLAGS_INIT "\${CMAKE_C_FLAGS_INIT}")
set(CMAKE_ASM_FLAGS_INIT "\${CMAKE_C_FLAGS_INIT}")
EOF

if [[ USE_LLVM_LIBS -ne 0 ]]; then
cat << EOF >> $currentpath/common_cmake.cmake
set(CMAKE_C_FLAGS_INIT "\${CMAKE_C_FLAGS_INIT} -rtlib=compiler-rt")
set(CMAKE_CXX_FLAGS_INIT "\${CMAKE_C_FLAGS_INIT} -stdlib=libc++ --unwindlib=libunwind")
set(CMAKE_ASM_FLAGS_INIT "\${CMAKE_C_FLAGS_INIT}")
EOF
fi

if [[ $USE_EMULATED_TLS -eq 1 ]]; then
cat << EOF >> $currentpath/common_cmake.cmake
set(CMAKE_C_FLAGS_INIT "\${CMAKE_C_FLAGS_INIT} -femulated-tls")
set(CMAKE_CXX_FLAGS_INIT "\${CMAKE_CXX_FLAGS_INIT} -femulated-tls")
set(CMAKE_ASM_FLAGS_INIT "\${CMAKE_ASM_FLAGS_INIT} -femulated-tls")
EOF
fi

# Initialize CMAKE_SIZEOF_VOID_P with default value
CMAKE_SIZEOF_VOID_P=4

if [[ "$CPU" == "x86_64" ]]; then
CMAKE_SIZEOF_VOID_P=8
elif [[ "$CPU" == "i686" ]]; then
CMAKE_SIZEOF_VOID_P=4
else
# Extract number from CPU variable and calculate CMAKE_SIZEOF_VOID_P
CPU_NUM=$(echo "$CPU" | grep -o '[0-9]*')
if [ -n "$CPU_NUM" ]; then
    CMAKE_SIZEOF_VOID_P=$((CPU_NUM / 8))
fi
fi

cat << EOF >> "$currentpath/common_cmake.cmake"
set(CMAKE_SIZEOF_VOID_P ${CMAKE_SIZEOF_VOID_P})
EOF

if [[ x"${SYSTEMVERSION}" != "x" ]]; then
cat << EOF >> "$currentpath/common_cmake.cmake"
set(CMAKE_SYSTEM_VERSION ${SYSTEMVERSION})
EOF
fi

cat << EOF > "$currentpath/compiler-rt.cmake"
include("\${CMAKE_CURRENT_LIST_DIR}/common_cmake.cmake")
set(CMAKE_C_COMPILER_WORKS On)
set(CMAKE_CXX_COMPILER_WORKS On)
set(CMAKE_ASM_COMPILER_WORKS On)
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION On)
set(COMPILER_RT_USE_LIBCXX On)
set(COMPILER_RT_BUILD_BUILTINS On)
EOF

cat << EOF > "$currentpath/builtins.cmake"
include("\${CMAKE_CURRENT_LIST_DIR}/compiler-rt.cmake")
EOF

if [[ "$USE_COMPILER_RT_BAREMETAL_BUILD" -eq 1 ]]; then
cat << EOF >> "$currentpath/builtins.cmake"
set(COMPILER_RT_BAREMETAL_BUILD On)
EOF
fi
cat << EOF > "$currentpath/zlib.cmake"
include("\${CMAKE_CURRENT_LIST_DIR}/common_cmake.cmake")

set(ZLIB_BUILD_TESTING Off)
EOF

cat << EOF > "$currentpath/libxml2.cmake"
include("\${CMAKE_CURRENT_LIST_DIR}/common_cmake.cmake")
set(LIBXML2_WITH_ICONV Off)
set(LIBXML2_WITH_PYTHON Off)
set(BUILD_SHARED_LIBS Off)
set(BUILD_STATIC_LIBS On)
set(LIBXML2_WITH_TESTS OFF)
set(LIBXML2_WITH_CATALOG OFF)
set(LIBXML2_WITH_PROGRAMS Off)
EOF

cat << EOF > "$currentpath/cppwinrt.cmake"
include("\${CMAKE_CURRENT_LIST_DIR}/common_cmake.cmake")
EOF

cat << EOF > "$currentpath/runtimes.cmake"
include("\${CMAKE_CURRENT_LIST_DIR}/common_cmake.cmake")

set(CMAKE_C_COMPILER_WORKS On)
set(CMAKE_CXX_COMPILER_WORKS On)
set(CMAKE_ASM_COMPILER_WORKS On)
set(LIBCXXABI_SILENT_TERMINATE "On")
set(LIBCXX_CXX_ABI "libcxxabi")
set(LIBCXX_ENABLE_SHARED "On")
set(LIBCXX_ABI_VERSION "1")
set(LIBCXX_CXX_ABI_INCLUDE_PATHS "${LLVMPROJECTPATH}/libcxxabi/include")
set(LIBCXX_ENABLE_EXCEPTIONS On)
set(LIBCXXABI_ENABLE_EXCEPTIONS On)
set(LIBCXX_ENABLE_RTTI On)
set(LIBCXXABI_ENABLE_RTTI On)
set(LLVM_ENABLE_ASSERTIONS "Off")
set(LLVM_INCLUDE_EXAMPLES "Off")
set(LLVM_ENABLE_BACKTRACES "Off")
set(LLVM_INCLUDE_TESTS "Off")
set(LIBCXX_INCLUDE_BENCHMARKS "Off")
set(LIBCXX_ENABLE_SHARED "On")
set(LIBCXXABI_ENABLE_SHARED "On")
set(LIBUNWIND_ENABLE_SHARED "On")
set(LIBUNWIND_ADDITIONAL_COMPILE_FLAGS "-fuse-ld=lld;-flto=thin;-rtlib=compiler-rt;-Wno-macro-redefined")
set(LIBCXX_ADDITIONAL_COMPILE_FLAGS "\${LIBUNWIND_ADDITIONAL_COMPILE_FLAGS};-nostdinc++;-Wno-user-defined-literals")
set(LIBCXXABI_ADDITIONAL_COMPILE_FLAGS "\${LIBCXX_ADDITIONAL_COMPILE_FLAGS};-lc++")
set(LIBCXX_ADDITIONAL_LIBRARIES "\${LIBCXX_ADDITIONAL_COMPILE_FLAGS};-L${CURRENTTRIPLEPATH_RUNTIMES}/lib;-lc++")
set(LIBCXXABI_ADDITIONAL_LIBRARIES "\${LIBCXX_ADDITIONAL_LIBRARIES}")
set(LIBUNWIND_ADDITIONAL_LIBRARIES "\${LIBCXX_ADDITIONAL_COMPILE_FLAGS}")
set(LIBCXX_USE_COMPILER_RT "On")
set(LIBCXXABI_USE_COMPILER_RT "On")
set(LIBCXX_USE_LLVM_UNWINDER "On")
set(LIBCXXABI_USE_LLVM_UNWINDER "On")
set(LIBUNWIND_USE_COMPILER_RT "On")
set(LLVM_HOST_TRIPLE $TRIPLET)
set(LLVM_DEFAULT_TARGET_TRIPLE \${LLVM_HOST_TRIPLE})
set(LLVM_ENABLE_LTO "Thin")
set(LLVM_ENABLE_LLD "On")
set(C_SUPPORTS_CUSTOM_LINKER On)
set(CXX_SUPPORTS_CUSTOM_LINKER On)
set(ASM_SUPPORTS_CUSTOM_LINKER On)
set(LLVM_ENABLE_RUNTIMES libcxx;libcxxabi;libunwind)
set(LIBCXX_ENABLE_THREADS On)
set(LIBCXXABI_ENABLE_THREADS On)
set(LIBUNWIND_ENABLE_THREADS On)
EOF

cat << EOF > "$currentpath/llvm.cmake"
include("\${CMAKE_CURRENT_LIST_DIR}/common_cmake.cmake")

set(LLVM_HOST_TRIPLE $TRIPLET)
set(LLVM_DEFAULT_TARGET_TRIPLE \${LLVM_HOST_TRIPLE})
set(LLVM_ENABLE_LTO "Thin")
set(LLVM_ENABLE_LLD "On")
set(C_SUPPORTS_CUSTOM_LINKER On)
set(CXX_SUPPORTS_CUSTOM_LINKER On)
set(ASM_SUPPORTS_CUSTOM_LINKER On)
set(LLVM_ENABLE_PROJECTS clang;clang-tools-extra;lld;lldb)
set(BUILD_SHARED_LIBS On)
set(LLVM_ENABLE_LIBCXX On)
set(LLVM_ENABLE_ZLIB FORCE_ON)
set(ZLIB_INCLUDE_DIR "\${CMAKE_FIND_ROOT_PATH}/include")

set(LLVM_ENABLE_LIBXML2 FORCE_ON)
if(EXISTS "\${CMAKE_FIND_ROOT_PATH}/include/libxml2")
set(LIBXML2_INCLUDE_DIR "\${CMAKE_FIND_ROOT_PATH}/include/libxml2")
else()
set(LIBXML2_INCLUDE_DIR "\${CMAKE_FIND_ROOT_PATH}/include")
endif()

if(EXISTS "\${CMAKE_FIND_ROOT_PATH}/lib/libz.dll.a")
set(ZLIB_LIBRARY "\${CMAKE_FIND_ROOT_PATH}/lib/libz.dll.a")
elseif(EXISTS "\${CMAKE_FIND_ROOT_PATH}/lib/libzlib.dll.a")
set(ZLIB_LIBRARY "\${CMAKE_FIND_ROOT_PATH}/lib/libzlib.dll.a")
elseif(EXISTS "\${CMAKE_FIND_ROOT_PATH}/lib/libzs.a")
set(ZLIB_LIBRARY "\${CMAKE_FIND_ROOT_PATH}/lib/libzs.a")
elseif(EXISTS "\${CMAKE_FIND_ROOT_PATH}/lib/libzlibstatic.a")
set(ZLIB_LIBRARY "\${CMAKE_FIND_ROOT_PATH}/lib/libzlibstatic.a")
elseif(EXISTS "\${CMAKE_FIND_ROOT_PATH}/lib/libz.a")
set(ZLIB_LIBRARY "\${CMAKE_FIND_ROOT_PATH}/lib/libz.a")
elseif(EXISTS "\${CMAKE_FIND_ROOT_PATH}/lib/libz.tbd")
set(ZLIB_LIBRARY "\${CMAKE_FIND_ROOT_PATH}/lib/libz.tbd")
else()
set(ZLIB_LIBRARY "\${CMAKE_FIND_ROOT_PATH}/lib/libz.so")
endif()

if(EXISTS "\${CMAKE_FIND_ROOT_PATH}/lib/libxml2.a")
set(LIBXML2_LIBRARY "\${CMAKE_FIND_ROOT_PATH}/lib/libxml2.a")
elseif(EXISTS "\${CMAKE_FIND_ROOT_PATH}/lib/libxml2.dll.a")
set(LIBXML2_LIBRARY "\${CMAKE_FIND_ROOT_PATH}/lib/libxml2.dll.a")
elseif(EXISTS "\${CMAKE_FIND_ROOT_PATH}/lib/libxml2.tbd")
set(LIBXML2_LIBRARY "\${CMAKE_FIND_ROOT_PATH}/lib/libxml2.tbd")
else()
set(LIBXML2_LIBRARY "\${CMAKE_FIND_ROOT_PATH}/lib/libxml2.so")
endif()
set(HAVE_LIBXML2 On)
EOF


if [[ USE_LLVM_LINK_DYLIB -eq 1 ]]; then
cat << EOF >> "$currentpath/llvm.cmake"
set(LLVM_BUILD_LLVM_DYLIB On)
set(LLVM_LINK_LLVM_DYLIB On)
unset(BUILD_SHARED_LIBS)
EOF
fi


if [[ "${ABI}" == "musl" ]]; then
cat << EOF >> $currentpath/runtimes.cmake
set(LIBCXX_HAS_MUSL_LIBC On)
set(LIBCXXABI_HAS_MUSL_LIBC On)
set(LIBUNWIND_HAS_MUSL_LIBC On)
EOF
fi

if [[ "${OS}" == "linux" ]]; then
    if [[ "${ABI}" == "android"* ]]; then
cat << EOF >> "$currentpath/builtins.cmake"
set(ANDROID On)
EOF
    fi
elif [[ "${OS}" == "windows" ]]; then
cat << EOF >> $currentpath/common_cmake.cmake
set(CMAKE_C_LINKER_DEPFILE_SUPPORTED FALSE)
set(CMAKE_CXX_LINKER_DEPFILE_SUPPORTED FALSE)
set(CMAKE_ASM_LINKER_DEPFILE_SUPPORTED FALSE)
EOF
if [[ "${ABI}" == "msvc" ]]; then
if [ -z ${WINDOWSMSVCSYSROOT+x} ]; then
	WINDOWSMSVCSYSROOT="$HOME/toolchains/windows-msvc-sysroot"
fi

cat << EOF >> $currentpath/common_cmake.cmake
set(CMAKE_C_COMPILER_WORKS On)
set(CMAKE_CXX_COMPILER_WORKS On)
set(CMAKE_ASM_COMPILER_WORKS On)
set(CMAKE_SYSROOT "$WINDOWSMSVCSYSROOT")
set(CMAKE_RC_FLAGS "\${CMAKE_RC_FLAGS} -I\${CMAKE_SYSROOT}/include")
EOF
cat << EOF >> "$currentpath/zlib.cmake"
set(ZLIB_BUILD_SHARED OFF)
EOF
cat << EOF >> "$currentpath/llvm.cmake"
unset(BUILD_SHARED_LIBS)
set(LLVM_ENABLE_LIBCXX Off)
EOF
else

cat << EOF >> "$currentpath/libxml2.cmake"
set(BUILD_SHARED_LIBS On)
EOF

cat << EOF >> "$currentpath/llvm.cmake"
set(CMAKE_CXX_FLAGS_INIT "\${CMAKE_CXX_FLAGS_INIT} -lc++abi")
EOF

cat << EOF >> "$currentpath/cppwinrt.cmake"
set(CMAKE_CXX_FLAGS_INIT "\${CMAKE_CXX_FLAGS_INIT} -lc++abi")
EOF

cat << EOF >> "$currentpath/compiler-rt.cmake"
set(CMAKE_CXX_FLAGS_INIT "\${CMAKE_CXX_FLAGS_INIT} -lc++abi")
EOF

cat << EOF >> $currentpath/runtimes.cmake
# Toolchain file for CMake

# Ensure we are setting the correct options for LIBCXXABI
set(LIBCXXABI_ENABLE_THREADS On)
set(LIBCXXABI_HAS_PTHREAD_API Off)
set(LIBCXXABI_HAS_WIN32_THREAD_API On)
set(LIBCXXABI_HAS_EXTERNAL_THREAD_API Off)

# Ensure we are setting the correct options for LIBCXX
set(LIBCXX_ENABLE_THREADS On)
set(LIBCXX_HAS_PTHREAD_API Off)
set(LIBCXX_HAS_WIN32_THREAD_API On)
set(LIBCXX_HAS_EXTERNAL_THREAD_API Off)

# Ensure we are setting the correct options for LIBUNWIND
set(LIBUNWIND_ENABLE_THREADS On)
set(LIBUNWIND_HAS_PTHREAD_API Off)
set(LIBUNWIND_HAS_WIN32_THREAD_API On)
set(LIBUNWIND_HAS_EXTERNAL_THREAD_API Off)

# Add any additional settings or compiler/linker options here
EOF

fi

elif [[ "${OS}" == "darwin"* ]]; then

cat << EOF >> $currentpath/common_cmake.cmake
set(CMAKE_OSX_ARCHITECTURES "${DARWINARCHITECTURES}")
set(MACOS_ARM_SUPPORT On)
# Find the path of llvm-libtool-darwin
find_program(CMAKE_LIBTOOL llvm-libtool-darwin)
if (NOT CMAKE_LIBTOOL)
    message(FATAL_ERROR "llvm-libtool-darwin not found")
endif()

# Set CMAKE_AR and CMAKE_RANLIB to use CMAKE_LIBTOOL with -static
set(CMAKE_AR "${CMAKE_LIBTOOL};-static")
set(CMAKE_RANLIB "${CMAKE_LIBTOOL};-static")
EOF


cat << EOF >> "$currentpath/compiler-rt.cmake"
set(COMPILER_RT_HAS_G_FLAG On)
set(DARWIN_osx_BUILTIN_ARCHS "\${CMAKE_OSX_ARCHITECTURES}")
set(OSX_SYSROOT "\${CMAKE_SYSROOT}")
set(DARWIN_macosx_CACHED_SYSROOT "\${CMAKE_SYSROOT}")
set(DARWIN_macosx_OVERRIDE_SDK_VERSION ${macosxs_SDK_VERSION})
set(COMPILER_RT_BUILD_SANITIZERS On)
EOF

cat << EOF >> $currentpath/runtimes.cmake
set(LIBCXX_CXX_ABI "system-libcxxabi")
set(LLVM_EXTERNALIZE_DEBUGINFO On)
set(COMPILER_RT_HAS_G_FLAG On)
EOF

cat << EOF >> $currentpath/llvm.cmake
set(LLDB_INCLUDE_TESTS Off)
set(LLDB_USE_SYSTEM_DEBUGSERVER On)
set(CMAKE_CURRENT_OSX_VERSION ${BUILD_CURRENT_OSX_VERSION})
EOF

fi


if [[ "${OS}" != "darwin"* ]]; then
cat << EOF >> $currentpath/llvm.cmake
set(CMAKE_CXX_FLAGS_INIT "\${CMAKE_CXX_FLAGS_INIT} -lc++abi")
EOF

cat << EOF >> $currentpath/compiler-rt.cmake
set(LLVM_INCLUDE_EXAMPLES "Off")
set(LLVM_ENABLE_BACKTRACES "Off")
set(LLVM_INCLUDE_TESTS "Off")
set(COMPILER_RT_USE_LIBCXX "Off")
set(COMPILER_RT_USE_BUILTINS_LIBRARY "On")
set(COMPILER_RT_DEFAULT_TARGET_ONLY "ON")
#set(COMPILER_RT_DEFAULT_TARGET_TRIPLE "$CMAKE_C_COMPILER_TARGET")
EOF
fi

fi

if [[ "x${GENERATE_CMAKE_ONLY}" == "xyes" ]]; then
exit 0
fi

# Define the function to build and install
build_project() {
    local project_name=$1
    local source_path=$2
    local toolchain_file=$3
    local build_prefix=$4
    local copy_to_sysroot_usr=$5
    local current_phase_file=".${project_name}_phase_done"
    local delete_previous_phase_file=".${project_name}_phase_delete_previous"
    local configure_phase_file=".${project_name}_phase_configure"
    local build_phase_file=".${project_name}_phase_build"
    local install_phase_file=".${project_name}_phase_install"
    local copy_phase_file=".${project_name}_phase_copy"
    local rt_rename_phase_file=".${project_name}_phase_rt_rename_phase_file"
    local need_move_tmp
    local project_name_alternative="${project_name}"
    if [[ "$project_name" == "runtimes" ]]; then
        if [[ $USE_RUNTIMES_RPATH -eq 1 ]]; then
            project_name_alternative="${project_name_alternative}_rpath"
        fi
    fi
    local install_prefix="${TOOLCHAINS_LLVMTRIPLETPATH}/${project_name_alternative}"
    if [[ "$project_name" == "runtimes" || "$projects" == "llvm" ]]; then
        if [[ "x$NO_TOOLCHAIN_DELETION" == "xyes" ]]; then
            install_prefix="${install_prefix}_tmp"
            need_move_tmp=yes
        fi
    fi
    if [ ! -f "${build_prefix}/${current_phase_file}" ]; then
        mkdir -p "${build_prefix}"
        cd "${build_prefix}"

        if [[ "$project_name" == "runtimes" ]]; then
            if [ ! -f "${build_prefix}/${delete_previous_phase_file}" ]; then
                if [ -d "${SYSROOTPATHUSR}/include/c++/v1" ]; then
                    rm -rf "${SYSROOTPATHUSR}/include/c++/v1"
                fi
                echo "$(date --iso-8601=seconds)" > "${build_prefix}/${delete_previous_phase_file}"
            fi
        fi

        if [ ! -f "${build_prefix}/${configure_phase_file}" ]; then
            cd "${build_prefix}"
            # Run CMake to generate Ninja build files
            cmake -GNinja -DCMAKE_CROSSCOMPILING=On -DCMAKE_BUILD_TYPE=Release "${source_path}" \
                -DCMAKE_TOOLCHAIN_FILE="${toolchain_file}" \
                -DCMAKE_INSTALL_PREFIX="${install_prefix}"
            cmake -GNinja -DCMAKE_CROSSCOMPILING=On -DCMAKE_BUILD_TYPE=Release "${source_path}" \
                -DCMAKE_TOOLCHAIN_FILE="${toolchain_file}" \
                -DCMAKE_INSTALL_PREFIX="${install_prefix}"
            if [ $? -ne 0 ]; then
                echo "${project_name}: CMake configuration failed for $TRIPLET"
                exit 1
            fi
            echo "$(date --iso-8601=seconds)" > "${configure_phase_file}"
        fi

        if [ ! -f "${build_prefix}/${build_phase_file}" ]; then
            cd "${build_prefix}"
            # Run Ninja to build the project
            if [[ "$project_name" == "runtimes" ]]; then
                ninja -C . cxx_static
                if [ $? -ne 0 ]; then
                    echo "${project_name}: Ninja build cxx_static failed for $TRIPLET"
                    exit 1
                fi
                touch "${toolchain_file}"
            fi
            if [[ -n "$JOBS" ]]; then
                ninja -j "$JOBS"
            else
                ninja
            fi
            if [ $? -ne 0 ]; then
                echo "${project_name}: Ninja build failed for $TRIPLET"
                exit 1
            fi
            echo "$(date --iso-8601=seconds)" > "${build_prefix}/${build_phase_file}"
        fi

        if [ ! -f "${build_prefix}/${install_phase_file}" ]; then
            cd "${build_prefix}"
            # Run Ninja to install and strip the build
            ninja install/strip
            if [ $? -ne 0 ]; then
                echo "${project_name}: Ninja install/strip failed for $TRIPLET"
                exit 1
            fi
            if [[ "$project_name" == "runtimes" ]]; then
                if [[ "$OS" == "linux" && "$ABI" == "android"* ]]; then
                    cd "${install_prefix}/lib"
                    rm libc++.so
                    ln -s libc++.so.1 libc++.so
                fi
            fi
            echo "$(date --iso-8601=seconds)" > "${build_prefix}/${install_phase_file}"
        fi
        if [[ "$project_name" == "compiler-rt" || "$project_name" == "builtins" ]]; then
            if [[ ${COPY_COMPILER_RT_WITH_SPECIAL_NAME} -eq 1 ]]; then
                if [ -d "${install_prefix}/lib" ]; then
                    if [ ! -f "${build_prefix}/${rt_rename_phase_file}" ]; then
                        cd "${install_prefix}/lib"
                        mv "$OS" "${TRIPLET_WITH_UNKNOWN}"
                        cd "${TRIPLET_WITH_UNKNOWN}"
                        for file in *-"${CPU}"*; do
                            new_name="${file//-${CPU}/}"
                            mv "$file" "$new_name"
                        done
                        # Iterate through files matching the pattern libclang_rt.*-${ABI_NO_VERSION}.a
                        for file in libclang_rt.*-"${ABI_NO_VERSION}".a; do
                            # Check if the file exists
                            if [ -e "$file" ]; then
                                # Construct the new file name by removing "-${ABI_NO_VERSION}" from the original file name
                                new_file="${file/-${ABI_NO_VERSION}/}"
                                # Copy the file to the new file name (preserve the original file)
                                cp "$file" "$new_file"
                            fi
                        done
                        if [[ "$project_name" == "compiler-rt" ]]; then
                            for file in *.so; do
                                filename="${file%.so}"
                                ln -s "$file" "${filename}-${CPU}-${ABI_NO_VERSION}.so"
                            done
                        fi
                        echo "$(date --iso-8601=seconds)" > "${build_prefix}/${rt_rename_phase_file}"
                    fi
                fi
            fi
            if [ ! -f "${build_prefix}/${copy_phase_file}" ]; then
                local clang_path=`which clang`
                local clang_directory=$(dirname "$clang_path")
                local clang_version=$(clang --version | grep -oP '\d+\.\d+\.\d+')
                local clang_major_version="${clang_version%%.*}"
                local llvm_install_directory="$clang_directory/.."
                local clangbuiltin="$llvm_install_directory/lib/clang/$clang_major_version"
                mkdir -p "${clangbuiltin}"
                cp -r --preserve=links "$install_prefix"/* "${clangbuiltin}/"
                echo "$(date --iso-8601=seconds)" > "${build_prefix}/${copy_phase_file}"
            fi
        fi
        if [[ "x$copy_to_sysroot_usr" == "xyes" ]]; then
            mkdir -p "${SYSROOTPATHUSR}"
            cp -r --preserve=links "$install_prefix"/* "${SYSROOTPATHUSR}"/
        fi
        if [[ "x${need_move_tmp}" == "xyes" ]]; then
            mkdir -p "${TOOLCHAINS_LLVMTRIPLETPATH}"
            if [[ -d "${TOOLCHAINS_LLVMTRIPLETPATH}/${project_name_alternative}_tmp" ]]; then
                rm -rf "${TOOLCHAINS_LLVMTRIPLETPATH}/${project_name_alternative}"
                cd "$TOOLCHAINS_LLVMTRIPLETPATH"
                mv "${project_name_alternative}_tmp" "${project_name_alternative}"
            fi
        fi
        echo "$(date --iso-8601=seconds)" > "${build_prefix}/${current_phase_file}"
    fi
}

# Function to build and install compiler-rt
build_compiler_rt() {
    build_project "compiler-rt" "$LLVMPROJECTPATH/compiler-rt" "$currentpath/compiler-rt.cmake" "${currentpath}/compiler-rt"
}

# Function to build and install builtins
build_builtins() {
    build_project "builtins" "$LLVMPROJECTPATH/compiler-rt/lib/builtins" "$currentpath/builtins.cmake" "${currentpath}/builtins"
}

build_runtimes() {
    local phase=$1
    local to_build_runtimes=0
    if [[ $phase -eq 0 ]]; then
        if [[ RUNTIMES_PHASE -eq 1 ]]; then
            to_build_runtimes=1
        fi
    elif [[ $phase -eq 1 ]]; then
        if [[ RUNTIMES_PHASE -eq 2 ]]; then
            to_build_runtimes=1
        fi
    fi
    if [[ $to_build_runtimes -eq 1 ]]; then
        build_project "runtimes" "$LLVMPROJECTPATH/runtimes" "$currentpath/runtimes.cmake" "${currentpath}/runtimes" "yes"
    fi
}

build_llvm() {
    if [[ LLVM_PHASE -ne 0 ]]; then
        build_project "llvm" "$LLVMPROJECTPATH/llvm" "$currentpath/llvm.cmake" "${currentpath}/llvm"
    fi
}

build_library() {
    local lib_name=$1
    local phase_var="${lib_name^^}_PHASE"
    local toolchain_file

    if [ -z "$2" ]; then
        toolchain_file="$currentpath/common_cmake.cmake"
    else
        toolchain_file="$2"
    fi

    if [[ ${!phase_var} -ne 0 ]]; then
        clone_or_update_dependency $lib_name
        build_project "$lib_name" "$TOOLCHAINS_BUILD/$lib_name" "$toolchain_file" "${currentpath}/$lib_name" "yes"
    fi
}

build_zlib() {
    build_library "zlib" "$currentpath/zlib.cmake"
}

build_libxml2() {
    build_library "libxml2" "$currentpath/libxml2.cmake"
}

build_cppwinrt() {
    build_library "cppwinrt" "$currentpath/cppwinrt.cmake"
}

# Function to build either compiler-rt or builtins based on phase values
build_compiler_rt_or_builtins() {
    local phase=$1
    if [[ $phase -eq 0 ]]; then
        if [[ $COMPILER_RT_PHASE -eq 3 ]]; then
            build_compiler_rt
        elif [[ $BUILTINS_PHASE -eq 2 ]]; then
            build_builtins
        fi
    elif [[ $phase -eq 1 ]]; then
        if [[ $COMPILER_RT_PHASE -eq 2 ]]; then
            build_compiler_rt
        elif [[ $BUILTINS_PHASE -eq 1 ]]; then
            build_builtins
        fi
    elif [[ $phase -eq 2 ]]; then
        if [[ $COMPILER_RT_PHASE -eq 1 ]]; then
            build_compiler_rt
        fi
    fi
}

clone_or_update_dependency llvm-project

if [[ LIBC_HEADERS_PHASE -ne 0 ]]; then
    install_libc $TRIPLET "${currentpath}/libc" "${TOOLCHAINS_LLVMTRIPLETPATH}" "${SYSROOTPATHUSR}" "${BUILD_LIBC_WITH_LLVM}" "yes"
fi

build_compiler_rt_or_builtins 0

if [[ LIBC_PHASE -ne 0 ]]; then
    install_libc $TRIPLET "${currentpath}/libc" "${TOOLCHAINS_LLVMTRIPLETPATH}" "${SYSROOTPATHUSR}" "${BUILD_LIBC_WITH_LLVM}" "no"
fi

build_compiler_rt_or_builtins 1

build_runtimes 0

build_compiler_rt_or_builtins 2

build_zlib

build_libxml2

build_cppwinrt

build_llvm

build_runtimes 1

if [ ! -f "$currentpath/.packagesuccess" ]; then
	rm -f "${TOOLCHAINS_LLVMTRIPLETPATH}.tar.xz"
	cd "$TOOLCHAINS_LLVMPATH"
	XZ_OPT=-e9T0 tar cJf ${TRIPLET}.tar.xz ${TRIPLET}
	chmod 755 ${TRIPLET}.tar.xz
	echo "$(date --iso-8601=seconds)" > "$currentpath/.packagesuccess"
fi
