if [ -z ${HOST+x} ]; then
HOST=loongarch64-linux-gnu
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

HOST=$HOST SYSTEMNAME=$SYSTEMNAME SYSROOTPATH=$SYSROOTPATH ./wavm.sh "$@"
exit $?
