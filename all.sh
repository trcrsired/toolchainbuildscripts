buildallcurrentpath=$(realpath .)

cd $buildallcurrentpath/llvm
./all.sh "$@"
cd $buildallcurrentpath/llvm
./wasm-sysroots.sh "$@"
cd $buildallcurrentpath/gccbuild/x86_64-w64-mingw32
./all.sh "$@"
cd $buildallcurrentpath/wavm
./all.sh "$@"

