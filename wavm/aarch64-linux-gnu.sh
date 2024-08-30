if [ -z ${HOST+x} ]; then
HOST=aarch64-linux-gnu
fi

if [ -z ${SYSTEMNAME+x} ]; then
SYSTEMNAME=aarch64-linux-gnu
fi

HOST=$HOST SYSTEMNAME=$SYSTEMNAME ./wavm.sh "$@"
exit $?