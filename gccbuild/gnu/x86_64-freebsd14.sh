#!/bin/bash

./dependencycheck.sh
if [ $? -ne 0 ]; then
exit 1
fi

relpath=$(realpath .)

if [ -z ${HOSTNOVERRSION+x} ]; then
	HOSTNOVERRSION=x86_64-freebsd
fi

if [ -z ${FREEBSDVERSION+x} ]; then
    FREEBSDVERSION=14
fi

if [ -z ${HOST+x} ]; then
	HOST=${HOSTNOVERRSION}${FREEBSDVERSION}
fi
if [ -z ${ARCH+x} ]; then
	ARCH=x86_64
fi
currentpath=$relpath/.gnuartifacts/$HOST
mkdir -p ${currentpath}
if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -z ${TOOLCHAINSPATH_GNU+x} ]; then
	TOOLCHAINSPATH_GNU=$TOOLCHAINSPATH/gnu
fi

mkdir -p "${TOOLCHAINSPATH_GNU}"


if [ -z ${CANADIANHOST+x} ]; then
	CANADIANHOST=x86_64-w64-mingw32
fi

BUILD=$(gcc -dumpmachine)
TARGET=$BUILD
PREFIX=$TOOLCHAINSPATH_GNU/$BUILD/$HOST
PREFIXTARGET=$PREFIX/$HOST
export PATH=$PREFIX/bin:$PATH
export -n LD_LIBRARY_PATH
HOSTPREFIX=$TOOLCHAINSPATH_GNU/$HOST/$HOST
HOSTPREFIXTARGET=$HOSTPREFIX/$HOST

export PATH=$TOOLCHAINSPATH_GNU/$BUILD/$CANADIANHOST/bin:$PATH
CANADIANHOSTPREFIX=$TOOLCHAINSPATH_GNU/$CANADIANHOST/$HOST

if [[ $1 == "clean" ]]; then
	echo "cleaning"
	rm -rf ${currentpath}
	echo "clean done"
	exit 0
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf ${currentpath}
	rm -rf ${PREFIX}
	rm -f ${PREFIX}.tar.xz
	rm -rf ${CANADIANHOSTPREFIX}
	rm -f ${CANADIANHOSTPREFIX}.tar.xz
	rm -rf ${HOSTPREFIXTARGET}
	rm -f ${HOSTPREFIXTARGET}.tar.xz
	echo "restart done"
fi

if [ ! -d ${currentpath} ]; then
	mkdir ${currentpath}
	cd ${currentpath}
fi

CROSSTRIPLETTRIPLETS="--build=$BUILD --host=$BUILD --target=$HOST"

GCCCONFIGUREFLAGSCOMMON="--disable-nls --disable-werror --enable-languages=c,c++ --disable-multilib --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --enable-libstdcxx-threads --enable-libstdcxx-backtrace"

if [[ ${ARCH} == "loongarch" ]]; then
ENABLEGOLD="--disable-tui --without-debuginfod"
else
ENABLEGOLD="--disable-tui --without-debuginfod --enable-gold"
fi

if ! $relpath/clonebinutilsgccwithdeps.sh
then
exit 1
fi

if [ ! -f ${currentpath}/$HOSTNOVERRSION-libc.tar.xz ]; then
cd ${currentpath}
wget https://github.com/trcrsired/x86_64-freebsd-libc-bin/releases/download/1/$HOSTNOVERRSION-libc.tar.xz
if [ $? -ne 0 ]; then
echo "wget failure"
exit 1
fi
fi

if [ ! -d ${currentpath}/$HOSTNOVERRSION-libc ]; then
cd ${currentpath}
tar xvf $HOSTNOVERRSION-libc.tar.xz
if [ $? -ne 0 ]; then
echo "tar unzip failure"
exit 1
fi
fi

SYSROOT=${currentpath}/$HOSTNOVERRSION-libc

if [[ ${USELLVM} == "yes" ]]; then
HOSTSTRIP=llvm-strip
else
HOSTSTRIP=$HOST-strip
fi
isnativebuild=
if [[ $BUILD == $HOST ]]; then
isnativebuild=yes
fi

