build_glibc() {
    local cpu=$1
    local currentpath=$2
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

    mkdir -p ${currentpath}/build/glibc
    local toolchains_path
    if [ -z ${TOOLCHAINS_BUILD+x} ]; then
        toolchains_path=$HOME/toolchains_build
    else
        toolchains_path=$TOOLCHAINS_BUILD
    fi
    for i in "${!multilibs[@]}"; do
        local item=${multilibs[$i]}
        local marchitem=${multilibsoptions[$i]}
        local libdir=${multilibsdir[$i]}
        local host=${multilibshost[$i]}

        mkdir -p ${currentpath}/build/glibc/$item
        cd ${currentpath}/build/glibc/$item

        if [ ! -f ${currentpath}/build/glibc/$item/.configuresuccess ]; then
            (export -n LD_LIBRARY_PATH; CC="$HOST-gcc$marchitem" CXX="$HOST-g++$marchitem" $toolchains_path/glibc/configure --disable-nls --disable-werror --prefix=$currentpath/install/glibc/${item} --build=$BUILD --with-headers=${sysrootpathusr}/include --without-selinux --host=$host )
            if [ $? -ne 0 ]; then
                echo "glibc ($item) configure failure"
                exit 1
            fi
            echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.configuresuccess
        fi

        if [ ! -f ${currentpath}/build/glibc/$item/.buildsuccess ]; then
            (export -n LD_LIBRARY_PATH; make -j$(nproc))
            if [ $? -ne 0 ]; then
                echo "glibc ($item) build failure"
                exit 1
            fi
            echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.buildsuccess
        fi

        if [ ! -f ${currentpath}/build/glibc/$item/.installsuccess ]; then
            (export -n LD_LIBRARY_PATH; make install -j$(nproc))
            if [ $? -ne 0 ]; then
                echo "glibc ($item) install failure"
                exit 1
            fi
            echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.installsuccess
        fi

        if [ ! -f ${currentpath}/build/glibc/$item/.removehardcodedpathsuccess ]; then
            local canadianreplacedstring=$currentpath/install/glibc/${item}/lib/
            for file in "${glibcfiles[@]}"; do
                local filepath=$canadianreplacedstring/$file
                if [ -f "$filepath" ]; then
                    local getfilesize=$(wc -c <"$filepath")
                    echo $getfilesize
                    if [ $getfilesize -lt 1024 ]; then
                        sed -i "s%${canadianreplacedstring}%%g" $filepath
                        echo "removed hardcoded path: $filepath"
                    fi
                fi
            done
            echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.removehardcodedpathsuccess
        fi

        if [ ! -f ${currentpath}/build/glibc/$item/.stripsuccess ]; then
            safe_llvm_strip "$currentpath/install/glibc/${item}/lib"
            echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.stripsuccess
        fi

        if [ ! -f ${currentpath}/build/glibc/$item/.sysrootsuccess ]; then
            cp -r --preserve=links ${currentpath}/install/glibc/$item/include ${sysrootpathusr}/
            mkdir -p ${sysrootpathusr}/$libdir
            cp -r --preserve=links ${currentpath}/install/glibc/$item/lib/* ${sysrootpathusr}/$libdir
            echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.sysrootsuccess
        fi
    done

    echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.glibcinstallsuccess
}

