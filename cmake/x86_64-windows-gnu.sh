if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
if [ -z ${ARCH+x} ]; then
	ARCH=x86_64
fi

CC=clang CXX=clang++ HOST=$ARCH-windows-gnu SYSROOT=$TOOLCHAINSPATH/llvm/$ARCH-windows-gnu/$ARCH-windows-gnu ARCH=$ARCH EXTRACXXFLAGS="-lc++abi -lunwind -rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++" EXTRACFLAGS="-rtlib=compiler-rt" EXTRAFLAGS="-DCMAKE_USE_OPENSSL=OFF -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RC_COMPILER=llvm-windres -DCMAKE_RC_COMPILER_TARGET=$ARCH-windows-gnu" ./cmake.sh "$@"
