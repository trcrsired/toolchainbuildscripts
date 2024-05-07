cmake_minimum_required(VERSION 3.15)

set(CMAKE_BUILD_TYPE Release)
set(CMAKE_C_COMPILER gcc)
set(CMAKE_ASM_COMPILER ${CMAKE_C_COMPILER})
set(CMAKE_CXX_COMPILER g++)
set(LLVM_ENABLE_PROJECTS "clang;lld;clang-tools-extra;lldb")
set(LLVM_OPTIMIZED_TABLEGEN On)
set(BUILD_SHARED_LIBS On)

set(TOOLCHAIN_COMMON_FLAGS "-march=native")
set(CMAKE_C_FLAGS ${TOOLCHAIN_COMMON_FLAGS})
set(CMAKE_CXX_FLAGS ${TOOLCHAIN_COMMON_FLAGS})

# runtimes
set(LLVM_ENABLE_RUNTIMES "libcxxabi;libcxx;compiler-rt;libunwind")
set(LIBCXXABI_SILENT_TERMINATE On)

