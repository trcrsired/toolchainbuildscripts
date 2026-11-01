#!/usr/bin/env bash
#
# install-gcc.sh - install prebuilt GCC toolchains (GCC only!)
#
# It downloads the toolchains published in
#   https://github.com/trcrsired/gcc-releases
# and unpacks them into the same layout the build scripts use:
#   $TOOLCHAINSPATH_GNU/<host>/<target>
#
# By default this installs exactly two toolchains for the detected platform
# (platform "aarch64-linux-gnu" is used as an example):
#
#   1. the native GCC for the platform:
#        aarch64-linux-gnu.aarch64-linux-gnu
#   2. the GCC targeting the Windows ABI of the same architecture:
#        aarch64-linux-gnu.aarch64-w64-mingw32
#
# Usage:
#   ./install-gcc.sh                 # native GCC + Windows GCC, env in ~/.bashrc
#   SETGCCENV=no ./install-gcc.sh        # do not touch ~/.bashrc
#   DOWNLOAD_ALL=yes ./install-gcc.sh    # every toolchain of the release
#   DRYRUN=yes ./install-gcc.sh          # print what would be installed
#
# On Windows use install-gcc.ps1 instead (same layout, PowerShell, mingw hosts).
#
# Environment variables:
#   TOOLCHAINSPATH            default: $HOME/toolchains
#   TOOLCHAINSPATH_GNU        default: $TOOLCHAINSPATH/gnu
#   GCC_RELEASE_VERSION       release tag, e.g. 20261101-gcc17
#                             (falls back to RELEASE_VERSION; otherwise the
#                             newest "-gcc<N>" tag is queried from git)
#   GITHUB_BUILD_GCC_REPO     default: trcrsired/gcc-releases
#   HOST_TRIPLET / TRIPLE     override the detected platform triplet
#   GCC_TARGETS               space separated targets to install for the host
#                             instead of the default native + Windows pair
#   DOWNLOAD_ALL              yes: install every toolchain of the release
#   FORCEDOWNLOAD             yes: download even when the .tar.xz is already
#                             cached in $TOOLCHAINSPATH_GNU/<host>/
#   SETGCCENV                 default yes: append PATH/WINEPATH (and a
#                             libc-free LD_LIBRARY_PATH) to ~/.bashrc;
#                             set to no to leave the shell config alone
#   DRYRUN                    yes: only print the toolchains that would be installed
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO="${GITHUB_BUILD_GCC_REPO:-trcrsired/gcc-releases}"

TOOLCHAINSPATH="${TOOLCHAINSPATH:-$HOME/toolchains}"
TOOLCHAINSPATH_GNU="${TOOLCHAINSPATH_GNU:-$TOOLCHAINSPATH/gnu}"

DOWNLOAD_ALL="${DOWNLOAD_ALL:-no}"
SETGCCENV="${SETGCCENV:-yes}"
DRYRUN="${DRYRUN:-no}"
FORCEDOWNLOAD="${FORCEDOWNLOAD:-no}"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

info() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

is_musl_host() {
    # ld-musl loader or an ldd that reports musl
    compgen -G '/lib/ld-musl-*' >/dev/null 2>&1 && return 0
    compgen -G '/usr/lib/ld-musl-*' >/dev/null 2>&1 && return 0
    ldd --version 2>&1 | grep -qi musl
}

# map `uname -m` to the cpu part used by the toolchains
normalize_arch() {
    case "$1" in
    x86_64 | amd64) printf 'x86_64\n' ;;
    aarch64 | arm64) printf 'aarch64\n' ;;
    loongarch64 | loong64) printf 'loongarch64\n' ;;
    riscv64) printf 'riscv64\n' ;;
    i386 | i486 | i586 | i686 | x86) printf 'i686\n' ;;
    *) return 1 ;;
    esac
}

