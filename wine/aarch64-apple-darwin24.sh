if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
SYSROOT=$TOOLCHAINSPATH/llvm/aarch64-apple-darwin24/aarch64-apple-darwin24 \
CC_FOR_HOST="clang --target=aarch64-apple-darwin24 --sysroot=$SYSROOT -mlinker-version=2.50"  \
CXX_FOR_HOST="clang++ --target=aarch64-apple-darwin24 --sysroot=$SYSROOT -mlinker-version=2.50"  \
CPP_FOR_HOST="clang-cpp --target=aarch64-apple-darwin24 --sysroot=$SYSROOT -mlinker-version=2.50"  \
LDFLAGS="-fuse-ld=lld -mlinker-version=2.50"  \
CONFIGUREEXTRAFLAGS="--without-x" \
enable_wineandroid_drv=no CC=clang CXX=clang++ HOST=aarch64-apple-darwin24 ARCH=aarch64 NO_CREATE_LIBPTHREAD=yes BUILDDEPENDENCIES="no"  \
./wine.sh "$@"
