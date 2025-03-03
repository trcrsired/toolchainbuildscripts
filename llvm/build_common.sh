#!/bin/bash

if [ -z ${TRIPLET+x} ]; then
echo "TRIPLET is not set. Please set the TRIPLET environment variable to the target triplet."
exit 1
fi
currentpath="$(realpath .)/.artifacts/llvm/${TRIPLET}"
mkdir -p "$currentpath"
cd ../common
source ./common.sh

cd "$currentpath"
# Parse the target triplet

parse_triplet $TRIPLET CPU VENDOR OS ABI

if [ $? -ne 0 ]; then
echo "Failed to parse the target triplet: $TRIPLET"
exit 1
fi

echo "TRIPLET: $TRIPLET"
echo "CPU: $CPU"
echo "VENDOR: $VENDOR"
echo "OS: $OS"
echo "ABI: $ABI"

# Parse the host triplet


if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi


TOOLCHAINS_LLVMPATH=$TOOLCHAINSPATH/llvm
TOOLCHAINS_LLVMTRIPLETPATH="$TOOLCHAINS_LLVMPATH/${TRIPLET}"

SYSROOTPATH="$TOOLCHAINS_LLVMTRIPLETPATH/${TRIPLET}"
SYSROOTPATHUSR="${SYSROOTPATH}/usr"
if [[ $OS == "darwin"* ]]; then
    RUNTIMES_USE_RPATH=1
else
    RUNTIMES_USE_RPATH=0
fi

if [[ RUNTIMES_USE_RPATH -eq 1 ]]; then
    CURRENTTRIPLEPATH_RUNTIMES="${currentpath}/runtimes_rpath"
else
    CURRENTTRIPLEPATH_RUNTIMES="${currentpath}/runtimes"
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "${currentpath}"
#	rm -rf "${TOOLCHAINS_LLVMTRIPLETPATH}"
	echo "restart done"
fi

LLVMPROJECTPATH=$TOOLCHAINS_BUILD/llvm-project

mkdir -p "${currentpath}"
cd "${currentpath}"
mkdir -p $TOOLCHAINSPATH
mkdir -p $TOOLCHAINS_LLVMPATH
mkdir -p $TOOLCHAINS_LLVMTRIPLETPATH
mkdir -p $TOOLCHAINS_BUILD

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

LIBC_PHASE=1
BUILTINS_PHASE=1
RUNTIMES_PHASE=1
COMPILER_RT_PHASE=1
ZLIB_PHASE=1
LIBXML2_PHASE=1
CPPWINRT_PHASE=0
LLVM_PHASE=1

if [[ "$OS" == "darwin"* ]]; then
    echo "Operating System: macOS (Darwin)"
    BUILTINS_PHASE=2
    COMPILER_RT_PHASE=0
    ZLIB_PHASE=0
    LIBXML2_PHASE=0
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
        fi
    fi
fi

if [[ -z "$ABI" ]]; then
    TRIPLET_WITH_UNKNOWN="$CPU-unknown-$OS"
else
    TRIPLET_WITH_UNKNOWN="$CPU-unknown-$OS-$ABI"
fi

if [ ! -f "$currentpath/common_cmake.cmake" ]; then

cat << EOF > $currentpath/common_cmake.cmake
set(CMAKE_BUILD_TYPE "Release")
set(CMAKE_C_COMPILER "$(which clang)")
set(CMAKE_CXX_COMPILER "$(which clang++)")
set(CMAKE_ASM_COMPILER "\${CMAKE_C_COMPILER}")
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
set(CMAKE_LIPO "$(which llvm-lipo)")
set(CMAKE_STRIP "$(which llvm-strip)")
set(CMAKE_NM "$(which llvm-nm)")
set(CMAKE_INSTALL_NAME_TOOL "$(which llvm-install-name-tool)")
set(CMAKE_POSITION_INDEPENDENT_CODE On)
EOF

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

cat << EOF >> $currentpath/common_cmake.cmake
set(CMAKE_SIZEOF_VOID_P ${CMAKE_SIZEOF_VOID_P})
EOF

if [[ x"${SYSTEMVERSION}" != "x" ]]; then
cat << EOF >> $currentpath/common_cmake.cmake
set(CMAKE_SYSTEM_VERSION ${SYSTEMVERSION})
EOF
fi

cat << EOF > $currentpath/compiler-rt.cmake
include("${currentpath}/common_cmake.cmake")
set(COMPILER_RT_DEFAULT_TARGET_ONLY On)
set(CMAKE_C_COMPILER_WORKS On)
set(CMAKE_CXX_COMPILER_WORKS On)
set(CMAKE_ASM_COMPILER_WORKS On)
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION On)
set(COMPILER_RT_USE_LIBCXX On)
EOF

cat << EOF > $currentpath/builtins.cmake
include("${currentpath}/compiler-rt.cmake")
set(COMPILER_RT_BAREMETAL_BUILD On)
set(COMPILER_RT_DEFAULT_TARGET_TRIPLE "${TRIPLET}")
EOF

cat << EOF > $currentpath/runtimes.cmake
include("${currentpath}/common_cmake.cmake")