# detect the triplet of the current platform, e.g. aarch64-linux-gnu
detect_platform_triplet() {
    if [[ -n "${HOST_TRIPLET:-}" ]]; then
        printf '%s\n' "$HOST_TRIPLET"
        return 0
    fi
    if [[ -n "${TRIPLE:-}" ]]; then
        # strip a redundant pc/unknown vendor: x86_64-pc-linux-gnu -> x86_64-linux-gnu
        local triplet="$TRIPLE"
        IFS='-' read -r -a parts <<<"$triplet"
        if [[ ${#parts[@]} -eq 4 && ("${parts[1]}" == "pc" || "${parts[1]}" == "unknown") ]]; then
            triplet="${parts[0]}-${parts[2]}-${parts[3]}"
        fi
        printf '%s\n' "$triplet"
        return 0
    fi

    local arch
    arch="$(normalize_arch "$(uname -m)")" || die "unsupported machine: $(uname -m)"

    case "$(uname -s)" in
    Linux)
        if [[ -n "${ANDROID_ROOT:-}" && "$arch" == "aarch64" ]]; then
            printf 'aarch64-linux-android30\n'
            return 0
        fi
        if is_musl_host; then
            printf '%s-linux-musl\n' "$arch"
        else
            printf '%s-linux-gnu\n' "$arch"
        fi
        ;;
    *)
        die "unsupported OS: $(uname -s) (GCC releases only ship Linux and Windows toolchains)"
        ;;
    esac
}

# the Windows ABI triplet of a given architecture (empty when not supported)
windows_target_for_arch() {
    case "$1" in
    x86_64 | aarch64 | i686) printf '%s-w64-mingw32\n' "$1" ;;
    *) return 1 ;;
    esac
}

