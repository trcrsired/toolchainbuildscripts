source ./safe-llvm-strip.sh
source ./parse-triplet.sh
source ./clone-dependencies.sh
source ./build-glibc.sh
source ./install-libc.sh
source ./check-location.sh
source ./detect-platform.sh
if [[ "x${SKIP_DEPENDENCY_CHECK}" != "xyes" ]]; then
./dependencycheck.sh
if [ $? -ne 0 ]; then
    exit 1
fi
fi
