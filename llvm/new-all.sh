llvmcurrentrealpath="$(realpath .)"

cd "$llvmcurrentrealpath"
TRIPLET=aarch64-linux-android28 ./build_common.sh "$@"