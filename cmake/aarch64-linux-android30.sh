if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
if [ -z ${ARCH+x} ]; then
	ARCH=aarch64
fi

TOOLCHAINSPATH=$TOOLCHAINSPATH ARCH=$ARCH ./x86_64-linux-android30.sh "$@"