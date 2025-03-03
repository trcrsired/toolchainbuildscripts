#!/bin/bash

# This script was generated by Microsoft Copilot

# This script updates multiple dependencies (e.g., LLVM, Linux, glibc, etc.).
# If the CLONE_IN_CHINA environment variable is set to "yes", alternative Git URLs will be used for faster cloning within China.

# Define a function to get the appropriate Git URLs
get_git_urls() {
    local DEPENDENCY_NAME=$1
    local GIT_URL
    local GIT_CHINA_DOWNSTREAM_URL

    case $DEPENDENCY_NAME in
        "llvm-project")
            GIT_URL="git@github.com:llvm/llvm-project.git"
            GIT_CHINA_DOWNSTREAM_URL="https://github.com.cnpmjs.org/llvm/llvm-project.git"
            ;;
        "linux")
            GIT_URL="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
            GIT_CHINA_DOWNSTREAM_URL="https://mirrors.tuna.tsinghua.edu.cn/git/kernel/linux.git"
            ;;
        "glibc")
            GIT_URL="git://sourceware.org/git/glibc.git"
            GIT_CHINA_DOWNSTREAM_URL="https://mirrors.tuna.tsinghua.edu.cn/git/glibc.git"
            ;;
        "newlib-cygwin")
            GIT_URL="git@github.com:mirror/newlib-cygwin.git"
            GIT_CHINA_DOWNSTREAM_URL="https://github.com.cnpmjs.org/mirror/newlib-cygwin.git"
            ;;
        "mingw-w64")
            GIT_URL="https://git.code.sf.net/p/mingw-w64/mingw-w64"
            GIT_CHINA_DOWNSTREAM_URL="https://mirrors.tuna.tsinghua.edu.cn/git/mingw-w64.git"
            ;;
        "zlib")
            GIT_URL="git@github.com:trcrsired/zlib.git"
            GIT_CHINA_DOWNSTREAM_URL="https://mirrors.tuna.tsinghua.edu.cn/git/zlib.git"
            ;;
        "libxml2")
            GIT_URL="https://gitlab.gnome.org/GNOME/libxml2.git"
            GIT_CHINA_DOWNSTREAM_URL="https://mirrors.tuna.tsinghua.edu.cn/git/libxml2.git"
            ;;
        "musl")
            GIT_URL="git://repo.or.cz/musl.git"
            GIT_CHINA_DOWNSTREAM_URL="https://mirrors.tuna.tsinghua.edu.cn/git/musl.git"
            ;;
        "gcc")
            GIT_URL="git://gcc.gnu.org/git/gcc.git"
            GIT_CHINA_DOWNSTREAM_URL="https://mirrors.tuna.tsinghua.edu.cn/git/gcc.git"
            ;;
        "windows-msvc-sysroot")
            GIT_URL="git@github.com:trcrsired/windows-msvc-sysroot.git"
            GIT_CHINA_DOWNSTREAM_URL="$GIT_URL"
            ;;
        "cppwinrt")
            GIT_URL="https://github.com/microsoft/cppwinrt.git"
            GIT_CHINA_DOWNSTREAM_URL="https://mirrors.tuna.tsinghua.edu.cn/git/microsoft/cppwinrt.git"
            ;;
        *)
            echo "Unknown dependency: $DEPENDENCY_NAME"
            exit 1
            ;;
    esac

    echo "$GIT_URL $GIT_CHINA_DOWNSTREAM_URL"
}

# Define a function to clone or update a dependency
clone_or_update_dependency() {
    local DEPENDENCY_NAME=$1
    local URLS
    URLS=$(get_git_urls "$DEPENDENCY_NAME")
    local GIT_URL=${URLS%% *}
    local GIT_CHINA_DOWNSTREAM_URL=${URLS##* }

    # Check and set the appropriate toolchains path variable
    local toolchains_path
    if [ "$DEPENDENCY_NAME" == "windows-msvc-sysroot" ]; then
        if [ -z ${TOOLCHAINSPATH+x} ]; then
            toolchains_path="$HOME/toolchains"
        else
            toolchains_path="$TOOLCHAINSPATH"
        fi
    else
        if [ -z ${TOOLCHAINS_BUILD+x} ]; then
            toolchains_path="$HOME/toolchains_build"
        else
            toolchains_path="$TOOLCHAINS_BUILD"
        fi
    fi

    if [ ! -d "$toolchains_path/$DEPENDENCY_NAME" ]; then
        cd "$toolchains_path" || return
        if [ "x${CLONE_IN_CHINA}" == "xyes" ] && [ "$GIT_CHINA_DOWNSTREAM_URL" != "$GIT_URL" ]; then
            git clone $GIT_CHINA_DOWNSTREAM_URL "$toolchains_path/$DEPENDENCY_NAME"
        else
            git clone $GIT_URL "$toolchains_path/$DEPENDENCY_NAME"
        fi

        if [ $? -ne 0 ]; then
            echo "$DEPENDENCY_NAME clone failed"
            exit 1
        fi

        if [ "x${CLONE_IN_CHINA}" == "xyes" ] && [ "$GIT_CHINA_DOWNSTREAM_URL" != "$GIT_URL" ]; then
            cd "$toolchains_path/$DEPENDENCY_NAME" || return
            git remote set-url origin $GIT_URL
            if [ $? -ne 0 ]; then
                echo "Failed to set upstream URL for $DEPENDENCY_NAME, continuing with downstream URL"
            fi
        fi
    fi
    cd "$toolchains_path/$DEPENDENCY_NAME" || return
    git pull --quiet
}
