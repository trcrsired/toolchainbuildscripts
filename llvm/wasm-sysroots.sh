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
ARTIFACTS_ROOT="$(realpath "$SCRIPT_DIR")/.artifacts"

# Define all WASI sysroot variants
WASI_VARIANTS=(
	"wasm-sysroot-noeh-mtg"
	"wasm-sysroot-noeh"
	"wasm-sysroot-mtg"
	"wasm-sysroot"
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
	rm -rf "${ARTIFACTS_ROOT}/wasm-sysroots"
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

	# Pseudo toolchain root inside .artifacts; build_common.sh installs
	# <triplet>/{<triplet>,builtins,runtimes,libherbceptions,...} under it
	# which we then collapse into the real sysroot layout.
	pseudo_llvm="${ARTIFACTS_ROOT}/wasm-sysroots/${variant}/pseudo"
	variant_sysroot="${TOOLCHAINS_LLVMSYSROOTSPATH}/${variant}"

	for triplet in "${WASI_TARGETS[@]}"; do
		echo "===== Building $variant / $triplet ====="

		TRIPLET=$triplet \
		WASI_SYSROOT_VARIANT=$variant \
		TOOLCHAINS_LLVMPATH="$pseudo_llvm" \
		ENABLE_WASILIBC_MEMTAG="$local_memtag" \
		BUILD_RUNTIMES_ENABLE_EXCEPTIONS=$local_eh \
		./build_common.sh "$1"

		if [ $? -ne 0 ]; then
			echo "❌ build_common.sh failed for $variant / $triplet"
			exit 1
		fi

		# Collapse pseudo/<triplet>/<triplet> (the per-triplet sysroot that
		# build_common.sh already merged wasi-libc + runtimes + libherbceptions
		# into) into the shared variant sysroot. Everything except lib merges at
		# the top level; lib/* goes under lib/<triplet> so triplets coexist.
		pseudo_triplet="${pseudo_llvm}/${triplet}"
		pseudo_sysroot="${pseudo_triplet}/${triplet}"
		mkdir -p "$variant_sysroot"

		if [ -d "$pseudo_sysroot" ]; then
			for item in "${pseudo_sysroot}/"*; do
				[ -e "$item" ] || continue
				if [ "$(basename "$item")" == "lib" ]; then
					mkdir -p "${variant_sysroot}/lib/${triplet}"
					# wasi-libc's own lib/<triplet> contents merge in place
					if [ -d "${item}/${triplet}" ]; then
						cp -r --preserve=links "${item}/${triplet}/"* "${variant_sysroot}/lib/${triplet}/"
					fi
					for libitem in "${item}/"*; do
						[ -e "$libitem" ] || continue
						[ "$(basename "$libitem")" == "$triplet" ] && continue
						cp -r --preserve=links "$libitem" "${variant_sysroot}/lib/${triplet}/"
					done
				else
					cp -r --preserve=links "$item" "${variant_sysroot}/"
				fi
			done
		fi

		# libc++.modules.json references ../share relative to lib/; fix it up
		# for the extra <triplet> level
		if [ -f "${variant_sysroot}/lib/${triplet}/libc++.modules.json" ]; then
			sed -i "s|\.\./share/|../../share/|g" "${variant_sysroot}/lib/${triplet}/libc++.modules.json"
		fi

		# builtins go to the shared wasm-sysroots root
		if [ -d "${pseudo_triplet}/builtins" ]; then
			mkdir -p "${TOOLCHAINS_LLVMSYSROOTSPATH}/builtins"
			cp -r --preserve=links "${pseudo_triplet}/builtins/"* "${TOOLCHAINS_LLVMSYSROOTSPATH}/builtins/"
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
