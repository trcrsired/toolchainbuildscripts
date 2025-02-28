./wine.sh "$@"
export MINIMUMBUILD=yes
./aarch64-linux-android30.sh "$@"
./x86_64-linux-gnu.sh "$@"
./aarch64-linux-gnu.sh "$@"

