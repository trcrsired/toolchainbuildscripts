echo "TOOLCHAINS_BUILD" $TOOLCHAINS_BUILD
echo "TOOLCHAINSPATH" $TOOLCHAINSPATH
echo "GMPMPFRMPCHOST" $GMPMPFRMPCHOST
echo "GMPMPFRMPCPREFIX" $GMPMPFRMPCPREFIX
echo "GMPMPFRMPCBUILD" $GMPMPFRMPCBUILD

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	echo "GMP MPFR MPC no $TOOLCHAINS_BUILD defined"
	exit 1
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	echo "GMP MPFR MPC no $TOOLCHAINSPATH defined"
	exit 1
fi

if [ -z ${GMPMPFRMPCHOST+x} ]; then
	echo "GMP MPFR MPC no host"
	exit 1
fi

if [ -z ${GMPMPFRMPCPREFIX+x} ]; then
	echo "GMP MPFR MPC no PREFIX"
	exit 1
fi

if [ -z ${GMPMPFRMPCBUILD+x} ]; then
	echo "GMP MPFR MPC no build"
	exit 1
fi

if [ -z "${GMPMPFRMPCBUILDCMAKE_SYSTEM_NAME+x}" ]; then

    LAST_PART=$(echo "$GMPMPFRMPCHOST" | awk -F'-' '{print $NF}')
    SECOND_LAST_PART=$(echo "$GMPMPFRMPCHOST" | awk -F'-' '{print $(NF-1)}')

    if [[ "$LAST_PART" == "mingw32" ]]; then
        GMPMPFRMPCBUILDCMAKE_SYSTEM_NAME=Windows
    elif [[ "$LAST_PART" == "msdosdjgpp" ]]; then
        GMPMPFRMPCBUILDCMAKE_SYSTEM_NAME=DOS
    elif [[ "$LAST_PART" == "cygwin" ]]; then
        GMPMPFRMPCBUILDCMAKE_SYSTEM_NAME=CYGWIN
    elif [[ "$LAST_PART" == "msys" ]]; then
        GMPMPFRMPCBUILDCMAKE_SYSTEM_NAME=MSYS
    elif [[ "$LAST_PART" == freebsd* ]]; then
        GMPMPFRMPCBUILDCMAKE_SYSTEM_NAME=Freebsd
    elif [[ "$LAST_PART" == "linux" || "$SECOND_LAST_PART" == "linux" ]]; then
        GMPMPFRMPCBUILDCMAKE_SYSTEM_NAME=Linux
    else
        GMPMPFRMPCBUILDCMAKE_SYSTEM_NAME=Generic
    fi
    echo "$LAST_PART"
    echo "$GMPMPFRMPCBUILDCMAKE_SYSTEM_NAME"

fi
FIRST_PART=$(echo "$GMPMPFRMPCHOST" | cut -d'-' -f1)

if [ -z "${GMPMPFRMPCBUILDUSEALTERNATIVELIB+x}" ]; then
    if [[ "$FIRST_PART" == "loongarch64" && "$GMPMPFRMPCBUILDCMAKE_SYSTEM_NAME" == "Linux" ]]; then
        GMPMPFRMPCBUILDUSEALTERNATIVELIB="lib64"
    fi
fi


if [ -z ${GMPMPFRMPCHOSTALTERNATIVE+x} ]; then
GMPMPFRMPCHOSTALTERNATIVE=$(echo $GMPMPFRMPCHOST | sed 's/^[^-]*/none/')
fi

echo "GMPMPFRMPCHOSTALTERNATIVE" $GMPMPFRMPCHOSTALTERNATIVE


GMPMPFRMPCBUILD_DEPINSTALLS="${GMPMPFRMPCBUILD}/depinstalls"

mkdir -p "${GMPMPFRMPCBUILD_DEPINSTALLS}"

