<#
.SYNOPSIS
    Install prebuilt GCC toolchains (GCC only!) on Windows.

.DESCRIPTION
    Downloads the Windows-hosted toolchains published in
        https://github.com/trcrsired/gcc-releases
    and unpacks them into the same layout the build scripts use:

        <TOOLCHAINSPATH_GNU>\<host>\<target>

    By default the four Windows/msdos targets of this architecture are
    installed, e.g. on an x86_64 Windows host:

        x86_64-w64-mingw32.i686-w64-mingw32
        x86_64-w64-mingw32.i586-msdosdjgpp
        x86_64-w64-mingw32.x86_64-w64-mingw32
        x86_64-w64-mingw32.aarch64-w64-mingw32

    and on an ARM64 Windows host the very same four, hosted by
    aarch64-w64-mingw32:

        aarch64-w64-mingw32.i686-w64-mingw32
        aarch64-w64-mingw32.i586-msdosdjgpp
        aarch64-w64-mingw32.x86_64-w64-mingw32
        aarch64-w64-mingw32.aarch64-w64-mingw32

    <prefix>\bin and <prefix>\lib are prepended to PATH: bin holds the
    compilers, lib holds the DLLs they and the programs they build need
    (libgcc_s_seh-1.dll, libstdc++-6.dll, libwinpthread-1.dll, ...).
    There is no LD_LIBRARY_PATH/WINEPATH to set on Windows, PATH is what the
    Windows loader uses (WINEPATH is only used by wine on Linux).

.PARAMETER ReleaseVersion
    Release tag to install, e.g. 20261101-gcc17. Defaults to
    $env:GCC_RELEASE_VERSION, then $env:RELEASE_VERSION, otherwise the newest
    "YYYYMMDD-gcc<N>" tag is queried from git.

.PARAMETER HostTriplet
    Override the detected Windows host triplet
    (x86_64-w64-mingw32 or aarch64-w64-mingw32).

.PARAMETER Targets
    Target triplets to install for that host. Defaults to
    i686-w64-mingw32, i586-msdosdjgpp, x86_64-w64-mingw32, aarch64-w64-mingw32.

.PARAMETER DownloadAll
    Install every toolchain of the release instead of the default set.

.PARAMETER ForceDownload
    Download even when the .tar.xz is already cached in
    <TOOLCHAINSPATH_GNU>\<host>\.

.PARAMETER AllowMissing
    Do not fail when one of the requested toolchains is not published in the
    release, just warn and continue (useful on hosts with a smaller asset set).

.PARAMETER DryRun
    Only print what would be installed, touch nothing.

.PARAMETER SetEnv
    $true (default): prepend the toolchain bin/lib dirs to the user PATH and to
    the current session. $false: leave PATH alone.

.EXAMPLE
    .\install-gcc.ps1

.EXAMPLE
    .\install-gcc.ps1 -HostTriplet aarch64-w64-mingw32 -Targets x86_64-w64-mingw32

.NOTES
    You may need to allow the script first:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

[CmdletBinding()]
param(
    [string]$ReleaseVersion = $(if ($env:GCC_RELEASE_VERSION) { $env:GCC_RELEASE_VERSION } elseif ($env:RELEASE_VERSION) { $env:RELEASE_VERSION } else { $null }),
    [string]$HostTriplet,
    [string[]]$Targets = @('i686-w64-mingw32', 'i586-msdosdjgpp', 'x86_64-w64-mingw32', 'aarch64-w64-mingw32'),
    [string]$ToolchainPath,
    [string]$ToolchainPathGnu,
    [string]$Repo = $(if ($env:GITHUB_BUILD_GCC_REPO) { $env:GITHUB_BUILD_GCC_REPO } else { 'trcrsired/gcc-releases' }),
    [switch]$DownloadAll,
    [switch]$ForceDownload,
    [switch]$AllowMissing,
    [switch]$DryRun,
    [bool]$SetEnv = $true
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

function Write-Info { param([string]$Message) Write-Host $Message }
function Write-Warn { param([string]$Message) Write-Host "warning: $Message" -ForegroundColor Yellow }
function Write-Err { param([string]$Message) Write-Host "error: $Message" -ForegroundColor Red }

# run a native program without letting its stderr turn into a terminating error
function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $FilePath @Arguments 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }

    return [pscustomobject]@{
        ExitCode = $code
        Output   = @($output | ForEach-Object { "$_" })
    }
}

