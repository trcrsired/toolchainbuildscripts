#!/bin/bash

# This script updates the LLVM and Linux projects. If the CLONE_IN_CHINA environment variable
# is set to "yes", alternative Git URLs will be used for faster cloning within China.

# Check and set the TOOLCHAINS_BUILD environment variable
if [ -z ${TOOLCHAINS_BUILD+x} ]; then
    TOOLCHAINS_BUILD=$HOME/toolchains_build
fi

# Define a function to update the LLVM project
update_llvm_project() {
    # Check if CLONE_IN_CHINA is set to "yes", and use an alternative Git URL if true
    local GIT_URL
    if [ "x${CLONE_IN_CHINA}" == "xyes" ]; then
        GIT_URL="https://github.com.cnpmjs.org/llvm/llvm-project.git"
    else
        GIT_URL="git@github.com:llvm/llvm-project.git"
    fi

    if [ ! -d "$TOOLCHAINS_BUILD/llvm" ]; then
        git clone $GIT_URL "$TOOLCHAINS_BUILD/llvm"
    fi
    
    cd "$TOOLCHAINS_BUILD/llvm" || return
    git pull --quiet
}

# Define a function to update the Linux project
update_linux_project() {
    # Check if CLONE_IN_CHINA is set to "yes", and use an alternative Git URL if true
    local GIT_URL
    if [[ "x${CLONE_IN_CHINA}" == "xyes" ]]; then
        GIT_URL="https://mirrors.tuna.tsinghua.edu.cn/git/kernel/linux.git"
    else
        GIT_URL="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
    fi

    if [ ! -d "$TOOLCHAINS_BUILD/linux" ]; then
        cd "$TOOLCHAINS_BUILD" || return
        git clone $GIT_URL
        if [ $? -ne 0 ]; then
            echo "linux clone failed"
            exit 1
        fi
    fi

    cd "$TOOLCHAINS_BUILD/linux" || return
    git pull --quiet
}

# Call the functions
update_llvm_project
update_linux_project
