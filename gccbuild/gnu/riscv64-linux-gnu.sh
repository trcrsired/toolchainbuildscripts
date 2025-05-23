#!/bin/bash

source ../../common/safe-llvm-strip.sh

./dependencycheck.sh
if [ $? -ne 0 ]; then
exit 1
fi

relpath=$(realpath .)
if [ -z ${HOST+x} ]; then
	HOST=riscv64-linux-gnu
fi
currentpath=$relpath/.gnuartifacts/$HOST
mkdir -p ${currentpath}
if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -z ${TOOLCHAINSPATH_GNU+x} ]; then
	TOOLCHAINSPATH_GNU=$TOOLCHAINSPATH/gnu
fi

mkdir -p "${TOOLCHAINSPATH_GNU}"


if [ -z ${CANADIANHOST+x} ]; then
	CANADIANHOST=x86_64-w64-mingw32
fi

BUILD=$(gcc -dumpmachine)
NEW_BUILD=$(echo "$BUILD" | sed 's/-pc//g')

if command -v "${NEW_BUILD}-g++" >/dev/null 2>&1; then
    BUILD=$NEW_BUILD
fi

TARGET=$BUILD
PREFIX=$TOOLCHAINSPATH_GNU/$BUILD/$HOST
PREFIXTARGET=$PREFIX/$HOST
export PATH=$PREFIX/bin:$PATH
HOSTPREFIX=$TOOLCHAINSPATH_GNU/$HOST/$HOST
HOSTPREFIXTARGET=$HOSTPREFIX/$HOST

export PATH=$TOOLCHAINSPATH_GNU/$BUILD/$CANADIANHOST/bin:$PATH
CANADIANHOSTPREFIX=$TOOLCHAINSPATH_GNU/$CANADIANHOST/$HOST

if [[ "${NEW_BUILD}" == "${HOST}" ]]; then
    export PATH="$TOOLCHAINSPATH_GNU/${TARGET}/${TARGET}/bin:$PATH"
fi

if [[ "${NEW_BUILD}" != "${BUILD}" ]]; then
    export PATH="$TOOLCHAINSPATH_GNU/${NEW_BUILD}/${NEW_BUILD}/bin:$PATH"
fi

# Echo the value of $HOST
echo "HOST: $HOST"

