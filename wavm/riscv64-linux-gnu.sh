if [ -z ${HOST+x} ]; then
HOST=riscv64-linux-gnu
fi

HOST=$HOST ./loongarch64-linux-gnu.sh "$@"
exit $?
