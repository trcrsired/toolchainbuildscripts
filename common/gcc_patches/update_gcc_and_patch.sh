#!/bin/bash

GCC_DIR="${1:-$GCC_DIR}"

if [ -z "$GCC_DIR" ]; then
    echo "Usage: $0 <gcc source directory>"
    exit 1
fi

cd "$GCC_DIR" || exit 1

git pull
