if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
if [ -z ${ARCH+x} ]; then
	ARCH=aarch64
fi

CC=clang CXX=clang++ HOST=$ARCH-linux-android30 SYSROOT=$TOOLCHAINSPATH/llvm/$ARCH-linux-android30/$ARCH-linux-android30 ARCH=$ARCH EXTRACXXFLAGS="-I$(realpath .)/android -L$(realpath .)/android -lc++abi -lunwind -I$TOOLCHAINSPATH/llvm/$ARCH-linux-android30/$ARCH-linux-android30/include/c++/v1" EXTRACFLAGS="-I$(realpath .)/android -L$(realpath .)/android" EXTRAFLAGS="-DCMAKE_USE_OPENSSL=OFF  -DCMAKE_SYSTEM_NAME=Linux" ./cmake.sh "$@"
