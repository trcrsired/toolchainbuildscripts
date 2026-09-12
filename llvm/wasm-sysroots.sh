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

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "$(realpath .)/.artifacts/wasm-sysroots"
	rm -rf "${TOOLCHAINS_LLVMSYSROOTSPATH}"
	rm "${TOOLCHAINS_LLVMSYSROOTSPATH}.tar.xz"
	# Also clean individual variant dirs
	for variant in wasm-sysroot wasm-memtag-sysroot wasm-noeh-sysroot wasm-noeh-memtag-sysroot; do
		rm -rf "${TOOLCHAINSPATH}/llvm/wasm-sysroots/${variant}"
	done
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

# Build all variants via build_common.sh
# Variants: <name> <enable_eh> <enable_memtag>
WASI_VARIANTS=(
	"wasm-sysroot 1 0"
	"wasm-memtag-sysroot 1 1"
	"wasm-noeh-sysroot 0 0"
	"wasm-noeh-memtag-sysroot 0 1"
)

for variant_spec in "${WASI_VARIANTS[@]}"; do
	read -r VARIANT ENABLE_EH ENABLE_MEMTAG <<< "$variant_spec"
	echo "===== Building variant: $VARIANT (EH=$ENABLE_EH, MEMTAG=$ENABLE_MEMTAG) ====="

	for triplet in "${WASI_TARGETS[@]}"; do
		echo "  --- Building $triplet ---"

		local_memtag=0
		if [[ "$ENABLE_MEMTAG" == "1" ]]; then
			local_memtag=1
		fi
#		MEMTAG_NOVERBOSE="yes"
		TRIPLET=$triplet \
		WASI_SYSROOT_VARIANT="$VARIANT" \
		ENABLE_WASILIBC_MEMTAG="$local_memtag" \
		BUILD_RUNTIMES_ENABLE_EXCEPTIONS=$ENABLE_EH \
		./build_common.sh "$1"

		if [ $? -ne 0 ]; then
			echo "❌ build_common.sh failed for $triplet (variant: $VARIANT)"
			exit 1
		fi
		echo "✔ Build succeeded for $triplet (variant: $VARIANT)"
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
