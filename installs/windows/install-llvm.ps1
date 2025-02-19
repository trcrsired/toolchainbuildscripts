param (
    [string]$DOWNLOADALL = "no",
    [string]$NOINSTALLING = "no"
)

# Please run the following command to allow the script to run:
# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Check if the script is running with administrator privileges
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ((-not (Test-Admin)) -and ($NOINSTALLING -ne "yes")) {
    Write-Host "Please run this script as an administrator."
    exit 1
}

# Check if TOOLCHAINSPATH environment variable is set, otherwise use $HOME/toolchains
if (-not $env:TOOLCHAINSPATH) {
    $env:TOOLCHAINSPATH = "$HOME\toolchains"
}

# Create necessary directories
if (-not (Test-Path -Path $env:TOOLCHAINSPATH)) {
    New-Item -ItemType Directory -Force -Path $env:TOOLCHAINSPATH
}

# Check if TOOLCHAINSPATH_LLVM environment variable is set, otherwise use $TOOLCHAINSPATH/llvm
if (-not $env:TOOLCHAINSPATH_LLVM) {
    $env:TOOLCHAINSPATH_LLVM = "$env:TOOLCHAINSPATH\llvm"
}

# Create necessary directories
if (-not (Test-Path -Path $env:TOOLCHAINSPATH_LLVM)) {
    New-Item -ItemType Directory -Force -Path $env:TOOLCHAINSPATH_LLVM
}

# Determine ARCH and TRIPLE from PROCESSOR_ARCHITECTURE if Windows
if ($env:OS -eq "Windows_NT") {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        "AMD64" {
            $ARCH = "x86_64"
            $TRIPLE = "x86_64-windows-gnu"
        }
        "ARM64" {
            $ARCH = "aarch64"
            $TRIPLE = "aarch64-windows-gnu"
        }
        "LOONG64" {
            $ARCH = "loongarch64"
            $TRIPLE = "loongarch64-windows-gnu"
        }
        Default {
            $ARCH = $env:PROCESSOR_ARCHITECTURE.ToLower()
            $TRIPLE = "$ARCH-windows-gnu"
        }
    }
} else {
    # Determine TRIPLE if not set
    if (-not $TRIPLE) {
        $uname = (uname -a)
        if ($uname -match "Linux") {
            if ($env:ANDROID_ROOT) {
                if ($uname -match "aarch64") {
                    $TRIPLE = "aarch64-linux-android30"
                } elseif ($uname -match "x86_64") {
                    $TRIPLE = "x86_64-linux-android30"
                }
            } else {
                if ($uname -match "x86_64") {
                    $TRIPLE = "x86_64-linux-gnu"
                } elseif ($uname -match "aarch64") {
                    $TRIPLE = "aarch64-linux-gnu"
                }
            }
        } elseif ($uname -match "Darwin") {
            $ISDARWIN = $true
            $machineArch = (uname -m)
            if ($machineArch -eq "arm64") {
                $machineArch = "aarch64"
            }
            $TRIPLE = "$machineArch-apple-darwin24"
        }
    }

    # Remove 'pc' or 'unknown' from TRIPLE if present
    $parts = $TRIPLE.Split('-')
    if ($parts.Length -eq 4 -and ($parts[1] -eq "pc" -or $parts[1] -eq "unknown")) {
        $TRIPLE = "$($parts[0])-$($parts[2])-$($parts[3])"
    }

    # Extract ARCH from TRIPLE
    $ARCH = $TRIPLE.Split('-')[0]
}

