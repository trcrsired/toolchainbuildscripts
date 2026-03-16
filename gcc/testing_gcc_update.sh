GCC_COMMON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common/gcc_patches" &>/dev/null && pwd)"
echo "$GCC_COMMON_SCRIPT_DIR"
cd ../common
source ./common.sh

clone_or_update_dependency gcc
