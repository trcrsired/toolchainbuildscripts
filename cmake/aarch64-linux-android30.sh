if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
CC=clang CXX=clang++ HOST=aarch64-linux-android30 SYSROOT=$TOOLCHAINSPATH/llvm/aarch64-linux-android30/aarch64-linux-android30 ARCH=aarch64 ./cmake.sh "$@"
