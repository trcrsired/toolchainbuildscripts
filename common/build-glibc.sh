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
        echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/.linuxkernelheadersinstallsuccess"
    fi
}

build_glibc() {
    local cpu=$1
    local currentpathlibc=$2
    local sysrootpathusr=$3
    local buildmulitlib=$4
    local multilibs=(default)
    local multilibsoptions=("")
    local multilibsdir=("lib")
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
    mkdir -p "${sysrootpathusr}"
    mkdir -p "${currentpathlibc}/build/glibc"
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

        mkdir -p "${currentpathlibc}/build/glibc/$item"
        cd "${currentpathlibc}/build/glibc/$item"

        if [ ! -f "${currentpathlibc}/build/glibc/$item/.configuresuccess" ]; then
            (export -n LD_LIBRARY_PATH; CC="$host-gcc$marchitem" CXX="$host-g++$marchitem" "$toolchains_path/glibc/configure" --disable-nls --disable-werror --prefix="${currentpathlibc}/install/glibc/${item}" --build="$BUILD" --with-headers="${sysrootpathusr}/include" --without-selinux --host="$host" )
            if [ $? -ne 0 ]; then
                echo "glibc ($item) configure failure"
                exit 1
            fi
            echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/build/glibc/$item/.configuresuccess"
        fi

        if [ ! -f "${currentpathlibc}/build/glibc/$item/.buildsuccess" ]; then
            (export -n LD_LIBRARY_PATH; make -j$(nproc))
            if [ $? -ne 0 ]; then
                echo "glibc ($item) build failure"
                exit 1
            fi
            echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/build/glibc/$item/.buildsuccess"
        fi

        if [ ! -f "${currentpathlibc}/build/glibc/$item/.installsuccess" ]; then
            (export -n LD_LIBRARY_PATH; make install -j$(nproc))
            if [ $? -ne 0 ]; then
                echo "glibc ($item) install failure"
                exit 1
            fi
            echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/build/glibc/$item/.installsuccess"
        fi

        if [ ! -f "${currentpathlibc}/build/glibc/$item/.removehardcodedpathsuccess" ]; then
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
            echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/build/glibc/$item/.removehardcodedpathsuccess"
        fi

        if [ ! -f "${currentpathlibc}/build/glibc/$item/.stripsuccess" ]; then
            safe_llvm_strip "${currentpathlibc}/install/glibc/${item}"
            echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/build/glibc/$item/.stripsuccess"
        fi
        if [ ! -f "${currentpathlibc}/build/glibc/$item/.sysrootsuccess" ]; then
            if [ $i -eq 0 ]; then
                cp -r --preserve=links "${currentpathlibc}/install/glibc/$item"/* "${sysrootpathusr}/"
            else
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
            echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/build/glibc/$item/.sysrootsuccess"
        fi
    done

    echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/install/.glibcinstallsuccess"
}

build_musl() {
    local host=$1
    local currentpathlibc=$2
    local sysrootpathusr=$3
    local usellvm=$4
    local build=${5:-}

    mkdir -p "${currentpathlibc}/build/musl/default"
    cd "${currentpathlibc}/build/musl/default"
    local toolchains_path
    if [ -z ${TOOLCHAINS_BUILD+x} ]; then
        toolchains_path="$HOME/toolchains_build"
    else
        toolchains_path="$TOOLCHAINS_BUILD"
    fi
    mkdir -p "${sysrootpathusr}"
    if [ ! -f "${currentpathlibc}/build/musl/default/.configuresuccess" ]; then
        if [[ ${usellvm} == "yes" ]]; then
            LIPO=llvm-lipo \
            OTOOL=llvm-otool \
            DSYMUTIL=dsymutil \
            STRIP=llvm-strip \
            AR=llvm-ar \
            CC="clang --target=$host" \
            CXX="clang++ --target=$host" \
            AS=llvm-as \
            RANLIB=llvm-ranlib \
            CXXFILT=llvm-cxxfilt \
            NM=llvm-nm \
            "$toolchains_path/musl/configure" \
            --disable-nls \
            --disable-werror \
            --prefix="$currentpathlibc/install/musl/default" \
            --with-headers="$sysrootpathusr/include" \
            --enable-shared \
            --enable-static \
            --without-selinux \
            --host="$host" \
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
            $( [ -n "$build" ] && echo "--build=$build" )
        fi

        if [ $? -ne 0 ]; then
            echo "musl configure failure"
            exit 1
        fi

        echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/build/musl/default/.configuresuccess"

    fi

    if [ ! -f "${currentpathlibc}/build/musl/default/.buildsuccess" ]; then
        if [[ ${usellvm} == "yes" ]]; then
            make -j$(nproc)
        else
            (export -n LD_LIBRARY_PATH; make -j$(nproc))           
        fi
        if [ $? -ne 0 ]; then
            echo "musl build failure"
            exit 1
        fi
        echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/build/musl/default/.buildsuccess"
    fi

    if [ ! -f "${currentpathlibc}/build/musl/default/.installsuccess" ]; then
        if [[ ${usellvm} == "yes" ]]; then
            make install -j$(nproc)
        else
            (export -n LD_LIBRARY_PATH; make install -j$(nproc))
        fi
        if [ $? -ne 0 ]; then
            echo "musl install failure"
            exit 1
        fi
        echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/build/musl/default/.installsuccess"
    fi

    if [ ! -f "${currentpathlibc}/build/musl/default/.stripsuccess" ]; then
        safe_llvm_strip "${currentpathlibc}/install/musl"
        echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/build/musl/default/.stripsuccess"
    fi

    if [ ! -f "${currentpathlibc}/build/musl/default/.sysrootsuccess" ]; then
        mkdir -p "$sysrootpathusr"
        cp -r --preserve=links "${currentpathlibc}/install/musl/default"/* "$sysrootpathusr/"

#        cp -r --preserve=links "${currentpathlibc}/install/musl/default/include" "$sysrootpathusr/"
#        mkdir -p "$sysrootpathusr/lib"
#        cp -r --preserve=links "${currentpathlibc}/install/musl/default/lib"/* "$sysrootpathusr/lib"/
#        echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/build/musl/default/.sysrootsuccess"
    fi

    echo "$(date --iso-8601=seconds)" > "${currentpathlibc}/install/.muslinstallsuccess"
}
