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

if [ -z ${GMPMPFRMPCHOSTALTERNATIVE+x} ]; then
GMPMPFRMPCHOSTALTERNATIVE=$(echo $GMPMPFRMPCHOST | sed 's/^[^-]*/none/')
fi

echo "GMPMPFRMPCHOSTALTERNATIVE" $GMPMPFRMPCHOSTALTERNATIVE

GMPMPFRMPCCONFIGURE="--disable-nls --disable-werror --disable-option-checking --prefix=${GMPMPFRMPCPREFIX} --disable-shared --enable-static --disable-multilib --disable-assembly --host=$GMPMPFRMPCHOSTALTERNATIVE"

if [ ! -f ${GMPMPFRMPCBUILD}/gmp/.configuregmp ]; then
mkdir -p ${GMPMPFRMPCBUILD}/gmp
cd ${GMPMPFRMPCBUILD}/gmp
CC=$GMPMPFRMPCHOST-gcc CXX=$GMPMPFRMPCHOST-g++ CC_FOR_BUILD=gcc CXX_FOR_BUILD=g++ CXX_FOR_BUILD=g++ CPP="$GMPMPFRMPCHOST-gcc -E" CXXCPP="$GMPMPFRMPCHOST-g++ -E" AS="$GMPMPFRMPCHOST-as" STRIP="$GMPMPFRMPCHOST-strip" $TOOLCHAINS_BUILD/gmp/configure $GMPMPFRMPCCONFIGURE
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



if [ ! -f ${GMPMPFRMPCBUILD}/mpfr/.configurempfr ]; then
mkdir -p ${GMPMPFRMPCBUILD}/mpfr
cd ${GMPMPFRMPCBUILD}/mpfr
CC=$GMPMPFRMPCHOST-gcc CXX=$GMPMPFRMPCHOST-g++ CC_FOR_BUILD=gcc CXX_FOR_BUILD=g++ CPP="$GMPMPFRMPCHOST-gcc -E" CXXCPP="$GMPMPFRMPCHOST-g++ -E" DLLTOOL="$GMPMPFRMPCHOST-dlltool" NM="$GMPMPFRMPCHOST-nm" RANLIB="$GMPMPFRMPCHOST-ranlib" AR="$GMPMPFRMPCHOST-ar" AS="$GMPMPFRMPCHOST-as" STRIP="$GMPMPFRMPCHOST-strip" $TOOLCHAINS_BUILD/mpfr/configure $GMPMPFRMPCCONFIGURE
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



if [ ! -f ${GMPMPFRMPCBUILD}/mpc/.configurempc ]; then
mkdir -p ${GMPMPFRMPCBUILD}/mpc
cd ${GMPMPFRMPCBUILD}/mpc
CC=$GMPMPFRMPCHOST-gcc CXX=$GMPMPFRMPCHOST-g++ CC_FOR_BUILD=gcc CXX_FOR_BUILD=g++ CPP="$GMPMPFRMPCHOST-gcc -E" CXXCPP="$GMPMPFRMPCHOST-g++ -E" DLLTOOL="$GMPMPFRMPCHOST-dlltool" NM="$GMPMPFRMPCHOST-nm" RANLIB="$GMPMPFRMPCHOST-ranlib" AR="$GMPMPFRMPCHOST-ar" AS="$GMPMPFRMPCHOST-as" STRIP="$GMPMPFRMPCHOST-strip" $TOOLCHAINS_BUILD/mpc/configure $GMPMPFRMPCCONFIGURE
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

