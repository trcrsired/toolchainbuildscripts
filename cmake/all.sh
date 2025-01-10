./aarch64-windows-gnu.sh "$@"
./x86_64-windows-gnu.sh "$@"
./aarch64-linux-android30.sh "$@"
./x86_64-linux-android30.sh "$@"
if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -d "$TOOLCHAINSPATH/windows-msvc-sysroot" ]; then
./aarch64-windows-msvc.sh "$@"
./x86_64-windows-msvc.sh "$@"
fi
