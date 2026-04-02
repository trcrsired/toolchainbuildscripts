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

if ($env:TOOLCHAINS) {
    $TOOLCHAINS = $env:TOOLCHAINS
    Write-Host "TOOLCHAINS = $TOOLCHAINS"
} else {
    $TOOLCHAINS = Join-Path $env:USERPROFILE "toolchains"
    Write-Host "TOOLCHAINS not set - using default: $TOOLCHAINS"
}

if ($env:TOOLCHAINS_BUILD) {
    $TOOLCHAINS_BUILD = $env:TOOLCHAINS_BUILD
    Write-Host "TOOLCHAINS_BUILD = $TOOLCHAINS_BUILD"
} else {
    $TOOLCHAINS_BUILD = Join-Path $env:USERPROFILE "toolchains_build"
    Write-Host "TOOLCHAINS_BUILD not set - using default: $TOOLCHAINS_BUILD"
}

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

    git fetch origin
    git reset --hard origin/main

    git submodule update --init --recursive boost-math

    $cmakeFile = Join-Path $Path "CMakeLists.txt"
    if (Test-Path $cmakeFile) {
        $lines = Get-Content $cmakeFile -Encoding UTF8

        $output = New-Object System.Collections.Generic.List[string]
        $commenting = $false

        foreach ($line in $lines) {
            if (-not $commenting -and $line -match 'if\s*\(.*CMAKE_CXX_COMPILER_VERSION') {
                $commenting = $true
                $output.Add("# $line")
                continue
            }

            if ($commenting) {
                $output.Add("# $line")
                if ($line -match 'endif\s*\(\s*\)') {
                    $commenting = $false
                }
                continue
            }

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
} else {
    Write-Host "STL source not found - cloning from GitHub"
    New-Item -ItemType Directory -Force -Path $TOOLCHAINS_BUILD | Out-Null
    Push-Location $TOOLCHAINS_BUILD
    git clone https://github.com/microsoft/STL.git stl
    Pop-Location
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
        $hostCombos += $NATIVE_ARCH
    } else {
        $hostCombos += "${NATIVE_ARCH}_${target}"
    }
}

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

    $Vcvarsall_Q = '"' + $VcvarsallPath + '"'
    $StlDir_Q    = '"' + $StlDir + '"'
    $Sysroot_Q   = '"' + $Sysroot + '"'
    $buildDir_Q  = '"' + $buildDir + '"'

    $cmakeConfigure = "cmake -GNinja -S $StlDir_Q -B $buildDir_Q -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl -DBUILD_TESTING=Off -DCONFIGURE_TESTING=Off -DVCLIBS_SUFFIX= -DCMAKE_INSTALL_PREFIX=$Sysroot_Q"
    $cmakeBuild     = "ninja -C $buildDir_Q"

    $cmdLine = $Vcvarsall_Q + " " + $vcArg + " && " + $cmakeConfigure + " && " + $cmakeBuild

    cmd /c $cmdLine
}

# ============================================================
# 7. Build and install all discovered targets
# ============================================================

function Get-BuildOutputArch {
    param([string]$TargetArch)

    switch ($TargetArch) {
        "x86"   { return "i386" }
        "x64"   { return "amd64" }
        "arm64" { return "arm64" }
        default { throw "Unsupported TargetArch: $TargetArch" }
    }
}

$HeadersInstalled = $false
$ModulesInstalled = $false

foreach ($arch in $TARGET_ARCHES) {
    Invoke-Build -HostArch $NATIVE_ARCH `
                 -TargetArch $arch `
                 -VcvarsallPath $vcvarsall `
                 -StlDir $STL_DIR `
                 -Sysroot $WINDOWSMSVCSYSROOT

    Write-Host "=== Installing for target $arch ==="

    $buildDir = ".artifacts/stl/$arch"

    switch ($arch) {
        "x86"   { $msvcLibDir = "i686-unknown-windows-msvc" }
        "x64"   { $msvcLibDir = "x86_64-unknown-windows-msvc" }
        "arm64" { $msvcLibDir = "aarch64-unknown-windows-msvc" }
        default { throw "Unsupported TargetArch: $arch" }
    }

    if (-not $HeadersInstalled) {
        $incSrc = Join-Path $buildDir "out\inc"
        $incDst = Join-Path $WINDOWSMSVCSYSROOT "include\c++\msstl"

        if (Test-Path $incDst) {
            Write-Host "Removing old msstl headers"
            Remove-Item $incDst -Recurse -Force
        }

        Write-Host "Installing headers to $incDst"
        New-Item -ItemType Directory -Force -Path $incDst | Out-Null
        Copy-Item "$incSrc\*" $incDst -Recurse -Force

        $HeadersInstalled = $true
    }

    $buildOutArch = Get-BuildOutputArch $arch
    $libSrc = Join-Path $buildDir "out\lib\$buildOutArch"
    $libDst = Join-Path $WINDOWSMSVCSYSROOT "lib\$msvcLibDir"

    Write-Host "Copying libraries to $libDst"
    New-Item -ItemType Directory -Force -Path $libDst | Out-Null
    Copy-Item "$libSrc\*" $libDst -Recurse -Force

    if (-not $ModulesInstalled) {
        $modulesJson = Join-Path $buildDir "modules.json"
        if (Test-Path $modulesJson) {
            Write-Host "Rewriting modules.json (.ixx → .cppm)"
            $json = Get-Content $modulesJson -Raw
            $json = $json -replace '\.ixx"', '.cppm"'
            Set-Content -Path $modulesJson -Value $json -Encoding UTF8
        }

        $modulesDir = Join-Path $buildDir "out\modules"
        if (Test-Path $modulesDir) {
            Write-Host "Renaming module files (.ixx -> .cppm)"
            Get-ChildItem $modulesDir -Filter *.ixx | ForEach-Object {
                $new = $_.FullName -replace '\.ixx$', '.cppm'

                if (Test-Path $new) {
                    Write-Host "Skipping rename: $new already exists"
                    return
                }

                # Try rename
                Rename-Item $old $new -Force -ErrorAction SilentlyContinue

                # If rename failed but .cppm exists, delete .ixx
                if (Test-Path $old -and Test-Path $new) {
                    Remove-Item $old -Force -ErrorAction SilentlyContinue
                }
            }
        }

        $modulesDst = Join-Path $WINDOWSMSVCSYSROOT "share\msstl"
        Write-Host "Copying modules to $modulesDst"
        New-Item -ItemType Directory -Force -Path $modulesDst | Out-Null
        if (Test-Path $modulesDir) {
            Copy-Item "$modulesDir\*" $modulesDst -Recurse -Force
        }
        if (Test-Path $modulesJson) {
            Copy-Item $modulesJson $modulesDst -Force
        }
    }
}

Write-Host "All builds completed successfully."