# map the Windows architecture to the mingw host triplet
function Get-WindowsHostTriplet {
    # PROCESSOR_ARCHITEW6432 is set when a 32-bit PowerShell runs on 64-bit Windows
    $arch = $env:PROCESSOR_ARCHITEW6432
    if (-not $arch) { $arch = $env:PROCESSOR_ARCHITECTURE }
    if (-not $arch) {
        try {
            $code = (Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1).Architecture
            switch ($code) {
                0 { $arch = 'x86' }
                9 { $arch = 'AMD64' }
                12 { $arch = 'ARM64' }
                default { $arch = $null }
            }
        }
        catch {
            $arch = $null
        }
    }
    if (-not $arch) { throw 'cannot determine the Windows architecture (PROCESSOR_ARCHITECTURE unset)' }

    switch -Regex ($arch) {
        '^(AMD64|x86_64|X64)$' { return 'x86_64-w64-mingw32' }
        '^(ARM64|aarch64)$' { return 'aarch64-w64-mingw32' }
        '^(x86|i[3-6]86)$' { return 'i686-w64-mingw32' }
        default { throw "unsupported Windows architecture: $arch" }
    }
}

function Get-LatestReleaseVersion {
    if ($ReleaseVersion) { return $ReleaseVersion }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'git is not installed. Please pass -ReleaseVersion (e.g. 20261101-gcc17) instead.'
    }

    Write-Info "Querying the latest GCC release from github.com/$Repo ..."
    $result = Invoke-NativeCommand -FilePath 'git' -Arguments @('ls-remote', '--tags', "https://github.com/$Repo.git")
    if ($result.ExitCode -ne 0) {
        throw "git ls-remote failed for $Repo"
    }

    $tags = @(
        $result.Output |
            ForEach-Object { ($_ -split '\s+')[1] } |
            Where-Object { $_ } |
            ForEach-Object { $_ -replace '^refs/tags/', '' } |
            Where-Object { $_ -match '^\d{8}-gcc\d+$' }
    )

    if ($tags.Count -eq 0) {
        throw "no 'YYYYMMDD-gcc<N>' tag found in $Repo"
    }

    $best = $tags |
        Sort-Object -Property @{ Expression = { [int]($_ -replace '^(\d{8})-gcc(\d+)$', '$1') } },
                              @{ Expression = { [int]($_ -replace '^(\d{8})-gcc(\d+)$', '$2') } } -Descending |
        Select-Object -First 1

    return $best
}

# every "<host> <target>" pair published in a release (for -DownloadAll)
function Get-ReleasePairs {
    param([string]$Version)

    $url = "https://api.github.com/repos/$Repo/releases/tags/$Version"
    $release = Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = 'install-gcc.ps1' }

    $pairs = @()
    foreach ($asset in $release.assets) {
        if ($asset.name -match '^(.+?)\.(.+?)\.tar\.xz$') {
            $pairs += [pscustomobject]@{ Host = $Matches[1]; Target = $Matches[2] }
        }
    }
    return @($pairs | Sort-Object Host, Target)
}

function Save-Download {
    param([string]$Url, [string]$Destination)

    $tmp = "$Destination.part"
    if (Test-Path $tmp) { Remove-Item $tmp -Force }

    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        $result = Invoke-NativeCommand -FilePath 'curl.exe' `
            -Arguments @('-fL', '--retry', '3', '--retry-delay', '2', '-o', $tmp, $Url)
    }
    elseif (Get-Command curl -ErrorAction SilentlyContinue) {
        $result = Invoke-NativeCommand -FilePath 'curl' `
            -Arguments @('-fL', '--retry', '3', '--retry-delay', '2', '-o', $tmp, $Url)
    }
    else {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing
            $result = [pscustomobject]@{ ExitCode = 0; Output = @() }
        }
        catch {
            $result = [pscustomobject]@{ ExitCode = 1; Output = @("$($_.Exception.Message)") }
        }
    }

    if ($result.ExitCode -ne 0 -or (-not (Test-Path $tmp)) -or ((Get-Item $tmp).Length -eq 0)) {
        if (Test-Path $tmp) { Remove-Item $tmp -Force }
        return $false
    }

    Move-Item -Force $tmp $Destination
    return $true
}

