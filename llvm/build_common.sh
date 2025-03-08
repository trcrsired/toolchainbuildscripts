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


TOOLCHAINS_LLVMPATH="$TOOLCHAINSPATH/llvm"
TOOLCHAINS_LLVMTRIPLETPATH="$TOOLCHAINS_LLVMPATH/${TRIPLET}"

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

if [[ "x${NO_TOOLCHAIN_DELETION}" == "xyes" ]]; then
    TOOLCHAINS_LLVMTRIPLETPATH_LLVM_TMP="${TOOLCHAINS_LLVMTRIPLETPATH_LLVM}_tmp"
    TOOLCHAINS_LLVMTRIPLETPATH_RUNTIMES_TMP="${TOOLCHAINS_LLVMTRIPLETPATH_RUNTIMES}_tmp"
else
    TOOLCHAINS_LLVMTRIPLETPATH_LLVM_TMP="${TOOLCHAINS_LLVMTRIPLETPATH_LLVM}"
    TOOLCHAINS_LLVMTRIPLETPATH_RUNTIMES_TMP="${TOOLCHAINS_LLVMTRIPLETPATH_RUNTIMES}"
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "${currentpath}"
	rm -rf "${TOOLCHAINS_LLVMTRIPLETPATH}"
	echo "restart done"
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

if [[ "$OS" == "darwin"* ]]; then
    echo "Operating System: macOS (Darwin)"
    BUILTINS_PHASE=0
    COMPILER_RT_PHASE=2
    ZLIB_PHASE=0
    LIBXML2_PHASE=0
    macosxs_SDK_VERSION=15.2
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
    elif [[ "$OS" == "linux" && "$ABI" == "android"* ]]; then
        COPY_COMPILER_RT_WITH_SPECIAL_NAME=1
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

set(CMAKE_POSITION_INDEPENDENT_CODE On)
set(LLVM_ENABLE_LTO thin)
set(LLVM_ENABLE_LLD On)
set(CMAKE_LINKER_TYPE LLD)
set(CMAKE_C_FLAGS_INIT "-fuse-ld=lld -fuse-lipo=llvm-lipo -flto=thin -Wno-unused-command-line-argument")
set(CMAKE_CXX_FLAGS_INIT "\${CMAKE_C_FLAGS_INIT}")
set(CMAKE_ASM_FLAGS_INIT "\${CMAKE_C_FLAGS_INIT}")
EOF

cat << EOF >> $currentpath/common_cmake.cmake
set(CMAKE_C_FLAGS_INIT "\${CMAKE_C_FLAGS_INIT} -rtlib=compiler-rt")
set(CMAKE_CXX_FLAGS_INIT "\${CMAKE_C_FLAGS_INIT} -stdlib=libc++ --unwindlib=libunwind")
set(CMAKE_ASM_FLAGS_INIT "\${CMAKE_C_FLAGS_INIT}")
EOF

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
set(COMPILER_RT_DEFAULT_TARGET_ONLY On)
set(CMAKE_C_COMPILER_WORKS On)
set(CMAKE_CXX_COMPILER_WORKS On)
set(CMAKE_ASM_COMPILER_WORKS On)
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION On)
set(COMPILER_RT_USE_LIBCXX On)
EOF

cat << EOF > "$currentpath/builtins.cmake"
include("\${CMAKE_CURRENT_LIST_DIR}/compiler-rt.cmake")
EOF

if [[ "$USE_COMPILER_RT_BAREMETAL_BUILD" -eq 1 ]]; then
cat << EOF >> "$currentpath/builtins.cmake"
set(COMPILER_RT_BAREMETAL_BUILD On)
EOF
fi

