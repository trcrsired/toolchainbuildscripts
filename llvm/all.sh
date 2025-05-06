#!/bin/bash

restart_paramter=$1
start_index=$2
end_index=$3

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
        "i686-linux-musl"
        "loongarch64-linux-gnu"
        "loongarch64-linux-musl"
        "x86_64-linux-android30"
        "x86_64-linux-gnu"
        "x86_64-linux-musl"
        "x86_64-windows-gnu"
    )

#    if [ "${ENABLE_RISCV_SUPPORT}" == "1" ]; then
        TRIPLETS2+=(
#            "riscv64-linux-android35"
            "riscv64-linux-gnu"
            "riscv64-linux-musl"
        )
#    fi

    echo "TRIPLETS total count: ${#TRIPLETS2[@]}"

    # Local variables for platform triplet detection
    local platform_triplet
    local platform_triplet_no_vendor

    # Detect platform triplet
    detect_platform_triplet platform_triplet platform_triplet_no_vendor
    echo "Detected: $platform_triplet, $platform_triplet_no_vendor"

    # Filter triplets based on the provided index range, if specified
    # The range is left-closed and right-open: [start_index, end_index)
    if [[ -z "$start_index" ]]; then
        start_index=0  # Default to the first element
    fi

    if [[ -z "$end_index" ]]; then
        end_index=${#TRIPLETS2[@]}  # Default to the length of the array
    fi

    # Ensure end_index can handle the full array, even if it equals the length of TRIPLETS2
    if [[ $end_index -gt ${#TRIPLETS2[@]} ]]; then
        echo "Error: end_index exceeds array bounds. Exiting."
        exit 1
    fi

    # Handle the range: [start_index, end_index)
    if [[ $start_index -lt $end_index ]]; then
        TRIPLETS2=("${TRIPLETS2[@]:$start_index:$(($end_index - $start_index))}")
    elif [[ $start_index -eq $end_index ]]; then
        # If start_index equals end_index, make the array explicitly empty
        TRIPLETS2=()
    else
        # If start_index is greater than end_index, exit with an error
        echo "Error: Invalid index range provided. Exiting."
        exit 1
    fi

    # Flag to track if a match is found
    local found_match=0
    local new_array=()

    # Always build the local platform_triplet unless explicitly skipped
    if [[ "$SKIP_PLATFORM_TRIPLET" != "yes" ]]; then
        echo "Building local platform_triplet: $platform_triplet"
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
    else
        echo "Skipping local platform_triplet due to environment variable SKIP_PLATFORM_TRIPLET"
    fi

    # Print the updated array
    echo "Updated TRIPLETS2 array (count: ${#TRIPLETS2[@]}):"
    for triplet in "${TRIPLETS2[@]}"; do
        echo "$triplet"
    done

    # Iterate through the triplets and trigger the build process
    for triplet in "${TRIPLETS2[@]}"; do
        TRIPLET=$triplet ./build_common.sh $restart_paramter
    done
}

main
cd "$llvmcurrentrealpath"
./wasm-sysroots.sh "$1"

if [[ $NO_BUILD_WAVM != "yes" ]]; then
cd "$llvmcurrentrealpath/../wavm"
./all.sh "$@"
fi

if [[ $NO_BUILD_WINE != "yes" ]]; then
cd "$llvmcurrentrealpath/../wine"
./all-min.sh "$@"
fi

if [[ $UPLOAD_LLVM != "yes" ]]; then
cd "$llvmcurrentrealpath"
./upload.sh
fi
