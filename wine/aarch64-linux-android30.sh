if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
enable_wineandroid_drv=no CC=clang CXX=clang++ DISABLEALSA=yes HOST=aarch64-linux-android30 SYSROOT=$TOOLCHAINSPATH/llvm/aarch64-linux-android30/aarch64-linux-android30 ARCH=aarch64 CMAKEEXTRAFLAGS="-DCMAKE_CXX_FLAGS=\"-I$TOOLCHAINSPATH/llvm/aarch64-linux-android30/aarch64-linux-android30/include/c++/v1\"" ./wine.sh "$@"