GMPMPFRMPCCONFIGURE="--disable-nls --disable-werror --disable-option-checking --disable-shared --enable-static --disable-multilib --disable-assembly --host=$GMPMPFRMPCHOSTALTERNATIVE"

if [ ! -f ${GMPMPFRMPCBUILD}/gmp/.configuregmp ]; then
mkdir -p ${GMPMPFRMPCBUILD}/gmp
cd ${GMPMPFRMPCBUILD}/gmp
CC=$GMPMPFRMPCHOST-gcc CXX=$GMPMPFRMPCHOST-g++ CC_FOR_BUILD=gcc CXX_FOR_BUILD=g++ CXX_FOR_BUILD=g++ CPP="$GMPMPFRMPCHOST-gcc -E" CXXCPP="$GMPMPFRMPCHOST-g++ -E" AS="$GMPMPFRMPCHOST-as" STRIP="$GMPMPFRMPCHOST-strip" $TOOLCHAINS_BUILD/gmp/configure $GMPMPFRMPCCONFIGURE --prefix="${GMPMPFRMPCBUILD_DEPINSTALLS}/gmp"
if [ $? -ne 0 ]; then
	echo "GMP configure failed"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/gmp/.configuregmp
fi

if [ ! -f ${GMPMPFRMPCBUILD}/gmp/.buildgmp ]; then
cd ${GMPMPFRMPCBUILD}/gmp
make -j$(nproc)
if [ $? -ne 0 ]; then
	echo "GMP build"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/gmp/.buildgmp
fi

if [ ! -f ${GMPMPFRMPCBUILD}/gmp/.installgmp ]; then
cd ${GMPMPFRMPCBUILD}/gmp
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
	echo "GMP install/strip"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/gmp/.installgmp
fi

