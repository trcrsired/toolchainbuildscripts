param(
    [switch]$Restart
)

$ErrorActionPreference = "Stop"

# ============================================================
# 0. Restart option: delete .artifacts
# ============================================================

if ($Restart) {
    if (Test-Path ".artifacts") {
        Write-Host "Restart requested - deleting .artifacts directory"
        Remove-Item ".artifacts" -Recurse -Force
    } else {
        Write-Host "Restart requested - no .artifacts directory to delete"
    }
}

# ============================================================
# 1. Environment variables
# ============================================================

# TOOLCHAINS: optional, with fallback
if ($env:TOOLCHAINS) {
    $TOOLCHAINS = $env:TOOLCHAINS
    Write-Host "TOOLCHAINS = $TOOLCHAINS"
} else {
    $TOOLCHAINS = Join-Path $env:USERPROFILE "toolchains"
    Write-Host "TOOLCHAINS not set - using default: $TOOLCHAINS"
}

# TOOLCHAINS_BUILD: optional, with fallback
if ($env:TOOLCHAINS_BUILD) {
    $TOOLCHAINS_BUILD = $env:TOOLCHAINS_BUILD
    Write-Host "TOOLCHAINS_BUILD = $TOOLCHAINS_BUILD"
} else {
    $TOOLCHAINS_BUILD = Join-Path $env:USERPROFILE "toolchains_build"
    Write-Host "TOOLCHAINS_BUILD not set - using default: $TOOLCHAINS_BUILD"
}

# WINDOWSMSVCSYSROOT: optional, with fallback
if ($env:WINDOWSMSVCSYSROOT) {
    $WINDOWSMSVCSYSROOT = $env:WINDOWSMSVCSYSROOT
    Write-Host "WINDOWSMSVCSYSROOT = $WINDOWSMSVCSYSROOT"
} else {
    $WINDOWSMSVCSYSROOT = Join-Path $TOOLCHAINS "windows-msvc-sysroot"
    Write-Host "WINDOWSMSVCSYSROOT not set - using default: $WINDOWSMSVCSYSROOT"
}

# ============================================================
# 2. Detect host architecture
# ============================================================

$cpuArch = (Get-CimInstance Win32_Processor).Architecture
$NATIVE_ARCH = switch ($cpuArch) {
    0  { "x86" }
    9  { "x64" }
    12 { "arm64" }
    default { throw "Unsupported Win32_Processor Architecture: $cpuArch" }
}

Write-Host "Detected host architecture: $NATIVE_ARCH"

# ============================================================
# 3. Ensure STL source (pull or clone, then patch)
# ============================================================

$STL_DIR = Join-Path $TOOLCHAINS_BUILD "stl"

function Update-STL {
    param([string]$Path)

    Push-Location $Path

    # Ensure clean state
    git fetch origin
    git reset --hard origin/main

    # Update submodules
    git submodule update --init --recursive boost-math

# Patch CMakeLists.txt to comment out MSVC version checks
$cmakeFile = Join-Path $Path "CMakeLists.txt"
if (Test-Path $cmakeFile) {
    # Read file as lines, preserving CRLF
    $lines = Get-Content $cmakeFile -Encoding UTF8

    $output = New-Object System.Collections.Generic.List[string]
    $commenting = $false

    foreach ($line in $lines) {

        # Detect start of version check
        if (-not $commenting -and $line -match 'if\s*\(.*CMAKE_CXX_COMPILER_VERSION') {
            $commenting = $true
            $output.Add("# $line")
            continue
        }

        # Comment until endif()
        if ($commenting) {
            $output.Add("# $line")
            if ($line -match 'endif\s*\(\s*\)') {
                $commenting = $false
            }
            continue
        }

        # Normal line
        $output.Add($line)
    }

    Write-Host "Commenting out MSVC version check block in CMakeLists.txt"
    [System.IO.File]::WriteAllLines($cmakeFile, $output, [System.Text.Encoding]::UTF8)
}

    Pop-Location
}

if (Test-Path $STL_DIR) {
    Write-Host "STL source found at $STL_DIR - updating"
    Update-STL -Path $STL_DIR
}
else {
    Write-Host "STL source not found - cloning from GitHub"

    Push-Location $TOOLCHAINS_BUILD
    git clone https://github.com/microsoft/STL.git stl
    Pop-Location

    # Apply the same processing to the fresh clone
    Update-STL -Path $STL_DIR
}

