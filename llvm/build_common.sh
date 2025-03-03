#!/bin/bash

if [ -z ${TRIPLET+x} ]; then
echo "TRIPLET is not set. Please set the TRIPLET environment variable to the target triplet."
exit 1
fi

source ../common/safe-llvm-strip.sh
source ../common/parse-triplet.sh

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
currentpath="$(realpath .)/.llvmartifacts/${TRIPLET}"

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi


TOOLCHAINS_LLVMPATH=$TOOLCHAINSPATH/llvm
TOOLCHAINS_LLVMSYSROOTSPATH="$TOOLCHAINS_LLVMPATH/${TRIPLET}"

SYSROOTPATH="$TOOLCHAINS_LLVMSYSROOTSPATH/${TRIPLET}"
SYSROOTPATHUSR="${SYSROOTPATH}/usr"

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "${currentpath}"
#	rm -rf "${TOOLCHAINS_LLVMSYSROOTSPATH}"
	echo "restart done"
fi

if [ -z ${LLVMPROJECTPATH+x} ]; then
LLVMPROJECTPATH=$TOOLCHAINS_BUILD/llvm-project
fi

echo "ok ${currentpath}"
mkdir -p "${currentpath}"
cd "${currentpath}"
mkdir -p $TOOLCHAINSPATH
mkdir -p $TOOLCHAINS_LLVMPATH
mkdir -p $TOOLCHAINS_LLVMSYSROOTSPATH
mkdir -p $TOOLCHAINS_BUILD

capitalize() {
    echo "$1" | sed 's/.*/\L&/; s/[a-z]*/\u&/g'
}

if [ -z ${SYSTEMNAME+x} ]; then
    SYSTEMNAME=$(capitalize "${OS}")
    if [[ "$SYSTEMNAME" =~ ([a-zA-Z]+)([0-9]*) ]]; then
        SYSTEMNAME=$(capitalize "${BASH_REMATCH[1]}")
        if [ "$SYSTEMNAME" == "Android" ]; then
            SYSTEMNAME="Linux"
            if [ -z ${ANDROIDVERSION+x} ]; then
                ANDROIDVERSION=${BASH_REMATCH[2]}
            fi
        elif [ -n "${BASH_REMATCH[2]}" ]; then
            if [ -z ${SYSTEMVERSION+x} ]; then
                SYSTEMVERSION=${BASH_REMATCH[2]}
            fi
        fi
    fi
fi

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
        echo "Operating System: windows with ABI: $ABI"
        CPPWINRT_PHASE=1
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
set(CMAKE_C_FLAGS "\${FLAGSCOMMON}")
set(CMAKE_CXX_FLAGS "\${FLAGSCOMMON}")
set(CMAKE_ASM_FLAGS "\${CMAKE_C_FLAGS}")
set(COMPILER_RT_HAS_G_FLAG On)
EOF


if [[ "${SYSTEMNAME}" == "Darwin" ]]; then

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
EOF

cat << EOF >> $currentpath/compiler-rt.cmake
set(COMPILER_RT_HAS_G_FLAG On)

EOF

fi

fi


if [ ! -d "$LLVMPROJECTPATH" ]; then
git clone git@github.com:llvm/llvm-project.git $LLVMPROJECTPATH
fi
cd "$LLVMPROJECTPATH"
git pull --quiet
