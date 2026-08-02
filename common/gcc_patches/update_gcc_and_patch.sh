#!/bin/bash

if [ -z "$GCC_DIR" ]; then
    echo "Usage: $0 <gcc source directory>"
    exit 1
fi

cd "$GCC_DIR" || exit 1

git pull
