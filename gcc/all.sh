#!/usr/bin/env bash
set -e

currentrealpath="$(realpath .)"

# Load common utilities
cd ../common
source ./common.sh

main() {
    # Variables for detected platform triplet
    local platform_triplet
    local platform_triplet_no_vendor

    # Detect the current platform triplet
    detect_platform_triplet platform_triplet platform_triplet_no_vendor
    echo "Detected platform: $platform_triplet (no-vendor: $platform_triplet_no_vendor)"

    # Parse triplet into components
    local cpu vendor os abi
    parse_triplet "$platform_triplet_no_vendor" cpu vendor os abi

    # Only Linux + GNU ABI is supported for now
    if [[ "$os" != "linux" || "$abi" != "gnu" ]]; then
        echo "Unsupported platform: $platform_triplet_no_vendor"
        exit 1
    fi

    # Determine the build script based on the platform triplet
    local script_dir
    script_dir="$currentrealpath"

    local build_script_name="all-build-${platform_triplet_no_vendor}.sh"
    local build_script="$script_dir/$build_script_name"

    # Check if the build script exists
    if [[ ! -f "$build_script" ]]; then
        echo "Error: build script not found: $build_script"
        echo "Expected file: ${build_script_name}"
        exit 1
    fi

    echo "Dispatching to: $build_script"

    # Execute the build script and forward all arguments
    cd "$script_dir"
    "./$build_script_name" "$@"
}

main "$@"
