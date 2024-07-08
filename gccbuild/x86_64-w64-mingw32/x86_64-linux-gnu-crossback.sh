#!/bin/bash
BUILD=$(gcc -dumpmachine)
currentpath=$relpath/.gnuartifacts/$BUILD
if [ ! -d ${currentpath} ]; then
	mkdir ${currentpath}
	cd ${currentpath}
fi

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

mkdir -p $currentpath/build
mkdir -p $currentpath/build/build
mkdir -p $currentpath/build/install
linuxkernelheaders=$currentpath/build/install/headers
if [ -z ${HOST+x} ]; then
	HOST=x86_64-w64-mingw32
fi

TARGET=$BUILD
PREFIX=$TOOLCHAINSPATH/$HOST/$TARGET
PREFIXTARGET=$PREFIX/$TARGET

export PATH=$TOOLCHAINSPATH/$TARGET/$HOST/bin:$PATH
export -n LD_LIBRARY_PATH
if [ -z ${GLIBCBRANCH+x} ]; then
GLIBCBRANCH="master"
fi
if [ -z ${GLIBCREPOPATH+x} ]; then
GLIBCREPOPATH="$TOOLCHAINS_BUILD/glibc"
fi
GCCVERSIONSTR=$(${TARGET}-gcc -dumpversion)
if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf ${currentpath}
	rm -rf ${PREFIX}
	rm -f "$PREFIXTARGET.tar.xz"
	echo "restart done"
fi
mkdir -p ${currentpath}
if [[ ${HOST} == ${BUILD} ]]; then
	PREFIXTARGET=$PREFIX
fi
TRIPLETTRIPLETS="--build=$TARGET --host=$HOST --target=$TARGET"

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/binutils-gdb" ]; then
git clone git://sourceware.org/git/binutils-gdb.git
if [ $? -ne 0 ]; then
echo "binutils-gdb clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/binutils-gdb"
git pull --quiet

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/gcc" ]; then
git clone git://gcc.gnu.org/git/gcc.git
if [ $? -ne 0 ]; then
echo "gcc clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/gcc"
git pull --quiet

if [ ! -L "$TOOLCHAINS_BUILD/gcc/gmp" ]; then
cd $TOOLCHAINS_BUILD/gcc
./contrib/download_prerequisites
fi

if [ ! -L "$TOOLCHAINS_BUILD/binutils-gdb/gmp" ]; then
cd $TOOLCHAINS_BUILD/binutils-gdb
ln -s ../gcc/gmp gmp
ln -s ../gcc/mpfr mpfr
ln -s ../gcc/mpc mpc
fi

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/mingw-w64" ]; then
git clone https://git.code.sf.net/p/mingw-w64/mingw-w64
if [ $? -ne 0 ]; then
echo "mingw-w64 clone failed"
fi
fi
cd "$TOOLCHAINS_BUILD/mingw-w64"
git pull --quiet

if [ ! -d "$GLIBCREPOPATH" ]; then
cd "$TOOLCHAINS_BUILD"
git clone -b $GLIBCBRANCH git://sourceware.org/git/glibc.git "$GLIBCREPOPATH"
if [ $? -ne 0 ]; then
echo "glibc clone failed"
exit 1
fi
fi
cd "$GLIBCREPOPATH"
git pull --quiet

if [ ! -d "$TOOLCHAINS_BUILD/linux" ]; then
cd "$TOOLCHAINS_BUILD"
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
if [ $? -ne 0 ]; then
echo "linux clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/linux"
git pull --quiet

if [ ! -d $linuxkernelheaders/include/linux ]; then
make headers_install ARCH=x86_64 -j INSTALL_HDR_PATH=$linuxkernelheaders
fi
cd $currentpath/build/build
multilibs=(m64)
multilibsdir=(lib64)
glibcfiles=(libm.a libm.so libc.so)

