#!/bin/bash

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -z ${SOFTWARESPATH+x} ]; then
	SOFTWARESPATH=$HOME/softwares
fi

if [ -z ${CC_FOR_BUILD+x} ]; then
    CC_FOR_BUILD=gcc
fi

if [ -z ${CXX_FOR_BUILD+x} ]; then
    CXX_FOR_BUILD=g++
fi

if [ -z ${CC+x} ]; then
    CC=gcc
fi

if [ -z ${CXX+x} ]; then
    CXX=g++
fi

if [ -z ${CLANG+x} ]; then
    CLANG=clang
fi

if [ -z ${CLANGXX+x} ]; then
    CLANGXX=clang++
fi

HOST=$(${CC} -dumpmachine)

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
    echo "Some commands are not installed. Please install all required commands before proceeding."
    exit 1  # Exit with status code 1 indicating failure
fi

BUILD=$(${CC_FOR_BUILD} -dumpmachine)
PREFIX=$SOFTWARESPATH/$HOST

WINEARTIFACTSDIR=$(realpath .)/.wineartifacts
currentpath=$WINEARTIFACTSDIR/$HOST
currentwinepath=${currentpath}/wine

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


cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/FreeType" ]; then
cd "$TOOLCHAINS_BUILD"
git clone https://gitlab.freedesktop.org/freetype/freetype.git
if [ $? -ne 0 ]; then
echo "freetype clone failed"
exit 1
fi
fi

cd "$TOOLCHAINS_BUILD/freetype"
git pull --quiet
if [ ! -f $TOOLCHAINS_BUILD/freetype/.autogensuccess ]; then
mkdir -p $TOOLCHAINS_BUILD/freetype
cd $TOOLCHAINS_BUILD/freetype
./autogen.sh
if [ $? -ne 0 ]; then
echo "freetype autogen failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${TOOLCHAINS_BUILD}/freetype/.autogensuccess
fi

mkdir -p ${currentpath}/freetype

if [ ! -f $currentpath/freetype/.configuresuccess ]; then
cd ${currentpath}/freetype
STRIP=llvm-strip ${TOOLCHAINS_BUILD}/freetype/configure --disable-nls --disable-werror --host=$HOST --prefix=$currentpath/installs
if [ $? -ne 0 ]; then
echo "freetype configure failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $currentpath/freetype/.configuresuccess
fi

if [ ! -f $currentpath/freetype/.buildsuccess ]; then
cd ${currentpath}/freetype
STRIP=llvm-strip ${TOOLCHAINS_BUILD}/freetype/configure --disable-nls --disable-werror --host=$HOST --prefix=$currentpath/installs
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "freetype build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $currentpath/freetype/.buildsuccess
fi

if [ ! -f $currentpath/freetype/.installsuccess ]; then
make install -j$(nproc)
if [ $? -ne 0 ]; then
echo "freetype install failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $currentpath/freetype/.installsuccess
fi

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/libx11" ]; then
cd "$TOOLCHAINS_BUILD"
git clone https://gitlab.freedesktop.org/xorg/lib/libx11
if [ $? -ne 0 ]; then
echo "x11 clone failed"
exit 1
fi
fi

cd "$TOOLCHAINS_BUILD/libx11"
git pull --quiet

if [ ! -f $TOOLCHAINS_BUILD/libx11/.autogensuccess ]; then
mkdir -p $TOOLCHAINS_BUILD/libx11
cd $TOOLCHAINS_BUILD/libx11
./autogen.sh
if [ $? -ne 0 ]; then
echo "libx11 autogen failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${TOOLCHAINS_BUILD}/libx11/.autogensuccess
fi

mkdir -p ${currentpath}/libx11

if [ ! -f $currentpath/libx11/.configuresuccess ]; then
cd ${currentpath}/libx11
STRIP=llvm-strip ${TOOLCHAINS_BUILD}/libx11/configure --disable-nls --disable-werror --host=$HOST --prefix=$currentpath/installs
if [ $? -ne 0 ]; then
echo "libx11 configure failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $currentpath/libx11/.configuresuccess
fi

if [ ! -f $currentpath/libx11/.buildsuccess ]; then
cd ${currentpath}/libx11
STRIP=llvm-strip ${TOOLCHAINS_BUILD}/libx11/configure --disable-nls --disable-werror --host=$HOST --prefix=$currentpath/installs
make -j$(nproc)
if [ $? -ne 0 ]; then
echo "libx11 build failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $currentpath/libx11/.buildsuccess
fi

if [ ! -f $currentpath/libx11/.installsuccess ]; then
make install -j$(nproc)
if [ $? -ne 0 ]; then
echo "libx11 install failure"
exit 1
fi
echo "$(date --iso-8601=seconds)" > $currentpath/libx11/.installsuccess
fi

if [ ! -d "$TOOLCHAINS_BUILD/Vulkan-Loader" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git@github.com:KhronosGroup/Vulkan-Loader.git
if [ $? -ne 0 ]; then
echo "Vulkan Loader clone failed"
exit 1
fi
fi

cd "$TOOLCHAINS_BUILD/Vulkan-Loader"
git pull --quiet


if [ ! -f $currentpath/Vulkan-Loader/.cmakeconfiguresuccess ]; then
${TOOLCHAINS_BUILD}/Vulkan-Loader/cmake -GNinja -DCMAKE_C_COMPILER=$HOST-gcc -DCMAKE_CXX_COMPILER=$HOST-g++ -DCMAKE_ASM_COMPILER=$HOST-gcc -DCMAKE_STRIP=llvm-strip -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$currentpath/installs
if [ $? -ne 0 ]; then
echo "Vulkan-Loader autogen failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${TOOLCHAINS_BUILD}/Vulkan-Loader/.cmakeconfiguresuccess
fi

if [ ! -f $currentpath/Vulkan-Loader/.buildsuccess ]; then
ninja
if [ $? -ne 0 ]; then
echo "ninja failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${TOOLCHAINS_BUILD}/Vulkan-Loader/.buildsuccess
fi

if [ ! -f $currentpath/Vulkan-Loader/.installsuccess ]; then
ninja install/strip
if [ $? -ne 0 ]; then
echo "install failed"
exit 1
fi
echo "$(date --iso-8601=seconds)" > ${TOOLCHAINS_BUILD}/Vulkan-Loader/.installsuccess
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
CC=$CC CXX=$CXX x86_64_CC=$CLANG i386_CC=$CLANG arm64ec_CC=$CLANG arm_CC=$CLANG aarch64_CC=$CLANG STRIP=$STRIP $TOOLCHAINS_BUILD/wine/configure --build=$BUILD --host=$HOST $CROSSSETTIGNS --disable-nls --disable-werror  --prefix=$PREFIX/wine --enable-archs=$ENABLEDARCHS
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
cp -r --preserve=links ${currentwinepath}/nls $PREFIX/wine/share/wine/
echo "$(date --iso-8601=seconds)" > ${currentwinepath}/.installsuccess
fi

if [ ! -f $SOFTWARESPATH/$HOST/wine-$HOST.tar.xz ]; then
cd ${SOFTWARESPATH}/$HOST
XZ_OPT=-e9T0 tar cJf wine-$HOST.tar.xz wine
chmod 755 wine-$HOST.tar.xz
fi
