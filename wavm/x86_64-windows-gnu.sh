if [ -z ${HOST+x} ]; then
HOST=x86_64-windows-gnu
fi

if [ -z ${SYSTEMNAME+x} ]; then
SYSTEMNAME=Windows
fi

HOST=$HOST SYSTEMNAME=$SYSTEMNAME ./wavm.sh "$@"
exit $?