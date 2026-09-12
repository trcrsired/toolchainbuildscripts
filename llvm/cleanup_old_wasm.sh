#!/bin/bash

# Cleanup script to reorganize existing wasm-sysroots:
# - Move builtins from per-triplet to shared wasm-sysroots/builtins/
# - Remove libherbceptions/runtimes from per-triplet dirs
# - Collapse nested ${TRIPLET}/${TRIPLET} dirs

TOOLCHAINSPATH="${TOOLCHAINSPATH:-$HOME/toolchains}"
WASMSYSROOTS="$TOOLCHAINSPATH/llvm/wasm-sysroots"

if [ ! -d "$WASMSYSROOTS" ]; then
    echo "Error: $WASMSYSROOTS does not exist"
    exit 1
fi

# Target triplets
WASI_TARGETS=(
    "wasm32-wasip1"
    "wasm32-wasip2"
    "wasm32-wasip3"
    "wasm32-wasip1-threads"
    "wasm64-wasip1"
    "wasm64-wasip2"
    "wasm64-wasip3"
    "wasm64-wasip1-threads"
)

# Handle old variant directories (wasm-sysroot, wasm-noeh-sysroot, etc.)
VARIANTS=(
    "wasm-sysroot"
    "wasm-memtag-sysroot"
    "wasm-noeh-sysroot"
    "wasm-noeh-memtag-sysroot"
)

for variant in "${VARIANTS[@]}"; do
    variantdir="$WASMSYSROOTS/$variant"
    if [ ! -d "$variantdir" ]; then
        echo "Skipping $variant: directory does not exist"
        continue
    fi

    echo "Processing variant: $variant"

    for triplet in "${WASI_TARGETS[@]}"; do
        tripletdir="$variantdir/$triplet"
        if [ ! -d "$tripletdir" ]; then
            continue
        fi

        # Move builtins to shared location
        if [ -d "$tripletdir/builtins" ]; then
            cp -r --preserve=links "$tripletdir/builtins" "$WASMSYSROOTS/builtins_tmp_$triplet"
            rm -rf "$tripletdir/builtins"
        fi

        # Remove libherbceptions and runtimes from triplet dir
        rm -rf "$tripletdir/libherbceptions"
        rm -rf "$tripletdir/runtimes"

        # Collapse nested ${TRIPLET}/${TRIPLET} into ${TRIPLET}
        if [ -d "$tripletdir/$triplet" ]; then
            for item in "$tripletdir/$triplet"/*; do
                [ -e "$item" ] || continue
                basename=$(basename "$item")
                if [ -e "$tripletdir/$basename" ]; then
                    # Skip if already exists (shouldn't happen normally)
                    echo "Warning: $tripletdir/$basename already exists, skipping"
                    continue
                fi
                mv "$item" "$tripletdir/"
            done
            rm -rf "$tripletdir/$triplet"
        fi
    done

    # Merge builtins from this variant
    for triplet in "${WASI_TARGETS[@]}"; do
        tmpbuiltins="$WASMSYSROOTS/builtins_tmp_$triplet"
        if [ -d "$tmpbuiltins" ]; then
            if [ ! -d "$WASMSYSROOTS/builtins" ]; then
                mkdir -p "$WASMSYSROOTS/builtins"
            fi
            cp -r --preserve=links "$tmpbuiltins"/* "$WASMSYSROOTS/builtins/" 2>/dev/null
            rm -rf "$tmpbuiltins"
        fi
    done

    # Move the collapsed triplet dirs up to wasm-sysroots level (flatten)
    for triplet in "${WASI_TARGETS[@]}"; do
        tripletdir="$variantdir/$triplet"
        if [ -d "$tripletdir" ]; then
            target="$WASMSYSROOTS/$triplet"
            if [ -d "$target" ]; then
                echo "Warning: $target already exists, merging"
                cp -r --preserve=links "$tripletdir"/* "$target/" 2>/dev/null
            else
                mv "$tripletdir" "$target"
            fi
        fi
    done

    # Remove variant directory (it should now be empty or have leftover cmake files)
    rm -rf "$variantdir"
done

# Also handle triplets that are directly under wasm-sysroots (already flat structure)
for triplet in "${WASI_TARGETS[@]}"; do
    tripletdir="$WASMSYSROOTS/$triplet"
    if [ ! -d "$tripletdir" ]; then
        continue
    fi

    # Move builtins to shared location
    if [ -d "$tripletdir/builtins" ]; then
        if [ ! -d "$WASMSYSROOTS/builtins" ]; then
            mkdir -p "$WASMSYSROOTS/builtins"
        fi
        cp -r --preserve=links "$tripletdir/builtins"/* "$WASMSYSROOTS/builtins/" 2>/dev/null
        rm -rf "$tripletdir/builtins"
    fi

    # Remove libherbceptions and runtimes
    rm -rf "$tripletdir/libherbceptions"
    rm -rf "$tripletdir/runtimes"

    # Collapse nested ${TRIPLET}/${TRIPLET}
    if [ -d "$tripletdir/$triplet" ]; then
        for item in "$tripletdir/$triplet"/*; do
            [ -e "$item" ] || continue
            basename=$(basename "$item")
            if [ -e "$tripletdir/$basename" ]; then
                echo "Warning: $tripletdir/$basename already exists, skipping"
                continue
            fi
            mv "$item" "$tripletdir/"
        done
        rm -rf "$tripletdir/$triplet"
    fi
done

# Clean up leftover cmake files in triplet dirs
for triplet in "${WASI_TARGETS[@]}"; do
    tripletdir="$WASMSYSROOTS/$triplet"
    if [ -d "$tripletdir" ]; then
        rm -f "$tripletdir"/*.cmake
    fi
done

echo "Cleanup complete!"
echo "New structure:"
ls -la "$WASMSYSROOTS"
