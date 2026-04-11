if [ -z ${HOST+x} ]; then
HOST=aarch64-linux-ohos
fi

if [ -z ${SYSTEMNAME+x} ]; then
SYSTEMNAME=Linux
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -z ${SYSROOTPATH+x} ]; then
SYSROOTPATH=$TOOLCHAINSPATH/llvm/$HOST/$HOST
fi

if [ -z ${EXTRACXXFLAGS+x} ]; then
EXTRACXXFLAGS="-I${SYSROOTPATH}/usr/include/c++/v1 -rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -lc++abi -lunwind"
fi

HOST=$HOST SYSTEMNAME=$SYSTEMNAME SYSROOTPATH=$SYSROOTPATH EXTRACXXFLAGS=$EXTRACXXFLAGS ./wavm.sh "$@"
exit $?
