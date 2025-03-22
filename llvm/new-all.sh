
#!/bin/bash

restart_paramter=$1

if [[ $restart_paramter == "restart" ]]; then
	echo "restarting"
	rm -rf "$llvmcurrentrealpath/.llvmartifacts"
	rm -rf "$llvmcurrentrealpath/.llvmwasmartifacts"
	rm -rf "$llvmcurrentrealpath/../wavm/.wavmartifacts"
	rm -rf "$llvmcurrentrealpath/../wine/.wineartifacts"
	echo "restart done"
fi

llvmcurrentrealpath="$(realpath .)"
cd ../common
source ./common.sh

cd "$llvmcurrentrealpath"

main() {
    # Define an array with TRIPLET values, each on a new line
    local TRIPLETS2=(
        "aarch64-apple-darwin24"
        "aarch64-linux-android30"
        "aarch64-linux-gnu"
        "aarch64-linux-musl"
        "aarch64-windows-gnu"
        "i686-windows-gnu"
        "i686-linux-gnu"
        "i686-linux-musl"
        "loongarch64-linux-gnu"
        "loongarch64-linux-musl"
        "riscv64-linux-gnu"
        "x86_64-linux-android30"
        "x86_64-linux-gnu"
        "x86_64-linux-musl"
        "x86_64-windows-gnu"
    )

    # Local variables for platform triplet detection
    local platform_triplet
    local platform_triplet_no_vendor

    # Detect platform triplet
    detect_platform_triplet platform_triplet platform_triplet_no_vendor
    echo "Detected: $platform_triplet, $platform_triplet_no_vendor"

    # Flag to track if a match is found
    local found_match=0
    local new_array=()

    # Check if platform_triplet_no_vendor exists in TRIPLETS2
    for triplet in "${TRIPLETS2[@]}"; do
        if [[ "$triplet" == "$platform_triplet_no_vendor" ]]; then
            found_match=1
        else
            new_array+=("$triplet")
        fi
    done

    if [[ $found_match -eq 1 ]]; then
        # If found, move platform_triplet_no_vendor to the front
        TRIPLETS2=("$platform_triplet_no_vendor" "${new_array[@]}")
    else
        # If not found, add it to the front
        TRIPLETS2=("$platform_triplet_no_vendor" "${TRIPLETS2[@]}")
    fi

    # Print the updated array
    echo "Updated TRIPLETS2 array:"
    for triplet in "${TRIPLETS2[@]}"; do
        echo "$triplet"
    done
    for triplet in "${TRIPLETS2[@]}"; do
        TRIPLET=$triplet ./build_common.sh $restart_paramter
    done
}


main

if [[ $NO_BUILD_WAVM != "yes" ]]; then
cd "$llvmcurrentrealpath/../wavm"
./all.sh "$@"
fi

if [[ $NO_BUILD_WINE != "yes" ]]; then
cd "$llvmcurrentrealpath/../wine"
./all-min.sh "$@"
fi
