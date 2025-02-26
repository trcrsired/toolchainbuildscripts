if ! ./native.sh "$@"; then
exit 1
fi
#if ! ./aarch64-w64-mingw32.sh "$@"; then
#exit 1
#fi
if ! ./x86_64-linux-gnu.sh "$@"; then
exit 1
fi
if ! ./aarch64-linux-gnu.sh "$@"; then
exit 1
fi
if ! ./x86_64-elf.sh "$@"; then
exit 1
fi
if ! ./loongarch64-linux-gnu.sh "$@"; then
exit 1
fi
if ! ./loongarch64-linux-musl.sh "$@"; then
exit 1
fi
if ! ./x86_64-freebsd14.sh "$@"; then
exit 1
fi
if ! ./i586-msdosdjgpp.sh "$@"; then
exit 1
fi
if ! ./i686-w64-mingw32.sh "$@"; then
exit 1
fi
if ! ./riscv64-linux-gnu.sh "$@"; then
exit 1
fi

