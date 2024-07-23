if ! ./native.sh "$@"; then
exit 1
fi
if ! ./x86_64-w64-mingw32.sh "$@"; then
exit 1
fi
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
