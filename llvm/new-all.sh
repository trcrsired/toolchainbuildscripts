
#!/bin/bash

restart_paramter=$1

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
        "aarch64-windows-gnu"
        "i686-windows-gnu"
        "loongarch64-linux-gnu"
        "riscv64-linux-gnu"
        "x86_64-linux-android30"
        "x86_64-linux-gnu"
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