if ($NOINSTALLING -ne "yes") {
    # Get the latest release version if not set
    if (-not $env:NODOWNLOADLLVM) {
        if (-not $env:RELEASE_VERSION) {
            if (Get-Command git -ErrorAction SilentlyContinue) {
                $RELEASE_VERSION = git ls-remote --tags https://github.com/trcrsired/llvm-releases.git |
                    Select-String -Pattern "refs/tags/llvm[0-9]+(\-[0-9]+)*$" |
                    Sort-Object { $_.Matches[0].Groups[0].Value } -Descending |
                    Select-Object -First 1 |
                    ForEach-Object { $_.ToString().Split("/")[-1] }
                if (-not $RELEASE_VERSION) {
                    Write-Host "Failed to retrieve the latest release version. Please check your network connection or set the RELEASE_VERSION environment variable."
                    exit 1
                }
            } else {
                Write-Host "Git is not installed. Please install it or set the RELEASE_VERSION environment variable."
                exit 1
            }
        }

        $BASE_URL = "https://github.com/trcrsired/llvm-releases/releases/download/$RELEASE_VERSION"
    }


    Write-Host "Latest LLVM release version: $RELEASE_VERSION"

    # Determine the list of files to download
    $FILES = @()
    if ($DOWNLOADALL -eq "yes") {
        $FILES = @(
            "aarch64-apple-darwin24",
            "aarch64-windows-gnu",
            "aarch64-linux-gnu",
            "aarch64-linux-android30",
            "x86_64-windows-gnu",
            "x86_64-linux-gnu",
            "x86_64-linux-android30",
            "loongarch64-linux-gnu",
            "riscv64-linux-gnu",
            "wasm-sysroots"
        )
    } else {
        if (-not $TRIPLE) {
            Write-Host "Could not determine TRIPLE. Please set the TRIPLE environment variable."
            exit 1
        }
        $FILES += "$ARCH-windows-gnu"
        if ($TRIPLE -ne "$ARCH-windows-gnu") {
            $FILES += $TRIPLE
        }
        $FILES += "wasm-sysroots"
    }

    # Download files using PowerShell
    function Download-File {
        param (
            [string]$url,
            [string]$dest
        )

        (New-Object System.Net.WebClient).DownloadFile($url, $dest)
    }

    # Download and extract files
    foreach ($file in $FILES) {
        $destPath = Join-Path -Path $env:TOOLCHAINSPATH_LLVM -ChildPath "$file.tar.xz"
        Remove-Item -Path $destPath -Force -ErrorAction SilentlyContinue
        Write-Host "Downloading $file.tar.xz to $env:TOOLCHAINSPATH_LLVM"
        Download-File -url "$BASE_URL/$file.tar.xz" -dest $destPath
    }

    Write-Host "Downloads completed successfully to $env:TOOLCHAINSPATH_LLVM"

    # Check if Windows Defender real-time protection is enabled
    function Check-DefenderRealtimeProtection {
        try {
            $defenderStatus = Get-MpPreference | Select-Object -ExpandProperty RealtimeProtectionEnabled
            return [bool]$defenderStatus
        } catch {
            return $false
        }
    }

    # Extract and clean up tar.xz files
    function Extract-TarFile {
        param (
            [string]$tarFile,
            [string]$destination,
            [bool]$isDefenderEnabled
        )

        $errorOccured = $false

        try {
            if ($isDefenderEnabled) {
                # Add the destination path to the exclusion list
                Add-MpPreference -ExclusionPath $destination
            }

            # Try using tar
            if (Get-Command tar -ErrorAction SilentlyContinue) {
                & { $env:XZ_OPT = '-T0'; tar -xf $tarFile -C $destination }
            }
            # Try using 7z if tar is not available
            elseif (Get-Command 7z -ErrorAction SilentlyContinue) {
                7z x $tarFile -o$destination
            } 
            else {
                Write-Host "Neither tar nor 7z is available to extract files. Please install one of them and try again."
                $errorOccured = $true
            }
        } catch {
            $errorOccured = $true
            throw $_
        } finally {
            if ($isDefenderEnabled) {
                # Remove the destination path from the exclusion list
                Remove-MpPreference -ExclusionPath $destination -ErrorAction SilentlyContinue
            }
        }

        if ($errorOccured) {
            exit 1
        } else {
            return $true
        }
    }

    # Ensure the script execution policy allows running the script
    # Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

    # Check Windows Defender real-time protection status once
    $isDefenderEnabled = Check-DefenderRealtimeProtection

    Get-ChildItem -Path "$env:TOOLCHAINSPATH_LLVM" -Filter *.tar.xz | ForEach-Object {
        $tarFile = $_.FullName
        $tarDir = [System.IO.Path]::ChangeExtension($tarFile, $null)

        # Skip if no tar.xz files found
        if (-not (Test-Path -Path $tarFile)) {
            return
        }

        # Extract tar.xz file
        if (Test-Path -Path $tarDir) {
            Write-Host "Removing existing directory $tarDir"
            Remove-Item -Recurse -Force -Path $tarDir
        }

        Write-Host "Extracting $tarFile to $env:TOOLCHAINSPATH_LLVM"
        Extract-TarFile -tarFile $tarFile -destination $env:TOOLCHAINSPATH_LLVM -isDefenderEnabled $isDefenderEnabled
    }

    # Copy files from TOOLCHAINSPATH_LLVM subdirectories containing 'compiler-rt' or 'builtins' to destination directories
    Get-ChildItem -Path "$env:TOOLCHAINSPATH_LLVM/*/llvm/lib/clang/*" -Directory | ForEach-Object {
        $llvmDir = $_.FullName

        Get-ChildItem -Path "$env:TOOLCHAINSPATH_LLVM/*" -Directory | ForEach-Object {
            $dir = $_.FullName

            if (Test-Path -Path "$dir/compiler-rt") {
                Write-Host "Copying files from $dir/compiler-rt/ to $llvmDir/"
                Copy-Item -Path "$dir/compiler-rt/*" -Destination $llvmDir -Recurse -Force
            } elseif (Test-Path -Path "$dir/builtins") {
                Write-Host "Copying files from $dir/builtins/ to $llvmDir/"
                Copy-Item -Path "$dir/builtins/*" -Destination $llvmDir -Recurse -Force
            }
        }
    }

    Write-Host "Files copied successfully to subdirectories of $env:TOOLCHAINSPATH_LLVM containing llvm/lib/clang/{version}/"

    # Check if WAVM_RELEASE_VERSION is not set
    if (-not $env:WAVM_RELEASE_VERSION) {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            # Fetch tags
            $tagsOutput = git ls-remote --tags https://github.com/trcrsired/wavm-release.git
            
            # Split the output into lines and process the tags
            $tags = $tagsOutput -split "`n" | ForEach-Object { $_ -replace '.*refs/tags/', '' }
            
            # Get the last tag
            $WAVM_RELEASE_VERSION = ($tags | Select-Object -Last 1).Trim()

            if (-not $WAVM_RELEASE_VERSION) {
                Write-Host "Failed to retrieve the latest release version. Please check your network connection or set the RELEASE_VERSION environment variable."
                exit 1
            }
        } else {
            Write-Host "Git is not installed. Please install it or set the RELEASE_VERSION environment variable."
            exit 1
        }
    }
    else
    {
        $WAVM_RELEASE_VERSION = "$env:WAVM_RELEASE_VERSION"
    }

    Write-Host "Latest WAVM release version: $WAVM_RELEASE_VERSION"


    $WAVM_URL = "https://github.com/trcrsired/wavm-release/releases/download/$WAVM_RELEASE_VERSION"
}

