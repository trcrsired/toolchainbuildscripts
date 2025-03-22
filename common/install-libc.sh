#!/bin/bash

install_libc() {
    local TRIPLET="$1"
    local currentpathlibc="$2"
    local tripletpath="$3"
    local sysrootpathusr="$4"
    local usellvm="$5"
    local CPU
    local VENDOR
    local OS
    local ABI
    parse_triplet $TRIPLET CPU VENDOR OS ABI
    if [[ "$OS" == mingw* ]]; then
        VENDOR=""
        OS="windows"
        ABI="gnu"
    fi

    local ANDROIDAPIVERSION
    if [[ "$OS" == "linux" && "$ABI" == android* ]]; then
        ANDROIDAPIVERSION=${ABI#android}
        if [ -z "$ANDROIDAPIVERSION" ]; then
            echo "Error: ANDROIDAPIVERSION is not set."
            exit 1
        fi
    fi

    mkdir -p "${currentpathlibc}"
    mkdir -p "${tripletpath}"
    if [ ! -f "${currentpathlibc}/.libc_phase_done" ]; then
        if [[ "$OS" == "darwin"* ]]; then
            cd "${currentpathlibc}"
            local darwinversiondate
            if [ -z ${DARWINVERSIONDATE+x} ]; then
                darwinversiondate=$(git ls-remote --tags git@github.com:trcrsired/apple-darwin-sysroot.git | tail -n 1 | sed 's/.*\///')
            else
                darwinversiondate=${DARWINVERSIONDATE}
            fi
            wget https://github.com/trcrsired/apple-darwin-sysroot/releases/download/${darwinversiondate}/${TRIPLET}.tar.xz
            if [ $? -ne 0 ]; then
                echo "Failed to download the Darwin sysroot"
                exit 1
            fi
            chmod 755 ${TRIPLET}.tar.xz
            tar -xf "${TRIPLET}.tar.xz" -C "${tripletpath}"
            if [ $? -ne 0 ]; then
                echo "Failed to extract the Darwin sysroot"
                exit 1
            fi
        elif [[ "$OS" == "freebsd"* ]]; then
            cd "${currentpathlibc}"
            wget https://github.com/trcrsired/x86_64-freebsd-libc-bin/releases/download/1/${CPU}-freebsd-libc.tar.xz
            if [ $? -ne 0 ]; then
                echo "wget ${HOST} failure"
                exit 1
            fi

            mkdir -p ${currentpathlibc}/sysroot_decompress
            tar -xvf ${CPU}-freebsd-libc.tar.xz -C "${currentpathlibc}/sysroot_decompress"
            if [ $? -ne 0 ]; then
                echo "tar extraction failure"
                exit 1
            fi
            mkdir -p "${sysrootpathusr}"
            cp -r --preserve=links "${currentpathlibc}/sysroot_decompress"/${CPU}-freebsd-libc/* "${sysrootpathusr}/"
            if [ $? -ne 0 ]; then
                echo "Failed to move files to ${sysrootpathusr}"
                exit 1
            fi
        elif [[ "$OS" == "windows" ]]; then
            if [[ "$ABI" == "msvc" ]]; then
                clone_or_update_dependency windows-msvc-sysroot
            elif [[ "$ABI" == "gnu" ]]; then
                clone_or_update_dependency mingw-w64
                local MINGWTRIPLET="${CPU}-w64-mingw32"
                local MINGWW64COMMON
                if [[ ${CPU} == "x86_64" ]]; then
                    MINGWW64COMMON="--disable-lib32 --enable-lib64"
                elif [[ ${CPU} == "aarch64" ]]; then
                    MINGWW64COMMON="--disable-lib32 --disable-lib64 --disable-libarm32 --enable-libarm64"
                elif [[ ${CPU} == "arm" ]]; then
                    MINGWW64COMMON="--disable-lib32 --disable-lib64 --enable-libarm32 --disable-libarm64"
                elif [[ ${CPU} =~ i[3-6]86 ]]; then
                    MINGWW64COMMON="--enable-lib32 --disable-lib64 --with-default-msvcrt=msvcrt"
                else
                    MINGWW64COMMON="--disable-lib32 --disable-lib64 --enable-libarm32 --disable-libarm64 --enable-lib$CPU"
                fi
                MINGWW64COMMON="$MINGWW64COMMON --host=${MINGWTRIPLET} --prefix=${sysrootpathusr}"
                local MINGWW64COMMONENV="
                CC=\"clang --target=${TRIPLET} -fuse-ld=lld \"--sysroot=${sysrootpathusr}\"\"
                CXX=\"clang++ --target=${TRIPLET} -fuse-ld=lld \"--sysroot=${sysrootpathusr}\"\"
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
                if [ ! -f "${currentpathlibc}/.libc_phase_header" ]; then
                    mkdir -p "${currentpathlibc}/mingw-w64-headers"
                    cd "${currentpathlibc}/mingw-w64-headers"

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

                    echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/.libc_phase_header"
                fi

                mkdir -p "${currentpathlibc}/mingw-w64-crt"
                cd "${currentpathlibc}/mingw-w64-crt"

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
                if [ -z "${ANDROIDNDKVERSION}" ]; then
                    ANDROIDNDKVERSION=$(git ls-remote --tags git@github.com:android/ndk.git 2>/dev/null | grep -v '\^{}' | awk -F'/' '{print $3}' | sort -V | tail -n1)
                    echo "Detected ANDROIDNDKVERSION: ${ANDROIDNDKVERSION}"       
                    # Default to r28 if no valid tag is found
                    if [ -z "${ANDROIDNDKVERSION}" ]; then
                        ANDROIDNDKVERSION="r28"
                    fi
                fi
                mkdir -p ${currentpathlibc}
                cd ${currentpathlibc}
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
                mkdir -p "${sysrootpathusr}"
                cp -r --preserve=links ${currentpathlibc}/${ANDROIDNDKVERSIONSHORTNAME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${CPU}-linux-android/${ANDROIDAPIVERSION} ${sysrootpathusr}/lib
                cp -r --preserve=links ${currentpathlibc}/${ANDROIDNDKVERSIONSHORTNAME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include ${sysrootpathusr}/
                cp -r --preserve=links ${sysrootpathusr}/include/${CPU}-linux-android/asm ${sysrootpathusr}/include/
            else
                clone_or_update_dependency linux
                if [ $? -ne 0 ]; then
                    echo "Error: Failed to clone or update linux"
                    exit 1
                fi
                install_linux_kernel_headers $CPU "${currentpathlibc}" "${sysrootpathusr}"
                if [ $? -ne 0 ]; then
                    echo "Error: Failed to install Linux kernel headers"
                    exit 1
                fi

                if [[ "$ABI" == "gnu" ]]; then
                    clone_or_update_dependency glibc
                    if [ $? -ne 0 ]; then
                        echo "Error: Failed to clone or update glibc"
                        exit 1
                    fi
                    build_glibc $CPU "${currentpathlibc}" "${sysrootpathusr}"
                    if [ $? -ne 0 ]; then
                        echo "Error: Failed to build glibc"
                        exit 1
                    fi
                elif [[ "$ABI" == "musl" ]]; then
                    clone_or_update_dependency musl
                    if [ $? -ne 0 ]; then
                        echo "Error: Failed to clone or update musl"
                        exit 1
                    fi
                    build_musl $TRIPLET "${currentpathlibc}" "${sysrootpathusr}" "$usellvm"
                    if [ $? -ne 0 ]; then
                        echo "Error: Failed to build musl"
                        exit 1
                    fi
                fi
            fi
        fi
        echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/.libc_phase_done"
    fi
}