./x86_64-linux-gnu.sh "$@"
if [ $? -ne 0 ]; then
echo "WAVM x86_64-linux-gnu failed"
exit 1
fi
./x86_64-windows-gnu.sh "$@"
if [ $? -ne 0 ]; then
echo "WAVM x86_64-windows-gnu failed"
exit 1
fi
./aarch64-windows-gnu.sh "$@"
if [ $? -ne 0 ]; then
echo "WAVM aarch64-windows-gnu failed"
fi
./aarch64-linux-gnu.sh "$@"
if [ $? -ne 0 ]; then
echo "WAVM aarch64-linux-gnu failed"
fi
./aarch64-linux-android30.sh "$@"
if [ $? -ne 0 ]; then
echo "WAVM aarch64-linux-android30 failed"
fi
./x86_64-linux-android30.sh "$@"
if [ $? -ne 0 ]; then
echo "WAVM x86_64-linux-android30 failed"
fi
#./aarch64-apple-darwin24.sh "$@"
#if [ $? -ne 0 ]; then
#echo "WAVM aarch64-apple-darwin24 failed"
#fi