# Ensure SOFTWARESPATH is set
if (-not $env:SOFTWARESPATH)
{
    $SOFTWARESPATH = "$HOME\softwares"
}
else
{
    $SOFTWARESPATH = "$env:SOFTWARESPATH"
}

$WAVM_INSTALL_PATH = "$SOFTWARESPATH\wavm"

if ($NOINSTALLING -ne "yes") {

    # Create necessary directories
    if (-not (Test-Path -Path $WAVM_INSTALL_PATH)) {
        New-Item -ItemType Directory -Force -Path $WAVM_INSTALL_PATH
    }
    if ($env:OS -eq "Windows_NT") {
    $WAVM_FILES = @(
        "$ARCH-windows-gnu")
    }
    else {
    $WAVM_FILES = @(
        "$ARCH-windows-gnu"
        "$TRIPLE")
    }

    foreach ($file in $WAVM_FILES) {
        $destFilePath = "$WAVM_INSTALL_PATH/$file.tar.xz"
        if (Test-Path -Path $destFilePath) {
            Remove-Item -Force -Path $destFilePath
        }

        Write-Host "Downloading $file to $WAVM_INSTALL_PATH"
        Download-File -url "$WAVM_URL/$file.tar.xz" -dest $destFilePath

        Write-Host "Extracting $file.tar.xz to $WAVM_INSTALL_PATH"
        & { $env:XZ_OPT = '-T0'; tar -xf $destFilePath -C $WAVM_INSTALL_PATH }
    }
}

# Check and update PATH
function Update-Path {
    param (
        [string]$newPath
    )

    $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
    if ($currentPath -notlike "*$newPath*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$currentPath;$newPath", [System.EnvironmentVariableTarget]::User)
        Write-Host "Added $newPath to PATH"
    } else {
        Write-Host "$newPath is already in PATH"
    }
}

# Define the paths to check
if ($env:OS -eq "Windows_NT") {
$pathsToCheck = @(
    "$env:TOOLCHAINSPATH_LLVM\$TRIPLE\llvm\bin",
    "$env:TOOLCHAINSPATH_LLVM\$TRIPLE\compiler-rt\lib\windows",
    "$env:TOOLCHAINSPATH_LLVM\$TRIPLE\$TRIPLE\bin",
    "$WAVM_INSTALL_PATH\$TRIPLE\bin"
)

# Check each path and update PATH if necessary
foreach ($path in $pathsToCheck) {
    if (-not (Test-Path -Path $path)) {
        Write-Host "Path $path does not exist"
    } else {
        Update-Path -newPath $path
    }
}

}

exit 0