function Expand-TarXz {
    param([string]$Archive, [string]$Destination)

    # Windows 10+ ships bsdtar as tar.exe and it understands .tar.xz
    if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
        $result = Invoke-NativeCommand -FilePath 'tar.exe' -Arguments @('-xf', $Archive, '-C', $Destination)
        if ($result.ExitCode -eq 0) { return $true }
        Write-Warn "tar.exe failed on $Archive"
    }

    if (Get-Command 7z.exe -ErrorAction SilentlyContinue) {
        $tmpDir = Join-Path $Destination ('.7z-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
        $result = Invoke-NativeCommand -FilePath '7z.exe' -Arguments @('x', '-y', "-o$tmpDir", $Archive)
        if ($result.ExitCode -ne 0) {
            Remove-Item $tmpDir -Recurse -Force
            return $false
        }
        $innerTar = Get-ChildItem -Path $tmpDir -Filter '*.tar' | Select-Object -First 1
        if (-not $innerTar) {
            Remove-Item $tmpDir -Recurse -Force
            return $false
        }
        $result = Invoke-NativeCommand -FilePath '7z.exe' -Arguments @('x', '-y', "-o$Destination", $innerTar.FullName)
        $code = $result.ExitCode
        Remove-Item $tmpDir -Recurse -Force
        return ($code -eq 0)
    }

    Write-Err 'neither tar.exe nor 7z.exe is available to extract .tar.xz archives'
    return $false
}

function Install-Toolchain {
    param(
        [string]$HostTriplet,
        [string]$Target,
        [string]$BaseUrl,
        [string]$GnuPath,
        [bool]$Strict
    )

    $name = "$HostTriplet.$Target"
    $hostDir = Join-Path $GnuPath $HostTriplet
    $archive = Join-Path $hostDir "$name.tar.xz"
    $prefix = Join-Path $hostDir $Target
    $url = "$BaseUrl/$name.tar.xz"

    Write-Info "==> $name"

    if ($DryRun) {
        Write-Info "    dry run: would download $url"
        Write-Info "    dry run: would extract into $hostDir"
        return $true
    }

    New-Item -ItemType Directory -Force -Path $hostDir | Out-Null
    if (Test-Path $prefix) { Remove-Item $prefix -Recurse -Force }

    $reused = $false
    if ((Test-Path $archive) -and ((Get-Item $archive).Length -gt 0) -and (-not $ForceDownload)) {
        Write-Info "    reusing existing $archive (use -ForceDownload to download again)"
        $reused = $true
    }

    if (-not $reused) {
        if (Test-Path $archive) { Remove-Item $archive -Force }
        Write-Info "    downloading $url"
        if (-not (Save-Download -Url $url -Destination $archive)) {
            if (Test-Path $archive) { Remove-Item $archive -Force }
            if ($Strict) { throw "failed to download $url" }
            Write-Warn "$name is not available in this release, skipping"
            return $false
        }
    }

    Write-Info "    extracting to $hostDir"
    if (-not (Expand-TarXz -Archive $archive -Destination $hostDir)) {
        if ($reused) {
            Write-Info '    cached archive is broken, downloading again'
            Remove-Item $archive -Force
            if (-not (Save-Download -Url $url -Destination $archive)) { throw "failed to download $url" }
            if (-not (Expand-TarXz -Archive $archive -Destination $hostDir)) { throw "failed to extract $archive" }
        }
        else {
            throw "failed to extract $archive"
        }
    }

    if (-not (Test-Path (Join-Path $prefix 'bin'))) {
        throw "$archive does not contain $Target\bin"
    }

    Write-Info "    installed $prefix"
    return $true
}

function Test-Toolchain {
    param([string]$HostTriplet, [string]$Target, [string]$GnuPath)

    $prefix = Join-Path (Join-Path $GnuPath $HostTriplet) $Target
    $binDir = Join-Path $prefix 'bin'
    $driver = Join-Path $binDir "$Target-g++.exe"
    if (-not (Test-Path $driver)) { $driver = Join-Path $binDir "$Target-gcc.exe" }
    if (-not (Test-Path $driver)) { $driver = Join-Path $binDir 'g++.exe' }

    if (-not (Test-Path $driver)) {
        Write-Warn "no g++/gcc driver found in $binDir"
        return
    }

    $result = Invoke-NativeCommand -FilePath $driver -Arguments @('--version')
    if ($result.ExitCode -eq 0 -and $result.Output.Count -gt 0) {
        Write-Info "    $driver -> $($result.Output[0])"
        return
    }

    Write-Warn "$driver fails to run:"
    foreach ($line in $result.Output) { Write-Warn "  $line" }
    Write-Info "    the DLLs of the toolchain live in $prefix\lib, that directory must be on PATH"
}

