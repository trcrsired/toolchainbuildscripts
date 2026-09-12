#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -z ${LLVMPROJECTPATH+x} ]; then
	LLVMPROJECTPATH=$TOOLCHAINS_BUILD/llvm-project
fi

if [ -z ${WASILIBCPATH+x} ]; then
	WASILIBCPATH=$TOOLCHAINS_BUILD/wasi-libc
fi

TOOLCHAINS_LLVMPATH="$TOOLCHAINSPATH/llvm"
TOOLCHAINS_LLVMSYSROOTSPATH="$TOOLCHAINS_LLVMPATH/wasm-sysroots"

# Define all WASI sysroot variants
WASI_VARIANTS=(
	"wasm-sysroot"
	"wasm-sysroot-mtg"
	"wasm-sysroot-noeh"
	"wasm-sysroot-noeh-mtg"
)

# Define all WASI targets
WASI_TARGETS=(
	"wasm32-wasip1"
	"wasm32-wasip2"
	"wasm32-wasip3"
	"wasm32-wasip1-threads"
	"wasm64-wasip1"
	"wasm64-wasip2"
	"wasm64-wasip3"
	"wasm64-wasip1-threads"
)

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "$(realpath .)/.artifacts/wasm-sysroots"
	rm -rf "${TOOLCHAINS_LLVMSYSROOTSPATH}"
	rm -f "${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz"
	echo "restart done"
fi

mkdir -p "$TOOLCHAINS_LLVMSYSROOTSPATH"
mkdir -p "$TOOLCHAINS_BUILD"
mkdir -p "$TOOLCHAINSPATH"

cd "$SCRIPT_DIR/../common"
source ./common.sh

cd "$SCRIPT_DIR"

# Clone wasi-libc if needed
clone_or_update_dependency wasi-libc

cd "$SCRIPT_DIR"

for variant in "${WASI_VARIANTS[@]}"; do
	echo "===== Building variant $variant ====="

	local_memtag=0
	local_eh=1
	if [[ "$variant" == *mtg* ]]; then
		local_memtag=1
	fi
	if [[ "$variant" == *noeh* ]]; then
		local_eh=0
	fi

	for triplet in "${WASI_TARGETS[@]}"; do
		echo "===== Building $variant / $triplet ====="

		TRIPLET=$triplet \
		WASI_SYSROOT_VARIANT=$variant \
		WASI_FLAT_SYSROOTS=1 \
		ENABLE_WASILIBC_MEMTAG="$local_memtag" \
		BUILD_RUNTIMES_ENABLE_EXCEPTIONS=$local_eh \
		./build_common.sh "$1"

		if [ $? -ne 0 ]; then
			echo "❌ build_common.sh failed for $variant / $triplet"
			exit 1
		fi
		echo "✔ Build succeeded for $variant / $triplet"
	done
done

echo "🎉 All WASI builds completed successfully"

# Package all sysroots
if [ ! -f "${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz" ]; then
	if [ -d "${TOOLCHAINS_LLVMSYSROOTSPATH}" ]; then
		cd "$TOOLCHAINS_LLVMPATH"
		XZ_OPT=-e9T0 tar cJf wasm-sysroots.tar.xz wasm-sysroots
		chmod 755 wasm-sysroots.tar.xz
	fi
fi