for item in "${multilibs[@]}"; do
	mkdir -p $item
	cd $item
	if [[ "$item" == "m32" ]]; then
		host=i686-linux-gnu
	elif [[ "$item" == "mx32" ]]; then
		host=x86_64-linux-gnux32
	else
		host=x86_64-linux-gnu
	fi
	if [ ! -f Makefile ]; then
		(export -n LD_LIBRARY_PATH; CC="gcc -${item}" CXX="g++ -${item}" $GLIBCREPOPATH/configure --disable-nls --disable-werror --prefix=$currentpath/build/install/${item} --build=$BUILD --with-headers=$linuxkernelheaders/include --without-selinux --host=${host} )
	fi
	if [[ ! -d $currentpath/build/install/${item} ]]; then
		(export -n LD_LIBRARY_PATH; make -j16)
		(export -n LD_LIBRARY_PATH; make install -j16)
	fi
	cd ..
done

cd ${currentpath}/build/install

if [ ! -d canadian ]; then
mkdir -p canadian
cp -r headers/include canadian/
mkdir -p .canadiantemp

for item in "${multilibs[@]}"; do
	if [[ "$item" == "m32" ]]; then
		glibclibname=lib
	elif [[ "$item" == "mx32" ]]; then
		glibclibname=libx32
	else
		glibclibname=lib64
	fi
	cp -r $item/include canadian/
	cp -r $item/lib .canadiantemp/
	mv .canadiantemp/lib .canadiantemp/$glibclibname
	mv .canadiantemp/$glibclibname canadian/
	strip --strip-unneeded canadian/$glibclibname/* canadian/$glibclibname/audit/* canadian/$glibclibname/gconv/*
	canadianreplacedstring=$currentpath/build/install/${item}/lib/

	for file in canadian/$glibclibname/*; do
		if [[ ! -d "$file" ]]; then
			getfilesize=$(wc -c <"$file")
			if [ $getfilesize -lt 1024 ]; then
				for file2 in "${glibcfiles[@]}"; do
					if [[ $file == "canadian/$glibclibname/$file2" ]]; then
						sed -i "s%${canadianreplacedstring}%%g" $file
						break
					fi
				done
			fi
			unset getfilesize
		fi
	done
done

rm -rf .canadiantemp
fi

mkdir -p ${currentpath}/hostbuild
mkdir -p ${currentpath}/hostbuild/$HOST
cd ${currentpath}/hostbuild/$HOST
mkdir -p binutils-gdb
cd binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --enable-gold $TRIPLETTRIPLETS --prefix=$PREFIX
fi
if [ ! -d $PREFIX/lib/bfd-plugins ]; then
make -j16
make install-strip -j
fi
cd ..
mkdir -p gcc
cd gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib --with-multilib-list=m64 --with-gxx-libcxx-include-dir=$PREFIXTARGET/include/c++/v1 --prefix=$PREFIX $TRIPLETTRIPLETS --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --enable-libstdcxx-backtrace
fi
if [ ! -d $PREFIX/lib/gcc ]; then
make -j16
make install-strip -j
cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > $PREFIX/lib/gcc/$TARGET/$GCCVERSIONSTR/include/limits.h
fi
cd $PREFIXTARGET
if [[ ${HOST} != ${BUILD} ]]; then
	if [ -d lib32 ]; then
		mv lib/ldscripts lib32/ldscripts
		if [ -d lib64 ]; then
			mv lib lib64
		fi
		mv lib32 lib
	fi
fi

LIBTARGETS="runtimes"

if [ ! -d $LIBTARGETS ]; then
	mkdir -p $LIBTARGETS
fi
for libdir in "${multilibsdir[@]}"; do
	if [ ! -d $LIBTARGETS/$libdir ]; then
		mkdir -p $LIBTARGETS/$libdir
		cp -a $libdir/*.so.* $LIBTARGETS/$libdir/
	fi
done

if [ ! -f include/stdio.h ]; then
	cp -r --preserve=links ${currentpath}/build/install/canadian/* .
fi
cd $TOOLCHAINSPATH/$HOST
if [ ! -f $TARGET.tar.xz ]; then
	XZ_OPT=-e9T0 tar cJf $TARGET.tar.xz $TARGET
	chmod 755 $TARGET.tar.xz
fi
