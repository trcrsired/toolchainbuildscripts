if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
CC=clang CXX=clang++ HOST=aarch64-linux-android30 SYSROOT=$TOOLCHAINSPATH/llvm/aarch64-linux-android30/aarch64-linux-android30 ARCH=aarch64 EXTRACXXFLAGS="-lc++abi -lunwind -DCMAKE_CXX_FLAGS=\"-I$TOOLCHAINSPATH/llvm/aarch64-linux-android30/aarch64-linux-android30/include/c++/v1\" -I$(realpath .)/android" EXTRAFLAGS="-DCMAKE_USE_OPENSSL=OFF" ./cmake.sh "$@"
