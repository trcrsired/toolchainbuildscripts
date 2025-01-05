#!/bin/bash

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -z ${SOFTWARESPATH+x} ]; then
	SOFTWARESPATH=$HOME/softwares/wine
fi

if [ -z ${CC_FOR_BUILD+x} ]; then
    CC_FOR_BUILD=gcc
	if ! command -v "$CC_FOR_BUILD" &> /dev/null; then
		CC_FOR_BUILD=clang
	fi
fi

if [ -z ${CXX_FOR_BUILD+x} ]; then
    CXX_FOR_BUILD=g++
	if ! command -v "$CXX_FOR_BUILD" &> /dev/null; then
		CXX_FOR_BUILD=clang++
	fi
fi

if [ -z ${CPP_FOR_BUILD+x} ]; then
    CPP_FOR_BUILD=cpp
	if ! command -v "$CPP_FOR_BUILD" &> /dev/null; then
		CPP_FOR_BUILD=clang-cpp
	fi
fi

if [ -z ${CC+x} ]; then
    CC=gcc
	if ! command -v "$CC" &> /dev/null; then
		CC=clang
	fi
fi

if [ -z ${CXX+x} ]; then
    CXX=g++
	if ! command -v "$CXX" &> /dev/null; then
		CXX=clang
	fi
fi

if [ -z ${CLANG+x} ]; then
    CLANG=clang
fi

if [ -z ${CLANGXX+x} ]; then
    CLANGXX=clang++
fi

if [ -z ${CLANGCPP+x} ]; then
    CLANGCPP=clang-cpp
fi

if [ -z ${GCC+x} ]; then
    GCC=no
fi

if [ -z ${HOST+x} ]; then
	HOST=$(${CC} -dumpmachine)
fi

if [ -z ${CC_TARGET+x} ]; then
	CC_TARGET=$HOST
fi
if [ -z ${CXX_TARGET+x} ]; then
	CXX_TARGET=$HOST
fi

if [ -z ${STRIP+x} ]; then
	if ! command -v "llvm-strip" &> /dev/null; then
		STRIP=$HOST-strip
	else
	    STRIP=llvm-strip
	fi
fi

# Array of commands to check
commands=("CC_FOR_BUILD" "CXX_FOR_BUILD" "CC" "CXX" "CLANG" "CLANGXX" "STRIP")

# Variable to track if any command is missing
missing_commands=false

# Loop through each command and check if it's installed
for cmd in "${commands[@]}"; do
    if ! command -v "${!cmd}" &> /dev/null; then
        echo "$cmd uninstalled or set incorrectly. Your value: ${!cmd}"
        missing_commands=true
	else
		echo "$cmd=${!cmd}"
    fi
done

# Check if any command is missing and decide whether to continue
if [ "$missing_commands" = true ]; then
    echo "Some commands not installed?"
fi

BUILD=$(${CC_FOR_BUILD} -dumpmachine)
PREFIX=$SOFTWARESPATH/$HOST

WINEARTIFACTSDIR=$(realpath .)/.wineartifacts
currentpath=$WINEARTIFACTSDIR/$HOST
currentwinepath=${currentpath}/wine

if [ -z ${SYSROOT+x} ]; then
gccpath=$(command -v "$HOST-gcc")
gccbinpath=$(dirname "$gccpath")
SYSROOTPATH=$(dirname "$gccbinpath")
if [ -f $SYSROOTPATH/include/stdio.h ]; then
SYSROOT=$SYSROOTPATH
else
SYSROOT=$SYSROOTPATH/$HOST
fi
fi

if [ -z ${ARCH} ]; then
    ARCH=${HOST%%-*}
fi

if [ -z ${ENABLEDARCHS} ]; then
if [[ ${ARCH} == "aarch64" ]]; then
ENABLEDARCHS=aarch64
elif [[ ${ARCH} == "x86_64" ]]; then
ENABLEDARCHS=i386,x86_64
fi
fi

if [ -z ${ARCH} ]; then
    ARCH=${HOST%%-*}
fi

UPDATED_HOST=$(echo $HOST | sed 's/androidxx/gnu/')

