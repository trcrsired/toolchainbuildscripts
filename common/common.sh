source ./safe-llvm-strip.sh
source ./parse-triplet.sh
source ./clone-dependencies.sh
source ./build-glibc.sh
./dependencycheck.sh
if [ $? -ne 0 ]; then
    exit 1
fi