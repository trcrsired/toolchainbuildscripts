check_clang_location() {
  local clang_path
  local clang_dir
  local resolved_path

  # Resolve the absolute path of $TOOLCHAINS_LLVMTRIPLETPATH/llvm/bin
  resolved_path=$(realpath "$TOOLCHAINS_LLVMTRIPLETPATH/llvm/bin")

  clang_path=$(command -v clang)
  clang_dir=$(dirname "$clang_path")
  
  if [ "$clang_dir" = "$resolved_path" ]; then
    # clang is located in the specified directory, set NO_TOOLCHAIN_DELETION
    return 0
  else
    return 1
  fi
}