echo "ARCH=$ARCH"
echo "--build=$BUILD"
echo "--host=$HOST"
echo "--enable-archs=$ENABLEDARCHS"

if [[ $1 == "clean" ]]; then
	echo "cleaning"
	rm -rf ${currentpath}
	rm -f $SOFTWARESPATH/$HOST/wine-$HOST.tar.xz
	echo "cleaning done"
    exit 0
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf ${currentpath}
	rm -f $SOFTWARESPATH/$HOST/wine-$HOST.tar.xz
	echo "restart done"
fi

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/wine" ]; then
cd "$TOOLCHAINS_BUILD"
git clone https://gitlab.winehq.org/wine/wine.git
if [ $? -ne 0 ]; then
echo "wine clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/wine"
git pull --quiet


if [[ ${BUILD} != ${HOST} ]]; then
if [ "$MINIMUMBUILD" != "yes" ]; then
BUILDDEPENDENCIES=yes
fi
fi

if [ "$BUILDDEPENDENCIES" == "yes" ]; then


function handlebuild
{
local x11pjname=$1
local x11pjrepo=$2

mkdir -p "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/$x11pjname" ]; then
cd "$TOOLCHAINS_BUILD"
git clone $x11pjrepo
if [ $? -ne 0 ]; then
echo "$x11pjname clone failed"
exit 1
fi
git submodule update --init --recursive
fi
cd "$TOOLCHAINS_BUILD/$x11pjname"
git pull --quiet


if [ -f "$TOOLCHAINS_BUILD/$x11pjname/CMakeLists.txt" ]; then

cd "$TOOLCHAINS_BUILD/$x11pjname"
git pull --quiet

mkdir -p $currentpath/$x11pjname
if [ ! -f $currentpath/$x11pjname/.cmakeconfiguresuccess ]; then
cd $currentpath/$x11pjname
echo cmake -DCMAKE_POSITION_INDEPENDENT_CODE=On ${TOOLCHAINS_BUILD}/$x11pjname -GNinja -DCMAKE_SYSTEM_PROCESSOR=$ARCH -DCMAKE_C_COMPILER=$CLANG -DCMAKE_CXX_COMPILER=$CLANGXX -DCMAKE_C_FLAGS="-rtlib=compiler-rt --unwindlib=libunwind -fuse-ld=lld -Wno-unused-command-line-argument" -DCMAKE_CXX_FLAGS="-rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -lc++abi -lunwind -fuse-ld=lld -Wno-unused-command-line-argument" $CMAKEEXTRAFLAGS -DCMAKE_ASM_COMPILER=$CLANG -DCMAKE_C_COMPILER_TARGET=$HOST -DCMAKE_CXX_COMPILER_TARGET=$HOST -DCMAKE_ASM_COMPILER_TARGET=$HOST -DCMAKE_SYSROOT=$SYSROOT -DCMAKE_STRIP=llvm-strip -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$currentpath/installs -DCMAKE_SYSTEM_NAME=Linux
cmake -DCMAKE_POSITION_INDEPENDENT_CODE=On ${TOOLCHAINS_BUILD}/$x11pjname -GNinja -DCMAKE_SYSTEM_PROCESSOR=$ARCH -DCMAKE_C_COMPILER=$CLANG -DCMAKE_CXX_COMPILER=$CLANGXX -DCMAKE_C_FLAGS="-rtlib=compiler-rt --unwindlib=libunwind -fuse-ld=lld -Wno-unused-command-line-argument" -DCMAKE_CXX_FLAGS="-rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -lc++abi -lunwind -fuse-ld=lld -Wno-unused-command-line-argument" $CMAKEEXTRAFLAGS -DCMAKE_ASM_COMPILER=$CLANG -DCMAKE_C_COMPILER_TARGET=$HOST -DCMAKE_CXX_COMPILER_TARGET=$HOST -DCMAKE_ASM_COMPILER_TARGET=$HOST -DCMAKE_SYSROOT=$SYSROOT -DCMAKE_STRIP=llvm-strip -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$currentpath/installs -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_CROSSCOMPILING=On -DCMAKE_FIND_ROOT_PATH=$SYSROOT -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
if [ $? -ne 0 ]; then
echo "$x11pjname autogen failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/$x11pjname/.cmakeconfiguresuccess
fi

