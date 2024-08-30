if [ -z ${HOST+x} ]; then
HOST=x86_64-windows-gnu
fi

if [ -z ${SYSTEMNAME+x} ]; then
SYSTEMNAME=Windows
fi

HOST=$HOST SYSTEMNAME=$SYSTEMNAME EXTRAFLAGS="-DCMAKE_C_LINKER_DEPFILE_SUPPORTED=Off -DCMAKE_CXX_LINKER_DEPFILE_SUPPORTED=Off -DCMAKE_ASM_LINKER_DEPFILE_SUPPORTED=Off" EXTRACFLAGS="-rtlib=compiler-rt --unwindlib=libunwind" EXTRACXXFLAGS="-rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -lunwind -lc++abi" ./wavm.sh "$@"
exit $?