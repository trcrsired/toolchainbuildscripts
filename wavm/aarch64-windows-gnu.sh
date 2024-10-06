if [ -z ${HOST+x} ]; then
HOST=aarch64-windows-gnu
fi

if [ -z ${SYSTEMNAME+x} ]; then
SYSTEMNAME=Windows
fi

HOST=$HOST SYSTEMNAME=$SYSTEMNAME ./x86_64-windows-gnu.sh "$@"
exit $?
