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

if [ -z ${WINDOWSSYSROOT+x} ]; then
	WINDOWSSYSROOT=$TOOLCHAINSPATH/windows-msvc-sysroot
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf "$(realpath .)/.artifacts/windows-msvc-sysroot"
	rm -rf "${WINDOWSSYSROOT}/include/c++/v1"
	rm -rf "${WINDOWSSYSROOT}/share/libc++"
	echo "restart done"
fi

if [ ! -d "$LLVMPROJECTPATH" ]; then
	cd $TOOLCHAINS_BUILD
	git clone git@github.com:llvm/llvm-project.git $LLVMPROJECTPATH
	if [ $? -ne 0 ]; then
		echo "llvm clone failure"
		exit 1
	fi
fi
cd "$LLVMPROJECTPATH"
git pull --quiet

if [ ! -d "$WINDOWSSYSROOT" ]; then
	cd $TOOLCHAINSPATH
	git clone git@github.com:trcrsired/windows-msvc-sysroot.git
	if [ $? -ne 0 ]; then
		echo "windows-msvc-sysroot clone failure"
		exit 1
	fi
fi

cd "$WINDOWSSYSROOT"
git pull --quiet

export WINDOWSMSVCSYSROOT="$WINDOWSSYSROOT"
export WINDOWS_MSVC_SYSROOT_RUNTIMES_LIBCXX_BUILD=1
export WINDOWS_MSVC_SYSROOT_RUNTIMES_BUILD=1

cd "$SCRIPT_DIR"

for arch in x86_64 i686 aarch64; do
	export TRIPLET="$arch-unknown-windows-msvc"
	echo "===== Building libc++ for $TRIPLET ====="
	bash "$SCRIPT_DIR/build_common.sh" $1
	if [ $? -ne 0 ]; then
		echo "❌ build_common.sh failed for $TRIPLET"
		exit 1
	fi
	echo "✅ Build succeeded for $TRIPLET"
done

if [[ -z "${NO_GIT_PUSH+x}" ]]; then
	cd "$WINDOWSSYSROOT"
	git add -A
	git commit -m "auto update libc++ from LLVM source"
	git push
fi
