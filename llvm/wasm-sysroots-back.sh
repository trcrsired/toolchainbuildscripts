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

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "$(realpath .)/.artifacts/llvm/wasm32-wasip1"
	rm -rf "$(realpath .)/.artifacts/llvm/wasm32-wasip2"
	rm -rf "$(realpath .)/.artifacts/llvm/wasm32-wasip1-threads"
	rm -rf "$(realpath .)/.artifacts/llvm/wasm32-wasip2-threads"
	rm -rf "$(realpath .)/.artifacts/llvm/wasm64-wasip1"
	rm -rf "$(realpath .)/.artifacts/llvm/wasm64-wasip1-threads"
	rm -rf "$TOOLCHAINS_LLVMPATH/wasm32-wasip1"
	rm -rf "$TOOLCHAINS_LLVMPATH/wasm32-wasip2"
	rm -rf "$TOOLCHAINS_LLVMPATH/wasm32-wasip1-threads"
	rm -rf "$TOOLCHAINS_LLVMPATH/wasm32-wasip2-threads"
	rm -rf "$TOOLCHAINS_LLVMPATH/wasm64-wasip1"
	rm -rf "$TOOLCHAINS_LLVMPATH/wasm64-wasip1-threads"
	echo "restart done"
fi

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
	"wasm32-wasip1-threads"
	"wasm32-wasip2-threads"
	"wasm64-wasip1"
	"wasm64-wasip1-threads"
)

for triplet in "${WASI_TARGETS[@]}"; do
	echo "===== Building $triplet ====="
	TRIPLET=$triplet ./build_common.sh "$1"
	if [ $? -ne 0 ]; then
		echo "❌ Build failed for $triplet"
		exit 1
	fi
	echo "✔ Build succeeded for $triplet"
done

echo "🎉 All WASI builds completed successfully"
