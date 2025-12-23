# Please run the following command to allow the script to run:
# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Replace backslashes with forward slashes
function Convert-PathToDoubleBackslashes {
    param (
        [string]$path
    )
    return $path
}

if (-not $env:HOME) {
    $env:HOME = $env:USERPROFILE
}

# Check if TOOLCHAINSPATH environment variable is set, otherwise use $HOME/toolchains
if (-not $env:TOOLCHAINSPATH) {
    $TOOLCHAINSPATH = "$env:HOME/toolchains"
}
else {
    $TOOLCHAINSPATH = "$env:TOOLCHAINSPATH"
}

# Check if TOOLCHAINSPATH_LLVM environment variable is set, otherwise use $TOOLCHAINSPATH/llvm
if (-not $env:TOOLCHAINSPATH_LLVM) {
    $TOOLCHAINSPATH_LLVM = "$TOOLCHAINSPATH/llvm"
}
else {
    $TOOLCHAINSPATH_LLVM = "$env:TOOLCHAINSPATH_LLVM"
}

if (-not $env:LIBRARIESPATH) {
    $LIBRARIESPATH = "$env:HOME/libraries"
}
else {
    $LIBRARIESPATH = "$env:LIBRARIESPATH"
}

if (-not $env:CFGS) {
    $CFGS = "$env:HOME/cfgs"
}
else {
    $CFGS = "$env:CFGS"
}

# Create necessary directories
if (-not (Test-Path -Path $TOOLCHAINSPATH_LLVM)) {
    New-Item -ItemType Directory -Force -Path $TOOLCHAINSPATH_LLVM
}
if (-not (Test-Path -Path "$CFGS/c")) {
    New-Item -ItemType Directory -Force -Path "$CFGS/c"
}
if (-not (Test-Path -Path $LIBRARIESPATH)) {
    New-Item -ItemType Directory -Force -Path $LIBRARIESPATH
}

function ConvertToUnixPath {
    param (
        [string]$path
    )
    return $path -replace '\\', '/'
}
# Absolute paths
$ABS_TOOLCHAINSPATH = [System.IO.Path]::GetFullPath($TOOLCHAINSPATH)
$ABS_TOOLCHAINSPATH_LLVM = [System.IO.Path]::GetFullPath($TOOLCHAINSPATH_LLVM)
$ABS_LIBRARIES = [System.IO.Path]::GetFullPath($LIBRARIESPATH)

$ABS_TOOLCHAINSPATH = ConvertToUnixPath $ABS_TOOLCHAINSPATH
$ABS_TOOLCHAINSPATH_LLVM = ConvertToUnixPath $ABS_TOOLCHAINSPATH_LLVM
$ABS_LIBRARIES = ConvertToUnixPath $ABS_LIBRARIES

# Function to create a config file for C and C++
function Create-CfgFile {
    param (
        [string]$cfgName,
        [string]$target,
        [string]$sysroot,
        [string]$standardFlagsC,
        [string]$standardFlagsCpp,
        [string]$extraFlags
    )

    # C config
    $cConfig = @"
-std=c23 --target=$target --sysroot=$sysroot $standardFlagsC $extraFlags -I$ABS_LIBRARIES/fast_io/include
"@
    Set-Content -Path "$CFGS/c/$cfgName" -Value $cConfig

    # C++ config
    $cppConfig = @"
-std=c++26 -fuse-ld=lld --target=$target --sysroot=$sysroot $standardFlagsCpp $extraFlags -I$ABS_LIBRARIES/fast_io/include
"@
    Set-Content -Path "$CFGS/$cfgName" -Value $cppConfig
}

# Standard flags for C
$STANDARD_FLAGS_C = "-rtlib=compiler-rt --unwindlib=libunwind"

# Standard flags for C++ without libunwind
$STANDARD_FLAGS_CPP_NOLIBUNWIND = "-rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -lc++abi"

# Standard flags for C++
$STANDARD_FLAGS_CPP = "$STANDARD_FLAGS_CPP_NOLIBUNWIND -lunwind"

# Flags for Darwin
$FLAGS_DARWIN = "-fuse-lipo=llvm-lipo -arch x86_64 -arch arm64"

# Create .cfg files for different triples
Create-CfgFile "x86_64-windows-gnu-libcxx.cfg" "x86_64-windows-gnu" "$ABS_TOOLCHAINSPATH_LLVM/x86_64-windows-gnu/x86_64-windows-gnu" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP "-lntdll"
Create-CfgFile "aarch64-windows-gnu-libcxx.cfg" "aarch64-windows-gnu" "$ABS_TOOLCHAINSPATH_LLVM/aarch64-windows-gnu/aarch64-windows-gnu" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP "-lntdll"
Create-CfgFile "x86_64-linux-gnu-libcxx.cfg" "x86_64-linux-gnu" "$ABS_TOOLCHAINSPATH_LLVM/x86_64-linux-gnu/x86_64-linux-gnu" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP ""
Create-CfgFile "aarch64-linux-gnu-libcxx.cfg" "aarch64-linux-gnu" "$ABS_TOOLCHAINSPATH_LLVM/aarch64-linux-gnu/aarch64-linux-gnu" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP ""
Create-CfgFile "aarch64-linux-android30-libcxx.cfg" "aarch64-linux-android30" "$ABS_TOOLCHAINSPATH_LLVM/aarch64-linux-android30/aarch64-linux-android30" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP ""
Create-CfgFile "x86_64-linux-android30-libcxx.cfg" "x86_64-linux-android30" "$ABS_TOOLCHAINSPATH_LLVM/x86_64-linux-android30/x86_64-linux-android30" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP ""
Create-CfgFile "loongarch64-linux-gnu-libcxx.cfg" "loongarch64-linux-gnu" "$ABS_TOOLCHAINSPATH_LLVM/loongarch64-linux-gnu/loongarch64-linux-gnu" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP ""
Create-CfgFile "riscv64-linux-gnu-libcxx.cfg" "riscv64-linux-gnu" "$ABS_TOOLCHAINSPATH_LLVM/riscv64-linux-gnu/riscv64-linux-gnu" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP ""

