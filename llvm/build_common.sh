#!/bin/bash

if [ -z ${TRIPLET+x} ]; then
echo "TRIPLET is not set. Please set the TRIPLET environment variable to the target triplet."
exit 1
fi
currentpath="$(realpath .)/.llvmartifacts/${TRIPLET}"
mkdir -p $currentpath
cd ../common
source ../common/common.sh
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
    mkdir -p "${currentpath}/libc"
    if [ ! -f "$currentpath/libc/.libc_phase_done" ]; then
        if [[ "$OS" == "darwin"* ]]; then
            cd "${currentpath}/libc"
            if [ -z ${DARWINVERSIONDATE+x} ]; then
                DARWINVERSIONDATE=$(git ls-remote --tags git@github.com:trcrsired/apple-darwin-sysroot.git | tail -n 1 | sed 's/.*\///')
            fi
            wget https://github.com/trcrsired/apple-darwin-sysroot/releases/download/${DARWINVERSIONDATE}/${TRIPLET}.tar.xz
            if [ $? -ne 0 ]; then
                echo "Failed to download the Darwin sysroot"
                exit 1
            fi
            chmod 755 ${TRIPLET}.tar.xz
            tar -xf "${TRIPLET}.tar.xz" -C "$TOOLCHAINS_LLVMTRIPLETPATH"
            if [ $? -ne 0 ]; then
                echo "Failed to extract the Darwin sysroot"
                exit 1
            fi
        elif [[ "$OS" == "freebsd"* ]]; then
			cd "${currentpath}/libc"
			wget https://github.com/trcrsired/x86_64-freebsd-libc-bin/releases/download/1/${CPU}-freebsd-libc.tar.xz
			if [ $? -ne 0 ]; then
					echo "wget ${HOST} failure"
					exit 1
			fi

			mkdir -p ${currentpath}/libc/sysroot_decompress
			# Decompress the tarball into a temporary directory
			tar -xvf ${CPU}-freebsd-libc.tar.xz -C "${currentpath}/libc/sysroot_decompress"
			if [ $? -ne 0 ]; then
					echo "tar extraction failure"
					exit 1
			fi
			mkdir -p "${SYSROOTPATHUSR}"
			# Move all extracted files into ${SYSROOTPATHUSR}
			cp -r --preserve=links "${currentpath}/libc/sysroot_decompress"/${CPU}-freebsd-libc/* "${SYSROOTPATHUSR}/"
			if [ $? -ne 0 ]; then
					echo "Failed to move files to ${SYSROOTPATHUSR}"
					exit 1
			fi
        elif [[ "$OS" == "windows" ]]; then
            if [[ "$ABI" == "msvc" ]]; then
                clone_or_update_dependency windows-msvc-sysroot
            elif [[ "$ABI" == "gnu" ]]; then
                clone_or_update_dependency mingw-w64
                MINGWTRIPLET=${CPU}-w64-mingw32
                if [[ ${CPU} == "x86_64" ]]; then
                    MINGWW64COMMON="--disable-lib32 --enable-lib64"
                elif [[ ${CPU} == "aarch64" ]]; then
                    MINGWW64COMMON="--disable-lib32 --disable-lib64 --disable-libarm32 --enable-libarm64"
                elif [[ ${CPU} == "arm" ]]; then
                    MINGWW64COMMON="--disable-lib32 --disable-lib64 --enable-libarm32 --disable-libarm64"
                elif [[ ${CPU} == "i[3-6]86" ]]; then
                    MINGWW64COMMON="--disable-lib32 --enable-lib64 --with-default-msvcrt=msvcrt"
                else
                    MINGWW64COMMON="--disable-lib32 --disable-lib64 --enable-libarm32 --disable-libarm64 --enable-lib$CPU"
                fi
                MINGWW64COMMON="$MINGWW64COMMON --host=${MINGWTRIPLET} --prefix=${SYSROOTPATHUSR}"
                MINGWW64COMMONENV="
                CC=\"clang --target=${TRIPLET} -fuse-ld=lld \"--sysroot=${SYSROOTPATH}\"\"
                CXX=\"clang++ --target=${TRIPLET} -fuse-ld=lld \"--sysroot=${SYSROOTPATH}\"\"
                LD=lld
                NM=llvm-nm
                RANLIB=llvm-ranlib
                AR=llvm-ar
                DLLTOOL=llvm-dlltool
                AS=llvm-as
                STRIP=llvm-strip
                OBJDUMP=llvm-objdump
                WINDRES=llvm-windres
                "
                if [ ! -f "$currentpath/libc/.libc_phase_header" ]; then
                    mkdir -p "${currentpath}/libc/mingw-w64-headers"
                    cd "${currentpath}/libc/mingw-w64-headers"

                    if [ ! -f Makefile ]; then
                        eval ${MINGWW64COMMONENV} $TOOLCHAINS_BUILD/mingw-w64/mingw-w64-headers/configure ${MINGWW64COMMON}
                        if [ $? -ne 0 ]; then
                            echo "Error: mingw-w64-headers($TRIPLET) configure failed"
                            exit 1
                        fi
                    fi

                    make -j$(nproc) 2>err.txt
                    if [ $? -ne 0 ]; then
                        echo "Error: make mingw-w64-headers($TRIPLET) install-strip failed"
                        exit 1
                    fi

                    make install-strip -j$(nproc) 2>>err.txt
                    if [ $? -ne 0 ]; then
                        echo "Error: make mingw-w64-headers($TRIPLET) install-strip failed"
                        exit 1
                    fi

                    echo "$(date --iso-8601=seconds)" > "$currentpath/libc/.libc_phase_header"
                fi

                mkdir -p "${currentpath}/libc/mingw-w64-crt"
                cd "${currentpath}/libc/mingw-w64-crt"

                if [ ! -f Makefile ]; then
                    eval ${MINGWW64COMMONENV} $TOOLCHAINS_BUILD/mingw-w64/mingw-w64-crt/configure ${MINGWW64COMMON}
                    if [ $? -ne 0 ]; then
                        echo "Error: configure mingw-w64-crt($TRIPLET) failed"
                        exit 1
                    fi
                fi

                make -j$(nproc) 2>err.txt
                if [ $? -ne 0 ]; then
                    echo "Error: make mingw-w64-crt($TRIPLET) failed"
                    exit 1
                fi

                make install-strip -j$(nproc) 2>>err.txt
                if [ $? -ne 0 ]; then
                    echo "Error: make install-strip mingw-w64-crt($TRIPLET) failed"
                    exit 1
                fi

            else
                echo "Unknown Windows ABI: $ABI"
                exit 1
            fi
        elif [[ "$OS" == "linux" ]]; then
            if [[ "$ABI" == "android"* ]]; then
                if [ -z ${ANDROIDNDKVERSION+x} ]; then
                    ANDROIDNDKVERSION=r28
                fi
                mkdir -p ${currentpath}/libc
                cd ${currentpath}/libc
                ANDROIDNDKVERSIONSHORTNAME=android-ndk-${ANDROIDNDKVERSION}
                ANDROIDNDKVERSIONFULLNAME=android-ndk-${ANDROIDNDKVERSION}-linux
                wget https://dl.google.com/android/repository/${ANDROIDNDKVERSIONFULLNAME}.zip
                if [ $? -ne 0 ]; then
                        echo "wget ${HOST} failure"
                        exit 1
                fi
                chmod 755 ${ANDROIDNDKVERSIONFULLNAME}.zip
                unzip ${ANDROIDNDKVERSIONFULLNAME}.zip
                if [ $? -ne 0 ]; then
                        echo "unzip ${HOST} failure"
                        exit 1
                fi
                mkdir -p "${SYSROOTPATHUSR}"
                cp -r --preserve=links ${currentpath}/libc/${ANDROIDNDKVERSIONSHORTNAME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${CPU}-linux-android/${ANDROIDAPIVERSION} ${SYSROOTPATHUSR}/lib
                cp -r --preserve=links ${currentpath}/libc/${ANDROIDNDKVERSIONSHORTNAME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include ${SYSROOTPATHUSR}/
                cp -r --preserve=links ${SYSROOTPATHUSR}/include/${CPU}-linux-android/asm ${SYSROOTPATHUSR}/include/
            else
                clone_or_update_dependency linux
                if [[ "$ABI" == "gnu" ]]; then
                    clone_or_update_dependency glibc
                elif [[ "$ABI" == "musl" ]]; then
                    clone_or_update_dependency musl
                fi
            fi
        fi
        echo "$(date --iso-8601=seconds)" > "$currentpath/libc/.libc_phase_done"
    fi
fi

clone_or_update_dependency llvm-project

