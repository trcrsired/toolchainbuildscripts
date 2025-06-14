if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
enable_wineandroid_drv=no CC=clang CXX=clang++ MINIMUMBUILD=yes DISABLEALSA=yes HOST=aarch64-linux-musl SYSROOT=$TOOLCHAINSPATH/llvm/aarch64-linux-musl/aarch64-linux-musl ARCH=aarch64 CMAKEEXTRAFLAGS="-DCMAKE_CXX_FLAGS=\"-I$TOOLCHAINSPATH/llvm/aarch64-linux-musl/aarch64-linux-musl/include/c++/v1\"" ./wine.sh "$@"
