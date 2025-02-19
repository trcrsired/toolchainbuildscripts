# Function to get the latest release version
function Get-WAVMLatestReleaseVersion {
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
        } else {
            $env:WAVM_RELEASE_VERSION = $WAVM_RELEASE_VERSION
        }
    } else {
        Write-Host "Git is not installed. Please install it or set the RELEASE_VERSION environment variable."
        exit 1
    }
}

# Check if WAVM_RELEASE_VERSION is not set
if (-not $env:WAVM_RELEASE_VERSION) {
    Get-WAVMLatestReleaseVersion
} else {
    $WAVM_RELEASE_VERSION = $env:WAVM_RELEASE_VERSION
}

Write-Host "Latest WAVM release version: $env:WAVM_RELEASE_VERSION"