Create-CfgFile "aarch64-apple-darwin24.cfg" "aarch64-apple-darwin24" "$ABS_TOOLCHAINSPATH_LLVM/aarch64-apple-darwin24/aarch64-apple-darwin24" "" "" $FLAGS_DARWIN

# Create wasm .cfg files
Create-CfgFile "wasm64-wasip1.cfg" "wasm64-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-memtag-sysroot/wasm64-wasip1" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP "-fsanitize=memtag -fwasm-exceptions"
Create-CfgFile "wasm32-wasip1.cfg" "wasm32-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-memtag-sysroot/wasm32-wasip1" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP "-fsanitize=memtag -fwasm-exceptions"
Create-CfgFile "wasm64-wasip1-noeh.cfg" "wasm64-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-noeh-memtag-sysroot/wasm64-wasip1" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP_NOLIBUNWIND "-fsanitize=memtag -fno-exceptions"
Create-CfgFile "wasm32-wasip1-noeh.cfg" "wasm32-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-noeh-memtag-sysroot/wasm32-wasip1" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP_NOLIBUNWIND "-fsanitize=memtag -fno-exceptions"
Create-CfgFile "wasm64-wasip1-nomtg.cfg" "wasm64-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-memtag-sysroot/wasm64-wasip1" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP "-fwasm-exceptions"
Create-CfgFile "wasm32-wasip1-nomtg.cfg" "wasm32-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-memtag-sysroot/wasm32-wasip1" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP "-fwasm-exceptions"
Create-CfgFile "wasm64-wasip1-noeh-nomtg.cfg" "wasm64-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-noeh-memtag-sysroot/wasm64-wasip1" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP_NOLIBUNWIND "-fno-exceptions"
Create-CfgFile "wasm32-wasip1-noeh-nomtg.cfg" "wasm32-wasip1" "$ABS_TOOLCHAINSPATH_LLVM/wasm-sysroots/wasm-noeh-memtag-sysroot/wasm32-wasip1" $STANDARD_FLAGS_C $STANDARD_FLAGS_CPP_NOLIBUNWIND "-fno-exceptions"

# Create msvc .cfg files
Create-CfgFile "x86_64-windows-msvc.cfg" "x86_64-windows-msvc" "$ABS_TOOLCHAINSPATH/windows-msvc-sysroot" "" "" "-D_DLL=1 -lmsvcrt"
Create-CfgFile "aarch64-windows-msvc.cfg" "aarch64-windows-msvc" "$ABS_TOOLCHAINSPATH/windows-msvc-sysroot" "" "" "-D_DLL=1 -lmsvcrt"
Create-CfgFile "i686-windows-msvc.cfg" "i686-windows-msvc" "$ABS_TOOLCHAINSPATH/windows-msvc-sysroot" "" "" "-D_DLL=1 -lmsvcrt"

# Create msvc .cfg files with libcxx
Create-CfgFile "x86_64-windows-msvc-libcxx.cfg" "x86_64-windows-msvc" "$ABS_TOOLCHAINSPATH/windows-msvc-sysroot" "" "" "-D_DLL=1 -lmsvcrt -stdlib=libc++"
Create-CfgFile "aarch64-windows-msvc-libcxx.cfg" "aarch64-windows-msvc" "$ABS_TOOLCHAINSPATH/windows-msvc-sysroot" "" "" "-D_DLL=1 -lmsvcrt -stdlib=libc++"
Create-CfgFile "i686-windows-msvc-libcxx.cfg" "i686-windows-msvc" "$ABS_TOOLCHAINSPATH/windows-msvc-sysroot" "" "" "-D_DLL=1 -lmsvcrt -stdlib=libc++"

# --- FAST_IO ---
if ($Env:CLONE_FAST_IO -eq "yes") {

    $fastIoPath = Join-Path $LIBRARIES "fast_io"

    if (-not (Test-Path $fastIoPath)) {
        git clone --branch next https://github.com/cppfastio/fast_io.git $fastIoPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "fast_io clone failure"
            exit 1
        }
    }

    Set-Location $fastIoPath
    git pull --quiet
}

# --- WINDOWS MSVC SYSROOT ---
if ($Env:CLONE_WINDOWS_MSVC_SYSROOT -eq "yes") {

    $sysrootPath = Join-Path $TOOLCHAINSPATH "windows-msvc-sysroot"

    if (-not (Test-Path $sysrootPath)) {
        git clone https://github.com/trcrsired/windows-msvc-sysroot.git $sysrootPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "windows-msvc-sysroot clone failure"
            exit 1
        }
    }

    Set-Location $sysrootPath
    git pull --quiet --rebase
}

Write-Host "Configuration files and repository setup completed successfully."
