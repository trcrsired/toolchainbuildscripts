if [ -z ${HOST+x} ]; then
HOST=aarch64-windows-msvc
fi

if [ -z ${SYSTEMNAME+x} ]; then
SYSTEMNAME=Windows
fi

HOST=$HOST SYSTEMNAME=$SYSTEMNAME EXTRAFLAGS="-DCMAKE_C_LINKER_DEPFILE_SUPPORTED=Off -DCMAKE_CXX_LINKER_DEPFILE_SUPPORTED=Off -DCMAKE_ASM_LINKER_DEPFILE_SUPPORTED=Off -DCMAKE_C_COMPILER_WORKS=On -DCMAKE_CXX_COMPILER_WORKS=On -DCMAKE_ASM_COMPILER_WORKS=On" EXTRACFLAGS="--config=$HOME/cfgs/c/aarch64-windows-msvc.cfg -Wl,--section-alignment=0x10000 -Wl,/driver" EXTRACXXFLAGS="--config=$HOME/cfgs/aarch64-windows-msvc.cfg -Wl,--section-alignment=0x10000 -Wl,/driver" ./wavm.sh "$@"
exit $?