cat << EOF > "$currentpath/libxml2.cmake"
include("\${CMAKE_CURRENT_LIST_DIR}/common_cmake.cmake")
set(LIBXML2_WITH_ICONV Off)
set(LIBXML2_WITH_PYTHON Off)
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
set(C_SUPPORTS_CUSTOM_LINKER On)
set(CXX_SUPPORTS_CUSTOM_LINKER On)
set(ASM_SUPPORTS_CUSTOM_LINKER On)
set(LLVM_ENABLE_RUNTIMES libcxx;libcxxabi;libunwind)
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

fi

fi

# Define the function to build and install
build_project() {
    local project_name=$1
    local source_path=$2
    local toolchain_file=$3
    local build_prefix=$4
    local copy_to_sysroot_usr=$5
    local install_prefix="${TOOLCHAINS_LLVMTRIPLETPATH}/${project_name}" 
    local current_phase_file=".${project_name}_phase_done"
    local configure_phase_file=".${project_name}_phase_configure"
    local build_phase_file=".${project_name}_phase_build"
    local install_phase_file=".${project_name}_phase_install"
    local copy_phase_file=".${project_name}_phase_copy"
    local rt_rename_phase_file=".${project_name}_phase_rt_rename_phase_file"
    
    if [ ! -f "${build_prefix}/${current_phase_file}" ]; then
        mkdir -p "${build_prefix}"
        cd "${build_prefix}"

        if [ ! -f "${build_prefix}/${configure_phase_file}" ]; then
            cd "${build_prefix}"
            # Run CMake to generate Ninja build files
            cmake -GNinja -DCMAKE_BUILD_TYPE=Release "${source_path}" \
                -DCMAKE_TOOLCHAIN_FILE="${toolchain_file}" \
                -DCMAKE_INSTALL_PREFIX="${install_prefix}"
            cmake -GNinja -DCMAKE_BUILD_TYPE=Release "${source_path}" \
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
            fi
            ninja
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
            if [[ "$project_name" == "runtimes" && "$OS" == "linux" && "$ABI" == "android"* ]]; then
                cd "${install_prefix}/lib"
                rm libc++.so
                ln -s libc++.so.1 libc++.so
            fi
            echo "$(date --iso-8601=seconds)" > "${build_prefix}/${install_phase_file}"
        fi
        if [[ "$project_name" == "compiler-rt" || "$project_name" == "builtins" ]]; then
            if [[ ${COPY_COMPILER_RT_WITH_SPECIAL_NAME} -eq 1 ]]; then
                if [ ! -f "${build_prefix}/${rt_rename_phase_file}" ]; then
                    cd "${install_prefix}/lib"
                    mv "$OS" "${TRIPLET_WITH_UNKNOWN}"
                    cd "${TRIPLET_WITH_UNKNOWN}"
                    for file in *-"${CPU}"*; do
                        new_name="${file//-${CPU}/}"
                        mv "$file" "$new_name"
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
    build_project "runtimes" "$LLVMPROJECTPATH/runtimes" "$currentpath/runtimes.cmake" "${currentpath}/runtimes" "yes"
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

    if [[ ${!phase_var} -eq 1 ]]; then
        clone_or_update_dependency $lib_name
        build_project "$lib_name" "$TOOLCHAINS_BUILD/$lib_name" "$toolchain_file" "${currentpath}/$lib_name" "yes"
    fi
}

build_zlib() {
    build_library "zlib"
}

build_libxml2() {
    build_library "libxml2" "$currentpath/libxml2.cmake"
}

build_cppwinrt() {
    build_library "cppwinrt"
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

# Example usage of the functions
clone_or_update_dependency llvm-project

build_compiler_rt_or_builtins 0

if [[ $LIBC_PHASE -eq 1 ]]; then
    install_libc $TRIPLET "${currentpath}/libc" "${TOOLCHAINS_LLVMTRIPLETPATH}" "${SYSROOTPATHUSR}" "yes"
fi

build_compiler_rt_or_builtins 1

build_runtimes

build_compiler_rt_or_builtins 2

build_zlib

build_libxml2

#build_cppwinrt
