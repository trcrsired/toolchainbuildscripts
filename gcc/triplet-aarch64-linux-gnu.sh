GCC_BUILD_MAIN="aarch64-linux-gnu"
GCCTRIPLETS=(
    "$GCC_BUILD_MAIN aarch64-linux-gnu aarch64-linux-gnu"

    "$GCC_BUILD_MAIN x86_64-linux-gnu x86_64-linux-gnu"
    "$GCC_BUILD_MAIN loongarch64-linux-gnu loongarch64-linux-gnu"
    "$GCC_BUILD_MAIN riscv64-linux-gnu riscv64-linux-gnu"
    "$GCC_BUILD_MAIN x86_64-w64-mingw32 x86_64-w64-mingw32"
    "$GCC_BUILD_MAIN i686-w64-mingw32 i686-w64-mingw32"
    "$GCC_BUILD_MAIN x86_64-linux-musl x86_64-linux-musl"
    "$GCC_BUILD_MAIN aarch64-linux-musl aarch64-linux-musl"
#    "$GCC_BUILD_MAIN i686-linux-musl i686-linux-musl"

    "$GCC_BUILD_MAIN x86_64-w64-mingw32 x86_64-linux-gnu"
    "$GCC_BUILD_MAIN x86_64-w64-mingw32 aarch64-linux-gnu"
    "$GCC_BUILD_MAIN x86_64-w64-mingw32 loongarch64-linux-gnu"
    "$GCC_BUILD_MAIN x86_64-w64-mingw32 riscv64-linux-gnu"
    "$GCC_BUILD_MAIN x86_64-w64-mingw32 x86_64-elf"
    "$GCC_BUILD_MAIN x86_64-w64-mingw32 i586-msdosdjgpp"
    "$GCC_BUILD_MAIN x86_64-w64-mingw32 i686-w64-mingw32"
    "$GCC_BUILD_MAIN x86_64-w64-mingw32 x86_64-linux-musl"
    "$GCC_BUILD_MAIN x86_64-w64-mingw32 aarch64-linux-musl"
    "$GCC_BUILD_MAIN x86_64-w64-mingw32 i686-linux-musl"
)

GCC_EXTRA_HOSTS=(
    # x86_64-linux-gnu hosts
    "$GCC_BUILD_MAIN x86_64-linux-gnu x86_64-w64-mingw32"
    "$GCC_BUILD_MAIN x86_64-linux-gnu aarch64-linux-gnu"
    "$GCC_BUILD_MAIN x86_64-linux-gnu loongarch64-linux-gnu"
    "$GCC_BUILD_MAIN x86_64-linux-gnu riscv64-linux-gnu"
    "$GCC_BUILD_MAIN x86_64-linux-gnu x86_64-elf"
    "$GCC_BUILD_MAIN x86_64-linux-gnu i586-msdosdjgpp"
    "$GCC_BUILD_MAIN x86_64-linux-gnu i686-w64-mingw32"
    "$GCC_BUILD_MAIN x86_64-linux-gnu x86_64-linux-musl"
    "$GCC_BUILD_MAIN x86_64-linux-gnu aarch64-linux-musl"
    "$GCC_BUILD_MAIN x86_64-linux-gnu i686-linux-musl"

    # loongarch64-linux-gnu hosts
    "$GCC_BUILD_MAIN loongarch64-linux-gnu x86_64-w64-mingw32"
    "$GCC_BUILD_MAIN loongarch64-linux-gnu x86_64-linux-gnu"
    "$GCC_BUILD_MAIN loongarch64-linux-gnu aarch64-linux-gnu"
    "$GCC_BUILD_MAIN loongarch64-linux-gnu riscv64-linux-gnu"
    "$GCC_BUILD_MAIN loongarch64-linux-gnu x86_64-elf"
    "$GCC_BUILD_MAIN loongarch64-linux-gnu i586-msdosdjgpp"
    "$GCC_BUILD_MAIN loongarch64-linux-gnu i686-w64-mingw32"
    "$GCC_BUILD_MAIN loongarch64-linux-gnu x86_64-linux-musl"
    "$GCC_BUILD_MAIN loongarch64-linux-gnu aarch64-linux-musl"
    "$GCC_BUILD_MAIN loongarch64-linux-gnu i686-linux-musl"
)

if [[ -n "$GCC_BUILD_ALL_HOSTS" ]]; then
    GCCTRIPLETS+=("${EXTRA_HOSTS[@]}")
fi

unset GCC_BUILD_MAIN
unset GCC_EXTRA_HOSTS