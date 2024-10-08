if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

CC="clang --target=aarch64-linux-android30 --sysroot=$TOOLCHAINSPATH/llvm/aarch64-linux-android30/aarch64-linux-android30" CXX="clang++ --target=aarch64-linux-android30 --sysroot=$TOOLCHAINSPATH/llvm/aarch64-linux-android30/aarch64-linux-android30 -I$TOOLCHAINSPATH/llvm/aarch64-linux-android30/aarch64-linux-android30/include/c++/v1 -lc++abi -lunwind" HOST=aarch64-linux-android30 EXTRACONFIGUREFLAGS="--with-btls-android-ndk=$TOOLCHAINSPATH/llvm/aarch64-linux-android30/aarch64-linux-android30 --disable-dependency-tracking" ./mono.sh "$@"