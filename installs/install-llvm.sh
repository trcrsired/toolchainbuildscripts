#!/bin/bash

# Check if TOOLCHAINSPATH environment variable is set, otherwise use $HOME/toolchains
if [ -z ${TOOLCHAINSPATH+x} ]; then
    TOOLCHAINSPATH="$HOME/toolchains"
fi

# Create necessary directories
mkdir -p "$TOOLCHAINSPATH"

# Check if TOOLCHAINSPATH_LLVM environment variable is set, otherwise use $TOOLCHAINSPATH/llvm
if [ -z ${TOOLCHAINSPATH_LLVM+x} ]; then
    TOOLCHAINSPATH_LLVM="$TOOLCHAINSPATH/llvm"
fi

# Create necessary directories
mkdir -p "$TOOLCHAINSPATH_LLVM"

# Get the latest release version if not set
if [ -z ${RELEASE_VERSION+x} ]; then
    if command -v git > /dev/null; then
        RELEASE_VERSION=$(git ls-remote --tags https://github.com/trcrsired/llvm-releases.git | awk '/refs\/tags\/llvm[0-9]+(\-[0-9]+)*$/ {print $2}' | sed 's/refs\/tags\///' | sort -V | tail -n1)
        if [ -z "$RELEASE_VERSION" ]; then
            echo "Failed to retrieve the latest release version. Please check your network connection or set the RELEASE_VERSION environment variable."
            exit 1
        fi
    else
        echo "Git is not installed. Please install it or set the RELEASE_VERSION environment variable."
        exit 1
    fi
fi

# Determine TRIPLE if not set
if [ -z ${TRIPLE+x} ]; then
    UNAME=$(uname -a)
    if [[ "$UNAME" == *"Linux"* ]]; then
        if [ -n "${ANDROID_ROOT+x}" ]; then
            if [[ "$UNAME" == *"aarch64"* ]]; then
                TRIPLE="aarch64-linux-android30"
            elif [[ "$UNAME" == *"x86_64"* ]]; then
                TRIPLE="x86_64-linux-android30"
            fi
        else
            if [[ "$UNAME" == *"x86_64"* ]]; then
                TRIPLE="x86_64-linux-gnu"
            elif [[ "$UNAME" == *"aarch64"* ]]; then
                TRIPLE="aarch64-linux-gnu"
            fi
        fi
    fi
fi

# Remove 'pc' or 'unknown' from TRIPLE if present
IFS='-' read -r -a parts <<< "$TRIPLE"
if [ "${#parts[@]}" -eq 4 ] && [[ "${parts[1]}" == "pc" || "${parts[1]}" == "unknown" ]]; then
    TRIPLE="${parts[0]}-${parts[2]}-${parts[3]}"
fi
# Extract ARCH from TRIPLE
ARCH=$(echo $TRIPLE | cut -d'-' -f1)

# Set the base URL for downloads
BASE_URL="https://github.com/trcrsired/llvm-releases/releases/download/$RELEASE_VERSION"


# Determine the list of files to download
if [ "$DOWNLOAD_ALL" == "yes" ]; then
    FILES=(
        "aarch64-windows-gnu.tar.xz"
        "aarch64-linux-gnu.tar.xz"
        "aarch64-linux-android30.tar.xz"
        "x86_64-windows-gnu.tar.xz"
        "x86_64-linux-gnu.tar.xz"
        "x86_64-linux-android30.tar.xz"
        "loongarch64-linux-gnu.tar.xz"
        "riscv64-linux-gnu.tar.xz"
        "wasm-sysroots.tar.xz"
    )
else
    if [ -z "$TRIPLE" ]; then
        echo "Could not determine TRIPLE. Please set the TRIPLE environment variable."
        exit 1
    fi
    FILES=(
        "$ARCH-windows-gnu.tar.xz"
        "$TRIPLE.tar.xz"
        "wasm-sysroots.tar.xz"
    )
fi

# Download files using curl or wget
download_file() {
    local url=$1
    local dest=$2

    if command -v curl > /dev/null; then
        curl -L -o "$dest" "$url"
    elif command -v wget > /dev/null; then
        wget -O "$dest" "$url"
    else
        echo "Neither curl nor wget is installed. Please install one of them to proceed."
        exit 1
    fi
}

if [ "x$NODOWNLOADLLVM" != "xyes" ]; then

# Find and delete all .tar.xz files and their corresponding folders
for tar_file in "$TOOLCHAINSPATH_LLVM"/*.tar.xz; do
    # Check if the file exists
    if [ -f "$tar_file" ]; then
        # Get the corresponding folder name by removing the .tar.xz extension
        folder="${tar_file%.tar.xz}"
        # Delete the .tar.xz file
        echo "Deleting file: $tar_file"
        rm -f "$tar_file"
        # Check if the corresponding folder exists and delete it
        if [ -d "$folder" ]; then
            echo "Deleting folder: $folder"
            rm -rf "$folder"
        fi
    fi
done

echo "Cleanup completed successfully."

for file in "${FILES[@]}"; do
    echo "Downloading $file to $TOOLCHAINSPATH_LLVM"
    download_file "$BASE_URL/$file" "$TOOLCHAINSPATH_LLVM/$file"
done

echo "Downloads completed successfully to $TOOLCHAINSPATH_LLVM"

fi

# Run the script to extract and copy files
# Please ensure the script is saved as "llvmbuiltins.sh" and is executable
./llvmbuiltins.sh

# Add environment variables to .bashrc if SETLLVMENV is set to yes
if [ "$SETLLVMENV" == "yes" ]; then
    # Set WINEDEBUG if not set
    if ! grep -q "export WINEDEBUG=" ~/.bashrc; then
        echo "export WINEDEBUG=-all" >> ~/.bashrc
    fi

    # Ensure SOFTWAREPATH is set
    if [ -z ${SOFTWAREPATH+x} ]; then
        SOFTWAREPATH="$HOME/softwares"
    fi

    # Create necessary directories
    mkdir -p "$SOFTWAREPATH/wine"

    if [ -z ${WINE_RELEASE_VERSION+x} ]; then
        # Get the latest Wine release version
        if command -v git > /dev/null; then
            WINE_RELEASE_VERSION=$(git ls-remote --tags https://github.com/trcrsired/wine-release.git | grep -o 'refs/tags/[^{}]*$' | sed 's#refs/tags/##' | sort -V | tail -n1)
            if [ -z "$WINE_RELEASE_VERSION" ]; then
                echo "Failed to retrieve the latest release version. Please check your network connection or set the WINE_RELEASE_VERSION environment variable."
                exit 1
            fi
        else
            echo "Git is not installed. Please install it to proceed."
            exit 1
        fi
    fi

    # Download and extract the Wine release
    WINE_URL="https://github.com/trcrsired/wine-release/releases/download/$WINE_RELEASE_VERSION/$TRIPLE.tar.xz"
    echo $WINE_URL
    echo "Downloading $TRIPLE Wine release to $SOFTWAREPATH/wine"
    download_file "$WINE_URL" "$SOFTWAREPATH/wine/$TRIPLE.tar.xz"
    echo "Extracting $TRIPLE Wine release to $SOFTWAREPATH/wine"
    
    echo tar -xf "$SOFTWAREPATH/wine/$TRIPLE.tar.xz" -C "$SOFTWAREPATH/wine" --hard-dereference
    tar -xf "$SOFTWAREPATH/wine/$TRIPLE.tar.xz" -C "$SOFTWAREPATH/wine" --hard-dereference

    # If TRIPLE is Android, move toolchains to Wine's virtual C drive and create a symlink
    if [[ "$TRIPLE" == *"android"* ]]; then
        if [ ! -L "$HOME/toolchains" ]; then
            mkdir -p "$HOME/.wine/drive_c"
            mv "$HOME/toolchains" "$HOME/.wine/drive_c/toolchains"
            ln -s "$HOME/.wine/drive_c/toolchains" "$HOME/toolchains"
        fi
    fi

    # Function to check if a line exists in .bashrc
    line_exists_in_bashrc() {
        grep -Fxq "$1" ~/.bashrc
    }

    {
        if [ -n "$ARCH" ]; then
            if [[ "$TRIPLE" == *"android"* ]]; then
                WINEPATH_LINE1="export WINEPATH=\"c:/toolchains/llvm/$ARCH-windows-gnu/$ARCH-windows-gnu/bin;\$WINEPATH\""
                WINEPATH_LINE2="export WINEPATH=\"c:/toolchains/llvm/$ARCH-windows-gnu/compiler-rt/windows/lib;\$WINEPATH\""
                WINEPATH_LINE3="export WINEPATH=\"c:/toolchains/llvm/$ARCH-windows-gnu/llvm/bin;\$WINEPATH\""
                WINEPATH_LINE4="export WINEPATH=\"c:/toolchains/windows-msvc-sysroot/bin/$ARCH-unknown-windows-msvc;\$WINEPATH\""
                if [[ "$ARCH" == "x86_64" ]]; then
                WINEPATH_LINE5="export WINEPATH=\"c:/toolchains/windows-msvc-sysroot/bin/i686-unknown-windows-msvc;\$WINEPATH\""
                fi
            else
                WINEPATH_LINE1="export WINEPATH=\"\$HOME/toolchains/llvm/$ARCH-windows-gnu/$ARCH-windows-gnu/bin;\$WINEPATH\""
                WINEPATH_LINE2="export WINEPATH=\"\$HOME/toolchains/llvm/$ARCH-windows-gnu/compiler-rt/windows/lib;\$WINEPATH\""
                WINEPATH_LINE3="export WINEPATH=\"\$HOME/toolchains/llvm/$ARCH-windows-gnu/llvm/bin;\$WINEPATH\""
                WINEPATH_LINE4="export WINEPATH=\"\$HOME/toolchains/windows-msvc-sysroot/bin/$ARCH-unknown-windows-msvc;\$WINEPATH\""
                if [[ "$ARCH" == "x86_64" ]]; then
                WINEPATH_LINE5="export WINEPATH=\"\$HOME/toolchains/windows-msvc-sysroot/bin/i686-unknown-windows-msvc;\$WINEPATH\""
                fi
            fi
            ! line_exists_in_bashrc "$WINEPATH_LINE1" && echo "$WINEPATH_LINE1"
            ! line_exists_in_bashrc "$WINEPATH_LINE2" && echo "$WINEPATH_LINE2"
            ! line_exists_in_bashrc "$WINEPATH_LINE3" && echo "$WINEPATH_LINE3"
            ! line_exists_in_bashrc "$WINEPATH_LINE4" && echo "$WINEPATH_LINE4"
            if [ -n "$WINEPATH_LINE5" ]; then
                ! line_exists_in_bashrc "$WINEPATH_LINE5" && echo "$WINEPATH_LINE5"
            fi
        fi
        if [ -n "$TRIPLE" ]; then
            PATH_LINE="export PATH=\$HOME/toolchains/llvm/$TRIPLE/llvm/bin:\$PATH"
            LD_LIBRARY_PATH_LINE1="export LD_LIBRARY_PATH=\$HOME/toolchains/llvm/$TRIPLE/llvm/lib:\$LD_LIBRARY_PATH"
            ! line_exists_in_bashrc "$PATH_LINE" && echo "$PATH_LINE"
            ! line_exists_in_bashrc "$LD_LIBRARY_PATH_LINE1" && echo "$LD_LIBRARY_PATH_LINE1"
            LD_LIBRARY_PATH_LINE2="export LD_LIBRARY_PATH=\$HOME/toolchains/llvm/$TRIPLE/compiler-rt/lib/linux:\$LD_LIBRARY_PATH"
            LD_LIBRARY_PATH_LINE3="export LD_LIBRARY_PATH=\$HOME/toolchains/llvm/$TRIPLE/runtimes/lib:\$LD_LIBRARY_PATH"
            ! line_exists_in_bashrc "$LD_LIBRARY_PATH_LINE2" && echo "$LD_LIBRARY_PATH_LINE2"
            ! line_exists_in_bashrc "$LD_LIBRARY_PATH_LINE3" && echo "$LD_LIBRARY_PATH_LINE3"

            # Add Wine paths
            if [[ "$TRIPLE" == *"android"* ]]; then
                ARCH_VARIANT=$(uname -m)
                if [ "$ARCH_VARIANT" == "aarch64" ]; then
                    NDK_ARCH="arm64-v8a"
                elif [ "$ARCH_VARIANT" == "x86_64" ]; then
                    NDK_ARCH="x86_64"
                fi
                WINE_PATH_LINE="export PATH=\$HOME/softwares/wine/$TRIPLE/wine/$NDK_ARCH/bin:\$PATH"
            else
                WINE_PATH_LINE="export PATH=\$HOME/softwares/wine/$TRIPLE/wine/bin:\$PATH"
            fi
            ! line_exists_in_bashrc "$WINE_PATH_LINE" && echo "$WINE_PATH_LINE"
        fi
    } >> ~/.bashrc

    echo "Environment variables added to ~/.bashrc"
fi
