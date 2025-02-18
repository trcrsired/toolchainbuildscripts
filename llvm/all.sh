llvmcurrentrealpath="$(realpath .)"

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "$llvmcurrentrealpath/.llvmartifacts"
	rm -rf "$llvmcurrentrealpath/.llvmwasmartifacts"
	echo "restart done"
fi
./x86_64-linux-gnu.sh "$@"
./x86_64-windows-gnu.sh "$@"
./aarch64-windows-gnu.sh "$@"
./aarch64-linux-android30.sh "$@"
./x86_64-linux-android30.sh "$@"
#./x86_64-linux-android28.sh "$@"
#ANDROIDAPIVERSION=24 ./aarch64-linux-android30.sh "$@"
./aarch64-linux-gnu.sh "$@"
#./x86_64-generic-linux-gnu.sh "$@"
./loongarch64-linux-gnu.sh "$@"
./riscv64-linux-gnu.sh "$@"
./aarch64-apple-darwin24.sh "$@"
./wasm-sysroots.sh "$@"

if [[ $NO_BUILD_WAVM != "yes" ]]; then
cd "$llvmcurrentrealpath/../wavm"
./all.sh "$@"
fi