if [[ $isnativebuild != "yes" ]]; then

if [ ! -f ${currentpath}/targetbuild/$HOST/binutils-gdb/.configuresuccess ]; then
mkdir -p ${currentpath}/targetbuild/$HOST/binutils-gdb
cd ${currentpath}/targetbuild/$HOST/binutils-gdb
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --with-python3 $ENABLEGOLD $CROSSTRIPLETTRIPLETS --prefix=$PREFIX
if [ $? -ne 0 ]; then
echo "binutils-gdb configure failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/binutils-gdb/.configuresuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/binutils-gdb/.buildsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/binutils-gdb
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "binutils-gdb build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/binutils-gdb/.buildsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/binutils-gdb/.installsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/binutils-gdb
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
echo "binutils-gdb install-strip failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/binutils-gdb/.installsuccess
fi

cd ${currentpath}
mkdir -p build


if [ ! -f ${currentpath}/.copycrossprefix ]; then

if [[ $isnativebuild == "yes" ]]; then
cp -r $SYSROOT/* $PREFIX/
else
cp -r $SYSROOT/* $PREFIXTARGET/
fi

echo "$(date --iso-8601=seconds)" > ${currentpath}/.copycrossprefix
fi


GCCVERSIONSTR=$(${HOST}-gcc -dumpversion)

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.configuresuccesss ]; then
mkdir -p ${currentpath}/targetbuild/$HOST/gcc_phase2
cd ${currentpath}/targetbuild/$HOST/gcc_phase2
STRIP=strip STRIP_FOR_TARGET=$HOSTSTRIP $TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX $CROSSTRIPLETTRIPLETS ${GCCCONFIGUREFLAGSCOMMON}
if [ $? -ne 0 ]; then
echo "gcc phase2 configure failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.configuresuccesss
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.buildgccsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/gcc_phase2
make all-gcc -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc phase2 build gcc failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.buildgccsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.generatelimitssuccess ]; then
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > ${currentpath}/targetbuild/$HOST/gcc_phase2/gcc/include/limits.h
if [ $? -ne 0 ]; then
echo "gcc phase2 generate limits failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.generatelimitssuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.buildsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/gcc_phase2
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc phase2 build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.buildsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.installstripsuccess ]; then
cd ${currentpath}/targetbuild/$HOST/gcc_phase2
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
make install -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc phase2 install strip failure"
exit 1
fi
${BUILD}-strip --strip-unneeded $prefix/bin/* $prefixtarget/bin/*
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.installstripsuccess
fi

TOOLCHAINS_BUILD=$TOOLCHAINS_BUILD TOOLCHAINSPATH_GNU=$TOOLCHAINSPATH_GNU GMPMPFRMPCHOST=$HOST GMPMPFRMPCBUILD=${currentpath}/targetbuild/$HOST GMPMPFRMPCPREFIX=$PREFIXTARGET $relpath/buildgmpmpfrmpc.sh
if [ $? -ne 0 ]; then
	echo "$HOST gmp mpfr mpc build failed"
	exit 1
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.packagingsuccess ]; then
cd ${TOOLCHAINSPATH_GNU}/${BUILD}
rm -f $HOST.tar.xz
XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
chmod 755 $HOST.tar.xz
echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.packagingsuccess
fi

fi

function handlebuild
{
local hosttriple=$1
local build_prefix=${currentpath}/${hosttriple}/${HOST}
local prefix=${TOOLCHAINSPATH_GNU}/${hosttriple}/${HOST}
local prefixtarget=${prefix}/${HOST}

mkdir -p ${build_prefix}

if [ ! -f ${build_prefix}/binutils-gdb/.configuresuccess ]; then
mkdir -p ${build_prefix}/binutils-gdb
cd $build_prefix/binutils-gdb
local extra_binutils_configure_flags=
local hostarch=${hosttriple%%-*}
if [[ ${hostarch} == "loongarch" || ${hostarch} == "loongarch64" ]]; then
# see issue https://sourceware.org/bugzilla/show_bug.cgi?id=32031
extra_binutils_configure_flags="--disable-gdbserver --disable-gdb"
fi
if [[ ${hosttriple} == ${HOST} && ${MUSLLIBC} == "yes" ]]; then
extra_binutils_configure_flags="--disable-plugins $extra_binutils_configure_flags"
fi
if [[ ${hosttriple} == ${HOST} ]]; then
extra_binutils_configure_flags="$extra_binutils_configure_flags"
fi
STRIP=${hosttriple}-strip STRIP_FOR_TARGET=$HOSTSTRIP $TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror $ENABLEGOLD --prefix=$prefix --build=$BUILD --host=$hosttriple --target=$HOST $extra_binutils_configure_flags
if [ $? -ne 0 ]; then
echo "binutils-gdb (${hosttriple}/${HOST}) configure failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${build_prefix}/binutils-gdb/.configuresuccess
fi

if [ ! -f ${build_prefix}/binutils-gdb/.buildsuccess ]; then
cd $build_prefix/binutils-gdb
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "binutils-gdb (${hosttriple}/${HOST}) build failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${build_prefix}/binutils-gdb/.buildsuccess
fi

if [ ! -f ${build_prefix}/binutils-gdb/.installsuccess ]; then
cd $build_prefix/binutils-gdb
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
make install -j$(nproc)
if [ $? -ne 0 ]; then
echo "binutils-gdb (${hosttriple}/${HOST}) install failed"
exit 1
fi
$hosttriple-strip --strip-unneeded $prefix/bin/* $prefixtarget/bin/*
fi
echo "$(date --iso-8601=seconds)" > ${build_prefix}/binutils-gdb/.installsuccess
fi

if [ ! -f ${build_prefix}/gcc/.configuresuccess ]; then
mkdir -p ${build_prefix}/gcc
cd $build_prefix/gcc
STRIP=${hosttriple}-strip STRIP_FOR_TARGET=$HOSTSTRIP $TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$prefixtarget/include/c++/v1 --prefix=$prefix --build=$BUILD --host=$hosttriple --target=$HOST $GCCCONFIGUREFLAGSCOMMON
if [ $? -ne 0 ]; then
echo "gcc (${hosttriple}/${HOST}) configure failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.configuresuccess
fi

if [ ! -f ${build_prefix}/gcc/.buildsuccess ]; then
cd $build_prefix/gcc
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc (${hosttriple}/${HOST}) build failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.buildsuccess
fi

if [ ! -f ${build_prefix}/gcc/.installsuccess ]; then
cd $build_prefix/gcc
make install-strip -j$(nproc)
if [ $? -ne 0 ]; then
make install -j$(nproc)
if [ $? -ne 0 ]; then
echo "gcc (${hosttriple}/${HOST}) install failed"
exit 1
fi
$hosttriple-strip --strip-unneeded $prefix/bin/* $prefixtarget/bin/*
fi
echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.installsuccess
fi

if [ ! -f ${build_prefix}/.installsysrootsuccess ]; then
local prefixcross=$prefix

if [[ ${hosttriple} != ${HOST} ]]; then
prefixcross=$prefix/$HOST
fi
cp -r --preserve=links $SYSROOT/* ${prefixcross}/
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > ${prefix}/lib/gcc/$HOST/$GCCVERSIONSTR/include/limits.h

echo "$(date --iso-8601=seconds)" > ${build_prefix}/.installsysrootsuccess
fi
if [ ! -f ${build_prefix}/.packagingsuccess ]; then
	cd ${TOOLCHAINSPATH_GNU}/${hosttriple}
	rm -f $HOST.tar.xz
	XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
	chmod 755 $HOST.tar.xz
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/.packagingsuccess
fi
}

handlebuild ${HOST}

if [[ ${CANADIANHOST} == ${HOST} ]]; then
exit 0
fi

if [ -x "$(command -v ${CANADIANHOST}-g++)" ]; then
handlebuild ${CANADIANHOST}
else
echo "${CANADIANHOST}-g++ not found. skipped"
fi
