#!/bin/bash

parse_triplet() {
    local TRIPLET=$1
    local -n CPU_VAR=$2
    local -n VENDOR_VAR=$3
    local -n OS_VAR=$4
    local -n ABI_VAR=$5

    # Extract and assign parts from $TRIPLET
    CPU_VAR=${TRIPLET%%-*}                         # Extract 'cpu'
    local TRIPLET_REMAINDER=${TRIPLET#*-}          # Remaining parts after 'cpu'
    if [[ "$TRIPLET_REMAINDER" == "$TRIPLET" ]]; then
        return 1
    fi

    # Extract TRIPLET_VENDOR and update TRIPLET_REMAINDER
    if [[ "$TRIPLET_REMAINDER" == *-* ]]; then
        VENDOR_VAR=${TRIPLET_REMAINDER%%-*}        # Extract 'vendor'
        TRIPLET_REMAINDER=${TRIPLET_REMAINDER#*-}  # Update TRIPLET_REMAINDER
    else
        VENDOR_VAR=""
    fi

    # Correct behavior if TRIPLET_VENDOR is 'linux'
    if [[ "$VENDOR_VAR" == "windows" ]]; then
        VENDOR_VAR=""                              # Clear TRIPLET_VENDOR as 'windows' is part of TRIPLET_OS
        OS_VAR="windows"                           # Shift TRIPLET_OS from TRIPLET_REMAINDER
        ABI_VAR=${TRIPLET_REMAINDER#*-}            # Extract 'abi' from TRIPLET_REMAINDER
    elif [[ "$VENDOR_VAR" == "linux" ]]; then
        VENDOR_VAR=""                              # Clear TRIPLET_VENDOR as 'linux' is part of TRIPLET_OS
        OS_VAR="linux"                             # Shift TRIPLET_OS from TRIPLET_REMAINDER
        ABI_VAR=${TRIPLET_REMAINDER#*-}            # Extract 'abi' from TRIPLET_REMAINDER
    else
        # Normal behavior for non-'linux' TRIPLET_VENDOR
        if [[ "$TRIPLET_REMAINDER" == *-* ]]; then
            OS_VAR=${TRIPLET_REMAINDER%%-*}        # Extract 'os'
            ABI_VAR=${TRIPLET_REMAINDER#*-}        # Extract 'abi'
        else
            OS_VAR=$TRIPLET_REMAINDER              # Remaining part becomes OS
            ABI_VAR=""
        fi
    fi

    return 0
}

