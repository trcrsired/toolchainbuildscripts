buildallcurrentpath=$(realpath .)

cd $buildallcurrentpath/llvm
./all.sh "$@"
./libcxx-windows-msvc.sh "$@"
cd $buildallcurrentpath/others
./wasm-sysroots.sh "$@"
cd $buildallcurrentpath/gccbuild/x86_64-w64-mingw32
./all.sh "$@"
cd $buildallcurrentpath/wavm
./all.sh "$@"
cd $buildallcurrentpath/wine
./wine.sh "$@"
./aarch64-linux-android30.sh "$@"
