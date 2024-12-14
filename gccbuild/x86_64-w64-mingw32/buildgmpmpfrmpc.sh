echo "TOOLCHAINS_BUILD" $TOOLCHAINS_BUILD
echo "TOOLCHAINSPATH" $TOOLCHAINSPATH
echo "GMPMPFRMPCHOST" $GMPMPFRMPCHOST
echo "GMPMPFRMPCPREFIX" $GMPMPFRMPCPREFIX
echo "GMPMPFRMPCBUILD" $GMPMPFRMPCBUILD

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -n ${GMPMPFRMPCHOST+x} ]; then
	echo "GMP MPFR MPC no host"
	exit 1
fi

if [ -n ${GMPMPFRMPCPREFIX+x} ]; then
	echo "GMP MPFR MPC no PREFIX"
	exit 1
fi

if [ -n ${GMPMPFRMPCBUILD+x} ]; then
	echo "GMP MPFR MPC no build"
	exit 1
fi



if [ ! -f ${GMPMPFRMPCBUILD}/gmp/.configuregmp ]; then
mkdir -p ${GMPMPFRMPCBUILD}/gmp
cd ${GMPMPFRMPCBUILD}/gmp
$TOOLCHAINS_BUILD/gmp/configure --disable-nls --disable-werror --prefix=${GMPMPFRMPCPREFIX} --host=${GMPMPFRMPCHOST} --disable-shared --enable-static
if [ $? -ne 0 ]; then
	echo "GMP configure failed"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/gmp/.configuregmp
fi

if [ ! -f ${GMPMPFRMPCBUILD}/gmp/.buildgmp ]; then
cd ${GMPMPFRMPCPREFIX}/gmp
make -j$(nproc)
if [ $? -ne 0 ]; then
	echo "GMP build"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/gmp/.buildgmp
fi

if [ ! -f ${GMPMPFRMPCBUILD}/gmp/.installgmp ]; then
cd ${GMPMPFRMPCPREFIX}/gmp
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
$TOOLCHAINS_BUILD/mpfr/configure --disable-nls --disable-werror --prefix=${GMPMPFRMPCPREFIX} --host=${GMPMPFRMPCHOST} --disable-shared --enable-static
if [ $? -ne 0 ]; then
	echo "MPFR configure failed"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/mpfr/.configurempfr
fi

if [ ! -f ${GMPMPFRMPCBUILD}/mpfr/.buildmpfr ]; then
cd ${GMPMPFRMPCPREFIX}/mpfr
make -j$(nproc)
if [ $? -ne 0 ]; then
	echo "MPFR build"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/mpfr/.buildmpfr
fi

if [ ! -f ${GMPMPFRMPCBUILD}/mpfr/.installmpfr ]; then
cd ${GMPMPFRMPCPREFIX}/mpfr
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
$TOOLCHAINS_BUILD/mpc/configure --disable-nls --disable-werror --prefix=${GMPMPFRMPCPREFIX} --host=${GMPMPFRMPCHOST} --disable-shared --enable-static
if [ $? -ne 0 ]; then
	echo "MPC configure failed"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/mpc/.configurempc
fi

if [ ! -f ${GMPMPFRMPCBUILD}/mpc/.buildmpc ]; then
cd ${GMPMPFRMPCPREFIX}/mpc
make -j$(nproc)
if [ $? -ne 0 ]; then
	echo "MPC build"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/mpc/.buildmpc
fi

if [ ! -f ${GMPMPFRMPCBUILD}/mpc/.installmpc ]; then
cd ${GMPMPFRMPCPREFIX}/mpc
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
	echo "MPC install/strip"
	exit 1
fi
echo "$(date --iso-8601=seconds)" > ${GMPMPFRMPCBUILD}/mpc/.installmpc
fi

