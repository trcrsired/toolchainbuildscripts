if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
enable_wineandroid_drv=no CC=clang CXX=clang++ MINIMUMBUILD=yes DISABLEALSA=yes HOST=x86_64-linux-android30 SYSROOT=$TOOLCHAINSPATH/llvm/x86_64-linux-android30/x86_64-linux-android30 ARCH=x86_64 CMAKEEXTRAFLAGS="-DCMAKE_CXX_FLAGS=\"-I$TOOLCHAINSPATH/llvm/x86_64-linux-android30/x86_64-linux-android30/include/c++/v1\"" ./wine.sh "$@"
