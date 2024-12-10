if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
if [ -z ${ARCH+x} ]; then
	ARCH=x86_64
fi

TOOLCHAINSPATH=$TOOLCHAINSPATH ARCH=$ARCH ./aarch64-linux-android30.sh "$@"