# collect every "<host> <target>" pair defined by gcc/triplet-*.sh
collect_pairs_from_triplet_files() {
    local dir="$SCRIPT_DIR/../gcc"
    local file

    compgen -G "$dir/triplet-*.sh" >/dev/null 2>&1 ||
        die "no triplet files found in $dir"

    for file in "$dir"/triplet-*.sh; do
        bash -c '
            set +eu
            triplet_file=$1
            source "$triplet_file" >/dev/null 2>&1 || exit 0
            for entry in ${GCCTRIPLETS[@]+"${GCCTRIPLETS[@]}"}; do
                set -- $entry
                [[ $# -ge 3 ]] || continue
                printf "%s %s\n" "$2" "$3"
            done
        ' _ "$file"
    done | sort -u
}

resolve_release_version() {
    if [[ -n "${GCC_RELEASE_VERSION:-}" ]]; then
        return 0
    fi
    if [[ -n "${RELEASE_VERSION:-}" ]]; then
        GCC_RELEASE_VERSION="$RELEASE_VERSION"
        return 0
    fi

    command -v git >/dev/null 2>&1 ||
        die "git is not installed. Please set GCC_RELEASE_VERSION instead."

    info "Querying the latest GCC release from github.com/$REPO ..." >&2
    GCC_RELEASE_VERSION="$(
        git ls-remote --tags "https://github.com/$REPO.git" |
            awk '{print $2}' |
            sed 's#refs/tags/##' |
            grep -E -- '-gcc[0-9]+$' |
            sort -V |
            tail -n 1 || true
    )"

    [[ -n "$GCC_RELEASE_VERSION" ]] ||
        die "failed to query the latest release version for $REPO (network problem?)"
}

download_file() {
    local url=$1
    local dest=$2
    local tmp="${dest}.part"

    rm -f "$tmp"
    if command -v curl >/dev/null 2>&1; then
        if [[ -t 2 ]]; then
            curl -fL --retry 3 --retry-delay 2 -o "$tmp" "$url"
        else
            curl -fL --retry 3 --retry-delay 2 -sS -o "$tmp" "$url"
        fi
    elif command -v wget >/dev/null 2>&1; then
        wget -nv --tries=3 -O "$tmp" "$url"
    else
        die "neither curl nor wget is installed. Please install one of them."
    fi

    if [[ ! -s "$tmp" ]]; then
        rm -f "$tmp"
        return 1
    fi
    mv -f "$tmp" "$dest"
}

# install one "<host>.<target>" toolchain; returns 1 on failure when strict=yes
install_toolchain() {
    local host=$1
    local target=$2
    local strict=$3

    local name="$host.$target"
    local host_dir="$TOOLCHAINSPATH_GNU/$host"
    local archive="$host_dir/$name.tar.xz"
    local url="$BASE_URL/$name.tar.xz"

    info "==> $name"

    if [[ "$DRYRUN" == "yes" ]]; then
        info "    dry run: would download $url"
        info "    dry run: would extract into $host_dir"
        return 0
    fi

    mkdir -p "$host_dir"
    rm -rf "${host_dir:?}/$target"

    local reused=no
    if [[ -s "$archive" && "$FORCEDOWNLOAD" != "yes" ]]; then
        info "    reusing existing $archive (set FORCEDOWNLOAD=yes to download again)"
        reused=yes
    fi

    if [[ "$reused" != "yes" ]]; then
        rm -f "$archive" "${archive}.part"
        info "    downloading $url"
        if ! download_file "$url" "$archive"; then
            rm -f "$archive" "${archive}.part"
            if [[ "$strict" == "yes" ]]; then
                die "failed to download $url"
            fi
            warn "$name is not available in release $GCC_RELEASE_VERSION, skipping"
            return 0
        fi
    fi

    info "    extracting to $host_dir"
    if ! tar -xf "$archive" -C "$host_dir"; then
        if [[ "$reused" == "yes" ]]; then
            # the cached archive is broken: fetch it again and retry once
            info "    cached archive is broken, downloading again"
            rm -f "$archive"
            download_file "$url" "$archive" || die "failed to download $url"
            tar -xf "$archive" -C "$host_dir" || die "failed to extract $archive"
        else
            die "failed to extract $archive"
        fi
    fi

    [[ -d "$host_dir/$target/bin" ]] ||
        die "$archive does not contain $target/bin"

    info "    installed $host_dir/$target"
}

# A directory may only be put on LD_LIBRARY_PATH when it holds no libc and no
# dynamic loader. The dynamic linker honours LD_LIBRARY_PATH for *every*
# process started from this environment, so a libc/ld.so found there would be
# used by the whole OS (sudo, ssh, the desktop, ...) and can crash the machine.
# GCC toolchains do ship a target libc in <target>/lib - never export that.
is_safe_ld_dir() {
    local dir=$1
    local pattern
    [[ -d "$dir" ]] || return 1
    for pattern in 'libc.so*' 'libc-*.so*' 'libc.a' 'ld-linux*' 'ld-musl*' 'ld.so*' \
        'libpthread.so*' 'libdl.so*' 'librt.so*'; do
        compgen -G "$dir/$pattern" >/dev/null 2>&1 && return 1
    done
    return 0
}

# Add/refresh one "export VAR=..." line in a shell rc file.
#
# Like the llvm installer we never blindly append: first look at what the rc
# file already contains for that variable.
#   * the exact line is there        -> nothing to do
#   * VAR is exported for this very
#     toolchain prefix with other
#     content (older run, hand edit) -> replace that line in place
#   * VAR exported for other prefixes
#     (another toolchain)            -> keep them, append ours
upsert_env_line() {
    local rc=$1
    local var=$2
    local marker=$3
    local new_line=$4
    local tmp

    if grep -Fxq "$new_line" "$rc"; then
        info "    $var for this toolchain already present in $rc"
        return 0
    fi

    if grep -F -- "export $var=" "$rc" | grep -Fq -- "$marker"; then
        tmp="$(mktemp)"
        awk -v var="$var" -v marker="$marker" -v newline="$new_line" '
            index($0, "export " var "=") == 1 && index($0, marker) > 0 {
                if (!done) {
                    print newline
                    done = 1
                }
                next
            }
            { print }
        ' "$rc" >"$tmp"
        mv -f "$tmp" "$rc"
        info "    updated $var in $rc: $new_line"
        return 0
    fi

    printf '%s\n' "$new_line" >>"$rc"
    info "    added to $rc: $new_line"
}

# append PATH/LD_LIBRARY_PATH/WINEPATH for an installed toolchain to ~/.bashrc
setup_env() {
    local host=$1
    local target=$2
    local abs_prefix="$TOOLCHAINSPATH_GNU/$host/$target"
    local prefix="$abs_prefix"

    # keep $HOME unexpanded in .bashrc when possible
    if [[ "$prefix" == "$HOME/"* ]]; then
        prefix="\$HOME/${prefix#"$HOME/"}"
    fi

    # LD_LIBRARY_PATH: the toolchain's own runtime dirs only, and only when they
    # are free of libc/ld.so (lib64 for Linux hosts, lib for Windows hosts)
    local -a ld_dirs=()
    local dir
    for dir in lib64 lib; do
        if is_safe_ld_dir "$abs_prefix/$dir"; then
            ld_dirs+=("$prefix/$dir")
        elif [[ -d "$abs_prefix/$dir" ]]; then
            warn "refusing to add $abs_prefix/$dir to LD_LIBRARY_PATH: it contains a libc or a dynamic loader"
        fi
    done

    local rc="$HOME/.bashrc"
    [[ -f "$rc" ]] || touch "$rc"

    upsert_env_line "$rc" PATH "$prefix/bin" \
        "export PATH=\"$prefix/bin\${PATH:+:\$PATH}\""

    if [[ ${#ld_dirs[@]} -gt 0 ]]; then
        local ld_path
        ld_path="$(IFS=:; printf '%s' "${ld_dirs[*]}")"
        upsert_env_line "$rc" LD_LIBRARY_PATH "$prefix" \
            "export LD_LIBRARY_PATH=\"$ld_path\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}\""
    fi

    # WINEPATH: bin (compilers) and lib (the DLLs of a Windows hosted toolchain)
    upsert_env_line "$rc" WINEPATH "$prefix" \
        "export WINEPATH=\"$prefix/bin;$prefix/lib\${WINEPATH+;\$WINEPATH}\""
}

# Sanity check: run the installed toolchain (only possible when it is built for
# this very platform). The Linux-hosted GCC binaries link against the *system*
# libisl/libgmp/libzstd (no RPATH, nothing bundled), so without those the
# compiler exists but cannot start - report it instead of leaving the user with
# a "g++ does not work" mystery.
check_toolchain() {
    local host=$1
    local target=$2
    local prefix="$TOOLCHAINSPATH_GNU/$host/$target"
    local driver

    # a Windows hosted toolchain can only run under wine
    [[ "$host" == "$PLATFORM_TRIPLET" ]] || return 0

    if [[ -x "$prefix/bin/$target-g++" ]]; then
        driver="$prefix/bin/$target-g++"
    elif [[ -x "$prefix/bin/g++" ]]; then
        driver="$prefix/bin/g++"
    else
        warn "no g++ driver found in $prefix/bin"
        return 0
    fi

    local output
    if output="$("$driver" --version 2>&1)"; then
        info "    $driver -> ${output%%$'\n'*}"
        return 0
    fi

    warn "$driver fails to run:"
    local line
    while IFS= read -r line; do
        warn "  $line"
    done <<<"$output"

    local missing=""
    if command -v ldd >/dev/null 2>&1; then
        local cc1
        missing="$(
            {
                ldd "$driver" 2>/dev/null || true
                for cc1 in "$prefix"/libexec/gcc/*/*/cc1plus; do
                    [[ -f "$cc1" ]] && ldd "$cc1" 2>/dev/null || true
                done
            } | awk '/not found/ { print $1 }' | sort -u | tr '\n' ' '
        )"
    fi
    if [[ -n "$missing" ]]; then
        warn "missing shared libraries: $missing"
        info "    the Linux-hosted toolchains do not bundle isl/gmp/mpfr/mpc/zstd,"
        info "    they use the system ones. Install them, e.g.:"
        case "$(awk -F= '/^ID=/{gsub(/"/,"",$2); print $2}' /etc/os-release 2>/dev/null)" in
        arch | manjaro | endeavouros) info "      sudo pacman -S --needed isl gmp mpfr mpc zstd" ;;
        debian | ubuntu | linuxmint | pop) info "      sudo apt install libisl23 libgmp10 libmpfr6 libmpc3 libzstd1" ;;
        fedora | rhel | centos | rocky | almalinux) info "      sudo dnf install isl gmp mpfr libmpc libzstd" ;;
        *) info "      install your distribution packages for isl, gmp, mpfr, mpc and zstd" ;;
        esac
    fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
    local platform
    platform="$(detect_platform_triplet)"

    local platform_arch="${platform%%-*}"
    platform_arch="$(normalize_arch "$platform_arch")" ||
        die "unsupported platform triplet: $platform"

    info "Detected platform: $platform"

    local -a hosts=()
    local -a targets=()
    local -a strictness=()

    PLATFORM_TRIPLET="$platform"

    if [[ "$DOWNLOAD_ALL" == "yes" ]]; then
        info "DOWNLOAD_ALL=yes: installing every toolchain of the release"
        local host target
        while read -r host target; do
            [[ -n "$host" && -n "$target" ]] || continue
            hosts+=("$host")
            targets+=("$target")
            strictness+=("no")
        done < <(collect_pairs_from_triplet_files)
    else
        if [[ -n "${GCC_TARGETS:-}" ]]; then
            local target
            for target in $GCC_TARGETS; do
                hosts+=("$platform")
                targets+=("$target")
                strictness+=("yes")
            done
        else
            # 1) the native GCC of this platform
            hosts+=("$platform")
            targets+=("$platform")
            strictness+=("yes")

            # 2) the GCC that targets Windows on this architecture
            local windows_target
            if windows_target="$(windows_target_for_arch "$platform_arch")"; then
                hosts+=("$platform")
                targets+=("$windows_target")
                strictness+=("yes")
            else
                warn "no Windows ($platform_arch-w64-mingw32) GCC is shipped for $platform_arch, only the native GCC will be installed"
            fi
        fi
    fi

    [[ ${#hosts[@]} -gt 0 ]] || die "nothing to install"

    resolve_release_version
    BASE_URL="https://github.com/$REPO/releases/download/$GCC_RELEASE_VERSION"
    info "Release: $GCC_RELEASE_VERSION"
    info "Install prefix: $TOOLCHAINSPATH_GNU"

    local i
    for i in "${!hosts[@]}"; do
        install_toolchain "${hosts[$i]}" "${targets[$i]}" "${strictness[$i]}"
        if [[ "$DRYRUN" != "yes" ]]; then
            check_toolchain "${hosts[$i]}" "${targets[$i]}"
            if [[ "$SETGCCENV" == "yes" ]]; then
                setup_env "${hosts[$i]}" "${targets[$i]}"
            fi
        fi
    done

    if [[ "$DRYRUN" == "yes" ]]; then
        info "dry run finished, nothing was installed"
        return 0
    fi

    info ""
    info "Done. Installed toolchains under $TOOLCHAINSPATH_GNU:"
    for i in "${!hosts[@]}"; do
        [[ -d "$TOOLCHAINSPATH_GNU/${hosts[$i]}/${targets[$i]}" ]] &&
            info "  $TOOLCHAINSPATH_GNU/${hosts[$i]}/${targets[$i]}"
    done

    if [[ "$SETGCCENV" == "yes" ]]; then
        info ""
        info "PATH/LD_LIBRARY_PATH/WINEPATH for the installed toolchains are in $HOME/.bashrc."
        info "Open a new shell, or run: source ~/.bashrc"
    else
        local prefix="$TOOLCHAINSPATH_GNU/${hosts[0]}/${targets[0]}"
        info ""
        info "SETGCCENV=no, nothing was written to ~/.bashrc. Add manually:"
        info "  export PATH=\"$prefix/bin:\$PATH\""
        info "  export LD_LIBRARY_PATH=\"$prefix/lib64:\$LD_LIBRARY_PATH\"  # only when it holds no libc/ld.so"
        info "  export WINEPATH=\"$prefix/bin;$prefix/lib;\$WINEPATH\""
    fi
}

main "$@"
