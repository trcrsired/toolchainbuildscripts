if [ -z ${HOST+x} ]; then
HOST=aarch64-linux-gnu
fi

HOST=$HOST ./loongarch64-linux-gnu.sh "$@"
exit $?
