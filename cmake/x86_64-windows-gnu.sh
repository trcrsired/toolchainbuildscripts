if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
if [ -z ${ARCH+x} ]; then
	ARCH=x86_64
fi

CC=clang CXX=clang++ HOST=$ARCH-windows-gnu SYSROOT=$TOOLCHAINSPATH/llvm/$ARCH-windows-gnu/$ARCH-windows-gnu ARCH=$ARCH EXTRACXXFLAGS="-lc++abi -lunwind -rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++" EXTRACFLAGS="-lc++abi -lunwind -rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++" EXTRAFLAGS="-DCMAKE_USE_OPENSSL=OFF -DCMAKE_SYSTEM_NAME=Windows" ./cmake.sh "$@"