if [ ! -f "${GMPMPFRMPCBUILD_DEPINSTALLS}/gmp/.installgmpcopy" ]; then
    if [ -n "${GMPMPFRMPCBUILDUSEALTERNATIVELIB+x}" ]; then
        cd "${GMPMPFRMPCBUILD_DEPINSTALLS}/gmp"
        mv lib "${GMPMPFRMPCBUILDUSEALTERNATIVELIB}"
    fi
    cp -a "${GMPMPFRMPCBUILD_DEPINSTALLS}/gmp"/* "${GMPMPFRMPCPREFIX}/"
    echo "$(date --iso-8601=seconds)" > "${GMPMPFRMPCBUILD_DEPINSTALLS}/gmp/.installgmpcopy"
fi

if [ ! -f ${GMPMPFRMPCBUILD}/mpfr/.configurempfr ]; then
mkdir -p ${GMPMPFRMPCBUILD}/mpfr
cd ${GMPMPFRMPCBUILD}/mpfr
CC=$GMPMPFRMPCHOST-gcc CXX=$GMPMPFRMPCHOST-g++ CC_FOR_BUILD=gcc CXX_FOR_BUILD=g++ CPP="$GMPMPFRMPCHOST-gcc -E" CXXCPP="$GMPMPFRMPCHOST-g++ -E" DLLTOOL="$GMPMPFRMPCHOST-dlltool" NM="$GMPMPFRMPCHOST-nm" RANLIB="$GMPMPFRMPCHOST-ranlib" AR="$GMPMPFRMPCHOST-ar" AS="$GMPMPFRMPCHOST-as" STRIP="$GMPMPFRMPCHOST-strip" $TOOLCHAINS_BUILD/mpfr/configure $GMPMPFRMPCCONFIGURE --prefix="${GMPMPFRMPCBUILD_DEPINSTALLS}/mpfr"
if [ $? -ne 0 ]; then
	echo "MPFR configure failed"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/mpfr/.configurempfr
fi

if [ ! -f ${GMPMPFRMPCBUILD}/mpfr/.buildmpfr ]; then
cd ${GMPMPFRMPCBUILD}/mpfr
make -j$(nproc)
if [ $? -ne 0 ]; then
	echo "MPFR build"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/mpfr/.buildmpfr
fi

if [ ! -f ${GMPMPFRMPCBUILD}/mpfr/.installmpfr ]; then
cd ${GMPMPFRMPCBUILD}/mpfr
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
	echo "MPFR install/strip"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/mpfr/.installmpfr
fi

if [ ! -f "${GMPMPFRMPCBUILD_DEPINSTALLS}/mpfr/.installmpfrcopy" ]; then
    if [ -n "${GMPMPFRMPCBUILDUSEALTERNATIVELIB+x}" ]; then
        cd "${GMPMPFRMPCBUILD_DEPINSTALLS}/mpfr"
        mv lib "${GMPMPFRMPCBUILDUSEALTERNATIVELIB}"
    fi
    cp -a "${GMPMPFRMPCBUILD_DEPINSTALLS}/mpfr"/* "${GMPMPFRMPCPREFIX}/"
    echo "$(date --iso-8601=seconds)" > "${GMPMPFRMPCBUILD_DEPINSTALLS}/mpfr/.installmpfrcopy"
fi

if [ ! -f ${GMPMPFRMPCBUILD}/mpc/.configurempc ]; then
mkdir -p ${GMPMPFRMPCBUILD}/mpc
cd ${GMPMPFRMPCBUILD}/mpc
CC=$GMPMPFRMPCHOST-gcc CXX=$GMPMPFRMPCHOST-g++ CC_FOR_BUILD=gcc CXX_FOR_BUILD=g++ CPP="$GMPMPFRMPCHOST-gcc -E" CXXCPP="$GMPMPFRMPCHOST-g++ -E" DLLTOOL="$GMPMPFRMPCHOST-dlltool" NM="$GMPMPFRMPCHOST-nm" RANLIB="$GMPMPFRMPCHOST-ranlib" AR="$GMPMPFRMPCHOST-ar" AS="$GMPMPFRMPCHOST-as" STRIP="$GMPMPFRMPCHOST-strip" $TOOLCHAINS_BUILD/mpc/configure $GMPMPFRMPCCONFIGURE --prefix="${GMPMPFRMPCBUILD_DEPINSTALLS}/mpc"
if [ $? -ne 0 ]; then
	echo "MPC configure failed"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/mpc/.configurempc
fi

if [ ! -f ${GMPMPFRMPCBUILD}/mpc/.buildmpc ]; then
cd ${GMPMPFRMPCBUILD}/mpc
make -j$(nproc)
if [ $? -ne 0 ]; then
	echo "MPC build failed"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/mpc/.buildmpc
fi

if [ ! -f ${GMPMPFRMPCBUILD}/mpc/.installmpc ]; then
cd ${GMPMPFRMPCBUILD}/mpc
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
	echo "MPC install/strip failed"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/mpc/.installmpc
fi

if [ ! -f "${GMPMPFRMPCBUILD_DEPINSTALLS}/mpc/.installmpccopy" ]; then
    if [ -n "${GMPMPFRMPCBUILDUSEALTERNATIVELIB+x}" ]; then
        cd "${GMPMPFRMPCBUILD_DEPINSTALLS}/mpc"
        mv lib "${GMPMPFRMPCBUILDUSEALTERNATIVELIB}"
    fi
    cp -a "${GMPMPFRMPCBUILD_DEPINSTALLS}/mpc"/* "${GMPMPFRMPCPREFIX}/"
    echo "$(date --iso-8601=seconds)" > "${GMPMPFRMPCBUILD_DEPINSTALLS}/mpc/.installmpccopy"
fi

if [[ "x${NO_BUILD_ZSTD}" != "xyes" ]]; then

if [ ! -f ${GMPMPFRMPCBUILD}/zstd/.configurezstd ]; then
mkdir -p ${GMPMPFRMPCBUILD}/zstd
cd ${GMPMPFRMPCBUILD}/zstd
cmake -DCMAKE_BUILD_TYPE=Release -GNinja \
	$TOOLCHAINS_BUILD/zstd/build/cmake \
	-DCMAKE_C_COMPILER=$GMPMPFRMPCHOST-gcc \
	-DCMAKE_CXX_COMPILER=$GMPMPFRMPCHOST-g++ \
	-DCMAKE_ASM_COMPILER=$GMPMPFRMPCHOST-gcc \
	-DCMAKE_INSTALL_PREFIX="${GMPMPFRMPCBUILD_DEPINSTALLS}/zstd" \
	-DZSTD_PROGRAMS_LINK_SHARED=Off \
	-DCMAKE_SYSTEM_NAME=${GMPMPFRMPCBUILDCMAKE_SYSTEM_NAME} \
	-DCMAKE_CROSSCOMPILING=On \
	-DCMAKE_SYSTEM_PROCESSOR=${FIRST_PART}
if [ $? -ne 0 ]; then
	cmake -DCMAKE_BUILD_TYPE=Release -GNinja \
		$TOOLCHAINS_BUILD/zstd/build/cmake \
		-DCMAKE_C_COMPILER=$GMPMPFRMPCHOST-gcc \
		-DCMAKE_CXX_COMPILER=$GMPMPFRMPCHOST-g++ \
		-DCMAKE_ASM_COMPILER=$GMPMPFRMPCHOST-gcc \
		-DCMAKE_INSTALL_PREFIX="${GMPMPFRMPCBUILD_DEPINSTALLS}/zstd" \
		-DZSTD_PROGRAMS_LINK_SHARED=Off \
		-DZSTD_MULTITHREAD_SUPPORT=Off \
		-DCMAKE_SYSTEM_NAME=${GMPMPFRMPCBUILDCMAKE_SYSTEM_NAME} \
		-DCMAKE_CROSSCOMPILING=On \
		-DCMAKE_SYSTEM_PROCESSOR=${FIRST_PART}
	if [ $? -ne 0 ]; then
		echo "zstd cmake configure failed"
		exit 1
	fi
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/zstd/.configurezstd
fi

if [ ! -f ${GMPMPFRMPCBUILD}/zstd/.ninjazstd ]; then
mkdir -p ${GMPMPFRMPCBUILD}/zstd
cd ${GMPMPFRMPCBUILD}/zstd
ninja
if [ $? -ne 0 ]; then
	echo "zstd ninja failed"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/zstd/.ninjazstd
fi

if [ ! -f ${GMPMPFRMPCBUILD}/zstd/.ninjazstdinstallstrip ]; then
	mkdir -p ${GMPMPFRMPCBUILD}/zstd
	cd ${GMPMPFRMPCBUILD}/zstd
	ninja install/strip
	if [ $? -ne 0 ]; then
		echo "zstd ninja install/strip failed"
		exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/zstd/.ninjazstdinstallstrip
fi

if [ ! -f "${GMPMPFRMPCBUILD_DEPINSTALLS}/zstd/.installzstdcopy" ]; then
	rm -f "${GMPMPFRMPCBUILD_DEPINSTALLS}/zstd/bin/libzstd.dll"
	rm -f "${GMPMPFRMPCBUILD_DEPINSTALLS}/zstd/lib/libzstd.dll.a"
    if [ -n "${GMPMPFRMPCBUILDUSEALTERNATIVELIB+x}" ]; then
        cd "${GMPMPFRMPCBUILD_DEPINSTALLS}/zstd"
        mv lib "${GMPMPFRMPCBUILDUSEALTERNATIVELIB}"
    fi
    cp -a "${GMPMPFRMPCBUILD_DEPINSTALLS}/zstd"/* "${GMPMPFRMPCPREFIX}/"
    echo "$(date --iso-8601=seconds)" > "${GMPMPFRMPCBUILD_DEPINSTALLS}/zstd/.installzstdcopy"
fi
fi
