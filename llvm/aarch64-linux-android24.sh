if [ -z ${ANDROIDNDKVERSION+x} ]; then
ANDROIDNDKVERSION=24
fi
ANDROIDAPIVERSION=$ANDROIDNDKVERSION ./aarch64-linux-android30.sh "$@"
