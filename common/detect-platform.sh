#!/bin/bash

detect_platform_triplet() {
    local -n triplet=$1         # Name reference to the first argument
    local -n triplet_no_vendor=$2  # Name reference to the second argument

    # Get the target platform from gcc if available
    if command -v gcc &> /dev/null; then
        triplet=$(gcc -dumpmachine)
    elif command -v clang &> /dev/null; then
        # Get the target platform from clang if gcc is not available
        triplet=$(clang -dumpmachine)
    else
        triplet="unknown-unknown-unknown-unknown"
    fi

    # Parse triplet and compute triplet_no_vendor
    local cpu
    local vendor
    local os
    local abi
    parse_triplet "$triplet" cpu vendor os abi   # Ensure parse_triplet is defined and works properly

    triplet_no_vendor="$cpu-$os-$abi"  # Assign the processed value to the referenced variable
}