# Extract and assign parts from $HOST
HOST_CPU=${HOST%%-*}                         # Extract 'cpu'
HOST_REMAINDER=${HOST#*-}                    # Remaining parts after 'cpu'
if [[ "$HOST_REMAINDER" == "$HOST" ]]; then
    echo "Invalid format: Missing other parts"
    exit 1
fi

# Extract HOST_VENDOR and update HOST_REMAINDER
if [[ "$HOST_REMAINDER" == *-* ]]; then
    HOST_VENDOR=${HOST_REMAINDER%%-*}        # Extract 'vendor'
    HOST_REMAINDER=${HOST_REMAINDER#*-}      # Update HOST_REMAINDER
else
    HOST_VENDOR=""
fi

# Correct behavior if HOST_VENDOR is 'linux'
if [[ "$HOST_VENDOR" == "linux" ]]; then
    HOST_VENDOR=""                           # Clear HOST_VENDOR as 'linux' is part of HOST_OS
    HOST_OS="linux"            # Shift HOST_OS from HOST_REMAINDER
    HOST_ABI=${HOST_REMAINDER#*-}            # Extract 'abi' from HOST_REMAINDER
else
    # Normal behavior for non-'linux' HOST_VENDOR
    if [[ "$HOST_REMAINDER" == *-* ]]; then
        HOST_OS=${HOST_REMAINDER%%-*}        # Extract 'os'
        HOST_ABI=${HOST_REMAINDER#*-}        # Extract 'abi'
    else
        HOST_OS=$HOST_REMAINDER              # Remaining part becomes OS
        HOST_ABI=""
    fi
fi

# Unset HOST_REMAINDER to clean up
unset HOST_REMAINDER

# Echo the results
echo "HOST_CPU: $HOST_CPU"
echo "HOST_VENDOR: $HOST_VENDOR"
echo "HOST_OS: $HOST_OS"
echo "HOST_ABI: $HOST_ABI"

echo "gcc=$(which gcc)
cc=$(which cc)
g++=$(which g++)
PATH=$PATH
HOST=${HOST}
TARGET=$TARGET
NEWBUILD=${NEW_BUILD}"

if [ -z ${ARCH+x} ]; then
	ARCH=${HOST_CPU}
fi

if [[ $ARCH == "aarch64" ]]; then
	ARCH="arm64"
elif [[ $ARCH != x86_64 ]]; then
	ARCH="${ARCH%%[0-9]*}"	
fi

if [[ $1 == "clean" ]]; then
	echo "cleaning"
	rm -rf ${currentpath}
	echo "clean done"
	exit 0
fi

if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -rf ${currentpath}
	rm -rf ${PREFIX}
	rm -f ${PREFIX}.tar.xz
	rm -rf ${CANADIANHOSTPREFIX}
	rm -f ${CANADIANHOSTPREFIX}.tar.xz
	rm -rf ${HOSTPREFIXTARGET}
	rm -f ${HOSTPREFIXTARGET}.tar.xz
	echo "restart done"
fi

if [ ! -d ${currentpath} ]; then
	mkdir ${currentpath}
	cd ${currentpath}
fi

CROSSTRIPLETTRIPLETS="--build=$BUILD --host=$BUILD --target=$HOST"

if [[ ${USE_NEWLIB} == "yes" ]]; then
	FREESTANDINGBUILD=no
	MULTILIBLISTS="$MULTILIBLISTS --with-newlib"
fi
USRALTERNATIVENAME=usr

if [[ ${HOST_OS} == mingw* ]]; then
USRALTERNATIVENAME=mingw
fi

if [[ ${FREESTANDINGBUILD} == "yes" ]]; then
	MULTILIBLISTS="$MULTILIBLISTS \
	--disable-hosted-libstdcxx \
	--disable-libssp \
	--disable-libquadmath \
	--disable-libbacktarce"
elif [[ ${FREESTANDINGBUILD} != "yes" ]]; then
	if [[ ${HOST_ABI} == "musl" ]]; then
		MULTILIBLISTS="--disable-multilib --disable-shared --enable-static --disable-libsanitizer"
	elif [[ ${HOST_OS} == "linux" && ${HOST_ABI} == "gnu" ]]; then
		if [[ ${HOST_CPU} == "x86_64" ]]; then
			MULTILIBLISTS="--with-multilib-list=m64"
		elif [[ ${ARCH} == "sparc" ]]; then
			MULTILIBLISTS="--disable-multilib"
		fi
		if [[ ${ARCH} == "arm64" || ${ARCH} == riscv* ]]; then
			MULTILIBLISTS="$MULTILIBLISTS --disable-libsanitizer"
		fi
	elif [[ ${HOST_OS} == mingw* ]]; then
		if [[ ${HOST_CPU} == "i[3-6]86" ]]; then
			MULTILIBLISTS="--disable-tls --disable-threads --disable-libstdcxx-threads --disable-multilib"
		fi
		if [[ $HOST_CPU == "x86_64" ]]; then
			MINGWW64FLAGS=""
		elif [[ $HOST_CPU == "aarch64" ]]; then
			MINGWW64FLAGS="--disable-libarm32 --disable-lib32 --disable-lib64 --enable-libarm64"
		elif [[ $HOST_CPU == "i[3-6]86" ]]; then
			MINGWW64FLAGS="--disable-libarm32 --enable-lib32 --disable-lib64 --disable-libarm64 --with-default-msvcrt=msvcrt"
		fi
	fi
fi

if [[ ${FREESTANDINGBUILD} == "yes" ]]; then
GCCCONFIGUREFLAGSCOMMON="--disable-nls \
--disable-werror \
--enable-languages=c,c++ \
$MULTILIBLISTS \
--disable-bootstrap \
--with-libstdcxx-eh-pool-obj-count=0 \
--disable-sjlj-exceptions"
else
GCCCONFIGUREFLAGSCOMMON="--disable-nls \
--disable-werror \
--enable-languages=c,c++ \
$MULTILIBLISTS \
--disable-bootstrap \
--disable-libstdcxx-verbose \
--with-libstdcxx-eh-pool-obj-count=0 \
--disable-sjlj-exceptions \
--enable-libstdcxx-backtrace"
fi

: <<'EOF'
if [[ ${ARCH} == "loongarch" ]]; then
ENABLEGOLD="--disable-tui --without-debuginfod"
else
ENABLEGOLD="--disable-tui --without-debuginfod --enable-gold"
fi
EOF

if [[ ${ARCH} != "loongarch" ]]; then
if [[ ${HOST_OS} == "linux" || ${HOST_OS} == "elf" || ${HOST_OS} == freebsd* ]]; then
ENABLEGOLD="--enable-gold"
fi
fi

if ! $relpath/clonebinutilsgccwithdeps.sh
then
exit 1
fi

if [[ $HOST_ABI == "musl" ]]; then
if [ ! -d "$TOOLCHAINS_BUILD/musl" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git@github.com:bminor/musl.git
if [ $? -ne 0 ]; then
echo "musl clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/musl"
git pull --quiet
fi

if [[  $HOST_OS == "linux" && $HOST_ABI == "gnu" ]]; then
if [ ! -d "$TOOLCHAINS_BUILD/glibc" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git://sourceware.org/git/glibc.git
if [ $? -ne 0 ]; then
echo "glibc clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/glibc"
git pull --quiet
fi

if [[ ${USE_NEWLIB} == "yes" ]]; then

if [ -z "${CUSTOM_BUILD_SYSROOT}" ]; then
if [ ! -d "$TOOLCHAINS_BUILD/newlib-cygwin" ]; then
cd "$TOOLCHAINS_BUILD"
git clone git@github.com:mirror/newlib-cygwin.git
if [ $? -ne 0 ]; then
echo "newlib-cygwin clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/newlib-cygwin"
git pull --quiet
fi

fi
if [[  $HOST_OS == "linux" ]]; then
if [ ! -d "$TOOLCHAINS_BUILD/linux" ]; then
cd "$TOOLCHAINS_BUILD"
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
if [ $? -ne 0 ]; then
echo "linux clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/linux"
git pull --quiet
fi

isnativebuild=
if [[ $BUILD == $HOST ]]; then
isnativebuild=yes
fi


# Ensure SYSROOT and the tarball are set
SYSROOT="${currentpath}/install/sysroot"
mkdir -p "${SYSROOT}"

# Download the tarball (if needed)
if [[ "$HOST_OS" == freebsd* ]]; then
    USE_PRECOMPILED_SYSROOT=yes
		DISABLE_CANADIAN_NATIVE=yes

		mkdir -p ${currentpath}/downloads

	if [ ! -f ${currentpath}/install/.copysysrootsuccess ]; then
			cd "${currentpath}/downloads"
			wget https://github.com/trcrsired/x86_64-freebsd-libc-bin/releases/download/1/${HOST_CPU}-freebsd-libc.tar.xz
			if [ $? -ne 0 ]; then
					echo "wget ${HOST} failure"
					exit 1
			fi

			mkdir -p ${currentpath}/downloads/sysroot_decompress
			# Decompress the tarball into a temporary directory
			tar -xvf ${HOST_CPU}-freebsd-libc.tar.xz -C "${currentpath}/downloads/sysroot_decompress"
			if [ $? -ne 0 ]; then
					echo "tar extraction failure"
					exit 1
			fi
			mkdir -p "${SYSROOT}/${USRALTERNATIVENAME}"
			# Move all extracted files into $SYSROOT/${USRALTERNATIVENAME}
			cp -r --preserve=links "${currentpath}/downloads/sysroot_decompress"/${HOST_CPU}-freebsd-libc/* "${SYSROOT}/${USRALTERNATIVENAME}/"
			if [ $? -ne 0 ]; then
					echo "Failed to move files to ${SYSROOT}/${USRALTERNATIVENAME}"
					exit 1
			fi

			echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.copysysrootsuccess
		fi
elif [[ "$HOST_OS" == darwin* ]]; then
	ELIMINATESYSROOT=no
	# Enable the precompiled sysroot
	USE_PRECOMPILED_SYSROOT=yes
	# Check if sysroot copying is already marked as successful
	if [ ! -f "${currentpath}/install/.copysysrootsuccess" ]; then

			# Retrieve DARWINVERSIONDATE if not already set
			if [ -z "${DARWINVERSIONDATE+x}" ]; then
					DARWINVERSIONDATE=$(git ls-remote --tags git@github.com:trcrsired/apple-darwin-sysroot.git | tail -n 1 | sed 's/.*\///')
					if [ $? -ne 0 ] || [ -z "$DARWINVERSIONDATE" ]; then
							echo "Error: Failed to retrieve DARWINVERSIONDATE."
							exit 1
					fi
			fi

			mkdir -p ${currentpath}/downloads
			# Change to the downloads directory
			cd "${currentpath}/downloads"

			NEWHOST=${HOST/arm64-/aarch64-}
			# Download the tarball
			wget https://github.com/trcrsired/apple-darwin-sysroot/releases/download/${DARWINVERSIONDATE}/${NEWHOST}.tar.xz
			if [ $? -ne 0 ]; then
					echo "Error: Failed to download ${NEWHOST}.tar.xz."
					exit 1
			fi

			# Set appropriate permissions for the tarball
			chmod 755 "${NEWHOST}.tar.xz"
			if [ $? -ne 0 ]; then
					echo "Error: Failed to set permissions on ${NEWHOST}.tar.xz."
					exit 1
			fi

			# Extract the tarball into the sysroot directory
			tar -xf "${NEWHOST}.tar.xz" -C "${currentpath}/downloads/sysroot_decompress"
			if [ $? -ne 0 ]; then
					echo "Error: Failed to extract ${NEWHOST}.tar.xz to $SYSROOT."
					exit 1
			fi

			cp -r --preserve=links "${currentpath}/downloads/sysroot/$sysroot_decompress/*" "${SYSROOT}/"

			# Mark the operation as successful
			echo "$(date --iso-8601=seconds)" > "${currentpath}/install/.copysysrootsuccess"
			if [ $? -ne 0 ]; then
					echo "Error: Failed to create success marker file."
					exit 1
			fi

			echo "Sysroot setup completed successfully."
	else
			echo "Sysroot is already set up. Skipping."
	fi
elif [[ "$HOST_OS" == mingw* ]]; then
	USE_ONEPHASE_GCC_BUILD=yes
	if [ -z ${ELIMINATESYSROOT+x} ]; then
		ELIMINATESYSROOT=yes
	fi
	cd "$TOOLCHAINS_BUILD"
	if [ ! -d "$TOOLCHAINS_BUILD/mingw-w64" ]; then
	git clone https://git.code.sf.net/p/mingw-w64/mingw-w64
	fi
	cd "$TOOLCHAINS_BUILD/mingw-w64"
	git pull --quiet

elif [[ "$USE_NEWLIB" == "yes" || "${FREESTANDINGBUILD}" == "yes" ]]; then
	USE_ONEPHASE_GCC_BUILD=yes
	ELIMINATESYSROOT=yes
elif [[ "$HOST_OS" == "msdosdjgpp" ]]; then
	# Enable the precompiled sysroot
	USE_PRECOMPILED_SYSROOT=yes
	DISABLE_CANADIAN_NATIVE=yes
	GCCCONFIGUREFLAGSCOMMON="$GCCCONFIGUREFLAGSCOMMON --disable-threads"
	if [ ! -f "${currentpath}/install/.copysysrootsuccess" ]; then
		if [ -z ${DJCRX+x} ]; then
						DJCRX=djcrx205
		fi
		USRALTERNATIVENAME=dev/env/DJDIR
		mkdir -p "${currentpath}/downloads"
		mkdir -p "${SYSROOT}/${USRALTERNATIVENAME}"
		cd "${currentpath}/downloads"
		# Download the zip file
		wget http://www.delorie.com/pub/djgpp/current/v2/${DJCRX}.zip
		if [ $? -ne 0 ]; then
				echo "Error: Failed to download ${DJCRX}.zip"
				exit 1
		fi

		# Change permissions of the downloaded zip file (ignore errors)
		chmod 755 ${DJCRX}.zip || true

		# Unzip the downloaded file
		unzip ${DJCRX}.zip -d "${SYSROOT}/${USRALTERNATIVENAME}"
		if [ $? -ne 0 ]; then
				echo "Error: Failed to unzip ${DJCRX}.zip"
				exit 1
		fi

		# Create the target directory for binaries (ignore errors)
		mkdir -p "${PREFIXTARGET}/bin" || true

		# Compile stubify
		gcc -o $PREFIXTARGET/bin/stubify ${SYSROOT}/${USRALTERNATIVENAME}/src/stub/stubify.c -s -O3 -flto
		if [ $? -ne 0 ]; then
				echo "Error: Failed to compile stubify"
				exit 1
		fi

		# Compile stubedit
		gcc -o $PREFIXTARGET/bin/stubedit ${SYSROOT}/${USRALTERNATIVENAME}/src/stub/stubedit.c -s -O3 -flto
		if [ $? -ne 0 ]; then
				echo "Error: Failed to compile stubedit"
				exit 1
		fi
		mkdir -p "${currentpath}/install"
		mkdir -p "${PREFIX}/${USRALTERNATIVENAME}"
		cp -r --preserve=links "${SYSROOT}"/* "${PREFIX}"/  
		echo "$(date --iso-8601=seconds)" > "${currentpath}/install/.copysysrootsuccess"
	fi
fi

if [[ "${USE_PRECOMPILED_SYSROOT}" == "yes" ]]; then
	USE_ONEPHASE_GCC_BUILD=yes
	if [ ! -f "${currentpath}/install/.copysysrootsuccess" ]; then
		cp -r --preserve=links "${SYSROOT}"/* "${PREFIX}"/ 
		echo "$(date --iso-8601=seconds)" > "${currentpath}/install/.copysysrootsuccess"
	fi
fi

echo "USE_ONEPHASE_GCC_BUILD: $USE_ONEPHASE_GCC_BUILD"
echo "USE_PRECOMPILED_SYSROOT: $USE_PRECOMPILED_SYSROOT"


function build_gcc_phase2_gcc {
    # Parameter to control whether to perform the installation step (0 = skip, 1 = perform)
    local installstripgcc="$1"

    # Ensure the target directory for gcc phase 2 exists
    mkdir -p "${currentpath}/targetbuild/${HOST}/gcc_phase2"

    # Step 1: Configure gcc phase 2
    if [ ! -f "${currentpath}/targetbuild/${HOST}/gcc_phase2/.configuresuccesss" ]; then
        # Change to the gcc phase 2 directory or exit if the directory change fails
        cd "${currentpath}/targetbuild/${HOST}/gcc_phase2" || { echo "Failed to change directory"; exit 1; }

        # Run the configuration command for gcc phase 2
        LIPO=llvm-lipo OTOOL=llvm-otool DSYMUTIL=dsymutil STRIP=llvm-strip STRIP_FOR_TARGET=llvm-strip \
        "$TOOLCHAINS_BUILD/gcc/configure" \
        --with-gxx-libcxx-include-dir="$PREFIX/include/c++/v1" \
        --prefix="$PREFIX" $CROSSTRIPLETTRIPLETS $GCCCONFIGUREFLAGSCOMMON --with-sysroot="$PREFIX"
        
        # Check if the configuration command failed and exit if it did
        if [ $? -ne 0 ]; then
            echo "gcc phase 2 configuration failed"
            exit 1
        fi

        # Record the success of the configuration step
        echo "$(date --iso-8601=seconds)" > "${currentpath}/targetbuild/${HOST}/gcc_phase2/.configuresuccesss"
    fi

    # Step 2: Build gcc phase 2
    if [ ! -f "${currentpath}/targetbuild/${HOST}/gcc_phase2/.buildgccsuccess" ]; then
        # Change to the gcc phase 2 directory or exit if the directory change fails
        cd "${currentpath}/targetbuild/${HOST}/gcc_phase2" || { echo "Failed to change directory"; exit 1; }
        
        # Build the gcc binary for phase 2 using all available processor cores
        make all-gcc -j$(nproc)
        
        # Check if the build command failed and exit if it did
        if [ $? -ne 0 ]; then
            echo "gcc phase 2 build failed"
            exit 1
        fi

        # Record the success of the build step
        echo "$(date --iso-8601=seconds)" > "${currentpath}/targetbuild/${HOST}/gcc_phase2/.buildgccsuccess"
    fi

    # Step 3: Install gcc phase 2 (optional, controlled by parameter)
    if [ "$installstripgcc" -eq 1 ] && [ ! -f "${currentpath}/targetbuild/$HOST/gcc_phase2/.buildinstallstripgccsuccess" ]; then
        cd "${currentpath}/targetbuild/$HOST/gcc_phase2" || { echo "Failed to change directory"; exit 1; }
        
        # Run the installation command
        make install-strip-gcc -j$(nproc)
        
        # Check if the install command failed and exit if it did
        if [ $? -ne 0 ]; then
            echo "gcc install-strip gcc failure"
            exit 1
        fi

        # Strip unnecessary symbols from the installation
        safe_llvm_strip "$PREFIX"
        
        # Record the success of the installation step
        echo "$(date --iso-8601=seconds)" > "${currentpath}/targetbuild/$HOST/gcc_phase2/.buildinstallstripgccsuccess"
    fi
}


if [[ $isnativebuild != "yes" ]]; then

	if [ ! -f ${currentpath}/targetbuild/$HOST/binutils-gdb/.configuresuccess ]; then
		mkdir -p ${currentpath}/targetbuild/$HOST/binutils-gdb
		cd ${currentpath}/targetbuild/$HOST/binutils-gdb
		LIPO=llvm-lipo OTOOL=llvm-otool DSYMUTIL=dsymutil STRIP=llvm-strip STRIP_FOR_TARGET=llvm-strip $TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror --with-python3 $ENABLEGOLD $CROSSTRIPLETTRIPLETS --prefix=$PREFIX
		if [ $? -ne 0 ]; then
			echo "binutils-gdb configure failure"
			exit 1
		fi
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/binutils-gdb/.configuresuccess
	fi

	if [ ! -f ${currentpath}/targetbuild/$HOST/binutils-gdb/.buildsuccess ]; then
		cd ${currentpath}/targetbuild/$HOST/binutils-gdb
		make -j$(nproc)
		if [ $? -ne 0 ]; then
			echo "binutils-gdb build failure"
			exit 1
		fi
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/binutils-gdb/.buildsuccess
	fi

	if [ ! -f ${currentpath}/targetbuild/$HOST/binutils-gdb/.installsuccess ]; then
		cd ${currentpath}/targetbuild/$HOST/binutils-gdb
		make install-strip -j$(nproc)
		if [ $? -ne 0 ]; then
			echo "binutils-gdb install-strip failure"
			make install -j$(nproc)
			if [ $? -ne 0 ]; then
				echo "binutils-gdb install failure"
				exit 1
			fi
			safe_llvm_strip ${PREFIX}
		fi
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/binutils-gdb/.installsuccess
	fi

	if [[ ${HOST_OS} == mingw*  ]]; then
		if [ ! -d "${currentpath}/install/mingw-w64-headers" ] || [ ! -f "${currentpath}/build/.headersinstallsuccess" ]; then
				mkdir -p "${currentpath}/build"
				cd "${currentpath}/build"
				mkdir -p mingw-w64-headers
				if [ ! -f Makefile ]; then
						STRIP=llvm-strip $TOOLCHAINS_BUILD/mingw-w64/mingw-w64-headers/configure --host="$HOST" --prefix="${currentpath}/install/mingw-w64-headers" $MINGWW64FLAGS 
						if [ $? -ne 0 ]; then
							echo "mingw-w64-headers configuration failed"
							exit 1
						fi
				fi
				make -j$(nproc) || { echo "make failed for mingw-w64-headers"; exit 1; }
				make install-strip -j$(nproc) || { echo "make install-strip failed for mingw-w64-headers"; exit 1; }
				mkdir -p "${SYSROOT}/${USRALTERNATIVENAME}"
				cp -r --preserve=links "${currentpath}/install"/mingw-w64-headers/* "${SYSROOT}/${USRALTERNATIVENAME}/"
				cp -r --preserve=links "${SYSROOT}"/* "${PREFIX}/"
				echo "$(date --iso-8601=seconds)" > "${currentpath}/build/.headersinstallsuccess"
		fi
	fi

	if [[ ${USE_ONEPHASE_GCC_BUILD} == "yes" ]]; then
		build_gcc_phase2_gcc	1
	else
		if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.configuresuccesss ]; then
			mkdir -p ${currentpath}/targetbuild/$HOST/gcc_phase1
			cd ${currentpath}/targetbuild/$HOST/gcc_phase1
			LIPO=llvm-lipo OTOOL=llvm-otool DSYMUTIL=dsymutil STRIP=llvm-strip STRIP_FOR_TARGET=llvm-strip $TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$PREFIX/include/c++/v1 --prefix=$PREFIX $MULTILIBLISTS $CROSSTRIPLETTRIPLETS --disable-nls --disable-werror --enable-languages=c,c++ --enable-multilib  --disable-bootstrap --disable-libstdcxx-verbose --with-libstdcxx-eh-pool-obj-count=0 --disable-sjlj-exceptions --disable-libstdcxx-threads --disable-libstdcxx-backtrace --disable-hosted-libstdcxx --without-headers --disable-shared --disable-threads --disable-libsanitizer --disable-libquadmath --disable-libatomic --disable-libssp
			if [ $? -ne 0 ]; then
				echo "gcc phase1 configure failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.configuresuccesss
		fi
		if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.buildgccsuccess ]; then
			cd ${currentpath}/targetbuild/$HOST/gcc_phase1
			make all-gcc -j$(nproc)
			if [ $? -ne 0 ]; then
				echo "gcc phase1 build gcc failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.buildgccsuccess
		fi

		if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.buildlibgccsuccess ]; then
			cd ${currentpath}/targetbuild/$HOST/gcc_phase1
			make all-target-libgcc -j$(nproc)
			if [ $? -ne 0 ]; then
				echo "gcc phase1 build libgcc failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.buildlibgccsuccess
		fi

		if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.installstripgccsuccess ]; then
			cd ${currentpath}/targetbuild/$HOST/gcc_phase1
			make install-strip-gcc -j$(nproc)
			if [ $? -ne 0 ]; then
				echo "gcc phase1 install strip gcc failure"
				exit 1
			fi
			safe_llvm_strip $PREFIX
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.installstripgccsuccess
		fi

		if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase1/.installstriplibgccsuccess ]; then
			cd ${currentpath}/targetbuild/$HOST/gcc_phase1
			make install-strip-target-libgcc -j$(nproc)
			if [ $? -ne 0 ]; then
				echo "gcc phase1 install strip libgcc failure"
				exit 1
			fi
			safe_llvm_strip $PREFIX
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase1/.installstriplibgccsuccess
		fi
	fi
fi

if [[ ${USE_NEWLIB} == "yes" ]]; then


	mkdir -p ${SYSROOT}/${USRALTERNATIVENAME}
	mkdir -p ${currentpath}/targetbuild/$HOST/newlib-cygwin

	if [ -z "${CUSTOM_BUILD_SYSROOT}" ]; then
		if [ ! -f ${currentpath}/targetbuild/$HOST/newlib-cygwin/.configurenewlibsuccess ]; then
			cd ${currentpath}/targetbuild/$HOST/newlib-cygwin
			LIPO=llvm-lipo OTOOL=llvm-otool DSYMUTIL=dsymutil STRIP=llvm-strip STRIP_FOR_TARGET=llvm-strip $TOOLCHAINS_BUILD/newlib-cygwin/configure --disable-werror --disable-nls --build=$BUILD --target=$HOST --prefix=${currentpath}/install/newlib-cygwin
			if [ $? -ne 0 ]; then
				echo "configure newlib-cygwin failure"
				exit 1
			fi
			cp -r --preserve=links ${currentpath}/install/newlib-cygwin/$HOST/* $SYSROOT/${USRALTERNATIVENAME}/
			cp -r --preserve=links ${SYSROOT}/${USRALTERNATIVENAME}/* ${PREFIXTARGET}/
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/newlib-cygwin/.configurenewlibsuccess
		fi

		if [ ! -f ${currentpath}/targetbuild/$HOST/newlib-cygwin/.makenewlibsuccess ]; then
			cd ${currentpath}/targetbuild/$HOST/newlib-cygwin
			make -j$(nproc)
			if [ $? -ne 0 ]; then
				echo "make newlib-cygwin failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/newlib-cygwin/.makenewlibsuccess
		fi

		if [ ! -f ${currentpath}/targetbuild/$HOST/newlib-cygwin/.installstripnewlibsuccess ]; then
			cd ${currentpath}/targetbuild/$HOST/newlib-cygwin
			make install-strip -j$(nproc)
			if [ $? -ne 0 ]; then
				echo "make install-strip newlib-cygwin failure"
				exit 1
			fi
			safe_llvm_strip ${PREFIX}
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/newlib-cygwin/.installstripnewlibsuccess
		fi

		if [ ! -f ${currentpath}/targetbuild/$HOST/newlib-cygwin/.copysysrootsuccess ]; then
			cp -r --preserve=links ${currentpath}/install/newlib-cygwin/$HOST/* $SYSROOT/${USRALTERNATIVENAME}/
			cp -r --preserve=links ${currentpath}/install/newlib-cygwin/share $SYSROOT/${USRALTERNATIVENAME}/
			if [ $? -ne 0 ]; then
				echo "copy newlib-cygwin failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/newlib-cygwin/.copysysrootsuccess
		fi
	else
		if [ ! -f ${currentpath}/targetbuild/$HOST/newlib-cygwin/.newlibsysrootcopied ]; then
			cp -r --preserve=links "${CUSTOM_BUILD_SYSROOT}/include" $SYSROOT/${USRALTERNATIVENAME}/
			if [ $? -ne 0 ]; then
				echo "copy build sysroot include failed"
				exit 1
			fi
			cp -r --preserve=links "${CUSTOM_BUILD_SYSROOT}/lib" $SYSROOT/${USRALTERNATIVENAME}/
			if [ $? -ne 0 ]; then
				echo "copy build sysroot lib failed"
				exit 1
			fi
			rm -rf "$SYSROOT/include/c++"
			rm -rf "$SYSROOT/lib/ldscripts"
			echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/newlib-cygwin/.newlibsysrootcopied
		fi
	fi

	if [ ! -f ${currentpath}/targetbuild/$HOST/newlib-cygwin/.installsysrootsuccess ]; then
		cp -r --preserve=links $SYSROOT/* $PREFIX/
		if [ $? -ne 0 ]; then
			echo "copy newlib-cygwin failure"
			exit 1
		fi
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/newlib-cygwin/.installsysrootsuccess
	fi
fi

if [[ ${USE_PRECOMPILED_SYSROOT} != "yes" ]]; then
	mkdir -p "${currentpath}/build"
	if [[ ${HOST_OS} == mingw*  ]]; then
		if [ ! -d "${currentpath}/install/mingw-w64-crt" ] || [ ! -f "${currentpath}/build/.libinstallsuccess" ]; then
				cd "${currentpath}/build"
				mkdir -p mingw-w64-crt
				cd mingw-w64-crt
				if [ ! -f Makefile ]; then
						$TOOLCHAINS_BUILD/mingw-w64/mingw-w64-crt/configure --host="$HOST" --prefix="${currentpath}/install/mingw-w64-crt" $MINGWW64FLAGS
						if [ $? -ne 0 ]; then
							echo "mingw-w64-crt configuration failed"
							exit 1
						fi
				fi
				make -j$(nproc) 2>err.txt || { echo "make failed for mingw-w64-crt (see err.txt for details)"; exit 1; }
				make install-strip -j$(nproc) 2>err.txt || { echo "make install-strip failed for mingw-w64-crt (see err.txt for details)"; exit 1; }
				mkdir -p "${SYSROOT}/${USRALTERNATIVENAME}" || { echo "Failed to create directory ${SYSROOT}/${USRALTERNATIVENAME}"; exit 1; }
				cp -r --preserve=links "${currentpath}/install"/mingw-w64-crt/* "${SYSROOT}/${USRALTERNATIVENAME}/"
				cp -r --preserve=links "${SYSROOT}"/* "${PREFIX}/"
				echo "$(date --iso-8601=seconds)" > "${currentpath}/build/.libinstallsuccess"
		fi
	elif [[ ${HOST_OS} == "linux" ]]; then

		linuxkernelheaders=${SYSROOT}

		if [ ! -f ${currentpath}/install/.linuxkernelheadersinstallsuccess ]; then
			cd "$TOOLCHAINS_BUILD/linux"
			make headers_install ARCH=$ARCH -j INSTALL_HDR_PATH=${SYSROOT}/${USRALTERNATIVENAME}
			if [ $? -ne 0 ]; then
				echo "linux kernel headers install failure"
				exit 1
			fi
			echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.linuxkernelheadersinstallsuccess
		fi

		if [[ ${ARCH} == "riscv" ]]; then
			multilibs=(default lp64 lp64d ilp32 ilp32d)
			multilibsoptions=("" " -march=rv64imac -mabi=lp64" " -march=rv64imafdc -mabi=lp64d" " -march=rv32imac -mabi=ilp32" " -march=rv32imafdc -mabi=ilp32d")
			multilibsdir=("lib64" "lib64/lp64" "lib64/lp64d" "lib32/ilp32" "lib32/ilp32d")
			multilibsingccdir=("" "lib64/lp64" "lib64/lp64d" "lib32/ilp32" "lib32/ilp32d")
			multilibshost=("riscv64-linux-gnu" "riscv64-linux-gnu" "riscv64-linux-gnu" "riscv32-linux-gnu" "riscv32-linux-gnu")
		elif [[ ${ARCH} == "x86_64" ]]; then
	# 32 bit and x32 are phased out from linux kernel. There are completely useless. Just use wine if you need 32 bit
	#		multilibs=(m64 m32 mx32)
	#		multilibsoptions=(" -m64" " -m32" " -mx32")
	#		multilibsdir=("lib64" "lib" "libx32")
	#		multilibsingccdir=("" "32" "x32")
	#		multilibshost=("x86_64-linux-gnu" "i686-linux-gnu" "x86_64-linux-gnux32")


	#		multilibs=(m64 m32 mx32)
	#		multilibsoptions=(" -m64" " -m32" " -mx32")
	#		multilibsdir=("lib" "lib32" "libx32")
	#		multilibsingccdir=("" "32" "x32")
	#		multilibshost=("x86_64-linux-gnu" "i686-linux-gnu" "x86_64-linux-gnux32")

			multilibs=(m64)
			multilibsoptions=(" -m64")
			multilibsdir=("lib")
			multilibsingccdir=("")
			multilibshost=("x86_64-linux-gnu")
		elif [[ ${ARCH} == "loongarch" ]]; then
			multilibs=(m64)
			multilibsoptions=("")
			multilibsdir=("lib64")
			multilibsingccdir=("")
			multilibshost=("loongarch64-linux-gnu")
		else
			multilibs=(default)
			multilibsoptions=("")
			multilibsdir=("lib")
			multilibsingccdir=("")
			multilibshost=("$HOST")
		fi

		if [[ ${MUSLLIBC} == "yes" ]]; then
			if [ ! -f ${currentpath}/install/.muslinstallsuccess ]; then
				item="default"
				marchitem=""
				libdir="lib"
				host=$HOST
				libingccdir=""
				mkdir -p ${currentpath}/build/musl/$item
				cd ${currentpath}/build/musl/$item

				if [ ! -f ${currentpath}/build/musl/$item/.configuresuccess ]; then
					if [[ ${USELLVM} == "yes" ]]; then
						LIPO=llvm-lipo OTOOL=llvm-otool DSYMUTIL=dsymutil STRIP=llvm-strip AR=llvm-ar CC="clang --target=$host" CXX="clang++ --target=$host" AS=llvm-as RANLIB=llvm-ranlib CXXFILT=llvm-cxxfilt NM=llvm-nm $TOOLCHAINS_BUILD/musl/configure --disable-nls --disable-werror --prefix=$currentpath/install/musl/$item --build=$BUILD --with-headers=$SYSROOT/${USRALTERNATIVENAME}/include --disable-shared --enable-static --without-selinux --host=$host
					else
						(export -n LD_LIBRARY_PATH; CC="$HOST-gcc$marchitem" CXX="$HOST-g++$marchitem" $TOOLCHAINS_BUILD/musl/configure --disable-nls --disable-werror --prefix=$currentpath/install/musl/$item --build=$BUILD --with-headers=$SYSROOT/${USRALTERNATIVENAME}/include --disable-shared --enable-static --without-selinux --host=$host )
					fi
					if [ $? -ne 0 ]; then
						echo "musl configure failure"
						exit 1
					fi
					echo "$(date --iso-8601=seconds)" > ${currentpath}/build/musl/$item/.configuresuccess
				fi
				if [ ! -f ${currentpath}/build/musl/$item/.buildsuccess ]; then
					(export -n LD_LIBRARY_PATH; make -j$(nproc))
					if [ $? -ne 0 ]; then
						echo "musl build failure"
						exit 1
					fi
					echo "$(date --iso-8601=seconds)" > ${currentpath}/build/musl/$item/.buildsuccess
				fi
				if [ ! -f ${currentpath}/build/musl/$item/.installsuccess ]; then
					(export -n LD_LIBRARY_PATH; make install -j$(nproc))
					if [ $? -ne 0 ]; then
						echo "musl install failure"
						exit 1
					fi
					echo "$(date --iso-8601=seconds)" > ${currentpath}/build/musl/$item/.installsuccess
				fi
				if [ ! -f ${currentpath}/build/musl/$item/.stripsuccess ]; then
					safe_llvm_strip "$currentpath/install/musl/$item/lib"
					echo "$(date --iso-8601=seconds)" > ${currentpath}/build/musl/$item/.stripsuccess
				fi
				if [ ! -f ${currentpath}/build/musl/$item/.sysrootsuccess ]; then
					cp -r --preserve=links ${currentpath}/install/musl/$item/include $SYSROOT/
					mkdir -p $SYSROOT/$libdir
					cp -r --preserve=links ${currentpath}/install/musl/$item/lib/* $SYSROOT/$libdir
		#			mkdir -p $GCCSYSROOT/$libingccdir
		#			cp -r --preserve=links ${currentpath}/install/musl/$item/lib/* $GCCSYSROOT/$libingccdir
					echo "$(date --iso-8601=seconds)" > ${currentpath}/build/musl/$item/.sysrootsuccess
				fi
				unset item
				unset marchitem
				unset libdir
				unset host
				unset libingccdir
				echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.muslinstallsuccess
			fi
		elif [ ! -f ${currentpath}/install/.glibcinstallsuccess ]; then
			glibcfiles=(libm.a libm.so libc.so)

			mkdir -p ${currentpath}/build/glibc
			mkdir -p ${currentpath}/install/sysroot/${USRALTERNATIVENAME}

			for i in "${!multilibs[@]}"; do
				item=${multilibs[$i]}
				marchitem=${multilibsoptions[$i]}
				libdir=${multilibsdir[$i]}
				host=${multilibshost[$i]}
				libingccdir=${multilibsingccdir[$i]}
				mkdir -p ${currentpath}/build/glibc/$item
				cd ${currentpath}/build/glibc/$item
				if [ ! -f ${currentpath}/build/glibc/$item/.configuresuccess ]; then
					(export -n LD_LIBRARY_PATH; CC="$HOST-gcc$marchitem" CXX="$HOST-g++$marchitem" $TOOLCHAINS_BUILD/glibc/configure --disable-nls --disable-werror --prefix=$currentpath/install/glibc/${item} --build=$BUILD --with-headers=$SYSROOT/${USRALTERNATIVENAME}/include --without-selinux --host=$host )
					if [ $? -ne 0 ]; then
						echo "glibc ($item) configure failure"
						exit 1
					fi
					echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.configuresuccess
				fi
				if [ ! -f ${currentpath}/build/glibc/$item/.buildsuccess ]; then
					(export -n LD_LIBRARY_PATH; make -j$(nproc))
					if [ $? -ne 0 ]; then
						echo "glibc ($item) build failure"
						exit 1
					fi
					echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.buildsuccess
				fi
				if [ ! -f ${currentpath}/build/glibc/$item/.installsuccess ]; then
					(export -n LD_LIBRARY_PATH; make install -j$(nproc))
					if [ $? -ne 0 ]; then
						echo "glibc ($item) install failure"
						exit 1
					fi
					echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.installsuccess
				fi

				if [ ! -f ${currentpath}/build/glibc/$item/.removehardcodedpathsuccess ]; then
					canadianreplacedstring=$currentpath/install/glibc/${item}/lib/
					for file in "${glibcfiles[@]}"; do
						filepath=$canadianreplacedstring/$file
						if [ -f "$filepath" ]; then
							getfilesize=$(wc -c <"$filepath")
							echo $getfilesize
							if [ $getfilesize -lt 1024 ]; then
								sed -i "s%${canadianreplacedstring}%%g" $filepath
								echo "removed hardcoded path: $filepath"
							fi
						fi
						unset filepath
					done
					unset canadianreplacedstring
					echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.removehardcodedpathsuccess
				fi

				if [ ! -f ${currentpath}/build/glibc/$item/.stripsuccess ]; then
					safe_llvm_strip "$currentpath/install/glibc/${item}/lib"
					echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.stripsuccess
				fi
				if [ ! -f ${currentpath}/build/glibc/$item/.sysrootsuccess ]; then
					cp -r --preserve=links ${currentpath}/install/glibc/$item/include $SYSROOT/${USRALTERNATIVENAME}/
					mkdir -p $SYSROOT/${USRALTERNATIVENAME}/$libdir
					cp -r --preserve=links ${currentpath}/install/glibc/$item/lib/* $SYSROOT/${USRALTERNATIVENAME}/$libdir
	#				mkdir -p $GCCSYSROOT/$libingccdir
	#				cp -r --preserve=links ${currentpath}/install/glibc/$item/lib/* $GCCSYSROOT/$libingccdir
					echo "$(date --iso-8601=seconds)" > ${currentpath}/build/glibc/$item/.sysrootsuccess
				fi
				unset item
				unset marchitem
				unset libdir
				unset host
			done
			echo "$(date --iso-8601=seconds)" > ${currentpath}/install/.glibcinstallsuccess
		fi
	fi
fi

if [[ ${FREESTANDINGBUILD} != "yes" ]]; then
	mkdir -p $PREFIX
	if [ ! -f ${currentpath}/targetbuild/$HOST/.copysysrootsuccess ]; then
		echo cp -r --preserve=links $SYSROOT/* $PREFIX/
		cp -r --preserve=links $SYSROOT/* $PREFIX/
		if [ $? -ne 0 ]; then
			echo "Copy sysroot failure"
			exit 1
		fi
		echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/.copysysrootsuccess
	fi
fi

if [[  ${USE_ONEPHASE_GCC_BUILD} != "yes" ]]; then
	build_gcc_phase2_gcc
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.generatelimitssuccess ]; then
	cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > ${currentpath}/targetbuild/$HOST/gcc_phase2/gcc/include/limits.h
	if [ $? -ne 0 ]; then
		echo "gcc phase2 generate limits failure"
		exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.generatelimitssuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.buildsuccess ]; then
	cd ${currentpath}/targetbuild/$HOST/gcc_phase2
	make -j$(nproc)
	if [ $? -ne 0 ]; then
		echo "gcc phase2 build failure"
		exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.buildsuccess
fi

if [ ! -f ${currentpath}/targetbuild/$HOST/gcc_phase2/.installstripsuccess ]; then
	cd ${currentpath}/targetbuild/$HOST/gcc_phase2
	make install-strip -j$(nproc)
	if [ $? -ne 0 ]; then
		make install -j$(nproc)
		if [ $? -ne 0 ]; then
			echo "gcc phase2 install strip failure"
			exit 1
		fi
	fi
	safe_llvm_strip $prefix/bin
	safe_llvm_strip $prefixtarget/bin
	echo "$(date --iso-8601=seconds)" > ${currentpath}/targetbuild/$HOST/gcc_phase2/.installstripsuccess
fi

if [[ ${FREESTANDINGBUILD} != "yes" ]]; then
	TOOLCHAINS_BUILD=$TOOLCHAINS_BUILD TOOLCHAINSPATH_GNU=$TOOLCHAINSPATH_GNU GMPMPFRMPCHOST=$HOST GMPMPFRMPCBUILD=${currentpath}/targetbuild/$HOST GMPMPFRMPCPREFIX=$PREFIX/${USRALTERNATIVENAME} $relpath/buildgmpmpfrmpc.sh
	if [ $? -ne 0 ]; then
		echo "$HOST gmp mpfr mpc build failed"
		exit 1
	fi
fi

if [[ "$ELIMINATESYSROOT" == "yes" ]]; then
	if [[ -d "$PREFIX/${USRALTERNATIVENAME}" ]]; then
		if [ ! -f "${currentpath}/targetbuild/$HOST/.eliminatesysroot" ]; then
			if [[ -d "${PREFIXTARGET}/include/c++" ]]; then
				cp -r --preserve=links "$PREFIX/${USRALTERNATIVENAME}"/* "${PREFIXTARGET}/"
			else
				cp -r --preserve=links "$PREFIX/${USRALTERNATIVENAME}"/* "${PREFIX}/"
			fi
			rm -rf "$PREFIX/${USRALTERNATIVENAME}"
			echo "$(date --iso-8601=seconds)" > "${currentpath}/targetbuild/$HOST/.eliminatesysroot"
		fi
	fi
fi

mkdir -p "${currentpath}/targetbuild/$HOST/gcc_phase2"

if [ ! -f "${currentpath}/targetbuild/$HOST/gcc_phase2/.packagingsuccess" ] || [ ! -f "${TOOLCHAINSPATH_GNU}/${BUILD}/$HOST.tar.xz" ]; then
		cd "${TOOLCHAINSPATH_GNU}/${BUILD}" || exit 1
		safe_llvm_strip "${TOOLCHAINSPATH_GNU}/${BUILD}/$HOST"
		rm -f "$HOST.tar.xz"
		XZ_OPT=-e9T0 tar cJf "$HOST.tar.xz" "$HOST"
		chmod 755 "$HOST.tar.xz"
		echo "$(date --iso-8601=seconds)" > "${currentpath}/targetbuild/$HOST/gcc_phase2/.packagingsuccess"
fi

function handlebuild
{
local hosttriple=$1
local build_prefix=${currentpath}/${hosttriple}/${HOST}
local prefix=${TOOLCHAINSPATH_GNU}/${hosttriple}/${HOST}
local prefixtarget=${prefix}/${HOST}

local tripletbuild=$NEW_BUILD

if command -v "${NEW_BUILD}-g++" >/dev/null 2>&1; then
    echo "${NEW_BUILD}-g++ exists!"
else
    echo "${NEW_BUILD}-g++ does not exist, switching to $BUILD"
    tripletbuild=$BUILD
fi


mkdir -p ${build_prefix}

echo $build_prefix
echo $prefix
echo $prefixtarget


if [[ ${FREESTANDINGBUILD} != "yes" ]]; then
	if [ ! -f ${build_prefix}/.installsysrootsuccess ]; then
		mkdir -p "${prefix}"
		cp -r --preserve=links $SYSROOT/* ${prefix}/

		echo "$(date --iso-8601=seconds)" > ${build_prefix}/.installsysrootsuccess
	fi
fi

if [[ ${HOST_OS} == "msdosdjgpp" ]]; then
if [ ! -f ${build_prefix}/.djgppstubifybuild ]; then
	mkdir "$prefixtarget/bin"
	# Compile stubify
	${hosttriple}-gcc -o $prefixtarget/bin/stubify ${SYSROOT}/${USRALTERNATIVENAME}/src/stub/stubify.c -s -O3 -flto
	if [ $? -ne 0 ]; then
			echo "Error (${hosttriple}/${HOST}): Failed to compile stubify"
			exit 1
	fi

	# Compile stubedit
	${hosttriple}-gcc -o $prefixtarget/bin/stubedit ${SYSROOT}/${USRALTERNATIVENAME}/stub/stubedit.c -s -O3 -flto
	if [ $? -ne 0 ]; then
			echo "Error (${hosttriple}/${HOST}): Failed to compile stubedit"
			exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/.djgppstubifybuild
fi
fi

if [ ! -f ${build_prefix}/binutils-gdb/.configuresuccess ]; then
	mkdir -p ${build_prefix}/binutils-gdb
	cd $build_prefix/binutils-gdb
	echo $build_prefix/binutils-gdb
	local extra_binutils_configure_flags=
	local hostarch=${hosttriple%%-*}
	if [[ ${hostarch} == loongarch* ]]; then
	# see issue https://sourceware.org/bugzilla/show_bug.cgi?id=32031
		extra_binutils_configure_flags="--disable-gdbserver --disable-gdb"
	fi
	if [[ ${hosttriple} == ${HOST} && ${MUSLLIBC} == "yes" ]]; then
		extra_binutils_configure_flags="--disable-plugins $extra_binutils_configure_flags"
	fi
	LIPO=llvm-lipo OTOOL=llvm-otool DSYMUTIL=dsymutil STRIP=llvm-strip STRIP_FOR_TARGET=llvm-strip $TOOLCHAINS_BUILD/binutils-gdb/configure --disable-nls --disable-werror $ENABLEGOLD --prefix=$prefix --build=$tripletbuild --host=$hosttriple --target=$HOST $extra_binutils_configure_flags
	if [ $? -ne 0 ]; then
		echo "binutils-gdb (${hosttriple}/${HOST}) configure failed"
		exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/binutils-gdb/.configuresuccess
fi

if [ ! -f ${build_prefix}/binutils-gdb/.buildsuccess ]; then
	cd $build_prefix/binutils-gdb
	make -j$(nproc)
	if [ $? -ne 0 ]; then
		echo "binutils-gdb (${hosttriple}/${HOST}) build failed"
		exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/binutils-gdb/.buildsuccess
fi

if [ ! -f ${build_prefix}/binutils-gdb/.installsuccess ]; then
	cd $build_prefix/binutils-gdb
	make install-strip -j$(nproc)
	if [ $? -ne 0 ]; then
		make install -j$(nproc)
		if [ $? -ne 0 ]; then
			echo "binutils-gdb (${hosttriple}/${HOST}) install failed"
			exit 1
		fi
		safe_llvm_strip $prefix
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/binutils-gdb/.installsuccess
fi

if [ ! -f ${build_prefix}/gcc/.configuresuccess ]; then
	mkdir -p ${build_prefix}/gcc
	cd $build_prefix/gcc
	local sysrootconfigure="--with-sysroot"
	if [[  ${hosttriple} == ${HOST} ]]; then
		sysrootconfigure="--with-build-sysroot"
	fi
	LIPO=llvm-lipo OTOOL=llvm-otool DSYMUTIL=dsymutil STRIP=llvm-strip STRIP_FOR_TARGET=llvm-strip $TOOLCHAINS_BUILD/gcc/configure --with-gxx-libcxx-include-dir=$prefix/include/c++/v1 --prefix=$prefix --build=$tripletbuild --host=$hosttriple --target=$HOST $GCCCONFIGUREFLAGSCOMMON "$sysrootconfigure=$prefix"
	if [ $? -ne 0 ]; then
		echo "gcc (${hosttriple}/${HOST}) configure failed"
		exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.configuresuccess
fi


if [ ! -f ${build_prefix}/gcc/.buildallgccsuccess ]; then
	cd $build_prefix/gcc
	make all-gcc -j$(nproc)
	if [ $? -ne 0 ]; then
		echo "gcc (${hosttriple}/${HOST}) all-gcc build failed"
		exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.buildallgccsuccess
fi

if [ ! -f ${build_prefix}/gcc/.generatelimitssuccess ]; then
	cat $TOOLCHAINS_BUILD/gcc/gcc/limitx.h $TOOLCHAINS_BUILD/gcc/gcc/glimits.h $TOOLCHAINS_BUILD/gcc/gcc/limity.h > ${build_prefix}/gcc/gcc/include/limits.h
	if [ $? -ne 0 ]; then
		echo "gcc (${hosttriple}/${HOST}) generate limits failure"
		exit 1
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.generatelimitssuccess
fi

if [ ! -f ${build_prefix}/gcc/.buildsuccess ]; then
	cd "$build_prefix/gcc"
	make -j$(nproc)
: <<'EOF'
if [ $? -ne 0 ]; then
        if [ -d "${build_prefix}/gcc/${HOST}/libstdc++-v3/libsupc++" ]; then
            cd "$build_prefix/gcc/${HOST}/libstdc++-v3/libsupc++"
            make -j$(nproc)
            if [ $? -ne 0 ]; then
                echo "gcc (${hosttriple}/${HOST}) build libstdc++-v3/libsupc++ failed"
                cp "${currentpath}/${HOST}/${HOST}/gcc/${HOST}/libstdc++-v3/config.h" "${build_prefix}/gcc/${HOST}/libstdc++-v3/"
                touch "${build_prefix}/gcc/${HOST}/libstdc++-v3/config.h"
                echo "copied config.h"
                if [ $? -ne 0 ]; then
                    echo "gcc (${hosttriple}/${HOST}) copy libstdc++-v3/config.h failed"
                    exit 1
                fi
            fi
            make -j$(nproc)
            if [ $? -ne 0 ]; then
                echo "gcc (${hosttriple}/${HOST}) build libstdc++-v3/libsupc++ failed"
                exit 1
            fi
        else
            if [ $? -ne 0 ]; then
                echo "gcc (${hosttriple}/${HOST}) build failed"
                exit 1
            fi
        fi
    fi
EOF
	if [ $? -ne 0 ]; then
		if [[ "${HOST_OS}" == "msdosdjgpp" ]]; then

			if [ -f "${build_prefix}/gcc/$HOST/libstdc++/config.h" ]; then
					# Replace #define HAVE_FENV_H 1 with /* #undef HAVE_FENV_H */
					sed -i 's/#define HAVE_FENV_H 1/\/\* #undef HAVE_FENV_H \*\//' "${build_prefix}/gcc/$HOST/libstdc++-v3/config.h"
					# Replace #define _GLIBCXX_HAVE_FENV_H 1 with /* #undef _GLIBCXX_HAVE_FENV_H */
					sed -i 's/#define _GLIBCXX_HAVE_FENV_H 1/\/\* #undef _GLIBCXX_HAVE_FENV_H \*\//' "${build_prefix}/gcc/$HOST/libstdc++-v3/include/$HOST/bits/c++config.h"
					make -j$(nproc)
					if [ $? -ne 0 ]; then
							echo "gcc (${hosttriple}/${HOST}) build failed after modifying config.h"
							exit 1
					fi
			else
					echo "config.h not found: ${build_prefix}/gcc/$HOST/libstdc++-v3/config.h"
					exit 1
			fi
			make -j$(nproc)
			if [ $? -ne 0 ]; then
				echo "gcc (${hosttriple}/${HOST}) build failed"
				exit 1
			fi
		else
			echo "gcc (${hosttriple}/${HOST}) build failed"
			exit 1
		fi
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.buildsuccess
fi

if [ ! -f ${build_prefix}/gcc/.installsuccess ]; then
	cd $build_prefix/gcc
	make install-strip -j$(nproc)
	if [ $? -ne 0 ]; then
		make install -j$(nproc)
		if [ $? -ne 0 ]; then
			echo "gcc (${hosttriple}/${HOST}) install failed"
			exit 1
		fi
		safe_llvm_strip $prefix
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.installsuccess
fi

if [ ! -f "${build_prefix}/gcc/.symlinksuccess" ]; then
if [[ "${hosttriple}" == "{$HOST}" ]]; then
  cd "${prefix}/bin"
	if [[ -e "${prefix}/bin/gcc" ]]; then
	  ln -s gcc cc
	elif [[ -e "${prefix}/bin/gcc.exe" ]]; then
	  ln gcc.exe cc.exe
	fi
	echo "$(date --iso-8601=seconds)" > ${build_prefix}/gcc/.symlinksuccess
fi
fi

if [[ "$ELIMINATESYSROOT" == "yes" ]]; then
	if [[ -d "$prefix/${USRALTERNATIVENAME}" ]]; then
		if [ ! -f "${build_prefix}/.eliminatesysroot" ]; then
			if [[ -d "${prefixtarget}/include/c++" ]]; then
				cp -r --preserve=links "$prefix/${USRALTERNATIVENAME}"/* "${prefixtarget}/"
			else
				cp -r --preserve=links "$prefix/${USRALTERNATIVENAME}"/* "${prefix}/"
			fi
			rm -rf "$prefix/${USRALTERNATIVENAME}"
			echo "$(date --iso-8601=seconds)" > "${build_prefix}/.eliminatesysroot"
		fi
	fi
fi

if [ ! -f "${build_prefix}/.packagingsuccess" ] || [ ! -f "${TOOLCHAINSPATH_GNU}/${hosttriple}/$HOST.tar.xz" ]; then
    cd "${TOOLCHAINSPATH_GNU}/${hosttriple}" || exit 1
    safe_llvm_strip "${TOOLCHAINSPATH_GNU}/${hosttriple}/$HOST"
    rm -f "$HOST.tar.xz"
    XZ_OPT=-e9T0 tar cJf "$HOST.tar.xz" "$HOST"
    chmod 755 "$HOST.tar.xz"
    echo "$(date --iso-8601=seconds)" > "${build_prefix}/.packagingsuccess"
fi
}

if [[ "${FREESTANDINGBUILD:-no}" != "yes" && "${DISABLE_CANADIAN_NATIVE:-no}" != "yes" ]]; then
    handlebuild "${HOST}"
fi

if [[ ${CANADIANHOST} == ${HOST} ]]; then
exit 0
fi

if [ -x "$(command -v ${CANADIANHOST}-g++)" ]; then
    handlebuild ${CANADIANHOST}
else
    echo "${CANADIANHOST}-g++ not found. skipped"
fi
