if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
SYSROOT=$TOOLCHAINSPATH/llvm/aarch64-linux-ohos/aarch64-linux-ohos
CC_FOR_HOST="clang --target=aarch64-linux-ohos --sysroot=$SYSROOT -fuse-ld=lld -rtlib=compiler-rt --unwindlib=libunwind"
CXX_FOR_HOST="clang++ --target=aarch64-linux-ohos --sysroot=$SYSROOT -fuse-ld=lld -rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -I$SYSROOT/usr/include/c++/v1 -lc++abi -lunwind"
CPP_FOR_HOST="clang-cpp --target=aarch64-linux-ohos --sysroot=$SYSROOT"
enable_wineandroid_drv=no CC=clang CXX=clang++ MINIMUMBUILD=yes DISABLEALSA=yes HOST=aarch64-linux-ohos SYSROOT=$SYSROOT CC_FOR_HOST="$CC_FOR_HOST" CXX_FOR_HOST="$CXX_FOR_HOST" CPP_FOR_HOST="$CPP_FOR_HOST" ARCH=aarch64 CMAKEEXTRAFLAGS="-DCMAKE_CXX_FLAGS=\"-I$SYSROOT/usr/include/c++/v1\"" ./wine.sh "$@"