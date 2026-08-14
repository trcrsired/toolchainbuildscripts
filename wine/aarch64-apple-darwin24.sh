if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi
# Homebrew provides self-contained dylibs (e.g. libfreetype.dylib) that are
# usable at build time, unlike the sysroot's static libfreetype.a which is
# missing its brotli/png dependencies. Override EXTRAPATH for cross builds.
# This script may not be running on macOS, so only set EXTRAPATH when Homebrew
# (or the /opt/homebrew fallback) actually exists on disk.
if [ -z ${EXTRAPATH+x} ]; then
    if command -v brew >/dev/null 2>&1; then
        EXTRAPATH=$(brew --prefix 2>/dev/null)
    fi
    if [ -z "$EXTRAPATH" ]; then
        EXTRAPATH=/opt/homebrew
    fi
    if [ ! -d "$EXTRAPATH/include" ] && [ ! -d "$EXTRAPATH/lib" ]; then
        EXTRAPATH=
    fi
fi

SYSROOT=$TOOLCHAINSPATH/llvm/aarch64-apple-darwin24/aarch64-apple-darwin24 \
CC_FOR_HOST="clang --target=aarch64-apple-darwin24 --sysroot=$SYSROOT -mlinker-version=2.50"  \
CXX_FOR_HOST="clang++ --target=aarch64-apple-darwin24 --sysroot=$SYSROOT -mlinker-version=2.50"  \
CPP_FOR_HOST="clang-cpp --target=aarch64-apple-darwin24 --sysroot=$SYSROOT -mlinker-version=2.50"  \
LDFLAGS="-fuse-ld=lld -mlinker-version=2.50"  \
CONFIGUREEXTRAFLAGS="$CONFIGUREEXTRAFLAGS" \
EXTRAPATH="$EXTRAPATH" \
enable_wineandroid_drv=no CC=clang CXX=clang++ HOST=aarch64-apple-darwin24 ARCH=aarch64 NO_CREATE_LIBPTHREAD=yes BUILDDEPENDENCIES="no"  \
./wine.sh "$@"