# ============================================================
# 4. Locate latest Visual Studio
# ============================================================

$vsBase = "C:\Program Files\Microsoft Visual Studio"
if (-not (Test-Path $vsBase)) {
    throw "ERROR: Visual Studio base directory not found at $vsBase"
}

$vsVersions = Get-ChildItem $vsBase -Directory |
    Where-Object { $_.Name -match '^\d+(\.\d+)?$' } |
    Sort-Object { [int]($_.Name.Split('.')[0]) } -Descending

$vsRoot = $null
$vcvarsall = $null

foreach ($ver in $vsVersions) {
    $editions = Get-ChildItem $ver.FullName -Directory |
        Sort-Object { if ($_.Name -match "Insiders") { 0 } else { 1 } }

    foreach ($ed in $editions) {
        $candidate = Join-Path $ed.FullName "VC\Auxiliary\Build\vcvarsall.bat"
        if (Test-Path $candidate) {
            $vsRoot = $ed.FullName
            $vcvarsall = $candidate
            break
        }
    }

    if ($vsRoot) { break }
}

if (-not $vcvarsall) {
    throw "ERROR: No Visual Studio installation with vcvarsall.bat found."
}

Write-Host "Using Visual Studio installation: $vsRoot"
Write-Host "vcvarsall.bat: $vcvarsall"

# ============================================================
# 5. Auto-generate valid host/target combos
# ============================================================

$ARCHES = @("x86", "x64", "arm64")

if ($ARCHES -notcontains $NATIVE_ARCH) {
    throw "ERROR: Unsupported host architecture: $NATIVE_ARCH"
}

$hostCombos = @()

foreach ($target in $ARCHES) {
    if ($target -eq $NATIVE_ARCH) {
        # native build
        $hostCombos += $NATIVE_ARCH
    } else {
        # cross build
        $hostCombos += "${NATIVE_ARCH}_${target}"
    }
}

# Extract target architectures cleanly
$TARGET_ARCHES = $hostCombos |
    ForEach-Object {
        if ($_ -eq $NATIVE_ARCH) { $NATIVE_ARCH }
        else { $_.Split("_")[1] }
    } |
    Sort-Object -Unique

Write-Host "Targets for host ${NATIVE_ARCH}:"
$TARGET_ARCHES | ForEach-Object { Write-Host " - $_" }

# ============================================================
# 6. Build function
# ============================================================

function Invoke-Build {
    param(
        [string]$HostArch,
        [string]$TargetArch,
        [string]$VcvarsallPath,
        [string]$StlDir,
        [string]$Sysroot
    )

    $buildDir = ".artifacts/stl/$TargetArch"
    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

    Write-Host "=== Building for target $TargetArch on host $HostArch ==="

    if ($TargetArch -eq $HostArch) {
        $vcArg = $HostArch
    } else {
        $vcArg = "${HostArch}_${TargetArch}"
    }

    # Quote paths for cmd.exe
    $Vcvarsall_Q = '"' + $VcvarsallPath + '"'
    $StlDir_Q    = '"' + $StlDir + '"'
    $Sysroot_Q   = '"' + $Sysroot + '"'
    $buildDir_Q  = '"' + $buildDir + '"'

    # Build commands
    $cmakeConfigure = "cmake -GNinja -S $StlDir_Q -B $buildDir_Q -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl -DBUILD_TESTING=Off -DCONFIGURE_TESTING=Off -DVCLIBS_SUFFIX= -DCMAKE_INSTALL_PREFIX=$Sysroot_Q"
    $cmakeBuild     = "ninja -C $buildDir_Q"

    # Build final cmd.exe chain
    $cmdLine = $Vcvarsall_Q + " " + $vcArg + " && " + $cmakeConfigure + " && " + $cmakeBuild

    cmd /c $cmdLine
}

# ============================================================
# 7. Build all discovered targets
# ============================================================

foreach ($arch in $TARGET_ARCHES) {
    Invoke-Build -HostArch $NATIVE_ARCH `
                 -TargetArch $arch `
                 -VcvarsallPath $vcvarsall `
                 -StlDir $STL_DIR `
                 -Sysroot $WINDOWSMSVCSYSROOT
}

Write-Host "All builds completed successfully."
