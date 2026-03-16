GCC_BUILD_MAIN="x86_64-linux-gnu"
GCCTRIPLETS=(
    "$GCC_BUILD_MAIN x86_64-w64-mingw32 i586-msdosdjgpp"
    "$GCC_BUILD_MAIN x86_64-w64-mingw32 x86_64-elf"
)
unset GCC_BUILD_MAIN