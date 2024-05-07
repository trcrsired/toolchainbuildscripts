cmake_minimum_required(VERSION 3.15)

set(CMAKE_BUILD_TYPE Release)
set(CMAKE_HOST_SYSTEM_NAME "Windows")
set(TOOLCHAIN_TRIPLE x86_64-w64-mingw32)
set(LLVM_HOST_TRIPLE x86_64-windows-gnu)
set(LLVM_DEFAULT_TARGET_TRIPLE ${LLVM_HOST_TRIPLE})

execute_process(
  COMMAND which ${TOOLCHAIN_TRIPLE}-gcc
  OUTPUT_VARIABLE BINUTILS_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

get_filename_component(TOOLCHAIN_BIN ${BINUTILS_PATH} DIRECTORY)

set(CMAKE_SYSROOT ${TOOLCHAIN_BIN}/..)

execute_process(
  COMMAND which clang
  OUTPUT_VARIABLE CLANGBIN_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
get_filename_component(LLVM_NATIVE_TOOL_DIR_PATH ${CLANGBIN_PATH} DIRECTORY)

set(LLVM_NATIVE_TOOL_DIR ${LLVM_NATIVE_TOOL_DIR_PATH})


set(TOOLCHAIN_COMMON_FLAGS "-Wno-array-bounds -Wno-cast-function-type -Wno-uninitialized -Wno-cast-function-type")
set(CMAKE_C_FLAGS ${TOOLCHAIN_COMMON_FLAGS})
set(CMAKE_CXX_FLAGS ${TOOLCHAIN_COMMON_FLAGS})

set(CMAKE_C_COMPILER clang)
set(CMAKE_C_COMPILER_TARGET ${LLVM_DEFAULT_TARGET_TRIPLE})
set(CMAKE_ASM_COMPILER ${CMAKE_C_COMPILER})
set(CMAKE_ASM_COMPILER_TARGET ${LLVM_DEFAULT_TARGET_TRIPLE})
set(CMAKE_CXX_COMPILER /clang++)
set(CMAKE_CXX_COMPILER_TARGET ${LLVM_DEFAULT_TARGET_TRIPLE})
set(CMAKE_AR /llvm-ar)
set(CMAKE_RANLIB /llvm-ranlib)

set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(ZLIB_LIBRARY ${CMAKE_SYSROOT}/${TOOLCHAIN_TRIPLE}/lib/libzlibstatic.a)
set(ZLIB_INCLUDE_DIR ${CMAKE_SYSROOT}/${TOOLCHAIN_TRIPLE}/include)

unset(linux)
unset(unix)
unset(Linux)
unset(Unix)
set(MINGW 1)
set(WIN32 1)

set(LLVM_ENABLE_PROJECTS "clang;lld;clang-tools-extra;lldb;mlir")

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

set(BUILD_SHARED_LIBS On)

set(LLVM_ENABLE_RUNTIMES "")

execute_process(
  COMMAND which llvm-tblgen
  OUTPUT_VARIABLE LLVM_TABLEGEN_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(LLVM_TABLEGEN ${LLVM_TABLEGEN_PATH})

execute_process(
  COMMAND which clang-tblgen
  OUTPUT_VARIABLE CLANG_TABLEGEN_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(CLANG_TABLEGEN ${CLANG_TABLEGEN_PATH})

execute_process(
  COMMAND which clang-pseudo-gen
  OUTPUT_VARIABLE CLANG_PSEUDO_GEN_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(CLANG_PSEUDO_GEN ${CLANG_PSEUDO_GEN_PATH})

execute_process(
  COMMAND which llvm-profgen
  OUTPUT_VARIABLE LLVM_PROFGEN_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(LLVM_PROFGEN ${LLVM_PROFGEN_PATH})

execute_process(
  COMMAND which lldb-tblgen
  OUTPUT_VARIABLE LLDB_TBLGEN_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(LLDB_TABLEGEN_EXE ${LLDB_TBLGEN_PATH})

execute_process(
  COMMAND which mlir-tblgen
  OUTPUT_VARIABLE MLIR_TBLGEN_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(MLIR_TABLEGEN ${MLIR_TBLGEN_PATH})

execute_process(
  COMMAND which clang-ast-dump
  OUTPUT_VARIABLE CLANG_AST_DUMP_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(CLANG_AST_DUMP ${CLANG_AST_DUMP_PATH})

execute_process(
  COMMAND which clang-tidy-confusable-chars-gen
  OUTPUT_VARIABLE CLANG_TIDY_CONFUSABLE_CHARS_GEN_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(CLANG_TIDY_CONFUSABLE_CHARS_GEN ${CLANG_TIDY_CONFUSABLE_CHARS_GEN_PATH})
set(clang_tidy_confusable_chars_gen ${CLANG_TIDY_CONFUSABLE_CHARS_GEN})
set(LLVM_ENABLE_LIBCXX On)
set(HAVE_CXX_ATOMICS64_WITHOUT_LIB On)
set(HAVE_CXX_ATOMICS_WITHOUT_LIB On)
set(LLDB_INCLUDE_TESTS Off)