# prepend <prefix>\bin and <prefix>\lib to the user PATH and to this session
function Set-ToolchainEnv {
    param([string[]]$Prefixes)

    $wanted = @()
    foreach ($prefix in $Prefixes) {
        $wanted += (Join-Path $prefix 'bin')
        $wanted += (Join-Path $prefix 'lib')
    }

    $normalize = {
        param([string]$Entry)
        return $Entry.Trim().TrimEnd('\').ToLowerInvariant()
    }

    $stale = @{}
    foreach ($entry in $wanted) { $stale[(& $normalize $entry)] = $true }

    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @()
    if ($current) { $entries = @($current -split ';' | Where-Object { $_ -and $_.Trim() }) }

    $keep = @($entries | Where-Object { -not $stale.ContainsKey((& $normalize $_)) })
    $new = (@($wanted) + $keep) -join ';'

    if ($new -ne ($current -as [string])) {
        [Environment]::SetEnvironmentVariable('Path', $new, 'User')
        Write-Info "    updated the user PATH ($($wanted.Count) toolchain entries)"
    }
    else {
        Write-Info '    user PATH already up to date'
    }

    $session = @($env:Path -split ';' | Where-Object { $_ -and $_.Trim() })
    $sessionKeep = @($session | Where-Object { -not $stale.ContainsKey((& $normalize $_)) })
    $env:Path = (@($wanted) + $sessionKeep) -join ';'
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

if (-not $ToolchainPath) {
    if ($env:TOOLCHAINSPATH) { $ToolchainPath = $env:TOOLCHAINSPATH }
    elseif ($env:USERPROFILE) { $ToolchainPath = Join-Path $env:USERPROFILE 'toolchains' }
    elseif ($HOME) { $ToolchainPath = Join-Path $HOME 'toolchains' }
    else { throw 'cannot determine HOME, please pass -ToolchainPath' }
}
if (-not $ToolchainPathGnu) {
    if ($env:TOOLCHAINSPATH_GNU) { $ToolchainPathGnu = $env:TOOLCHAINSPATH_GNU }
    else { $ToolchainPathGnu = Join-Path $ToolchainPath 'gnu' }
}

if (-not $HostTriplet) { $HostTriplet = Get-WindowsHostTriplet }
Write-Info "Windows host: $HostTriplet"

$version = Get-LatestReleaseVersion
$baseUrl = "https://github.com/$Repo/releases/download/$version"
Write-Info "Release: $version"
Write-Info "Install prefix: $ToolchainPathGnu"

$pairs = @()
if ($DownloadAll) {
    Write-Info 'DownloadAll: installing every toolchain published in the release'
    foreach ($pair in (Get-ReleasePairs -Version $version)) {
        $pairs += [pscustomobject]@{ Host = $pair.Host; Target = $pair.Target; Strict = $false }
    }
}
else {
    foreach ($target in $Targets) {
        $pairs += [pscustomobject]@{ Host = $HostTriplet; Target = $target; Strict = (-not $AllowMissing) }
    }
}

if ($pairs.Count -eq 0) { throw 'nothing to install' }

$installed = @()
foreach ($pair in $pairs) {
    $ok = Install-Toolchain -HostTriplet $pair.Host -Target $pair.Target `
        -BaseUrl $baseUrl -GnuPath $ToolchainPathGnu -Strict $pair.Strict
    if ($ok -and (-not $DryRun)) {
        $installed += (Join-Path (Join-Path $ToolchainPathGnu $pair.Host) $pair.Target)
    }
}

if ($DryRun) {
    Write-Info ''
    Write-Info 'dry run finished, nothing was installed'
    return
}

if ($SetEnv -and $installed.Count -gt 0) {
    Write-Info ''
    Write-Info 'Configuring PATH ...'
    Set-ToolchainEnv -Prefixes $installed
}

Write-Info ''
Write-Info "Done. Installed toolchains under $ToolchainPathGnu`:"
foreach ($prefix in $installed) {
    if (Test-Path $prefix) { Write-Info "  $prefix" }
}

if ($SetEnv) {
    Write-Info ''
    Write-Info 'PATH was updated for this session and for the current user.'
    Write-Info 'Open a new terminal so every process sees it.'
}

Write-Info ''
Write-Info 'Checking the installed compilers:'
foreach ($pair in $pairs) {
    if ($pair.Host -ne $HostTriplet) { continue }
    if (-not (Test-Path (Join-Path (Join-Path $ToolchainPathGnu $pair.Host) $pair.Target))) { continue }
    Test-Toolchain -HostTriplet $pair.Host -Target $pair.Target -GnuPath $ToolchainPathGnu
}
