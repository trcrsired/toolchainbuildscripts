#!/bin/bash

# Array of commands to check
commands=("gcc" "g++" "rsync" "bison" "flex" "autoconf" "makeinfo" "make" "wget" "git" "tar" "which" "python3" "xz" "realpath" "hg")

# Variable to track if any command is missing
missing_commands=false

# Loop through each command and check if it's installed
for cmd in "${commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "$cmd is not installed"
        missing_commands=true
    fi
done

# Check if any command is missing and decide whether to continue
if [ "$missing_commands" = true ]; then
    echo "Some commands are not installed. Please install all required commands before proceeding."
    exit 1  # Exit with status code 1 indicating failure
fi