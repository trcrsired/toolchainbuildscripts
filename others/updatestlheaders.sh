#!/bin/bash

if [ -z ${TOOLCHAINS_BUILD+x} ]; then
	TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

if [ -z ${TOOLCHAINSPATH+x} ]; then
	TOOLCHAINSPATH=$HOME/toolchains
fi

if [ -z ${WINDOWSSYSROOT+x} ]; then
WINDOWSSYSROOT=$TOOLCHAINSPATH/windows-msvc-sysroot
fi

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

if [ ! -d "$TOOLCHAINS_BUILD/STL" ]; then
cd $TOOLCHAINS_BUILD
git clone https://github.com/microsoft/STL
if [ $? -ne 0 ]; then
echo "Microsoft STL clone failure"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/STL"
git pull --quiet

#!/bin/bash

# Define source and target directories
SOURCE_DIR="$TOOLCHAINS_BUILD/STL/stl/modules"
TARGET_DIR="$WINDOWSSYSROOT/share/stl"

# Remove the target directory if it exists
rm -rf "$TARGET_DIR"

# Create target directory if it does not exist
mkdir -p "$TARGET_DIR"

# Copy all files to the target directory
cp -r "$SOURCE_DIR"/* "$TARGET_DIR"

# Rename all *.inc files to *.cppm
for file in "$TARGET_DIR"/*.inc; do
    mv "$file" "${file%.inc}.cppm"
done

# Update *.inc to *.cppm in modules.json
if [ -f "$TARGET_DIR/modules.json" ]; then
    sed -i 's/\.inc/\.cppm/g' "$TARGET_DIR/modules.json"
fi

# Change directory to the target directory
cd "$TARGET_DIR"
git add *

# Remove the existing include/c++/stl directory
rm -rf "$WINDOWSSYSROOT/include/c++/stl"

# Copy and preserve links from the source to the destination
cp -r --preserve=links "$TOOLCHAINS_BUILD/STL/stl/inc" "$WINDOWSSYSROOT/include/c++/stl"

# Change directory to the new stl directory
cd "$WINDOWSSYSROOT/include/c++/stl"
git add *

# Commit changes with a message
git commit -m "Update Microsoft STL headers from source"

# Push changes quietly
git push --quiet
