if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
if [ -z ${ARCH+x} ]; then
	ARCH=x86_64
fi

CC=clang CXX=clang++ HOST=$ARCH-windows-msvc SYSROOT=$TOOLCHAINSPATH/windows-msvc-sysroot ARCH=$ARCH EXTRACXXFLAGS="--sysroot=$TOOLCHAINSPATH/windows-msvc-sysroot -D_DLL=1 -lmsvcrt -fuse-ld=lld" EXTRACFLAGS="--sysroot=$TOOLCHAINSPATH/windows-msvc-sysroot -D_DLL=1 -lmsvcrt -fuse-ld=lld" EXTRAFLAGS="-DCMAKE_LINKER=lld -DCMAKE_USE_OPENSSL=OFF -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_RC_COMPILER=llvm-rc  -DCMAKE_RC_COMPILER_TARGET=$ARCH-windows-msvc -DCMAKE_MT=llvm-mt -DCMAKE_MT_TARGET=$ARCH-windows-msvc -DDISABLE_CMAKE_MANIFEST_INPUT=On" ./cmake.sh "$@"