set(LIBCXXABI_SILENT_TERMINATE "On")
set(LIBCXX_CXX_ABI "libcxxabi")
set(LIBCXX_ENABLE_SHARED "On")
set(LIBCXX_ABI_VERSION "1")
set(LIBCXX_CXX_ABI_INCLUDE_PATHS "${LLVMPROJECTPATH}/libcxxabi/include")
set(THREADS_FLAGS ${THREADS_FLAGS})
set(LIBCXX_ENABLE_EXCEPTIONS On)
set(LIBCXXABI_ENABLE_EXCEPTIONS On)
set(LIBCXX_ENABLE_RTTI On)
set(LIBCXXABI_ENABLE_RTTI $On)
set(LLVM_ENABLE_ASSERTIONS "Off")
set(LLVM_INCLUDE_EXAMPLES "Off")
set(LLVM_ENABLE_BACKTRACES "Off")
set(LLVM_INCLUDE_TESTS "Off")
set(LIBCXX_INCLUDE_BENCHMARKS "Off")
set(LIBCXX_ENABLE_SHARED "On")
set(LIBCXXABI_ENABLE_SHARED "On")
set(LIBUNWIND_ENABLE_SHARED "On")
set(LIBUNWIND_ADDITIONAL_COMPILE_FLAGS "-fuse-ld=lld;-flto=thin;-rtlib=compiler-rt;-Wno-macro-redefined")
set(LIBCXX_ADDITIONAL_COMPILE_FLAGS "\${LIBUNWIND_ADDITIONAL_COMPILE_FLAGS};-Wno-user-defined-literals")
set(LIBCXXABI_ADDITIONAL_COMPILE_FLAGS "\${LIBCXX_ADDITIONAL_COMPILE_FLAGS}")
set(LIBCXX_ADDITIONAL_LIBRARIES "\${LIBCXX_ADDITIONAL_COMPILE_FLAGS} -nostdinc++ -L${CURRENTTRIPLEPATH_RUNTIMES}/lib")
set(LIBCXXABI_ADDITIONAL_LIBRARIES "\${LIBCXX_ADDITIONAL_LIBRARIES}")
set(LIBUNWIND_ADDITIONAL_LIBRARIES "\${LIBCXX_ADDITIONAL_COMPILE_FLAGS}")
set(LIBCXX_USE_COMPILER_RT "On")
set(LIBCXXABI_USE_COMPILER_RT "On")
set(LIBCXX_USE_LLVM_UNWINDER "On")
set(LIBCXXABI_USE_LLVM_UNWINDER "On")
set(LIBUNWIND_USE_COMPILER_RT "On")
set(LLVM_HOST_TRIPLE $TARGETTRIPLE)
set(LLVM_DEFAULT_TARGET_TRIPLE $TARGETTRIPLE)
set(LLVM_ENABLE_LTO "Thin")
set(LLVM_ENABLE_LLD "On")
set(LLVM_ENABLE_PROJECTS "libcxx;libcxxabi;libunwind")
set(LIBCXX_ENABLE_THREADS On)
set(LIBCXXABI_ENABLE_THREADS On)
set(LIBUNWIND_ENABLE_THREADS On)
EOF

if [[ "${OS}" == "windows" ]]; then
cat << EOF >> $currentpath/common_cmake.cmake
set(CMAKE_C_LINKER_DEPFILE_SUPPORTED FALSE)
set(CMAKE_CXX_LINKER_DEPFILE_SUPPORTED FALSE)
set(CMAKE_ASM_LINKER_DEPFILE_SUPPORTED FALSE)
EOF

elif [[ "${OS}" == "darwin"* ]]; then

cat << EOF >> $currentpath/common_cmake.cmake
set(CMAKE_OSX_ARCHITECTURES "${DARWINARCHITECTURES}")
set(DARWIN_macosx_CACHED_SYSROOT "\${CMAKE_SYSROOT}")
set(DARWIN_macosx_OVERRIDE_SDK_VERSION \${CMAKE_SYSTEM_VERSION})
set(CMAKE_LIBTOOL "$(which llvm-libtool-darwin)")
set(CMAKE_AR "\${CMAKE_LIBTOOL};-static")
set(CMAKE_RANLIB "\${CMAKE_LIBTOOL};-static")
set(MACOS_ARM_SUPPORT On)
set(DARWIN_macosx_CACHED_SYSROOT "\${CMAKE_SYSROOT}")
set(DARWIN_macosx_OVERRIDE_SDK_VERSION "\${DARWINVERSION}")
set(COMPILER_RT_HAS_G_FLAG On)
EOF

cat << EOF >> $currentpath/runtimes.cmake
set(LIBCXX_CXX_ABI "system-libcxxabi")
set(LLVM_EXTERNALIZE_DEBUGINFO On)
EOF

fi

fi

if [[ $LIBC_PHASE -eq 1 ]]; then
    install_libc $TRIPLET "${currentpath}/libc" "${SYSROOTPATH}" "${SYSROOTPATHUSR}" "yes"
fi

clone_or_update_dependency llvm-project

