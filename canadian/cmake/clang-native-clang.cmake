cmake_minimum_required(VERSION 3.15)

set(CMAKE_BUILD_TYPE Release)
set(LLVM_ENABLE_LLD On)
set(LLVM_ENABLE_LTO thin)

set(CMAKE_C_COMPILER clang)
set(CMAKE_ASM_COMPILER ${CMAKE_C_COMPILER})
set(CMAKE_CXX_COMPILER clang++)

set(TOOLCHAIN_COMMON_FLAGS "-Wno-array-bounds -Wno-cast-function-type -Wno-uninitialized -Wno-cast-function-type -march=native -Wno-unused-command-line-argument -fuse-ld=lld -flto=thin")
set(CMAKE_C_FLAGS ${TOOLCHAIN_COMMON_FLAGS})
set(CMAKE_CXX_FLAGS ${TOOLCHAIN_COMMON_FLAGS})

set(LLVM_ENABLE_PROJECTS "clang;lld;clang-tools-extra;lldb")

set(LLVM_OPTIMIZED_TABLEGEN On)

set(BUILD_SHARED_LIBS On)

# runtimes
# set(LLVM_ENABLE_RUNTIMES "libcxxabi;libcxx;compiler-rt;libunwind")
set(LIBCXXABI_SILENT_TERMINATE On)
