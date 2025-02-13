if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
enable_wineandroid_drv=no CC=clang CXX=clang++ MINIMUMBUILD=yes HOST=aarch64-apple-darwin24 SYSROOT=$TOOLCHAINSPATH/llvm/aarch64-apple-darwin24/aarch64-apple-darwin24 ARCH=aarch64 ./wine.sh "$@"
