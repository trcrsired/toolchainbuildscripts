#!/bin/bash

detect_platform_triplet() {
    local triplet, tripletnovendor  # Declare a local variable to store the triplet

    # Get the target platform from gcc if available
    if command -v gcc &> /dev/null; then
        triplet=$(gcc -dumpmachine)
    elif command -v clang &> /dev/null; then
        # Get the target platform from clang if gcc is not available
        triplet=$(clang -dumpmachine)
    else
        triplet="unknown-unknown-unknown-unknown"
    fi
    local cpu, vendor, os, abi
    parse_triplet( $triplet, $cpu, $vendor, $os, $abi)
    return $triplet, $cpu-$os-$abi
}
