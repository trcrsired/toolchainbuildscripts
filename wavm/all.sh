if [[ "$SIMPLE_MODE" == "yes" ]]; then
echo "SIMPLE_MODE is enabled, only local triplets will be built for WAVM"
fi

# Must match the triplets built by llvm/all.sh, WAVM relies on the LLVM toolchains
TRIPLETS=(
    "x86_64-linux-gnu"
    "x86_64-windows-gnu"
    "aarch64-windows-gnu"
    "aarch64-linux-android30"
    "aarch64-apple-darwin24"
)

if [[ "$SIMPLE_MODE" != "yes" ]]; then
    TRIPLETS+=(
        "aarch64-linux-gnu"
        "aarch64-linux-musl"
        "loongarch64-linux-gnu"
        "loongarch64-linux-musl"
        "x86_64-linux-android30"
        "x86_64-linux-musl"
        "riscv64-linux-gnu"
    )
fi

for host in "${TRIPLETS[@]}"; do
    if [[ "$host" == *-linux-gnu || "$host" == *-linux-musl ]]; then
        # Despite the name, this script is generic and handles all linux triples
        HOST="$host" ./loongarch64-linux-gnu.sh "$@"
    else
        ./${host}.sh "$@"
    fi
    if [ $? -ne 0 ]; then
        echo "WAVM $host failed"
        if [[ "$host" == "x86_64-windows-gnu" ]]; then
            exit 1
        fi
    fi
done