if [ ! -f $currentpath/$x11pjname/.buildsuccess ]; then
cd $currentpath/$x11pjname
ninja
if [ $? -ne 0 ]; then
echo "$x11pjname ninja failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/$x11pjname/.buildsuccess
fi

if [ ! -f $currentpath/$x11pjname/.installsuccess ]; then
cd $currentpath/$x11pjname
ninja install/strip
if [ $? -ne 0 ]; then
echo "$x11pjname install failed"
exit 1
fi
cp -r --preserve=links $currentpath/installs/* $SYSROOT/usr/
echo "$(date --iso-8601=seconds)" > ${currentpath}/$x11pjname/.installsuccess
fi

elif [ -f $TOOLCHAINS_BUILD/${x11pjname}/configure.ac ]; then

if [ -f $TOOLCHAINS_BUILD/${x11pjname}/autogen.sh ]; then
if [ ! -f $TOOLCHAINS_BUILD/${x11pjname}/.autogensuccess ]; then
mkdir -p $TOOLCHAINS_BUILD/${x11pjname}
cd $TOOLCHAINS_BUILD/${x11pjname}
NOCONFIGURE=1 ./autogen.sh
if [ $? -ne 0 ]; then
echo "$x11pjname autogen failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${TOOLCHAINS_BUILD}/${x11pjname}/.autogensuccess
fi
fi

if [ ! -f ${TOOLCHAINS_BUILD}/${x11pjname}/configure ]; then
if [ ! -f ${TOOLCHAINS_BUILD}/${x11pjname}/configure.ac ]; then
echo "$x11pjname not an autotool project"
exit 1
fi
cd $TOOLCHAINS_BUILD/${x11pjname}
autoreconf -i
fi

mkdir -p "$currentpath/$x11pjname"

if [ ! -f $currentpath/$x11pjname/.configuresuccess ]; then
mkdir -p $currentpath/$x11pjname
cd $currentpath/$x11pjname
CC="$CC_FOR_HOST" CXX="$CXX_FOR_HOST" CPP="$CPP_FOR_HOST" STRIP=llvm-strip STRIP=$STRIP LD=lld RANLIB=llvm-ranlib AR=llvm-ar AS=llvm-as STRIP=llvm-strip ${TOOLCHAINS_BUILD}/${x11pjname}/configure --disable-nls --disable-werror --host=$UPDATED_HOST --prefix=$currentpath/installs --enable-malloc0returnsnull
if [ $? -ne 0 ]; then
echo "$x11pjname configure failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/${x11pjname}/.configuresuccess
fi

if [ ! -f $currentpath/$x11pjname/.buildsuccess ]; then
mkdir -p $currentpath/$x11pjname
cd ${currentpath}/$x11pjname
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "$x11pjname build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $currentpath/$x11pjname/.buildsuccess
fi

if [ ! -f $currentpath/$x11pjname/.installsuccess ]; then
cd ${currentpath}/$x11pjname
make install -j$(nproc)
if [ $? -ne 0 ]; then
echo "$x11pjname install failure"
#ignore issue
#exit 1
fi
llvm-strip --strip-unneeded $currentpath/installs/lib/*
cp -r --preserve=links $currentpath/installs/* $SYSROOT/usr/
echo "$(date --iso-8601=seconds)" > $currentpath/$x11pjname/.installsuccess
fi

elif [ -f ${TOOLCHAINS_BUILD}/${x11pjname}/meson.build ]; then

mkdir -p $currentpath/$x11pjname
if [ ! -f $currentpath/${x11pjname}/.mesonconfiguresuccess ]; then
cd $currentpath/$x11pjname
cat <<EOL > cross_file.txt
[host_machine]
system = 'linux'
cpu_family = '$ARCH'
cpu = '$ARCH'
endian = 'little'

[properties]
c_args = ['-rtlib=compiler-rt', '--unwindlib=libunwind', '-fuse-ld=lld', '-Wno-unused-command-line-argument']
cpp_args = ['-rtlib=compiler-rt', '--unwindlib=libunwind', '-stdlib=libc++', '-lc++abi', '-lunwind', '-fuse-ld=lld', '-Wno-unused-command-line-argument']
c_link_args = []
sys_root = '$SYSROOT'

[binaries]
c = 'clang'
cpp = 'clang++'
ar = 'llvm-ar'
strip = 'llvm-strip'
pkgconfig = 'pkg-config'
EOL

export PKG_CONFIG_PATH=
export PKG_CONFIG_LIBDIR=${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=${SYSROOT}
meson setup ${TOOLCHAINS_BUILD}/${x11pjname} --prefix=$currentpath/installs --cross-file cross_file.txt --buildtype release
if [ $? -ne 0 ]; then
echo "$x11pjname meson setup failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentpath}/${x11pjname}/.mesonconfiguresuccess
fi

if [ ! -f $currentpath/$x11pjname/.buildsuccess ]; then
cd $currentpath/$x11pjname
ninja -C .
if [ $? -ne 0 ]; then
echo "$x11pjname ninja failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $currentpath/$x11pjname/.buildsuccess
fi

if [ ! -f $currentpath/$x11pjname/.installsuccess ]; then
cd $currentpath/$x11pjname
ninja -C builddir install
if [ $? -ne 0 ]; then
echo "$x11pjname install failed"
exit 1
fi
llvm-strip --strip-unneeded $currentpath/installs/lib/*
cp -r --preserve=links $currentpath/installs/* $SYSROOT/usr/
echo "$(date --iso-8601=seconds)" > $currentpath/$x11pjname/.installsuccess
fi
fi
}

handlebuild "brotli" "git@github.com:google/brotli.git"
handlebuild "bzip2" "https://gitlab.com/federicomenaquintero/bzip2"
handlebuild "harfbuzz" "git@github.com:harfbuzz/harfbuzz.git"
handlebuild "libpng" "git@github.com:pnggroup/libpng.git"
handlebuild "freetype" "https://gitlab.freedesktop.org/freetype/freetype.git"
handlebuild "libxtrans" "https://gitlab.freedesktop.org/xorg/lib/libxtrans.git"
handlebuild "xorgproto" "https://gitlab.freedesktop.org/xorg/proto/xorgproto.git"
handlebuild "libxau" "https://gitlab.freedesktop.org/xorg/lib/libxau.git"
handlebuild "libxcb" "https://gitlab.freedesktop.org/xorg/lib/libxcb.git"
handlebuild "libx11" "https://gitlab.freedesktop.org/xorg/lib/libx11"
handlebuild "libxext" "https://gitlab.freedesktop.org/xorg/lib/libxext.git"
handlebuild "libxfixes" "https://gitlab.freedesktop.org/xorg/lib/libxfixes.git"
handlebuild "libxi" "https://gitlab.freedesktop.org/xorg/lib/libxi.git"
handlebuild "libxrender" "https://gitlab.freedesktop.org/xorg/lib/libxrender.git"
handlebuild "libxrandr" "https://gitlab.freedesktop.org/xorg/lib/libxrandr.git"
handlebuild "libxinerama" "https://gitlab.freedesktop.org/xorg/lib/libxinerama.git"
handlebuild "xinput" "https://gitlab.freedesktop.org/xorg/app/xinput.git"
handlebuild "libxcursor" "https://gitlab.freedesktop.org/xorg/lib/libxcursor.git"
#handlebuild "libsndfile" "git@github.com:libsndfile/libsndfile.git"
#handlebuild "samba" "https://git.samba.org/samba.git"
#handlebuild "pulseaudio" "https://gitlab.freedesktop.org/pulseaudio/pulseaudio.git"
if [ "$DISABLEALSA" != "yes" ]; then
handlebuild "alsa-lib" "git@github.com:alsa-project/alsa-lib.git"
fi
handlebuild "libffi" "git@github.com:libffi/libffi.git"
#handlebuild "wayland" "https://gitlab.freedesktop.org/wayland/wayland.git"
#handlebuild "libusb" "git@github.com:libusb/libusb.git"
#handlebuild "gnutls" "https://gitlab.com/gnutls/gnutls.git"
#handlebuild "mesa" "https://gitlab.freedesktop.org/mesa/mesa.git"
#handlebuild "Vulkan-Loader" "git@github.com:KhronosGroup/Vulkan-Loader.git"

mkdir -p $PREFIX/dependencies
cp -r --preserve=links $currentpath/installs/* $SYSROOT/usr/
cp -r $SYSROOT/usr/include/freetype2/* $SYSROOT/usr/include/
cp -r --preserve=links $currentpath/installs/* $PREFIX/dependencies/
fi

if [[ ${BUILD} != ${HOST} ]]; then
BUILDWINEDIR="$WINEARTIFACTSDIR/$BUILD/wine"
if [ ! -d "$BUILDWINEDIR" ]; then
echo "$BUILDWINEDIR not exists. Cannot cross compile"
exit 1
fi
CROSSSETTIGNS="--with-wine-tools=$BUILDWINEDIR"
else
CROSSSETTIGNS=
fi

if [ "$MINIMUMBUILD" == "yes" ]; then
echo "MINIMUMBUILD is set to yes. We build wine without GUI support."
CROSSSETTIGNS="$CROSSSETTIGNS --without-x --without-freetype"
fi


mkdir -p ${currentwinepath}

if [ ! -f ${currentwinepath}/Makefile ]; then
cd $currentwinepath

if [ -z ${CC_FOR_HOST+x} ]; then
if [[ ${BUILD} != ${HOST} ]]; then
CC_FOR_HOST="$CLANG --target=$HOST --sysroot=$SYSROOT -rtlib=compiler-rt --unwindlib=libunwind"
else
CC_FOR_HOST="$CC_FOR_BUILD"
fi
fi

if [ -z ${CXX_FOR_HOST+x} ]; then
if [[ ${BUILD} != ${HOST} ]]; then
CXX_FOR_HOST="$CLANGXX --target=$HOST --sysroot=$SYSROOT -rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -lc++abi -lunwind"
else
CXX_FOR_HOST="$CXX_FOR_BUILD"
fi
fi

if [ -z ${CPP_FOR_HOST+x} ]; then
if [[ ${BUILD} != ${HOST} ]]; then
CPP_FOR_HOST="$CLANGCPP --target=$HOST --sysroot=$SYSROOT"
else
CPP_FOR_HOST="$CPP_FOR_BUILD"
fi
fi

CC="$CC_FOR_HOST" CXX="$CXX_FOR_HOST" CPP="$CPP_FOR_HOST" STRIP=llvm-strip wine_cv_64bit_compare_swap="none needed" x86_64_CC=$CLANG i386_CC=$CLANG arm64ec_CC=$CLANG arm_CC=$CLANG aarch64_CC=$CLANG STRIP=$STRIP LD=lld enable_wineandroid_drv=no $TOOLCHAINS_BUILD/wine/configure --build=$BUILD --host=$HOST $CROSSSETTIGNS --disable-nls --disable-werror --disable-wineandroid-drv --prefix=$PREFIX/wine --enable-archs=$ENABLEDARCHS
if [ $? -ne 0 ]; then
echo "wine configure failure"
exit 1
fi
fi

if [ ! -f ${currentwinepath}/.buildsuccess ]; then
cd ${currentwinepath}
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "wine build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentwinepath}/.buildsuccess
fi

if [ ! -f ${currentwinepath}/.nlsbuildsuccess ]; then
cd ${currentwinepath}/nls
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "wine build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${currentwinepath}/.nlsbuildsuccess
fi

if [ ! -f ${currentwinepath}/.installsuccess ]; then
cd ${currentwinepath}
make install -j$(nproc)
if [ $? -ne 0 ]; then
echo "wine install failure"
exit 1
fi
mkdir -p $PREFIX/wine/share/wine
cp -r --preserve=links $TOOLCHAINS_BUILD/wine/nls $PREFIX/wine/share/wine/
echo "$(date --iso-8601=seconds)" > ${currentwinepath}/.installsuccess
fi

if [ ! -f $SOFTWARESPATH/$HOST.tar.xz ]; then
cd ${SOFTWARESPATH}
XZ_OPT=-e9T0 tar cJf $HOST.tar.xz $HOST
chmod 755 $HOST.tar.xz
fi
