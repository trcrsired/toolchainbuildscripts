
if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
if [ -z ${TOOLCHAINSPATH_LLVM+x} ]; then
	TOOLCHAINSPATH_LLVM=$TOOLCHAINSPATH/llvm
fi
if [ -z ${ARCH+x} ]; then
ARCH=$(uname -m)
fi
if [ -z ${TRIPLE+x} ]; then
TRIPLE=$ARCH-linux-gnu
fi
if [ -z ${SYSROOT+x} ]; then
SYSROOT=$TOOLCHAINSPATH_LLVM/$TRIPLE/$TRIPLE
fi
if [ -z ${MINIMUMBUILD+x} ]; then
MINIMUMBUILD=yes
fi
CC="clang --target=$TRIPLE --sysroot=$SYSROOT -fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind" CXX="clang --target=$TRIPLE --sysroot=$SYSROOT -fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++" MINIMUMBUILD=$MINIMUMBUILD CC_FOR_HOST="clang --target=$TRIPLE --sysroot=$SYSROOT -fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind" CXX_FOR_HOST="clang++ --target=$TRIPLE --sysroot=$SYSROOT -fuse-ld=lld -flto=thin -rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++" ARCH=$ARCH HOST=$TRIPLE SYSROOT=$SYSROOT ./wine.sh "$@"
