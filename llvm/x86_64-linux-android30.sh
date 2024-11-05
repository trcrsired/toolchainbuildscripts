if [ -z ${ARCH+x} ]; then
ARCH=x86_64
fi
ARCH=$ARCH ./aarch64-linux-android30.sh "$@"
