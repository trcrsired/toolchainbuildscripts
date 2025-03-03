#!/bin/bash

function safe_llvm_strip {
    # Check if a directory parameter is provided
    if [[ -z "$1" ]]; then
        echo "No directory specified. Exiting."
        return 1
    fi
		echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
		echo "PATH=$PATH"
		echo "llvm-strip=$(which llvm-strip)"
		echo "ldd $(which llvm-strip)=$(ldd $(which llvm-strip))"

    # Directory parameter
    local dir="$1"

    # Find all regular files in the specified directory and subdirectories
    find "$dir" -type f | while read -r file; do
        # Attempt to strip the file
        llvm-strip --strip-unneeded "$file" 2>/dev/null
    done
}