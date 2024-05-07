cmake_minimum_required(VERSION 3.15)
set(CMAKE_BUILD_TYPE Release)
set(CMAKE_SYSTEM_PROCESSOR wasm64)
set(TOOLCHAIN_TRIPLE wasm64-wasip1)
set(LLVM_DEFAULT_TARGET_TRIPLE ${TOOLCHAIN_TRIPLE})
set(LLVM_ENABLE_LLD On)

set(TOOLCHAIN_COMMON_FLAGS "-Wno-user-defined-literals -Wno-array-bounds -Wno-cast-function-type -Wno-uninitialized -fuse-ld=lld -Wno-misleading-indentation -Wno-global-constructors -Wno-unused-command-line-argument -fwasm-exceptions")
set(CMAKE_C_FLAGS ${TOOLCHAIN_COMMON_FLAGS})
set(CMAKE_CXX_FLAGS ${TOOLCHAIN_COMMON_FLAGS})

set(CMAKE_C_COMPILER_WORKS ON)
set(CMAKE_CXX_COMPILER_WORKS ON)

set(CMAKE_C_COMPILER clang)
set(CMAKE_C_COMPILER_TARGET ${TOOLCHAIN_TRIPLE})
set(CMAKE_ASM_COMPILER ${CMAKE_C_COMPILER})
set(CMAKE_ASM_COMPILER_TARGET ${TOOLCHAIN_TRIPLE})
set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_CXX_COMPILER_TARGET ${TOOLCHAIN_TRIPLE})
set(CMAKE_AR llvm-ar)
set(CMAKE_RANLIB llvm-ranlib)
set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

unset(linux)
unset(Linux)
unset(unix)
unset(UNIX)

set(HAVE_CXX_FLAG_WTHREAD_SAFETY Off)
set(HAVE_STEADY_CLOCK Off)

set(BENCHMARK_ENABLE_TESTING Off)

set(LLVM_OPTIMIZED_TABLEGEN On)
set(LLVM_INCLUDE_BENCHMARKS Off)
set(LLVM_ENABLE_PIC Off)
set(LLVM_ENABLE_ASSERTIONS Off)
set(LLVM_ENABLE_UNWIND_TABLES Off)
set(LLVM_INCLUDE_EXAMPLES Off)
set(LLVM_ENABLE_BACKTRACES Off)
set(LLVM_INCLUDE_TESTS Off)
set(LIBCXXABI_SILENT_TERMINATE On)
set(BUILD_SHARED_LIBS On)
set(HAS_WERROR_GLOBAL_CTORS Off)
set(LIBCXX_CXX_ABI libcxxabi)
set(LIBCXX_HAS_WIN32_THREAD_API Off)
set(LIBCXX_HAS_MUSL_LIBC On)
set(LIBCXX_HAS_PTHREAD_API Off)
set(LIBCXX_BUILD_EXTERNAL_THREAD_LIBRARY Off)
set(LIBCXXABI_HAS_WIN32_THREAD_API Off)
set(LIBCXXABI_HAS_MUSL_LIBC On)
set(LIBCXXABI_HAS_PTHREAD_API Off)
set(LIBCXXABI_BUILD_EXTERNAL_THREAD_LIBRARY Off)
set(LIBCXX_ENABLE_THREADS Off)
set(LIBCXXABI_ENABLE_EXCEPTIONS On)
set(LIBCXXABI_ENABLE_SHARED Off)
set(LIBCXX_BUILD_EXTERNAL_THREAD_LIBRARY Off)
set(LIBCXX_ENABLE_EXCEPTIONS On)
set(LIBCXX_ENABLE_RTTI On)
set(LIBCXXABI_ENABLE_RTTI On)
set(LIBCXX_INCLUDE_BENCHMARKS Off)
set(LIBCXXABI_ENABLE_THREADS Off)
set(LIBCXX_ENABLE_SHARED Off)
set(COMPILER_RT_DEFAULT_TARGET_ARCH ${CMAKE_SYSTEM_PROCESSOR})
set(COMPILER_RT_DEFAULT_TARGET_TRIPLE ${LLVM_HOST_TRIPLE})
set(COMPILER_RT_BAREMETAL_BUILD On)
set(LIBCXX_ENABLE_TIME_ZONE_DATABASE Off)

set(LIBUNWIND_ENABLE_SHARED Off)
set(LIBUNWIND_USE_COMPILER_RT On)

# libcxx
set(LLVM_ENABLE_RUNTIMES "libcxx;libcxxabi;libunwind")
set(COMPILER_RT_BUILD_LIBFUZZER Off)
set(LLVM_RUNTIME_TARGETS ${LLVM_HOST_TRIPLE})
set(WASI 1)
