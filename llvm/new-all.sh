
#!/bin/bash
llvmcurrentrealpath="$(realpath .)"

# Define an array with TRIPLET values, each on a new line
TRIPLETS2=(
    "x86_64-linux-gnu"
    "aarch64-linux-gnu"
    "x86_64-windows-gnu"
    "aarch64-windows-gnu"
    "aarch64-linux-android30"
    "x86_64-linux-android30"
    "aarch64-apple-darwin24"
    "loongarch64-linux-gnu"
    "riscv64-linux-gnu"
)

TRIPLETS=("x86_64-linux-gnu")

# Loop through the TRIPLET values and call the build script
for TRIPLET in "${TRIPLETS[@]}"; do
    TRIPLET=$TRIPLET ./build_common.sh "$@"
done

cd "$llvmcurrentrealpath"