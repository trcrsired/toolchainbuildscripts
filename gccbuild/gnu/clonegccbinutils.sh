cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/binutils-gdb" ]; then
git clone git://sourceware.org/git/binutils-gdb.git
if [ $? -ne 0 ]; then
echo "binutils-gdb clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/binutils-gdb"
git pull --quiet

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/gcc" ]; then
git clone git://gcc.gnu.org/git/gcc.git
if [ $? -ne 0 ]; then
echo "gcc clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/gcc"
git pull --quiet

if [ -z ${CLONELINUX+x} ]; then
if [ ! -d "$TOOLCHAINS_BUILD/linux" ]; then
cd "$TOOLCHAINS_BUILD"
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
if [ $? -ne 0 ]; then
echo "linux clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/linux"
git pull --quiet
fi

if [ -z ${CLONEMINGW64+x} ]; then
cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/mingw-w64" ]; then
git clone https://git.code.sf.net/p/mingw-w64/mingw-w64
if [ $? -ne 0 ]; then
echo "mingw-w64 clone failed"
fi
fi
cd "$TOOLCHAINS_BUILD/mingw-w64"
git pull --quiet
fi
