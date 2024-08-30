./wavm.sh "$@"
if [ $? -ne 0 ]; then
echo "WAVM native failed"
exit 1
fi
./x86_64-windows-gnu.sh "$@"
if [ $? -ne 0 ]; then
echo "WAVM x86_64-windows-gnu failed"
exit 1
fi
HOST=aarch64-windows-gnu ./x86_64-windows-gnu.sh "$@"
if [ $? -ne 0 ]; then
echo "WAVM aarch64-windows-gnu failed"
fi
./aarch64-linux-gnu.sh "$@"
if [ $? -ne 0 ]; then
echo "WAVM aarch64-linux-gnu failed"
fi
./aarch64-linux-android30.sh "$@"
if [ $? -ne 0 ]; then
echo "WAVM aarch64-linux-andoid30 failed"
fi
