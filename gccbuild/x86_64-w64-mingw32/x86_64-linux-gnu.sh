if [ false ]; then

mkdir -p ${currentpath}/hostbuild
mkdir -p ${currentpath}/hostbuild/$HOST
cd ${currentpath}/hostbuild/$HOST
mkdir -p ${currentpath}/hostbuild/$HOST/binutils-gdb
cd ${currentpath}/hostbuild/$HOST/binutils-gdb
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --enable-gold $CANADIANCROSSTRIPLETTRIPLETS --prefix=$CANADIANHOSTPREFIX
fi

if [ ! -d $CANADIANHOSTPREFIX/lib/bfd-plugins ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi
cd ${currentpath}/hostbuild/$HOST

mkdir -p ${currentpath}/hostbuild/$HOST/gcc
cd ${currentpath}/hostbuild/$HOST/gcc
if [ ! -f Makefile ]; then
$TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$CANADIANHOSTPREFIX/include/c++/v1 --prefix=$CANADIANHOSTPREFIX $CANADIANCROSSTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON
fi
if [ ! -d $CANADIANHOSTPREFIX/lib/gcc ]; then
make -j$(nproc)
make install-strip -j$(nproc)
fi

if [ ! -f $CANADIANHOSTPREFIX/include/stdio.h ]; then
	cp --preserve=links -r ${currentpath}/install/linux/* $CANADIANHOSTPREFIX/
	cp --preserve=links -r ${currentpath}/install/glibc/canadian/include $CANADIANHOSTPREFIX/
	rm -rf ${currentpath}/install/glibc/libs
	cp -r ${currentpath}/install/glibc/canadian/lib64 ${currentpath}/install/glibc/libs
	cp -r ${currentpath}/install/glibc/canadian/libx32 ${currentpath}/install/glibc/libs/
	mv ${currentpath}/install/glibc/libs/libx32 ${currentpath}/install/glibc/libs/x32
	cp -r ${currentpath}/install/glibc/canadian/lib32 ${currentpath}/install/glibc/libs/
	mv ${currentpath}/install/glibc/libs/lib32 ${currentpath}/install/glibc/libs/32
fi


fi