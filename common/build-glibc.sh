#!/bin/bash

install_linux_kernel_headers() {
    local cpu=$1
    local currentpathlibc=$2
    local sysrootpathusr=$3

    local linuxarch=$cpu
    if [[ $linuxarch == "aarch64" ]]; then
        linuxarch="arm64"
    elif [[ $linuxarch =~ i[3-6]86 ]]; then
        linuxarch="x86"
    elif [[ $linuxarch != x86_64 ]]; then
        linuxarch="${linuxarch%%[0-9]*}"
    fi

    local toolchains_path
    if [ -z ${TOOLCHAINS_BUILD+x} ]; then
        toolchains_path="$HOME/toolchains_build"
    else
        toolchains_path="$TOOLCHAINS_BUILD"
    fi

    if [ ! -f "${currentpathlibc}/.linuxkernelheadersinstallsuccess" ]; then
        cd "$toolchains_path/linux"
        make headers_install ARCH=$linuxarch -j "INSTALL_HDR_PATH=${sysrootpathusr}"
        if [ $? -ne 0 ]; then
            echo "linux kernel headers install failure"
            exit 1
        fi
        echo "$(date +%s)" > "${currentpathlibc}/.linuxkernelheadersinstallsuccess"
    fi
}

build_glibc() {
    local host=$1
    local currentpathlibc=$2
    local sysrootpathusr=$3
    local usellvm=$4
    local headersonly=$5
    local buildmulitlib=$6
    local build=${7:-}
    local install_full_libc=${8:-no}
    local multilibs=(default)
    local multilibsoptions=("")
    local multilibsdir=("lib")
    local cpu=${host%%-*}
    local multilibshost=("$cpu-linux-gnu")
    local glibcfiles=(libm.a libm.so libc.so)

    if [[ $buildmulitlib == "yes" ]]; then
        if [[ ${cpu} == "riscv64" ]]; then
            multilibs=(default lp64 lp64d ilp32 ilp32d)
            multilibsoptions=("" " -march=rv64imac -mabi=lp64" " -march=rv64imafdc -mabi=lp64d" " -march=rv32imac -mabi=ilp32" " -march=rv32imafdc -mabi=ilp32d")
            multilibsdir=("lib64" "lib64/lp64" "lib64/lp64d" "lib32/ilp32" "lib32/ilp32d")
            multilibshost=("riscv64-linux-gnu" "riscv64-linux-gnu" "riscv64-linux-gnu" "riscv32-linux-gnu" "riscv32-linux-gnu")
        elif [[ ${cpu} == "x86_64" ]]; then
            multilibs=(m64)
            multilibsoptions=(" -m64")
            multilibsdir=("lib")
            multilibshost=("x86_64-linux-gnu")
        elif [[ ${cpu} == "loongarch64" ]]; then
            multilibs=(m64)
            multilibsoptions=("")
            multilibsdir=("lib64")
            multilibshost=("loongarch64-linux-gnu")
        fi
    fi
    local phase_dir
    if [ "$buildheadersonly" == "yes" ]; then
        phase_dir="build-headers"
    else
        phase_dir="build"
    fi

    mkdir -p "${sysrootpathusr}"
    mkdir -p "${currentpathlibc}/${phase_dir}/glibc"
    local toolchains_path
    if [ -z ${TOOLCHAINS_BUILD+x} ]; then
        toolchains_path="$HOME/toolchains_build"
    else
        toolchains_path="$TOOLCHAINS_BUILD"
    fi
    for i in "${!multilibs[@]}"; do
        local item=${multilibs[$i]}
        local marchitem=${multilibsoptions[$i]}
        local libdir=${multilibsdir[$i]}
        local host=${multilibshost[$i]}

        mkdir -p "${currentpathlibc}/${phase_dir}/glibc/$item"
        cd "${currentpathlibc}/${phase_dir}/glibc/$item"

        if [ ! -f "${currentpathlibc}/${phase_dir}/glibc/$item/.configuresuccess" ]; then
            if [[ ${usellvm} == "yes" ]]; then
                LIPO=llvm-lipo \
                OTOOL=llvm-otool \
                DSYMUTIL=dsymutil \
                STRIP=llvm-strip \
                AR=llvm-ar \
                CC="clang --target=$host -fuse-ld=lld -fuse-lipo=llvm-lipo -rtlib=compiler-rt" \
                CXX="clang++ --target=$host -fuse-ld=lld -fuse-lipo=llvm-lipo -rtlib=compiler-rt" \
                TEST_CC="clang --target=$host -fuse-ld=lld -fuse-lipo=llvm-lipo -rtlib=compiler-rt" \
                AS=llvm-as \
                RANLIB=llvm-ranlib \
                CXXFILT=llvm-cxxfilt \
                NM=llvm-nm \
                LDNAME=ld.lld \
                OBJDUMP=llvm-objdump \
                READELF=llvm-readelf \
                SIZE=llvm-size \
                STRINGS=llvm-strings \
                OBJCOPY=llvm-objcopy \
                ADDR2LINE=llvm-addr2line \
                "$toolchains_path/glibc/configure" --disable-nls --disable-werror --prefix="${currentpathlibc}/install/glibc/${item}"  \
                $( [ -n "$build" ] && echo "--build=$build" ) \
                --with-headers="${sysrootpathusr}/include" --without-selinux --host="$host"
            else
                (export -n LD_LIBRARY_PATH; CC="$host-gcc$marchitem" CXX="$host-g++$marchitem" "$toolchains_path/glibc/configure" --disable-nls --disable-werror --prefix="${currentpathlibc}/install/glibc/${item}"  \
                $( [ -n "$build" ] && echo "--build=$build" ) \
                --with-headers="${sysrootpathusr}/include" --without-selinux --host="$host" )
            fi
            if [ $? -ne 0 ]; then
                echo "glibc ($item) configure failure"
                exit 1
            fi
            echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/glibc/$item/.configuresuccess"
        fi

        if [[ "$headersonly" == "yes" ]]; then
            if [ ! -f "${currentpathlibc}/${phase_dir}/glibc/$item/.headersinstallsuccess" ]; then
                if [[ ${usellvm} == "yes" ]]; then
                    LD=lld make install-headers -j$(nproc)
                else
                    (export -n LD_LIBRARY_PATH; make install-headers -j$(nproc))           
                fi
                if [ $? -ne 0 ]; then
                    echo "glibc install-headers failure"
                    exit 1
                fi
                mkdir -p "$sysrootpathusr"
                cp -r --preserve=links "${currentpathlibc}/install/glibc/$item"/* "$sysrootpathusr/"
                echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/glibc/$item/.headersinstallsuccess"
            fi
            return
        fi

        if [ ! -f "${currentpathlibc}/${phase_dir}/glibc/$item/.buildsuccess" ]; then
            if [[ ${usellvm} == "yes" ]]; then
                make -j$(nproc)
            else
                (export -n LD_LIBRARY_PATH; make -j$(nproc))
            fi
            if [ $? -ne 0 ]; then
                echo "glibc ($item) build failure"
                exit 1
            fi
            echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/glibc/$item/.buildsuccess"
        fi

        if [ ! -f "${currentpathlibc}/${phase_dir}/glibc/$item/.installsuccess" ]; then
            if [[ ${usellvm} == "yes" ]]; then
                make install -j$(nproc)
            else
                (export -n LD_LIBRARY_PATH; make install -j$(nproc))
            fi
            if [ $? -ne 0 ]; then
                echo "glibc ($item) install failure"
                exit 1
            fi
            echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/glibc/$item/.installsuccess"
        fi

        if [ ! -f "${currentpathlibc}/${phase_dir}/glibc/$item/.removehardcodedpathsuccess" ]; then
            local canadianreplacedstring="${currentpathlibc}/install/glibc/${item}/lib/"
            for file in "${glibcfiles[@]}"; do
                local filepath="$canadianreplacedstring/$file"
                if [ -f "$filepath" ]; then
                    local getfilesize=$(wc -c <"$filepath")
                    echo "$getfilesize"
                    if [ $getfilesize -lt 1024 ]; then
                        sed -i "s%${canadianreplacedstring}%%g" "$filepath"
                        echo "removed hardcoded path: $filepath"
                    fi
                fi
            done
            echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/glibc/$item/.removehardcodedpathsuccess"
        fi

        if [ ! -f "${currentpathlibc}/${phase_dir}/glibc/$item/.stripsuccess" ]; then
            safe_llvm_strip "${currentpathlibc}/install/glibc/${item}"
            echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/glibc/$item/.stripsuccess"
        fi
        if [ ! -f "${currentpathlibc}/${phase_dir}/glibc/$item/.sysrootsuccess" ]; then
            local to_copy_include_lib="yes"
            if [[ "x${install_full_libc}" == "xyes" ]]; then
                mkdir -p "${sysrootpathusr}/libc/$item"
                cp -r --preserve=links "${currentpathlibc}/install/glibc/$item"/* "${sysrootpathusr}/libc/$item"
            fi
            if [ $i -eq 0 ]; then
                if [[ "x${install_full_libc}" != "xyes" ]]; then
                    cp -r --preserve=links "${currentpathlibc}/install/glibc/$item"/* "${sysrootpathusr}/"
                    to_copy_include_lib="no"
                fi
            fi

            if [[ "x${to_copy_include_lib}" == "xyes" ]]; then
                cp -r --preserve=links "${currentpathlibc}/install/glibc/$item/include" "${sysrootpathusr}/"
                if [ $? -ne 0 ]; then
                    echo "cp failed:" cp -r --preserve=links "${currentpathlibc}/install/glibc/$item/include" "${sysrootpathusr}/"
                    exit 1
                fi
                mkdir -p "${sysrootpathusr}/$libdir"
                cp -r --preserve=links "${currentpathlibc}/install/glibc/$item/lib"/* "${sysrootpathusr}/$libdir"
                if [ $? -ne 0 ]; then
                    echo "cp failed:" cp -r --preserve=links "${currentpathlibc}/install/glibc/$item/lib/*" "${sysrootpathusr}/$libdir/"
                    exit 1
                fi
            fi
            echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/glibc/$item/.sysrootsuccess"
        fi
    done

    echo "$(date +%s)" > "${currentpathlibc}/install/.glibcinstallsuccess"
}

build_musl() {
    local host=$1
    local currentpathlibc=$2
    local sysrootpathusr=$3
    local usellvm=$4
    local headersonly=$5
    local buildmulitlib=$6
    local build=${7:-}
    local install_full_libc=${8:-no}

    local toolchains_path
    if [ -z ${TOOLCHAINS_BUILD+x} ]; then
        toolchains_path="$HOME/toolchains_build"
    else
        toolchains_path="$TOOLCHAINS_BUILD"
    fi

    local phase_dir
    if [ "$buildheadersonly" == "yes" ]; then
        phase_dir="build-headers"
    else
        phase_dir="build"
    fi
    mkdir -p "${currentpathlibc}/${phase_dir}/musl/default"
    cd "${currentpathlibc}/${phase_dir}/musl/default"

    mkdir -p "${sysrootpathusr}"
    if [ ! -f "${currentpathlibc}/${phase_dir}/musl/default/.configuresuccess" ]; then
        if [[ ${usellvm} == "yes" ]]; then
            LIPO=llvm-lipo \
            OTOOL=llvm-otool \
            DSYMUTIL=dsymutil \
            STRIP=llvm-strip \
            AR=llvm-ar \
            CC="clang --target=$host -fuse-ld=lld -fuse-lipo=llvm-lipo -rtlib=compiler-rt" \
            CXX="clang++ --target=$host -fuse-ld=lld -fuse-lipo=llvm-lipo -rtlib=compiler-rt" \
            AS=llvm-as \
            RANLIB=llvm-ranlib \
            CXXFILT=llvm-cxxfilt \
            NM=llvm-nm \
            LD=lld \
            OBJDUMP=llvm-objdump \
            READELF=llvm-readelf \
            SIZE=llvm-size \
            STRINGS=llvm-strings \
            OBJCOPY=llvm-objcopy \
            ADDR2LINE=llvm-addr2line \
            "$toolchains_path/musl/configure" \
            --disable-nls \
            --disable-werror \
            --prefix="$currentpathlibc/install/musl/default" \
            --with-headers="$sysrootpathusr/include" \
            --enable-shared \
            --enable-static \
            --without-selinux \
            --host="$host" \
            --exec-prefix="$currentpathlibc/install/musl/default" \
            --syslibdir="$sysrootpathusr/lib" \
            $( [ -n "$build" ] && echo "--build=$build" )
        else
            CC="$host-gcc" \
            CXX="$host-g++" \
            "$toolchains_path/musl/configure" \
            --disable-nls \
            --disable-werror \
            --prefix="$currentpathlibc/install/musl/default" \
            --with-headers="$sysrootpathusr/include" \
            --enable-shared \
            --enable-static \
            --without-selinux \
            --host="$host" \
            --exec-prefix="$currentpathlibc/install/musl/default" \
            --syslibdir="$sysrootpathusr/lib" \
            $( [ -n "$build" ] && echo "--build=$build" )
        fi

        if [ $? -ne 0 ]; then
            echo "musl configure failure"
            exit 1
        fi

        echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/musl/default/.configuresuccess"

    fi

    if [[ "$headersonly" == "yes" ]]; then
        if [ ! -f "${currentpathlibc}/${phase_dir}/musl/default/.headersinstallsuccess" ]; then
            if [[ ${usellvm} == "yes" ]]; then
                LD=lld make install-headers -j$(nproc)
            else
                (export -n LD_LIBRARY_PATH; make install-headers -j$(nproc))           
            fi
            if [ $? -ne 0 ]; then
                echo "musl install-headers failure"
                exit 1
            fi
            mkdir -p "$sysrootpathusr"
            cp -r --preserve=links "${currentpathlibc}/install/musl/default"/* "$sysrootpathusr/"
            echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/musl/default/.headersinstallsuccess"
        fi
        return
    fi

    if [ ! -f "${currentpathlibc}/${phase_dir}/musl/default/.buildsuccess" ]; then
        if [[ ${usellvm} == "yes" ]]; then
            LD=lld make -j$(nproc)
        else
            (export -n LD_LIBRARY_PATH; make -j$(nproc))           
        fi
        if [ $? -ne 0 ]; then
            echo "musl ${phase_dir} failure"
            exit 1
        fi
        echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/musl/default/.buildsuccess"
    fi

    if [ ! -f "${currentpathlibc}/${phase_dir}/musl/default/.installsuccess" ]; then
        if [[ ${usellvm} == "yes" ]]; then
            LD=lld make install -j$(nproc)
        else
            (export -n LD_LIBRARY_PATH; make install -j$(nproc))
        fi
        if [ $? -ne 0 ]; then
            echo "musl install failure"
            exit 1
        fi
        echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/musl/default/.installsuccess"
    fi

    if [ ! -f "${currentpathlibc}/${phase_dir}/musl/default/.stripsuccess" ]; then
        safe_llvm_strip "${currentpathlibc}/install/musl"
        echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/musl/default/.stripsuccess"
    fi

    if [ ! -f "${currentpathlibc}/${phase_dir}/musl/default/.sysrootsuccess" ]; then
        mkdir -p "$sysrootpathusr"
        cp -r --preserve=links "${currentpathlibc}/install/musl/default"/* "$sysrootpathusr/"

        for file in "$sysrootpathusr/lib"/ld-musl-*.so.1; do
            if [ -e "$file" ]; then
                ln -sf libc.so "$file"
            fi
        done

#        cp -r --preserve=links "${currentpathlibc}/install/musl/default/include" "$sysrootpathusr/"
#        mkdir -p "$sysrootpathusr/lib"
#        cp -r --preserve=links "${currentpathlibc}/install/musl/default/lib"/* "$sysrootpathusr/lib"/
        echo "$(date +%s)" > "${currentpathlibc}/${phase_dir}/musl/default/.sysrootsuccess"
    fi
}
