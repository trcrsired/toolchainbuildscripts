if [ -z ${ARCH+x} ]; then
ARCH=x86_64
fi

if [ -z ${ANDROIDAPIVERSION+x} ]; then
ANDROIDAPIVERSION=28
fi

ANDROIDAPIVERSION=$ANDROIDAPIVERSION ARCH=$ARCH ./aarch64-linux-android30.sh "$@"
