if [ -z ${SYSROOT+x} ]; then
SYSROOT=""
fi

if [ -z ${SYSTEMNAME+x} ]; then
SYSTEMNAME=Linux
fi

SYSROOT=$SYSROOT SYSTEMNAME=$SYSTEMNAME ./wavm.sh "$@"
exit $?