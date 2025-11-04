#!/bin/bash

install_libc() {
    local sharedstorage="$1"
    local host_triplet="$2"
    local TRIPLET="$3"
    local currentpathlibc="$4"
    local tripletpath="$5"
    local sysrootpathusr="$6"
    local usellvm="$7"
    local buildheadersonly="$8"
    local multilibs="${9:-no}"
    local isgcccrossing="${10:-no}"
    local install_full_libc="${11:-no}"
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

    local phase_file
    if [ "$buildheadersonly" == "yes" ]; then
        phase_file=".libc_headers_phase_done"
    else
        phase_file=".libc_phase_done"
    fi
    local installdirpath="${sysrootpathusr}"
    mkdir -p "${currentpathlibc}"
    mkdir -p "${tripletpath}"
    if [ ! -f "${currentpathlibc}/${phase_file}" ]; then
        if [[ "$OS" == "darwin"* ]]; then
            cd "${currentpathlibc}"
            local repo_url
            local base_url

            if [ "$CLONE_IN_CHINA" = "yes" ]; then
                repo_url="https://gitee.com/qabeowjbtkwb/apple-darwin-sysroot.git"
                base_url="https://gitee.com/qabeowjbtkwb/apple-darwin-sysroot/releases/download"
            else
                repo_url="https://github.com/trcrsired/apple-darwin-sysroot.git"
                base_url="https://github.com/trcrsired/apple-darwin-sysroot/releases/download"
            fi
            local darwinversiondate
            if [ -z ${DARWINVERSIONDATE+x} ]; then
                darwinversiondate=$(git ls-remote --tags $repo_url | tail -n 1 | sed 's/.*\///')
            else
                darwinversiondate=${DARWINVERSIONDATE}
            fi
            local triplet_variant=${TRIPLET}
            [[ $triplet_variant == arm64e-* ]] && triplet_variant="aarch64-${triplet_variant#arm64e-}"
            wget --no-verbose ${base_url}/${darwinversiondate}/${triplet_variant}.tar.xz
            if [ $? -ne 0 ]; then
                echo "Failed to download the Darwin sysroot"
                exit 1
            fi
            chmod 755 ${triplet_variant}.tar.xz
            tar -xf "${triplet_variant}.tar.xz" -C "${tripletpath}"
            if [ $? -ne 0 ]; then
                echo "Failed to extract the Darwin sysroot"
                exit 1
            fi
            if [[ $TRIPLET != "$triplet_variant" ]]; then
                mv "${tripletpath}/$triplet_variant" "${tripletpath}/$TRIPLET"
            fi
        elif [[ "$OS" == "freebsd"* ]]; then
            cd "${currentpathlibc}"

            local base_url
            if [ "$CLONE_IN_CHINA" = "yes" ]; then
                base_url="https://github.com/trcrsired/x86_64-freebsd-libc-bin/releases/download"
            else
                base_url="https://gitee.com/qabeowjbtkwb/x86_64-freebsd-libc-bin/releases/download"
            fi

            local version_tag="1"
            local archive_name="${CPU}-freebsd-libc.tar.xz"
            local remote_url="${base_url}/${version_tag}/${archive_name}"
            local local_archive="${currentpathlibc}/downloads/${archive_name}"
            local shared_archive="${sharedstorage}/freebsd-libc/${archive_name}"
            local decompress_dir="${currentpathlibc}/sysroot_decompress"

            mkdir -p "$(dirname "$local_archive")"
            mkdir -p "$(dirname "$shared_archive")"
            mkdir -p "$decompress_dir"

            # Step 1: Try to reuse shared archive if available
            if [ -f "$shared_archive" ]; then
                echo "Using cached libc archive from sharedstorage"
                cp "$shared_archive" "$local_archive"
            else
                echo "Downloading libc archive from $remote_url"
                wget --no-verbose -O "$local_archive" "$remote_url"
                if [ $? -ne 0 ]; then
                    echo "Error: Failed to download $archive_name for $TRIPLET"
                    exit 1
                fi
                cp "$local_archive" "$shared_archive"
            fi

            # Step 2: Extract
            tar -xf "$local_archive" -C "$decompress_dir"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to extract $archive_name"
                exit 1
            fi

            # Step 3: Install
            mkdir -p "$installdirpath"
            cp -a "$decompress_dir/${CPU}-freebsd-libc/"* "$installdirpath/"
            if [ $? -ne 0 ]; then
                echo "Error: Copy to installdir for freebsd"
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
                    if [[ "$multilibs" == "yes" ]]; then
                        MINGWW64COMMON="--enable-lib32 --enable-lib64"
                    else
                        MINGWW64COMMON="--disable-lib32 --enable-lib64"
                    fi
                elif [[ ${CPU} == "aarch64" ]]; then
                    MINGWW64COMMON="--disable-lib32 --disable-lib64 --disable-libarm32 --enable-libarm64"
                elif [[ ${CPU} == "arm" ]]; then
                    MINGWW64COMMON="--disable-lib32 --disable-lib64 --enable-libarm32 --disable-libarm64"
                elif [[ ${CPU} =~ i[3-6]86 ]]; then
                    MINGWW64COMMON="--enable-lib32 --disable-lib64 --with-default-msvcrt=msvcrt"
                else
                    MINGWW64COMMON="--disable-lib32 --disable-lib64 --disable-libarm32 --disable-libarm64 --enable-lib$CPU"
                fi
                MINGWW64COMMON="$MINGWW64COMMON --host=${MINGWTRIPLET} --disable-nls --disable-werror"
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

                # Resolve absolute paths to ensure accurate comparison
                local tripletpath_real="$(realpath "${tripletpath}")"
                local installdirpath_real="$(realpath "${installdirpath}")"

                if [ ! -f "${currentpathlibc}/.libc_phase_header" ]; then
                    mkdir -p "${currentpathlibc}/mingw-w64-headers"
                    cd "${currentpathlibc}/mingw-w64-headers"

                    if [ ! -f Makefile ]; then
                        if [[ "$usellvm" == "yes" ]]; then
                            eval ${MINGWW64COMMONENV} $TOOLCHAINS_BUILD/mingw-w64/mingw-w64-headers/configure ${MINGWW64COMMON} --prefix=${sysrootpathusr}/${TRIPLET}
                        else
                            $TOOLCHAINS_BUILD/mingw-w64/mingw-w64-headers/configure ${MINGWW64COMMON} --prefix=${sysrootpathusr}/${TRIPLET}
                        fi
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
                    # Skip copy if source and destination are the same directory
#                    if [ "$tripletpath_real" = "$installdirpath_real" ]; then
#                        echo "Skip copy: source and destination are the same ($tripletpath_real)"
#                    else
                        # Copy all files from source to destination, preserving symbolic links
#                        cp -r --preserve=links "${tripletpath}"/* "${installdirpath}"/

                        # Check if the copy command failed
#                        if [ $? -ne 0 ]; then
#                            echo "Error: copy mingw-w64-headers($TRIPLET) failed"
#                            exit 1
#                        fi
#                    fi
                    echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/.libc_phase_header"
                fi

                mkdir -p "${currentpathlibc}/mingw-w64-crt"
                cd "${currentpathlibc}/mingw-w64-crt"

                if [ ! -f Makefile ]; then
                    if [[ "$usellvm" == "yes" ]]; then
                        eval ${MINGWW64COMMONENV} $TOOLCHAINS_BUILD/mingw-w64/mingw-w64-crt/configure ${MINGWW64COMMON} --prefix=${sysrootpathusr}
                    else
                        $TOOLCHAINS_BUILD/mingw-w64/mingw-w64-crt/configure ${MINGWW64COMMON} --prefix=${sysrootpathusr}
                    fi
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

                if [[ "$isgcccrossing" == "yes" ]]; then
                    # Create lib/32 symlink if lib32 exists and multilibs is enabled for x86_64
                    if [[ "$CPU" == "x86_64" && "$multilibs" == "yes" ]]; then
                        if [ -d "${installdirpath}/lib32" ]; then
                            mkdir -p "${installdirpath}/lib"
                            if [ ! -e "${installdirpath}/lib/32" ]; then
                                ln -sfn ../lib32 "${installdirpath}/lib/32"
                                echo "Created symlink: ${installdirpath}/lib/32 → ../lib32"
                            else
                                echo "Symlink already exists: ${installdirpath}/lib/32"
                            fi
                        else
                            echo "lib32 directory not found under ${installdirpath}, skipping symlink"
                        fi
                    fi
                fi

                # Skip copy if source and destination are the same directory
#                if [ "$tripletpath_real" = "$installdirpath_real" ]; then
#                    echo "Skip copy: source and destination are the same ($tripletpath_real)"
#                else
                    # Copy all files from source to destination, preserving symbolic links
#                    cp -r --preserve=links "${tripletpath}"/* "${installdirpath}"/

                    # Check if the copy command failed
#                    if [ $? -ne 0 ]; then
#                        echo "Error: copy mingw-w64-crt($TRIPLET) failed"
#                        exit 1
#                    fi
#                fi
            else
                echo "Unknown Windows ABI: $ABI"
                exit 1
            fi
        elif [[ "$OS" == "linux" ]]; then
            if [[ "$ABI" == "android"* ]]; then
                if [ -z "${ANDROIDNDKVERSION}" ]; then
                    ANDROIDNDKVERSION=$(git ls-remote --tags https://github.com/android/ndk.git 2>/dev/null \
                        | grep -v '\^{}' \
                        | awk -F'/' '{print $3}' \
                        | grep -E '^r[0-9]+$' \
                        | sort -V \
                        | tail -n1)
                    echo "Detected ANDROIDNDKVERSION: ${ANDROIDNDKVERSION}"       
                    if [ -z "${ANDROIDNDKVERSION}" ]; then
                        ANDROIDNDKVERSION="r29"
                    fi
                fi

                local ANDROIDNDKVERSIONSHORTNAME="android-ndk-${ANDROIDNDKVERSION}"
                local ANDROIDNDKVERSIONFULLNAME="${ANDROIDNDKVERSIONSHORTNAME}-linux"
#                China Mirror no longer works
#                if [ "$CLONE_IN_CHINA" = "yes" ]; then
#                    base_url="https://googledownloads.cn/android/repository"
#                else
                    local base_url="https://dl.google.com/android/repository"
#                fi

                local NDKURL="${base_url}/${ANDROIDNDKVERSIONFULLNAME}.zip"

                # Define filenames and paths
                local NDK_ZIP="${ANDROIDNDKVERSIONFULLNAME}.zip"
                local NDK_DONE_FILE=".ndk_downloaded_at"
                local NDK_SHARED_ZIP="${sharedstorage}/${NDK_ZIP}"
                local NDK_SHARED_DONE="${sharedstorage}/${NDK_DONE_FILE}"

                # Ensure sharedstorage exists
                mkdir -p "${sharedstorage}"

                # Download to sharedstorage if not already completed
                if [ -f "${NDK_SHARED_DONE}" ] && [ -f "${NDK_SHARED_ZIP}" ]; then
                    echo "NDK zip already downloaded in shared storage."
                else
                    echo "Downloading NDK zip to shared storage..."
                    cd "${sharedstorage}"
                    wget --tries=2 --show-progress "${NDKURL}"
                    if [ $? -ne 0 ]; then
                        echo "wget ${NDKURL} failure"
                        exit 1
                    fi
                    echo "$(date --iso-8601=seconds)" > "${NDK_DONE_FILE}"
                fi

                # Prepare target extraction directory
                mkdir -p "${currentpathlibc}"
                cd "${currentpathlibc}"

                # Unzip directly from sharedstorage into currentpathlibc
                unzip -q "${NDK_SHARED_ZIP}"
                if [ $? -ne 0 ]; then
                    echo "unzip ${NDK_SHARED_ZIP} failure"
                    exit 1
                fi

                # Record download completion timestamp
                echo "$(date --iso-8601=seconds)" > "${NDK_DONE_FILE}"
                mkdir -p "${installdirpath}"
                cp -r --preserve=links ${currentpathlibc}/${ANDROIDNDKVERSIONSHORTNAME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${CPU}-linux-android/${ANDROIDAPIVERSION} ${installdirpath}/lib
                cp -r --preserve=links ${currentpathlibc}/${ANDROIDNDKVERSIONSHORTNAME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include ${installdirpath}/
                cp -r --preserve=links ${installdirpath}/include/${CPU}-linux-android/asm ${installdirpath}/include/
            else
                clone_or_update_dependency linux
                if [ $? -ne 0 ]; then
                    echo "Error: Failed to clone or update linux"
                    exit 1
                fi
                install_linux_kernel_headers $CPU "${currentpathlibc}" "${installdirpath}"
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
                    build_glibc $CPU "${currentpathlibc}" "${installdirpath}" "${usellvm}" "${buildheadersonly}" "no" "" "${install_full_libc}"
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
                    build_musl $TRIPLET "${currentpathlibc}" "${installdirpath}" "${usellvm}" "${buildheadersonly}" "no" "" "${install_full_libc}"
                    if [ $? -ne 0 ]; then
                        echo "Error: Failed to build musl"
                        exit 1
                    fi
                fi
            fi
        elif [[ "$OS" == "msdosdjgpp" ]]; then
            local DJCRX="${DJCRX:-djcrx205}"
            local shared_djgpp_zip="${sharedstorage}/djgpp/${DJCRX}.zip"
            local local_djgpp_zip="${currentpathlibc}/downloads/${DJCRX}.zip"
            local local_djgpp_root="${currentpathlibc}/${DJCRX}"

            mkdir -p "${currentpathlibc}/downloads"
            mkdir -p "${local_djgpp_root}"
            mkdir -p "${sysrootpathusr}"
            mkdir -p "$(dirname "$shared_djgpp_zip")"

            # Step 1: Try to copy from sharedstorage if available
            if [ -f "$shared_djgpp_zip" ]; then
                echo "Using cached ${DJCRX}.zip from sharedstorage"
                cp "$shared_djgpp_zip" "$local_djgpp_zip"
            else
                echo "Downloading ${DJCRX}.zip from Delorie"
#Use my fix up of djcrx since it has no struct timespec which breaks libstdc++ build
#                wget -O "$local_djgpp_zip" "http://www.delorie.com/pub/djgpp/current/v2/${DJCRX}.zip"
                wget -O "$local_djgpp_zip" "https://github.com/trcrsired/djcrx/releases/download/20251102/${DJCRX}.zip"
                if [ $? -ne 0 ]; then
                    echo "Error: Failed to download ${DJCRX}.zip"
                    exit 1
                fi
                cp "$local_djgpp_zip" "$shared_djgpp_zip"
            fi

            chmod 755 "$local_djgpp_zip" || true

            unzip "$local_djgpp_zip" -d "${local_djgpp_root}"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to unzip ${DJCRX}.zip"
                exit 1
            fi

            mkdir -p "${sysrootpathusr}/bin"

            # Determine compiler for stubify/stubedit
            local stub_compiler=""
            if [ -z "$host_triplet" ]; then
                if [[ "$usellvm" == "yes" ]]; then
                    stub_compiler="clang -fuse-ld=lld"
                else
                    stub_compiler="gcc"
                fi
            else
                if [[ "$usellvm" == "yes" ]]; then
                    stub_compiler="clang --target=${host_triplet} -fuse-ld=lld"
                else
                    stub_compiler="${host_triplet}-gcc"
                fi
            fi

            $stub_compiler -o "${sysrootpathusr}/bin/stubify" "${local_djgpp_root}/src/stub/stubify.c" -s -O3 -flto
            if [ $? -ne 0 ]; then
                echo "Error: Failed to compile stubify"
                exit 1
            fi

            $stub_compiler -o "${sysrootpathusr}/bin/stubedit" "${local_djgpp_root}/src/stub/stubedit.c" -s -O3 -flto
            if [ $? -ne 0 ]; then
                echo "Error: Failed to compile stubedit"
                exit 1
            fi

            cp -a "${local_djgpp_root}"/include "${sysrootpathusr}/"
            cp -a "${local_djgpp_root}"/lib "${sysrootpathusr}/"
        fi
        echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/${phase_file}"
    fi
}
