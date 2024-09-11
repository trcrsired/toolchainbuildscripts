if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

CC="clang --target=aarch64-linux-android30 --sysroot=$TOOLCHAINSPATH/llvm/aarch64-linux-android30/aarch64-linux-android30" CXX="clang++ --target=aarch64-linux-android30 --sysroot=$TOOLCHAINSPATH/llvm/aarch64-linux-android30/aarch64-linux-android30 -I$TOOLCHAINSPATH/llvm/aarch64-linux-android30/aarch64-linux-android30/include/c++/v1" HOST=aarch64-linux-android30 ./mono.sh "$@"